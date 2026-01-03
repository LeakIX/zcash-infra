# Run your own Zcash infrastructure

WARNING: zebra + zaino is not fully working, yet. An updated README will be
provided to deploy more efficiently on different cloud providers and bare metal
servers.

The endgoal of this repository is to maintain an easy-to-deploy Zcash
infrastructure using docker-compose and rely on Makefile targets. A setup using
[cloud-init](https://cloudinit.readthedocs.io/en/latest/) is being developed to
be used on different kind of servers, and get a "one-click" deployment.

See [the roadmap](#roadmap) for more information.

![zcash grafana](./.img/grafana.jpeg)

## Table of Contents

- [Environment Configuration](#environment-configuration)
- [Docker Compose Structure](#docker-compose-structure)
  - [Running the Services](#running-the-services)
- [Monitoring Setup](#monitoring-setup)
  - [Setup Instructions](#setup-instructions)
  - [Zcash Metrics](#zcash-metrics)
  - [Automatic Dashboard Provisioning](#automatic-dashboard-provisioning)
  - [Security Notes](#security-notes)
  - [Determining Container User IDs](#determining-container-user-ids)
- [Data Directory Setup](#data-directory-setup)
  - [Example: Hetzner Server Setup](#example-hetzner-server-setup)
- [Service Data Directories Setup](#service-data-directories-setup)
  - [Zcash Services (zcashd & lightwalletd)](#zcash-services-zcashd--lightwalletd)
    - [Zcash Configuration](#zcash-configuration)
  - [Caddy Web Server](#caddy-web-server)
  - [Monitoring Services](#monitoring-services)

## Environment Configuration

All configuration settings are stored in the `.env` file, including:

- `DATA_DIR`: The path where all persistent data will be stored
- Service configuration:
  - `ZCASH_NETWORK`: Network to connect to (mainnet, testnet, etc.)
  - `EXTERNAL_IP`: Your node's public IP address (for Zebra)
  - `ZCASH_CONF_FILENAME`: Name of the Zcash configuration file
- Port configuration (all optional with sensible defaults):
  - `ZCASHD_RPC_PORT`: RPC port for zcashd (default: 8232)
  - `ZCASHD_P2P_PORT`: P2P port for zcashd (default: 8233)
  - `LIGHTWALLETD_PORT`: gRPC port for lightwalletd (default: 9067)
  - `ZEBRA_RPC_PORT`: RPC port for Zebra (default: 8232)
  - `ZEBRA_P2P_PORT`: P2P port for Zebra (default: 8233)
  - `ZEBRA_METRICS_PORT`: Metrics port for Zebra (default: 3000)
- Web UI configuration:
  - `CADDY_CONFIG_PATH`: The path to the Caddy configuration file
  - `GRAFANA_DOMAIN`: The domain name for Grafana (e.g., foo.bar.com)
  - `GRAFANA_ROOT_URL`: The root URL for Grafana (e.g., https://foo.bar.com)
  - `GRAFANA_SERVE_FROM_SUB_PATH`: Whether Grafana is served from a sub-path
- Credentials and other sensitive configuration:
  - `LIGHTWALLETD_RPC_USER`/`LIGHTWALLETD_RPC_PASSWORD`: For lightwalletd to
    connect to zcashd
  - `ZEBRA_RPC_USER`/`ZEBRA_RPC_PASSWORD`: For services to connect to Zebra
  - `GRAFANA_ADMIN_USER`/`GRAFANA_ADMIN_PASSWORD`: For Grafana admin login

See the `.env.template` file for a complete list of configurable parameters.

Make sure to modify default values before deploying to production.

## Docker Compose Structure

The services are organized in separate Docker Compose files:

1. `docker-compose.zcash.yml`: Contains zcashd and lightwalletd services
2. `docker-compose.zebra.yml`: Contains zebra (Rust implementation) and zaino
   (indexer) services
   - Note: The Zaino image needs to be built manually before first use.

   **Zaino Build Workflow**:

   For production/stable use:

   ```bash
   # Build Zaino from the latest main branch
   make build-zaino

   # Start Zebra services with the latest Zaino
   make start-zebra
   ```

   For testing a specific commit:

   ```bash
   # 1. Build Zaino from a specific commit
   make build-zaino-commit COMMIT=abc123def456

   # 2. Update docker-compose to use that specific commit
   make update-zaino-commit COMMIT=abc123def456

   # 3. Start Zebra services with the specified Zaino version
   make start-zebra
   ```

   When you're done testing, you can return to the latest version:

   ```bash
   # Clean up all Zaino images
   make clean-zaino

   # Rebuild with the latest version
   make build-zaino

   # Start Zebra services with latest Zaino
   make start-zebra
   ```

3. `docker-compose.caddy.yml`: Contains the Caddy web server
4. `docker-compose.monitoring.yml`: Contains monitoring stack (Prometheus, Node
   Exporter, Grafana)

### Running the Services

#### Using the Makefile (Recommended)

A Makefile is provided to simplify common tasks:

```bash
# Show all available commands
make help

# Setup all required directories with proper permissions
make setup

# Start all services
make start-all

# Start just specific components
make start-zcash      # Start zcashd and lightwalletd
make start-zebra      # Start zebra and zaino
make start-caddy
make start-monitoring

# Check service status
make status

# View logs
make logs

# Stop all services
make stop-all
```

#### Using Docker Compose Directly

If you prefer to use Docker Compose commands directly:

```bash
# Start Zcash services
docker-compose -f docker-compose.zcash.yml up -d

# Start Caddy web server
docker-compose -f docker-compose.caddy.yml up -d

# Start monitoring stack
docker-compose -f docker-compose.monitoring.yml up -d

# Start all services together
docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml up -d

# Stop specific services
docker-compose -f docker-compose.zcash.yml down
```

## Monitoring Setup

The monitoring stack consists of Prometheus, Node Exporter, a custom Zcash
exporter, and Grafana configured to monitor system and Zcash node resources.

### Setup Instructions

1. Prepare the data directories (see
   [Data Directories Setup](#data-directories-setup)) - requires sudo privileges

2. Start the monitoring stack:

```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

3. Access Grafana at https://foo.bar.com
   - Login credentials are defined in the `.env` file
   - Prometheus data source is automatically configured
   - Node Exporter and Zcash dashboards are automatically provisioned

### Zcash Metrics

The infrastructure includes a custom Python-based Zcash metrics exporter
(`scripts/zcash-exporter.py`) that collects data from the Zcash node via RPC and
exposes it in Prometheus format. The metrics include:

- Block height and sync progress
- Network difficulty and hashrate
- Peer connections
- Blockchain size
- Memory usage by the node
- Mempool statistics
- Transaction metrics

These metrics are visualized in the Zcash dashboard in Grafana, providing a
comprehensive view of your node's performance and the network status.

### Automatic Dashboard Provisioning

The setup includes automatic provisioning for Grafana:

- Prometheus data source is automatically added
- A Node Exporter dashboard for monitoring CPU, memory, disk I/O, and network is
  included
- A Zcash dashboard for monitoring blockchain and node metrics including:
  - Block height and sync progress
  - Network difficulty and hashrate
  - Peer connections and mempool statistics
  - Memory usage and blockchain size
  - Transaction metrics
- All configurations are in the `grafana/` directory

### Security Notes

- Prometheus and Node Exporter are only accessible within the Docker network
- Only Grafana is exposed publicly through Caddy reverse proxy at foo.bar.com
- All sensitive credentials are stored in the `.env` file
- Change all default credentials in the `.env` file for production deployments
- Default credentials are provided only for development purposes

### Determining Container User IDs

To check the user IDs inside Docker containers (useful for setting volume
permissions):

```bash
# Check Prometheus user ID
docker run --rm --entrypoint "/bin/sh" prom/prometheus:latest -c "id"
# Output: uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)

# Check Grafana user ID
docker run --rm --entrypoint "/bin/sh" grafana/grafana:latest -c "id"
# Output: uid=472(grafana) gid=0(root) groups=0(root)
```

## Data Directory Setup

The data directory is configured in the `.env` file as `DATA_DIR`. By default,
it's set to `/media/data-disk`, but you can change it to any location suitable
for your environment.

### Example: Hetzner Server Setup

If using a Hetzner server, the data disk is not mounted automatically by
default, and an entry in `/etc/fstab` must be added. For instance:

```shell
# Data for zcashd and lightwalletd
/dev/nvme2n1p1                            /media/data-disk ext4 defaults 0 0
```

To mount the disk manually in case the automatic mounting does not work:

```shell
sudo mount -t ext4 /dev/nvme2n1p1 /media/data-disk/
```

You can also check that the file `/etc/fstab` is well-formed by using:

```
sudo mount -a
```

before rebooting the server

## Data Directories Setup

Before starting services, you'll need to create and set proper permissions for
all data directories. Most of these commands require sudo privileges, especially
if the DATA_DIR is in a system location or has restricted permissions:

### Zcash Services (zcashd, lightwalletd, zebra & zaino)

```bash
# Replace DATA_DIR with your actual data directory path from .env
sudo mkdir -p ${DATA_DIR}/zcashd_data
sudo mkdir -p ${DATA_DIR}/lightwalletd_db_volume
sudo mkdir -p ${DATA_DIR}/zebra_data
sudo mkdir -p ${DATA_DIR}/zaino_data
# Set ownership for lightwalletd (based on
# https://zcash.readthedocs.io/en/latest/rtd_pages/lightwalletd.html)
sudo chown 2002 ${DATA_DIR}/lightwalletd_db_volume
```

#### Zcash and Zebra Configuration

Template configuration files are provided for both node implementations:

- **zcashd**: `zcash.conf.template` is copied to
  `${DATA_DIR}/zcashd_data/zcash.conf` when running `make setup`, with RPC
  credentials automatically replaced from your `.env` file.

- **zebra**: `zebra.toml.template` is copied to
  `${DATA_DIR}/zebra_data/zebra.toml` when running `make setup`, with the
  external IP address automatically replaced from your `.env` file.

The zcash.conf file includes:

- Network configuration for external connectivity
- RPC authentication settings
- Performance optimizations
- Reliable seed nodes for initial connection
- Security settings
- Useful debug configurations

You can modify this file manually after setup if you need to fine-tune the
configuration.

### Caddy Web Server

```bash
# Create directories for Caddy
sudo mkdir -p ${DATA_DIR}/caddy_data
sudo mkdir -p ${DATA_DIR}/caddy_config
# You may need to set permissions if Caddy has permission issues
# sudo chown -R 1000:1000 ${DATA_DIR}/caddy_data ${DATA_DIR}/caddy_config
```

### Monitoring Services

```bash
# Create directories for Prometheus and Grafana
sudo mkdir -p ${DATA_DIR}/prometheus_data
sudo mkdir -p ${DATA_DIR}/grafana_data
# Set ownership for Prometheus (nobody user, uid 65534)
sudo chown 65534:65534 ${DATA_DIR}/prometheus_data
# Set ownership for Grafana (uid 472) and ensure it has full permissions
sudo chown -R 472:0 ${DATA_DIR}/grafana_data
sudo chmod -R 755 ${DATA_DIR}/grafana_data
```

## Roadmap

- [ ] Provide cloud-init files
- [ ] Provide different cloud providers setup instructions
- [ ] Setting firewalls automatically
- [ ] Integrate with one Internet scanner, like [LeakIX](https://leakix.net) to
      detect misconfigurations and setting up notifications for
      outdated/vulnerable infrastructure.
