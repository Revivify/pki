CFSSL=cfssl
CFSSLJSON=cfssljson
API_PORT=8888
DOMAIN=mydomain.com

.PHONY: all clean api list bundle test-cert

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
