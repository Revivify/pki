# 🔐 CFSSL PKI Authority

This repo contains a fully-automated, minimal PKI infrastructure using [Cloudflare's CFSSL](https://github.com/cloudflare/cfssl). It generates a full certificate hierarchy — Root CA → Intermediate CA → End-Entity Certs — and runs an optional signing API for on-demand certificate issuance.

---

## 📁 Structure

```
pki/
├── config/                   # CSR + signing policy JSON files
├── secrets/                 # 🔒 Root and Intermediate CA keys and certs
│   ├── root/
│   └── intermediate/
├── issued/                  # Generated end-entity certs by domain
├── Makefile                 # One-command automation and dev workflow
├── readme.md
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

- Root CA and Intermediate CA keys and certs under `secrets/`
- Default domain certificate and key under `issued/`

### 🔐 Issue Certificate for Any Domain

```bash
make DOMAIN=example.com server-cert
```

Automatically generates a CSR for the specified domain and issues a certificate signed by the Intermediate CA. The issued cert and key are saved under `issued/`.

### 🧼 Clean Generated Files

```bash
make clean
```

Deletes all secrets and issued certificates.

---

### 🌐 Run CFSSL API Server

```bash
make api
```

Runs a local CA server at `http://127.0.0.1:8888`, capable of issuing certs via `/api/v1/cfssl/newcert` and signing CSRs.

---

### 📋 List Issued Certificates

```bash
make list
```

Lists all domains with issued certificates under the `issued/` directory.

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
  -d @config/server-csr.json | cfssljson -bare issued/mydomain.com/mydomain.com
```

Outputs:

- `issued/mydomain.com/mydomain.com.pem` (certificate)
- `issued/mydomain.com/mydomain.com-key.pem` (private key)
- `issued/mydomain.com/mydomain.com.csr` (optional CSR)

---

### 🔐 Trust Chain

To create a full trust bundle:

```bash
cat issued/mydomain.com/mydomain.com.pem secrets/intermediate/intermediate-ca-signed.pem secrets/root/root-ca.pem > fullchain.pem
```

Use this `fullchain.pem` for TLS server configs (e.g., NGINX, HAProxy, Istio).

---

### 🛠 Makefile Targets

```bash
make all                   # Generates root, intermediate, and default domain cert
make DOMAIN=example.com server-cert   # Issues cert for any domain (with SAN)
make api                   # Launches CFSSL API server with intermediate
make list                  # Lists all domains with issued certs
make clean                 # Deletes all secrets and issued certs
```

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

- `make revoke DOMAIN=example.com` — remove issued certs for a domain
- `make bundle DOMAIN=example.com` — create fullchain PEM for a domain
- `make test-cert DOMAIN=example.com` — verify cert validity with OpenSSL
- `make watch` — auto-sign CSRs dropped into a folder
- Dockerized API server
- Systemd unit for background CA operation
- CRL/OCSP responder integration

---

### 📜 License

MIT or Unlicense — do what you want. Not responsible for misuse in prod without audit.
