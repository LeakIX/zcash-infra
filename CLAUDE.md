# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

Docker-based Zcash blockchain infrastructure deployment framework. Provides
containerized setup for running Zcash nodes with monitoring, reverse proxy, and
light wallet capabilities.

**Note:** zebra + zaino integration is still in development.

## Common Commands

```bash
# Initial setup (creates directories, sets permissions, generates configs from templates)
make setup

# Service management
make start-all              # Start all services
make stop-all               # Stop all services
make status                 # Check service status
make logs                   # Stream logs from all services

# Individual service control
make start-zcash            # zcashd + lightwalletd
make start-zebra            # zebra + zaino
make start-caddy            # Caddy reverse proxy
make start-monitoring       # Prometheus + Node Exporter + Grafana

# Zaino build (required before first zebra start)
make build-zaino                                    # Build from latest main
make build-zaino-commit COMMIT=<hash>              # Build specific commit
make update-zaino-commit COMMIT=<hash>             # Update docker-compose to use commit

# Diagnostics
make check-zcash-exporter   # Verify metrics collection

# Cleanup (destructive)
make clean                  # Remove all containers and volumes
make clean-zaino            # Remove Zaino images and build dir

# View all targets
make help
```

## Architecture

### Service Stacks

Two node implementation options (run one OR the other):

- **zcashd stack**: `docker-compose.zcash.yml` - zcashd + lightwalletd
- **zebra stack**: `docker-compose.zebra.yml` - zebra + zaino (built from
  source)

Supporting services:

- `docker-compose.caddy.yml` - Caddy reverse proxy with TLS termination
- `docker-compose.monitoring.yml` - Prometheus + Node Exporter + Grafana +
  zcash-exporter

### Network and Data Flow

All containers communicate via `zcash-network` Docker network. Caddy handles
TLS; internal services use plaintext/h2c.

```
External → Caddy (TLS) → lightwalletd/zaino (gRPC) → zcashd/zebra (RPC)
                       → Grafana (web UI)
```

### Data Persistence

All data stored in `${DATA_DIR}` (default: `/media/data-disk`). Key UIDs for
volume permissions:

- `lightwalletd_db_volume/` - uid 2002
- `zebrad-data/` - uid 2001
- `zaino-data/` - uid 2003
- `prometheus_data/` - uid 65534
- `grafana_data/` - uid 472

### Configuration

- `.env` - All environment variables (copy from `.env.template`)
- `*.template` files generate configs during `make setup` via sed substitution

### Key Ports

- zcashd/zebra RPC: 8232, P2P: 8233
- lightwalletd gRPC: 9067
- zaino gRPC: 8137
- Grafana: 3000, Prometheus: 9090, Node Exporter: 9100, Zcash Exporter: 9101

### Custom Components

`scripts/zcash-exporter.py` - Python Prometheus exporter that polls zcashd RPC
for blockchain metrics (block height, difficulty, peers, mempool stats).

## Development Guidelines

### Branching Strategy

The repository uses a protected main branch for production code with no direct
pushes permitted. All pull requests should target the develop branch instead.
Feature branches require descriptive naming conventions such as
`fix/dark-mode-seed-display` or `feat/qr-codes`.

### Changelog

Every modification requires a corresponding entry in CHANGELOG.md, which CI
enforces. The entry must appear in a separate commit from code changes and
include issue and PR references. The project follows Keep a Changelog format
with entries placed under the Unreleased section using categories like Added,
Changed, Fixed, and Security.

### Commit Standards

- No emojis in commit messages
- Do not add Claude as co-author
- Wrap commit message titles at 72 characters
- Wrap commit message body at 80 characters
- Use conventional commit prefixes: `feat:`, `fix:`, `docs:`, `chore:`,
  `refactor:`, `test:`
