CFSSL=cfssl
CFSSLJSON=cfssljson
API_PORT=8888

.PHONY: all clean api

all: root-ca intermediate-ca server-cert

# ===== Root CA =====
root-ca:
	mkdir -p root
	$(CFSSL) genkey -initca config/root-ca-csr.json | $(CFSSLJSON) -bare root/root-ca

# ===== Intermediate CA =====
intermediate-ca: root-ca
	mkdir -p intermediate
	$(CFSSL) genkey -initca config/intermediate-ca-csr.json | $(CFSSLJSON) -bare intermediate/intermediate-ca

	$(CFSSL) sign \
		-ca root/root-ca.pem \
		-ca-key root/root-ca-key.pem \
		-config config/intermediate-ca-config.json \
		-profile intermediate \
		intermediate/intermediate-ca.csr | $(CFSSLJSON) -bare intermediate/intermediate-ca-signed

# ===== Server Certificate =====
server-cert: intermediate-ca
	mkdir -p server
	$(CFSSL) gencert \
		-ca intermediate/intermediate-ca-signed.pem \
		-ca-key intermediate/intermediate-ca-key.pem \
		-config config/end-entity-config.json \
		-profile default \
		config/server-csr.json | $(CFSSLJSON) -bare server/server

# ===== Start API Server =====
api: intermediate-ca
	$(CFSSL) serve \
		-ca intermediate/intermediate-ca-signed.pem \
		-ca-key intermediate/intermediate-ca-key.pem \
		-config config/intermediate-ca-config.json \
		-address 127.0.0.1 \
		-port $(API_PORT)

# ===== Cleanup =====
clean:
	rm -rf root intermediate server
