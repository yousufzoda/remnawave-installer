# Remnawave Installer

Automated installer for [Remnawave](https://remna.st) VPN panel + XRAY node.

- No runtime module downloads — all lib files are bundled locally or cached on first run
- All inputs collected upfront — installation runs unattended after confirmation
- English + Russian interface
- Nginx only (no Caddy)
- SSL: Cloudflare DNS-01 (wildcard) or ACME HTTP-01

---

## Quick start (via curl)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/yousufzoda/remnawave-installer/main/remnawave.sh)
```

After first run the script installs itself as `remnawave` command:
```bash
remnawave
```

---

## Manual install (clone)

```bash
git clone https://github.com/yousufzoda/remnawave-installer
cd remnawave-installer
sudo bash remnawave.sh
```

---

## Requirements

| | |
|---|---|
| OS | Debian 11/12, Ubuntu 22.04/24.04 |
| User | root |
| Ports | 443/tcp open, 22/tcp open |
| DNS | A records pointing to server before running |

---

## Menu

```
1. Install Panel         — panel + subscription page on this server
2. Install Node          — XRAY node (SelfSteal/Reality) on this server
3. Add Node to Panel     — register extra node in existing panel via API
4. Manage Services       — start / stop / update / logs / CLI / port 8443
5. Manage Certificates   — renew all, or generate new cert
6. Manage IPv6           — enable / disable IPv6
```

---

## Architecture

### Panel server

```
Internet → nginx :443 (cookie auth) → remnawave :3000
                                     → remnawave-subscription-page :3010
```

- Cookie-protected panel URL: `https://panel.example.com/auth/login?KEY=VALUE`
- Subscription page exposed as-is on `https://sub.example.com`
- SSL certs mounted read-only into nginx container from `/etc/letsencrypt/live/`
- PostgreSQL 18.3 + Valkey (Redis-compatible) via Unix socket

### Node server

```
Internet → XRAY :443 (VLESS Reality)
              ↓ legit HTTPS
           nginx unix:/dev/shm/nginx.sock → /var/www/html (camouflage site)
```

- XRAY listens on port 443, does Reality TLS handshake
- Legitimate HTTPS traffic forwarded to nginx via Unix socket using PROXY protocol
- nginx serves a static camouflage site from `/var/www/html/`
- Panel connects to node on port 2222 (allowed only from panel IP via UFW)

---

## Installation flow

### Panel install

1. Enter: panel domain, subscription domain, selfsteal domain
2. Enter: SSL method + credentials
3. Show summary → confirm
4. Install packages (Docker, certbot, ufw, jq...)
5. Generate SSL certificates
6. Write `/opt/remnawave/docker-compose.yml`, `.env`, `nginx.conf`
7. `docker compose up -d`
8. Wait for API, register superadmin
9. API setup: x25519 keys → config profile → node → host → squads → API token
10. Print credentials

### Node install

1. Enter: selfsteal domain, panel IP, panel public key, SSL method
2. Show summary → confirm
3. Install packages
4. Generate SSL certificate
5. Write camouflage HTML to `/var/www/html/`
6. Write `/opt/remnanode/docker-compose.yml`, `nginx.conf`
7. UFW: allow panel IP → port 2222
8. `docker compose up -d`
9. Verify HTTPS on selfsteal domain

---

## File layout (on server after install)

```
/opt/remnawave/
├── docker-compose.yml
├── .env
└── nginx.conf

/opt/remnanode/
├── docker-compose.yml
└── nginx.conf

/var/www/html/
└── index.html          ← camouflage site

/usr/local/remnawave/
├── remnawave.sh        ← persistent copy of main script
├── language            ← saved language choice (1=en, 2=ru)
├── token               ← cached panel API token
└── lib/                ← cached module files
    ├── core.sh
    ├── packages.sh
    ├── certs.sh
    ├── api.sh
    ├── panel.sh
    ├── node.sh
    ├── add_node.sh
    └── manage.sh

/usr/local/bin/remnawave → symlink to /usr/local/remnawave/remnawave.sh
```

---

## Project layout

```
remnawave-installer/
├── remnawave.sh          ← entry point
└── lib/
    ├── core.sh           ← colors, RU/EN translations, utilities
    ├── packages.sh       ← apt packages, Docker, UFW, BBR
    ├── certs.sh          ← SSL cert generation and renewal
    ├── api.sh            ← Remnawave REST API calls
    ├── panel.sh          ← panel installation logic
    ├── node.sh           ← node installation logic
    ├── add_node.sh       ← add node to existing panel
    └── manage.sh         ← service management, IPv6, port 8443
```

---

## SSL methods

### Cloudflare DNS-01 (recommended)
- Issues a wildcard certificate `*.yourdomain.com`
- All subdomains covered by one cert
- Requires Cloudflare API Token (Zone:DNS:Edit) or Global API Key + email
- Panel proxy must be OFF (grey cloud) for node/selfsteal domains

### ACME HTTP-01
- Issues a per-domain certificate
- Requires port 80 to be temporarily open during issuance
- No Cloudflare account needed

---

## Manage services

After installation, run `remnawave` (or `sudo remnawave`) to open the menu.

**Update images:**
```bash
remnawave
# → 4. Manage Services → 3. Update Docker images
```

**View logs:**
```bash
# Panel
cd /opt/remnawave && docker compose logs -f

# Node
cd /opt/remnanode && docker compose logs -f
```

**Emergency port 8443:**  
Opens the panel directly on port 8443 without cookie protection — use only when locked out, then close immediately.

---

## Notes

- The selfsteal domain must point to the **node server** (not the panel server). It is used both as the XRAY Reality `serverName` (SNI) and as the camouflage HTTPS site.
- Run **Add Node to Panel** from the **panel server**. It calls the local panel API at `127.0.0.1:3000`.
- The panel API token for the subscription page is automatically generated and injected into `docker-compose.yml`.
- Certificates auto-renew weekly via cron.

---

## Credits

Based on [eGamesAPI/remnawave-reverse-proxy](https://github.com/eGamesAPI/remnawave-reverse-proxy).
