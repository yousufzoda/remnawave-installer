#!/bin/bash
# Module: Node installation

install_node() {
    # ── 1. Collect ALL inputs ─────────────────────────────────────────────────
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}       REMNAWAVE NODE INSTALLER          ${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""

    # SelfSteal domain
    while true; do
        reading "${LANG[ENTER_SELFSTEAL_DOMAIN]}" SELFSTEAL_DOMAIN
        local rc=0; check_domain "$SELFSTEAL_DOMAIN" false || rc=$?
        [ $rc -eq 2 ] && exit 0
        break
    done

    # Panel IP
    local PANEL_IP
    while true; do
        reading "${LANG[ENTER_PANEL_IP]}" PANEL_IP
        if [[ "$PANEL_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            local IFS_bak=$IFS; IFS='.'
            read -ra _oct <<< "$PANEL_IP"
            IFS=$IFS_bak
            local ok=true
            for o in "${_oct[@]}"; do
                (( o > 255 )) && ok=false && break
            done
            $ok && break
        fi
        warn "${LANG[IP_ERROR]}"
    done

    # Public key from panel
    local PUBLIC_KEY
    reading "${LANG[ENTER_PUBLIC_KEY]}" PUBLIC_KEY

    # SSL method
    echo ""
    echo -e "${COLOR_YELLOW}${LANG[CERT_METHOD_PROMPT]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}1. ${LANG[CERT_METHOD_CF]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[CERT_METHOD_ACME]}${COLOR_RESET}"
    echo ""
    reading "${LANG[CERT_METHOD_CHOOSE]}" CERT_METHOD

    case "$CERT_METHOD" in
        1)
            reading "${LANG[ENTER_CF_TOKEN]}" CF_API_KEY
            reading "${LANG[ENTER_CF_EMAIL]}" CF_EMAIL
            ;;
        2)
            reading "${LANG[EMAIL_PROMPT]}" ACME_EMAIL
            ;;
        *)
            warn "${LANG[INVALID_CHOICE]}"; exit 1 ;;
    esac

    # ── 2. Show summary & confirm ─────────────────────────────────────────────
    echo ""
    echo -e "${COLOR_GREEN}${LANG[SUMMARY_TITLE]}${COLOR_RESET}"
    echo -e "${COLOR_WHITE}  SelfSteal: ${COLOR_YELLOW}$SELFSTEAL_DOMAIN${COLOR_RESET}"
    echo -e "${COLOR_WHITE}  Panel IP:  ${COLOR_YELLOW}$PANEL_IP${COLOR_RESET}"
    case "$CERT_METHOD" in
        1) echo -e "${COLOR_WHITE}  SSL:       ${COLOR_YELLOW}Cloudflare DNS-01 (wildcard)${COLOR_RESET}" ;;
        2) echo -e "${COLOR_WHITE}  SSL:       ${COLOR_YELLOW}ACME HTTP-01${COLOR_RESET}" ;;
    esac
    echo ""
    reading "${LANG[SUMMARY_CONFIRM]}" _ok
    [[ "$_ok" != "y" && "$_ok" != "Y" ]] && { echo -e "${COLOR_YELLOW}${LANG[EXIT]}${COLOR_RESET}"; exit 0; }

    # ── 3. Install packages ───────────────────────────────────────────────────
    install_packages

    # ── 4. Generate SSL certificate ───────────────────────────────────────────
    case "$CERT_METHOD" in
        1)
            check_cf_api
            local base; base=$(extract_domain "$SELFSTEAL_DOMAIN")
            check_cert_exists "$base" || get_cert_cloudflare "$base" \
                || error "${LANG[CERT_GENERATION_FAILED]} $base"
            ;;
        2)
            check_cert_exists "$SELFSTEAL_DOMAIN" \
                || get_cert_acme "$SELFSTEAL_DOMAIN" "$ACME_EMAIL" \
                || error "${LANG[CERT_GENERATION_FAILED]} $SELFSTEAL_DOMAIN"
            ;;
    esac
    setup_cert_cron

    local NODE_CERT
    NODE_CERT=$(resolve_cert_domain "$SELFSTEAL_DOMAIN")

    # ── 5. Write camouflage HTML ──────────────────────────────────────────────
    mkdir -p /var/www/html
    _write_selfsteal_html

    # ── 6. Write configs ──────────────────────────────────────────────────────
    mkdir -p /opt/remnanode
    _write_node_compose
    _write_node_nginx

    # ── 7. UFW: allow panel to connect to node port 2222 ─────────────────────
    ufw allow from "$PANEL_IP" to any port 2222 >/dev/null 2>&1
    ufw reload >/dev/null 2>&1

    # ── 8. Start containers ───────────────────────────────────────────────────
    info "${LANG[STARTING_NODE]}"
    sleep 2
    cd /opt/remnanode
    docker compose up -d >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"

    # ── 9. Verify HTTPS ───────────────────────────────────────────────────────
    info "$(printf "${LANG[NODE_CHECK]}" "$SELFSTEAL_DOMAIN")"
    local attempt=1 max=5
    while (( attempt <= max )); do
        info "$(printf "${LANG[NODE_ATTEMPT]}" "$attempt" "$max")"
        if curl -s --fail --max-time 10 "https://$SELFSTEAL_DOMAIN" | grep -qi "html"; then
            ok "${LANG[NODE_LAUNCHED]}"
            break
        fi
        if (( attempt == max )); then
            warn "$(printf "${LANG[NODE_NOT_CONNECTED]}" "$max")"
            warn "${LANG[CHECK_CONFIG]}"
        else
            warn "$(printf "${LANG[NODE_UNAVAILABLE]}" "$attempt")"
            sleep 15
        fi
        (( attempt++ ))
    done

    # ── 10. Print result ──────────────────────────────────────────────────────
    echo ""
    echo -e "${COLOR_GREEN}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║     ${LANG[NODE_INSTALL_COMPLETE]}             ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║                                          ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_WHITE}https://$SELFSTEAL_DOMAIN${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║                                          ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_YELLOW}${LANG[NODE_HINT]}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

# ─── Config file generators ─────────────────────────────────────────────────

_write_node_compose() {
    cat > /opt/remnanode/docker-compose.yml <<EOF
x-common: &common
  ulimits:
    nofile:
      soft: 1048576
      hard: 1048576
  restart: always

x-logging: &logging
  logging:
    driver: json-file
    options:
      max-size: 100m
      max-file: 5

services:
  remnawave-nginx:
    image: nginx:1.28
    container_name: remnawave-nginx
    hostname: remnawave-nginx
    <<: [*common, *logging]
    network_mode: host
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /dev/shm:/dev/shm:rw
      - /var/www/html:/var/www/html:ro
      - /etc/letsencrypt/live/${NODE_CERT}/fullchain.pem:/etc/nginx/ssl/${NODE_CERT}/fullchain.pem:ro
      - /etc/letsencrypt/live/${NODE_CERT}/privkey.pem:/etc/nginx/ssl/${NODE_CERT}/privkey.pem:ro
    command: sh -c 'rm -f /dev/shm/nginx.sock && exec nginx -g "daemon off;"'

  remnanode:
    image: remnawave/node:latest
    container_name: remnanode
    hostname: remnanode
    <<: [*common, *logging]
    network_mode: host
    cap_add:
      - NET_ADMIN
    environment:
      - NODE_PORT=2222
      - SECRET_KEY=${PUBLIC_KEY}
    volumes:
      - /dev/shm:/dev/shm:rw
EOF
}

_write_node_nginx() {
    cat > /opt/remnanode/nginx.conf <<EOF
server_names_hash_bucket_size 64;

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ""      close;
}

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

server {
    server_name ${SELFSTEAL_DOMAIN};
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol;
    http2 on;

    ssl_certificate     "/etc/nginx/ssl/${NODE_CERT}/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/${NODE_CERT}/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/${NODE_CERT}/fullchain.pem";

    root /var/www/html;
    index index.html;
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex" always;
}

server {
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol default_server;
    server_name _;
    ssl_reject_handshake on;
    return 444;
}
EOF
}

_write_selfsteal_html() {
    local title="Nexus Systems"
    local heading="Infrastructure you can rely on"
    local body="We build resilient, high-performance infrastructure solutions for enterprises and growing businesses. From cloud architecture to network security, our team ensures your systems run without interruption."
    local footer="© $(date +%Y) Nexus Systems. All rights reserved."

    cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="robots" content="noindex, nofollow">
<title>$title</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0a0a0f;color:#e0e0e0;min-height:100vh}
header{padding:20px 40px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #1e1e2e}
.logo{font-size:1.3rem;font-weight:700;color:#7c3aed;letter-spacing:-0.5px}
nav a{color:#9ca3af;text-decoration:none;margin-left:24px;font-size:.9rem;transition:.2s}
nav a:hover{color:#e0e0e0}
main{max-width:800px;margin:100px auto;padding:0 40px;text-align:center}
h1{font-size:2.8rem;font-weight:800;line-height:1.1;margin-bottom:24px;background:linear-gradient(135deg,#7c3aed,#2563eb);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
p{font-size:1.05rem;color:#9ca3af;line-height:1.75;margin-bottom:40px}
.btn{display:inline-block;padding:13px 30px;background:#7c3aed;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:.95rem;transition:.2s}
.btn:hover{background:#6d28d9;transform:translateY(-1px)}
footer{text-align:center;padding:40px;color:#4b5563;font-size:.85rem;border-top:1px solid #1e1e2e;margin-top:120px}
</style>
</head>
<body>
<header>
  <div class="logo">◆ NexusSys</div>
  <nav>
    <a href="#">Solutions</a>
    <a href="#">About</a>
    <a href="#">Contact</a>
  </nav>
</header>
<main>
  <h1>$heading</h1>
  <p>$body</p>
  <a class="btn" href="#">Get in touch</a>
</main>
<footer><p>$footer</p></footer>
</body>
</html>
EOF
}
