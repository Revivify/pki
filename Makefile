CFSSL=cfssl
CFSSLJSON=cfssljson
API_PORT=8888


.PHONY: all clean api list bundle test-cert docker docker-build docker-run docker-run-fg docker-stop docker-rm docker-logs docker-clean-container docker-prepare-dirs

all: root-ca intermediate-ca server-cert

# ===== Root CA =====
root-ca:
	mkdir -p secrets/root
	$(CFSSL) genkey -initca config/root-ca-csr.json | $(CFSSLJSON) -bare secrets/root/root-ca

# ===== Intermediate CA =====
intermediate-ca: root-ca
	mkdir -p secrets/intermediate
	$(CFSSL) genkey -initca config/intermediate-ca-csr.json | $(CFSSLJSON) -bare secrets/intermediate/intermediate-ca

	$(CFSSL) sign \
		-ca secrets/root/root-ca.pem \
		-ca-key secrets/root/root-ca-key.pem \
		-config config/intermediate-ca-config.json \
		-profile intermediate \
		secrets/intermediate/intermediate-ca.csr | $(CFSSLJSON) -bare secrets/intermediate/intermediate-ca-signed

# ===== Server Certificate =====
server-cert: intermediate-ca
	@if [ -z "$(DOMAIN)" ]; then \
		echo "Usage: make server-cert DOMAIN=example.com"; \
		exit 1; \
	fi
	mkdir -p issued/$(DOMAIN)
	echo '{ "CN": "$(DOMAIN)", "hosts": ["$(DOMAIN)"], "key": { "algo": "rsa", "size": 2048 } }' > issued/$(DOMAIN)/$(DOMAIN)-csr.json
	$(CFSSL) gencert \
		-ca secrets/intermediate/intermediate-ca-signed.pem \
		-ca-key secrets/intermediate/intermediate-ca-key.pem \
		-config config/end-entity-config.json \
		-profile default \
		issued/$(DOMAIN)/$(DOMAIN)-csr.json | $(CFSSLJSON) -bare issued/$(DOMAIN)/server

# ===== Start API Server =====
api: intermediate-ca
	$(CFSSL) serve \
		-ca secrets/intermediate/intermediate-ca-signed.pem \
		-ca-key secrets/intermediate/intermediate-ca-key.pem \
		-config config/intermediate-ca-config.json \
		-address 127.0.0.1 \
		-port $(API_PORT)

# ===== List Issued Domains =====
list:
	@echo "Issued domains:"
	@find issued -mindepth 1 -maxdepth 1 -type d -exec basename {} \;

# ===== Generate Fullchain Bundle =====
bundle:
	@if [ -z "$(DOMAIN)" ]; then \
		echo "Usage: make bundle DOMAIN=example.com"; \
	else \
		cat issued/$(DOMAIN)/server.pem secrets/intermediate/intermediate-ca-signed.pem secrets/root/root-ca.pem > issued/$(DOMAIN)/fullchain.pem; \
		echo "Created: issued/$(DOMAIN)/fullchain.pem"; \
	fi

# ===== Verify Certificate =====
test-cert:
	@bash -c '\
	if [ -z "$(DOMAIN)" ]; then \
		echo "Usage: make test-cert DOMAIN=example.com"; \
	else \
		echo "Verifying issued/$(DOMAIN)/server.pem..."; \
		openssl verify \
			-CAfile <(cat secrets/root/root-ca.pem secrets/intermediate/intermediate-ca-signed.pem) \
			issued/$(DOMAIN)/server.pem; \
		echo ""; \
		echo "Subject, Issuer, and Expiry:"; \
		openssl x509 -in issued/$(DOMAIN)/server.pem -noout -subject -issuer -dates; \
	fi'

# ===== Cleanup =====
clean:
	rm -rf secrets issued

# ===== Revoke Issued Certificate =====
revoke:
	@if [ -z "$(DOMAIN)" ]; then \
		echo "Usage: make revoke DOMAIN=example.com"; \
	else \
		echo "Revoking certificate for $(DOMAIN)..."; \
		rm -rf issued/$(DOMAIN); \
		echo "Done."; \
	fi

# ===== Docker Orchestration =====
DOCKER_IMAGE_NAME ?= cfssl-pki-server
DOCKER_CONTAINER_NAME ?= cfssl-pki-api
# Use existing API_PORT as the default for Docker host and container ports
# You can override these by setting them before calling make, e.g., DOCKER_HOST_PORT=9999 make docker
DOCKER_HOST_PORT ?= $(API_PORT)
DOCKER_CONTAINER_INTERNAL_PORT ?= $(API_PORT)

# Define host directories for Docker volumes
HOST_SECRETS_DIR := $(shell pwd)/secrets
HOST_ISSUED_DIR := $(shell pwd)/issued

# Target to create host directories for volumes if they don't exist, ensuring correct ownership
docker-prepare-dirs:
	@echo "Ensuring host directories for Docker volumes exist..."
	@mkdir -p $(HOST_SECRETS_DIR)
	@mkdir -p $(HOST_ISSUED_DIR)
	@echo "Host directories: $(HOST_SECRETS_DIR), $(HOST_ISSUED_DIR)"

docker-build:
	@echo "Building Docker image $(DOCKER_IMAGE_NAME)..."
	docker build -t $(DOCKER_IMAGE_NAME) .

# The 'docker' target will build the image (if not already built) and run the container.
# This addresses your point that the 'docker' target needs to happen after another step (building).
docker: docker-run

docker-run: docker-build docker-prepare-dirs
	@echo "Running Docker container $(DOCKER_CONTAINER_NAME) from image $(DOCKER_IMAGE_NAME) in detached mode..."
	@echo "API server will be available on http://localhost:$(DOCKER_HOST_PORT)"
	@echo "Host secrets directory: $(HOST_SECRETS_DIR) -> /app/secrets (in container)"
	@echo "Host issued certs directory: $(HOST_ISSUED_DIR) -> /app/issued (in container)"
	docker run -d \
		-p $(DOCKER_HOST_PORT):$(DOCKER_CONTAINER_INTERNAL_PORT) \
		--name $(DOCKER_CONTAINER_NAME) \
		-e API_PORT=$(DOCKER_CONTAINER_INTERNAL_PORT) \
		-v $(HOST_SECRETS_DIR):/app/secrets \
		-v $(HOST_ISSUED_DIR):/app/issued \
		$(DOCKER_IMAGE_NAME)
	@echo "Container $(DOCKER_CONTAINER_NAME) started."
	@echo "To view logs: make docker-logs"
	@echo "To stop the container: make docker-stop"

docker-run-fg: docker-build docker-prepare-dirs
	@echo "Running Docker container $(DOCKER_CONTAINER_NAME)-fg from image $(DOCKER_IMAGE_NAME) in foreground..."
	@echo "API server will be available on http://localhost:$(DOCKER_HOST_PORT)"
	@echo "Host secrets directory: $(HOST_SECRETS_DIR) -> /app/secrets (in container)"
	@echo "Host issued certs directory: $(HOST_ISSUED_DIR) -> /app/issued (in container)"
	@echo "Press Ctrl+C to stop."
	docker run --rm -it \
		-p $(DOCKER_HOST_PORT):$(DOCKER_CONTAINER_INTERNAL_PORT) \
		--name $(DOCKER_CONTAINER_NAME)-fg \
		-e API_PORT=$(DOCKER_CONTAINER_INTERNAL_PORT) \
		-v $(HOST_SECRETS_DIR):/app/secrets \
		-v $(HOST_ISSUED_DIR):/app/issued \
		$(DOCKER_IMAGE_NAME)

docker-stop:
	@echo "Stopping Docker container $(DOCKER_CONTAINER_NAME)..."
	docker stop $(DOCKER_CONTAINER_NAME) || echo "Container $(DOCKER_CONTAINER_NAME) not running or already stopped."

docker-rm:
	@echo "Removing Docker container $(DOCKER_CONTAINER_NAME)..."
	docker rm $(DOCKER_CONTAINER_NAME) || echo "Container $(DOCKER_CONTAINER_NAME) not found or already removed."

docker-logs:
	@echo "Following logs for Docker container $(DOCKER_CONTAINER_NAME)... (Press Ctrl+C to stop)"
	docker logs -f $(DOCKER_CONTAINER_NAME)

# Stops and removes the container
docker-clean-container: docker-stop docker-rm
	@echo "Docker container $(DOCKER_CONTAINER_NAME) stopped and removed."