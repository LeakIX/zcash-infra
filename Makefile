# Makefile for Zcash Infrastructure

# Check if .env file exists and load it
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values if not defined in .env
DATA_DIR ?= /media/data-disk

# Set SUDO to empty for local development: make setup SUDO=
SUDO ?= sudo

# macOS sed requires '' for in-place, GNU sed does not
SEDI := $(shell if sed --version 2>/dev/null | grep -q GNU; then echo 'sed -i'; else echo 'sed -i ""'; fi)

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Create all required directories and set permissions
	@echo "Setting up directories and permissions for Zcash infrastructure..."
	@echo "Using DATA_DIR: $(DATA_DIR)"

	@echo "Creating Zcash service directories..."
	$(SUDO) mkdir -p $(DATA_DIR)/zcashd_data
	$(SUDO) mkdir -p $(DATA_DIR)/lightwalletd_db_volume
	$(if $(SUDO),$(SUDO) chown 2002 $(DATA_DIR)/lightwalletd_db_volume)

	@echo "Setting up zcash.conf file (updating if necessary)"
	cp zcash.conf.template zcash.conf; \
	$(SEDI) "s/LIGHTWALLETD_RPC_USER/$(LIGHTWALLETD_RPC_USER)/g" zcash.conf; \
	$(SEDI) "s/LIGHTWALLETD_RPC_USER/$(LIGHTWALLETD_RPC_USER)/g" zcash.conf; \
	$(SEDI) "s/LIGHTWALLETD_RPC_PASSWORD/$(LIGHTWALLETD_RPC_PASSWORD)/g" zcash.conf; \
	echo "Created new zcash.conf file with proper credentials. Copying in $(DATA_DIR)/zcashd/zcash.conf"; \
	$(SUDO) cp -f zcash.conf $(DATA_DIR)/zcashd_data/zcash.conf

	@echo "Setting up zebrad.toml (updating if necessary)"
	@cp -f zebrad.toml.template zebrad.toml
	$(SEDI) "s/ZEBRA_P2P_PORT/$(ZEBRA_P2P_PORT)/g" zebrad.toml
	$(SEDI) "s/ZEBRA_RPC_PORT/$(ZEBRA_RPC_PORT)/g" zebrad.toml

	@echo "Setting up zaino.toml (updating if necessary)"
	@cp -f zaino.toml.template zaino.toml
	$(SEDI) "s/ZAINO_GRPC_PORT/$(ZAINO_GRPC_PORT)/g" zaino.toml
	$(SEDI) "s/ZEBRA_RPC_PORT/$(ZEBRA_RPC_PORT)/g" zaino.toml

	@echo "Creating Caddy directories..."
	$(SUDO) mkdir -p $(DATA_DIR)/caddy_data
	$(SUDO) mkdir -p $(DATA_DIR)/caddy_config

	@echo "Creating monitoring directories..."
	$(SUDO) mkdir -p $(DATA_DIR)/prometheus_data
	$(SUDO) mkdir -p $(DATA_DIR)/grafana_data
	$(if $(SUDO),$(SUDO) chown 65534:65534 $(DATA_DIR)/prometheus_data)
	$(if $(SUDO),$(SUDO) chown -R 472:0 $(DATA_DIR)/grafana_data)
	$(if $(SUDO),$(SUDO) chmod -R 755 $(DATA_DIR)/grafana_data)

	@echo "Creating zebrad directories..."
	$(SUDO) mkdir -p $(DATA_DIR)/zebrad-data
	$(if $(SUDO),$(SUDO) chown -R 2001:2001 $(DATA_DIR)/zebrad-data)

	@echo "Creating zaino directories..."
	$(SUDO) mkdir -p $(DATA_DIR)/zaino-data
	$(if $(SUDO),$(SUDO) chown -R 2003:2003 $(DATA_DIR)/zaino-data)

	@echo "Creating Docker network..."
	-docker network create zcash-network 2>/dev/null || true

	@echo "Setup complete! You can now start services with 'make start-all'"

.PHONY: start-all
start-all: ## Start all services (Zcash, Caddy, and monitoring)
	@echo "Starting all services (zcash, caddy, monitoring)..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml up -d
	@echo "All services started successfully"

.PHONY: start-zcash
start-zcash: ## Start Zcash services only (zcashd and lightwalletd)
	@echo "Starting Zcash services (zcashd + lightwalletd)..."
	docker-compose -f docker-compose.zcash.yml up -d
	@echo "Zcash services started successfully"

.PHONY: start-zebra
start-zebra: ## Start Zebra services only (zebra and zaino)
	@echo "Starting Zebra (zebrad + zaino) services..."
	@echo "zebrad starts first, and zaino container might restart multiple times until zebrad is ready"
	docker-compose -f docker-compose.zebra.yml up -d
	@echo "Zebra services started successfully"

.PHONY: start-caddy
start-caddy: ## Start Caddy web server only
	@echo "Starting Caddy web server..."
	docker-compose -f docker-compose.caddy.yml up -d
	@echo "Caddy web server started successfully"

.PHONY: start-monitoring
start-monitoring: ## Start monitoring stack (Prometheus, Node Exporter, Grafana)
	@echo "Starting monitoring stack (Prometheus, Zcashd exporter, Node exporter, Grafana)..."
	docker-compose -f docker-compose.monitoring.yml pull
	docker-compose -f docker-compose.monitoring.yml up -d
	@echo "Monitoring stack started successfully"
	@echo "You can run make check-zcash-exporter to verify that data are fetched from zcash"
	@echo "You can visit http://localhost:3000/login to access Grafana and monitor the health of the node"

.PHONY: setup-testnet
setup-testnet: ## Create testnet directories and config files
	@echo "Setting up testnet directories..."
	$(SUDO) mkdir -p $(DATA_DIR)/zcashd_testnet_data
	$(SUDO) mkdir -p $(DATA_DIR)/lightwalletd_testnet_db
	$(SUDO) mkdir -p $(DATA_DIR)/zebrad-testnet-cache
	$(SUDO) mkdir -p $(DATA_DIR)/zaino-testnet-data
	$(if $(SUDO),$(SUDO) chown 2002 $(DATA_DIR)/lightwalletd_testnet_db)
	$(if $(SUDO),$(SUDO) chown -R 2001:2001 $(DATA_DIR)/zebrad-testnet-cache)
	$(if $(SUDO),$(SUDO) chown -R 2003:2003 $(DATA_DIR)/zaino-testnet-data)

	@echo "Setting up testnet config files..."
	@cp -f zcash.conf.testnet.template zcash.testnet.conf
	$(SEDI) "s/LIGHTWALLETD_RPC_USER/$(LIGHTWALLETD_RPC_USER)/g" zcash.testnet.conf
	$(SEDI) "s/LIGHTWALLETD_RPC_PASSWORD/$(LIGHTWALLETD_RPC_PASSWORD)/g" zcash.testnet.conf
	$(SUDO) cp -f zcash.testnet.conf $(DATA_DIR)/zcashd_testnet_data/zcash.conf

	@cp -f zebrad.toml.testnet.template zebrad.testnet.toml
	$(SEDI) "s/ZEBRA_P2P_PORT/18233/g" zebrad.testnet.toml
	$(SEDI) "s/ZEBRA_RPC_PORT/18232/g" zebrad.testnet.toml

	@cp -f zaino.toml.testnet.template zaino.testnet.toml
	$(SEDI) "s/ZAINO_GRPC_PORT/8137/g" zaino.testnet.toml
	$(SEDI) "s/ZEBRA_RPC_PORT/8232/g" zaino.testnet.toml

	@echo "Testnet setup complete!"

.PHONY: start-zcash-testnet
start-zcash-testnet: ## Start Zcash testnet services (zcashd-testnet and lightwalletd-testnet)
	@echo "Starting Zcash testnet services..."
	docker-compose -f docker-compose.zcash.testnet.yml up -d
	@echo "Zcash testnet services started successfully"

.PHONY: start-zebra-testnet
start-zebra-testnet: ## Start Zebra testnet services (zebra-testnet and zaino-testnet)
	@echo "Starting Zebra testnet services..."
	docker-compose -f docker-compose.zebra.testnet.yml up -d
	@echo "Zebra testnet services started successfully"

.PHONY: stop-zcash-testnet
stop-zcash-testnet: ## Stop Zcash testnet services
	@echo "Stopping Zcash testnet services..."
	docker-compose -f docker-compose.zcash.testnet.yml down
	@echo "Zcash testnet services stopped successfully"

.PHONY: stop-zebra-testnet
stop-zebra-testnet: ## Stop Zebra testnet services
	@echo "Stopping Zebra testnet services..."
	docker-compose -f docker-compose.zebra.testnet.yml down
	@echo "Zebra testnet services stopped successfully"

.PHONY: stop-all
stop-all: ## Stop all services
	@echo "Stopping all services..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml down
	@echo "All services stopped successfully"

.PHONY: stop-zcash
stop-zcash: ## Stop Zcash services only
	@echo "Stopping Zcash services..."
	docker-compose -f docker-compose.zcash.yml down
	@echo "Zcash services stopped successfully"

.PHONY: stop-zebra
stop-zebra: ## Stop Zebra services only
	@echo "Stopping Zebra services..."
	docker-compose -f docker-compose.zebra.yml down
	@echo "Zebra services stopped successfully"

.PHONY: stop-caddy
stop-caddy: ## Stop Caddy web server only
	@echo "Stopping Caddy web server..."
	docker-compose -f docker-compose.caddy.yml down
	@echo "Caddy web server stopped successfully"

.PHONY: stop-monitoring
stop-monitoring: ## Stop monitoring stack only
	@echo "Stopping monitoring stack..."
	docker-compose -f docker-compose.monitoring.yml down
	@echo "Monitoring stack stopped successfully"

.PHONY: logs
logs: ## Show logs for all services
	@echo "Showing logs for all services (press Ctrl+C to exit)..."
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml logs -f

.PHONY: status
status: ## Check status of all services
	@echo "Service status:"
	docker-compose -f docker-compose.zcash.yml -f docker-compose.caddy.yml -f docker-compose.monitoring.yml ps

.PHONY: lint
lint: ## Validate docker-compose files and lint YAML
	@echo "Validating Docker Compose files..."
	docker compose -f docker-compose.zcash.yml config --quiet
	docker compose -f docker-compose.zebra.yml config --quiet
	docker compose -f docker-compose.caddy.yml config --quiet
	docker compose -f docker-compose.monitoring.yml config --quiet
	@echo "Linting YAML files..."
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -d "{extends: relaxed, rules: {line-length: disable}}" *.yml prometheus.yml; \
	else \
		echo "Warning: yamllint not installed, skipping YAML linting (pip install yamllint)"; \
	fi
	@echo "All checks passed!"

.PHONY: format
format: ## Format YAML and Markdown files with prettier
	@echo "Formatting files with prettier..."
	@if command -v prettier >/dev/null 2>&1; then \
		prettier --write "*.yml" "*.yaml" "*.md" ".github/**/*.yml" 2>/dev/null || true; \
	else \
		echo "Error: prettier not installed (npm install -g prettier)"; \
		exit 1; \
	fi
	@echo "Formatting complete!"

.PHONY: format-check
format-check: ## Check if files are formatted correctly
	@echo "Checking file formatting..."
	@if command -v prettier >/dev/null 2>&1; then \
		prettier --check "*.yml" "*.yaml" "*.md" ".github/**/*.yml" 2>/dev/null || true; \
	else \
		echo "Error: prettier not installed (npm install -g prettier)"; \
		exit 1; \
	fi

.PHONY: check-zcash-exporter
check-zcash-exporter: ## Verify the Zcash metrics exporter is working
	@echo "Checking Zcash exporter metrics endpoint..."
	@echo "This will show if the exporter is working and collecting metrics from the Zcash node."
	@curl -s http://localhost:9101/metrics | grep zcash || { echo "Failed to get metrics - check if the zcash-exporter container is running"; exit 1; }
	@echo "\nZcash exporter is working correctly and collecting metrics."

.PHONY: restart-zcash-exporter
restart-zcash-exporter: ## Restart the Zcash metrics exporter container
	@echo "Restarting Zcash exporter container..."
	docker-compose -f docker-compose.monitoring.yml restart zcash-exporter
	@echo "Waiting for exporter to initialize (5 seconds)..."
	@sleep 5
	@echo "Checking metrics endpoint:"
	@curl -s http://localhost:9101/metrics | head -n 10
	@echo "\nZcash exporter has been restarted."

.PHONY: build-zaino
build-zaino: ## Build the Zaino Docker image from source (latest version)
	@echo "Building Zaino Docker image..."
	@if [ ! -d "tmp/zaino" ]; then \
		echo "Cloning Zaino repository..."; \
		mkdir -p tmp && \
		git clone --depth=1 https://github.com/zingolabs/zaino.git tmp/zaino; \
	else \
		echo "Updating Zaino repository..."; \
		cd tmp/zaino && git pull; \
	fi
	@echo "Applying Dockerfile patch to use compile with test_only_very_insecure to run behind Caddy..."
	@cd tmp/zaino && \
	patch -p1 < ../../zaino.dockerfile.no-tls.patch || echo "Patch may have already been applied"
	@echo "Building Docker image (this may take a while)..."
	@cd tmp/zaino && \
	docker build -t zingolabs/zaino:latest --build-arg NO_TLS=true .
	@echo "Zaino Docker image has been built successfully."
	@echo "You can now start Zebra services with 'make start-zebra'"

.PHONY: build-zaino-commit
build-zaino-commit: ## Build Zaino from a specific commit (COMMIT=<hash>)
	@if [ -z "$(COMMIT)" ]; then \
		echo "ERROR: COMMIT parameter is required. Usage: make build-zaino-commit COMMIT=<commit-hash>"; \
		exit 1; \
	fi
	@echo "Building Zaino Docker image from commit $(COMMIT)..."
	@if [ ! -d "tmp/zaino" ]; then \
		echo "Cloning Zaino repository..."; \
		mkdir -p tmp && \
		git clone https://github.com/zingolabs/zaino.git tmp/zaino; \
	else \
		echo "Repository already exists, fetching updates..."; \
		cd tmp/zaino && git fetch; \
	fi
	@echo "Applying Dockerfile patch to use compile with test_only_very_insecure to run behind Caddy..."
	@cd tmp/zaino && \
	patch -p1 < ../../zaino-dockerfile-tls.patch || echo "Patch may have already been applied"
	@echo "Checking out commit $(COMMIT)..."
	@cd tmp/zaino && git checkout $(COMMIT)
	@echo "Building Docker image (this may take a while)..."
	@cd tmp/zaino && \
	docker build -t zingolabs/zaino:$(COMMIT) --build-arg NO_TLS=true .
	@echo "Zaino Docker image has been built successfully from commit $(COMMIT)."
	@echo "To use this specific commit, run: make update-zaino-commit COMMIT=$(COMMIT)"
	@echo "You can now start Zebra services with 'make start-zebra'"

.PHONY: update-zaino-commit
update-zaino-commit: ## Update docker-compose to use a specific Zaino commit (COMMIT=<hash>)
	@if [ -z "$(COMMIT)" ]; then \
		echo "ERROR: COMMIT parameter is required. Usage: make update-zaino-commit COMMIT=<commit-hash>"; \
		exit 1; \
	fi
	@echo "Updating docker-compose.zebra.yml to use Zaino commit $(COMMIT)..."
	@$(SEDI) 's|image: zingolabs/zaino:.*|image: zingolabs/zaino:$(COMMIT)  # Build with '\''make build-zaino-commit COMMIT=$(COMMIT)'\''|' docker-compose.zebra.yml
	@echo "Docker Compose configuration updated to use Zaino commit $(COMMIT)."
	@echo "Run 'make start-zebra' to apply the changes."

.PHONY: clean
clean: clean-zcash ## Remove all containers and volumes (WARNING: destructive!)
	@echo "WARNING: This will remove all containers and volumes. Data may be lost!"
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Removing all services and volumes..."
	docker-compose -f docker-compose.caddy.yml -f docker-compose.monitoring.yml down -v
	@echo "Cleanup complete"

.PHONY: clean-zcash
clean-zcash: ## Remove Zcash containers and data volumes (WARNING: destructive!)
	@echo "WARNING: This will remove all containers and volumes. Data may be lost!"
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Revoming zcash services, including the directories"
	docker-compose -f docker-compose.zcash.yml down -v
	@echo "Delete Zcash directories..."
	$(SUDO) rm -rf $(DATA_DIR)/zcashd_data
	$(SUDO) rm -rf $(DATA_DIR)/lightwalletd_db_volume

.PHONY: clean-zaino
clean-zaino: ## Remove Zaino Docker image and build directory
	@echo "Cleaning Zaino Docker images and build directory..."
	@echo "Removing Zaino Docker images..."
	-docker images zingolabs/zaino --format "{{.Repository}}:{{.Tag}}" | xargs -r docker rmi 2>/dev/null || true
	@echo "Removing Zaino build directory..."
	-rm -rf tmp/zaino
	@echo "Zaino cleanup complete."

.PHONY: clean-networks
clean-networks: ## Remove all Docker networks (WARNING: destructive!)
	@echo "WARNING: This will attempt to remove ALL Docker networks. Running containers will be stopped!"
	@echo "Only the default bridge, host, and none networks will remain."
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Listing all Docker networks before cleanup:"
	docker network ls

	@echo "\nStopping ALL Docker containers..."
	-docker stop $$(docker ps -q) 2>/dev/null

	@echo "\nRemoving all custom Docker networks..."
	-docker network prune -f

	@echo "\nForcefully removing any remaining networks except default ones..."
	@for network in $$(docker network ls --format "{{.Name}}" | grep -v "^bridge$$" | grep -v "^host$$" | grep -v "^none$$"); do \
		echo "Removing network: $$network"; \
		docker network rm $$network 2>/dev/null || true; \
	done

	@echo "\nRemaining networks:"
	docker network ls

	@echo "\nNetwork cleanup complete"

.PHONY: clean-monitoring
clean-monitoring: ## Reset Prometheus and Grafana data (WARNING: destructive!)
	@echo "WARNING: This will remove all Prometheus and Grafana data. Monitoring history will be lost!"
	@echo "Press Ctrl+C now to abort, or wait 5 seconds to continue..."
	@sleep 5

	@echo "Stopping monitoring services..."
	docker-compose -f docker-compose.monitoring.yml down

	@echo "Removing Prometheus data..."
	$(SUDO) rm -rf $(DATA_DIR)/prometheus_data/*

	@echo "Removing Grafana data..."
	$(SUDO) rm -rf $(DATA_DIR)/grafana_data/*

	@echo "Recreating monitoring directories with proper permissions..."
	$(SUDO) mkdir -p $(DATA_DIR)/prometheus_data
	$(SUDO) mkdir -p $(DATA_DIR)/grafana_data
	$(if $(SUDO),$(SUDO) chown 65534:65534 $(DATA_DIR)/prometheus_data)
	$(if $(SUDO),$(SUDO) chown -R 472:0 $(DATA_DIR)/grafana_data)
	$(if $(SUDO),$(SUDO) chmod -R 755 $(DATA_DIR)/grafana_data)

	@echo "Monitoring data has been cleaned."
	@echo "You can restart the monitoring services with 'make start-monitoring'"
