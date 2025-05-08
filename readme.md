# 🔐 CFSSL PKI Authority

This repo contains a fully-automated, minimal PKI infrastructure using [Cloudflare's CFSSL](https://github.com/cloudflare/cfssl). It generates a full certificate hierarchy — Root CA → Intermediate CA → End-Entity Certs — and runs an optional signing API for on-demand certificate issuance.

---

## 📁 Structure

```
pki/
├── config/                   # CSR + signing policy JSON files
├── root/                     # Root CA private key + cert
├── intermediate/             # Intermediate CA private key + cert
├── server/                   # Example end-entity cert
├── Makefile                  # One-command automation
```

---

## 🚀 Usage

### 🔧 Dependencies

- [cfssl](https://github.com/cloudflare/cfssl)
- [cfssljson](https://github.com/cloudflare/cfssl)
- [`jq`](https://stedolan.github.io/jq/) (optional, for API output parsing)

### 🔁 Generate Entire PKI Chain

```bash
make all
```

Generates:

- `root/root-ca.pem`
- `intermediate/intermediate-ca-signed.pem`
- `server/server.pem` (signed by intermediate)

### 🧼 Clean Generated Files

```bash
make clean
```

---

### 🌐 Run CFSSL API Server

```bash
make api
```

Runs a local CA server at `http://127.0.0.1:8888`, capable of issuing certs via `/api/v1/cfssl/newcert` and signing CSRs.

---

### 🔐 Issue Cert via API

Example `server-csr.json`:

```json
{
  "CN": "mydomain.com",
  "hosts": ["mydomain.com", "www.mydomain.com"],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
```

Issue certificate with curl:

```bash
curl -X POST http://127.0.0.1:8888/api/v1/cfssl/newcert \
  -d @config/server-csr.json | cfssljson -bare server/server
```

Outputs:

- `server/server.pem` (certificate)
- `server/server-key.pem` (private key)
- `server/server.csr` (optional CSR)

---

### 🔐 Trust Chain

To create a full trust bundle:

```bash
cat server/server.pem intermediate/intermediate-ca-signed.pem root/root-ca.pem > fullchain.pem
```

Use this `fullchain.pem` for TLS server configs (e.g., NGINX, HAProxy, Istio).

---

### ✅ Profiles

- `intermediate-ca-config.json`

  Allows issuing CA certificates (`is_ca: true`) with `max_path_len: 1`.

- `end-entity-config.json`

  Issues standard server/client TLS certs (server auth, client auth, key encipherment).

---

### 🧠 Design Philosophy

- Root CA stays offline (only used during `make all`)
- Intermediate CA runs API
- Profiles and constraints strictly enforce CA hierarchy
- Portable and dev-friendly — can scale to production

---

### ✨ Extras

Coming soon (or PRs welcome):

- Dockerized API server
- Systemd service for API mode
- CRL/OCSP responders

---

### 📜 License

MIT or Unlicense — do what you want. Not responsible for misuse in prod without audit.
