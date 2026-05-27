#!/bin/bash
# Module: Panel installation

install_panel() {
    # ── 1. Collect ALL inputs ─────────────────────────────────────────────────
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}       REMNAWAVE PANEL INSTALLER         ${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""

    # Panel domain
    while true; do
        reading "${LANG[ENTER_PANEL_DOMAIN]}" PANEL_DOMAIN
        local rc; check_domain "$PANEL_DOMAIN" true; rc=$?
        [ $rc -eq 2 ] && exit 0
        break
    done

    # Sub domain
    while true; do
        reading "${LANG[ENTER_SUB_DOMAIN]}" SUB_DOMAIN
        local rc; check_domain "$SUB_DOMAIN" true; rc=$?
        [ $rc -eq 2 ] && exit 0
        [ "$SUB_DOMAIN" = "$PANEL_DOMAIN" ] && { warn "${LANG[DOMAINS_MUST_BE_UNIQUE]}"; continue; }
        break
    done

    # SelfSteal domain (used in XRAY config profile; the node runs on this domain)
    while true; do
        reading "${LANG[ENTER_SELFSTEAL_DOMAIN]}" SELFSTEAL_DOMAIN
        local rc; check_domain "$SELFSTEAL_DOMAIN" false; rc=$?
        [ $rc -eq 2 ] && exit 0
        [ "$SELFSTEAL_DOMAIN" = "$PANEL_DOMAIN" ] || [ "$SELFSTEAL_DOMAIN" = "$SUB_DOMAIN" ] \
            && { warn "${LANG[DOMAINS_MUST_BE_UNIQUE]}"; continue; }
        break
    done

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
    echo -e "${COLOR_WHITE}  Panel:      ${COLOR_YELLOW}$PANEL_DOMAIN${COLOR_RESET}"
    echo -e "${COLOR_WHITE}  Sub page:   ${COLOR_YELLOW}$SUB_DOMAIN${COLOR_RESET}"
    echo -e "${COLOR_WHITE}  SelfSteal:  ${COLOR_YELLOW}$SELFSTEAL_DOMAIN${COLOR_RESET}"
    case "$CERT_METHOD" in
        1) echo -e "${COLOR_WHITE}  SSL:        ${COLOR_YELLOW}Cloudflare DNS-01 (wildcard)${COLOR_RESET}" ;;
        2) echo -e "${COLOR_WHITE}  SSL:        ${COLOR_YELLOW}ACME HTTP-01${COLOR_RESET}" ;;
    esac
    echo ""
    reading "${LANG[SUMMARY_CONFIRM]}" _ok
    [[ "$_ok" != "y" && "$_ok" != "Y" ]] && { echo -e "${COLOR_YELLOW}${LANG[EXIT]}${COLOR_RESET}"; exit 0; }

    # ── 3. Install packages ───────────────────────────────────────────────────
    install_packages

    # ── 4. Generate SSL certificates ─────────────────────────────────────────
    echo ""
    case "$CERT_METHOD" in
        1)
            check_cf_api
            declare -A _cert_bases
            for d in "$PANEL_DOMAIN" "$SUB_DOMAIN"; do
                local base; base=$(extract_domain "$d")
                _cert_bases["$base"]=1
            done
            for base in "${!_cert_bases[@]}"; do
                check_cert_exists "$base" || get_cert_cloudflare "$base" \
                    || error "${LANG[CERT_GENERATION_FAILED]} $base"
            done
            ;;
        2)
            for d in "$PANEL_DOMAIN" "$SUB_DOMAIN"; do
                check_cert_exists "$d" || get_cert_acme "$d" "$ACME_EMAIL" \
                    || error "${LANG[CERT_GENERATION_FAILED]} $d"
            done
            ;;
    esac
    setup_cert_cron

    # Resolve cert domains (wildcard → base domain)
    local PANEL_CERT SUB_CERT
    PANEL_CERT=$(resolve_cert_domain "$PANEL_DOMAIN")
    SUB_CERT=$(resolve_cert_domain "$SUB_DOMAIN")

    # ── 5. Generate secrets ───────────────────────────────────────────────────
    local SUPERADMIN_USER SUPERADMIN_PASS
    SUPERADMIN_USER=$(generate_user)
    SUPERADMIN_PASS=$(generate_password)

    local COOKIE_KEY COOKIE_VAL
    COOKIE_KEY=$(generate_user)
    COOKIE_VAL=$(generate_user)

    local JWT_AUTH JWT_API METRICS_USER METRICS_PASS
    JWT_AUTH=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)
    JWT_API=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)
    METRICS_USER=$(generate_user)
    METRICS_PASS=$(generate_user)

    # ── 6. Write configs ──────────────────────────────────────────────────────
    mkdir -p /opt/remnawave
    _write_panel_env
    _write_panel_compose
    _write_panel_nginx

    # ── 7. Start containers ───────────────────────────────────────────────────
    info "${LANG[STARTING_PANEL]}"
    cd /opt/remnawave
    docker compose up -d >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"

    # ── 8. Wait for API ───────────────────────────────────────────────────────
    info "${LANG[REGISTERING_REMNAWAVE]}"
    sleep 20
    info "${LANG[CHECK_CONTAINERS]}"
    local domain_url="127.0.0.1:3000"
    local attempts=0 max_attempts=6
    until curl -s -f --max-time 30 \
        -H 'X-Forwarded-For: 127.0.0.1' \
        -H 'X-Forwarded-Proto: https' \
        "http://$domain_url/api/auth/status" >/dev/null; do
        attempts=$(( attempts + 1 ))
        (( attempts >= max_attempts )) \
            && error "$(printf "${LANG[CONTAINERS_TIMEOUT]}" "$max_attempts")"
        warn "$(printf "${LANG[CONTAINERS_NOT_READY_ATTEMPT]}" "$attempts" "$max_attempts")"
        sleep 60
    done

    # ── 9. API setup ──────────────────────────────────────────────────────────
    info "${LANG[REGISTERING_REMNAWAVE]}"
    local token
    token=$(register_remnawave "$domain_url" "$SUPERADMIN_USER" "$SUPERADMIN_PASS")
    ok "${LANG[REGISTRATION_SUCCESS]}"

    info "${LANG[GENERATE_KEYS]}"
    local private_key
    private_key=$(generate_xray_keys "$domain_url" "$token")
    ok "${LANG[GENERATE_KEYS_SUCCESS]}"

    delete_default_profile "$domain_url" "$token"

    info "${LANG[CREATING_CONFIG_PROFILE]}"
    local cfg_uuid ib_uuid
    read cfg_uuid ib_uuid <<< "$(create_config_profile \
        "$domain_url" "$token" "StealConfig" "$SELFSTEAL_DOMAIN" "$private_key")"
    ok "${LANG[CONFIG_PROFILE_CREATED]}"

    info "${LANG[CREATING_NODE]}"
    create_node "$domain_url" "$token" "$cfg_uuid" "$ib_uuid" "$SELFSTEAL_DOMAIN" "Steal"

    info "${LANG[CREATE_HOST]}"
    create_host "$domain_url" "$token" "$ib_uuid" "$SELFSTEAL_DOMAIN" "$cfg_uuid" "Steal"

    info "${LANG[GET_DEFAULT_SQUAD]}"
    local squad_uuids
    squad_uuids=$(get_squads "$domain_url" "$token")
    if [ -z "$squad_uuids" ]; then
        warn "${LANG[NO_SQUADS_TO_UPDATE]}"
    else
        while IFS= read -r sq; do
            [ -z "$sq" ] && continue
            info "${LANG[UPDATING_SQUAD]} $sq"
            update_squad "$domain_url" "$token" "$sq" "$ib_uuid"
        done <<< "$squad_uuids"
    fi

    info "${LANG[CREATING_API_TOKEN]}"
    create_api_token "$domain_url" "$token" "/opt/remnawave/docker-compose.yml"

    info "${LANG[STOPPING_SUB_PAGE]}"
    cd /opt/remnawave
    docker compose down remnawave-subscription-page >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"
    docker compose up -d remnawave-subscription-page >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"

    # ── 10. Print result ──────────────────────────────────────────────────────
    clear
    echo ""
    echo -e "${COLOR_GREEN}╔══════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║          ${LANG[INSTALL_COMPLETE]}                       ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╠══════════════════════════════════════════════════╣${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_YELLOW}${LANG[PANEL_ACCESS]}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_WHITE}https://${PANEL_DOMAIN}/auth/login?${COOKIE_KEY}=${COOKIE_VAL}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_YELLOW}${LANG[ADMIN_CREDS]}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_YELLOW}${LANG[USERNAME]}${COLOR_WHITE}${SUPERADMIN_USER}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_YELLOW}${LANG[PASSWORD]}${COLOR_WHITE}${SUPERADMIN_PASS}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║ ${COLOR_YELLOW}${LANG[RELAUNCH_CMD]} ${COLOR_WHITE}remnawave${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚══════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}${LANG[POST_PANEL_INSTRUCTION]}${COLOR_RESET}"
    echo ""
}

# ─── Config file generators ─────────────────────────────────────────────────

_write_panel_env() {
    cat > /opt/remnawave/.env <<EOF
### APP ###
APP_PORT=3000
METRICS_PORT=3001
API_INSTANCES=1

### DATABASE ###
DATABASE_URL="postgresql://postgres:postgres@remnawave-db:5432/postgres"

### REDIS ###
REDIS_SOCKET=/var/run/valkey/valkey.sock

### JWT ###
JWT_AUTH_SECRET=${JWT_AUTH}
JWT_API_TOKENS_SECRET=${JWT_API}
JWT_AUTH_LIFETIME=168

### TELEGRAM NOTIFICATIONS ###
IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
TELEGRAM_BOT_TOKEN=change_me
TELEGRAM_NOTIFY_USERS=change_me
TELEGRAM_NOTIFY_NODES=change_me
TELEGRAM_NOTIFY_CRM=change_me
TELEGRAM_NOTIFY_SERVICE=change_me
TELEGRAM_NOTIFY_TBLOCKER=change_me

### FRONT_END ###
FRONT_END_DOMAIN=${PANEL_DOMAIN}

### SUBSCRIPTION ###
SUB_PUBLIC_DOMAIN=${SUB_DOMAIN}

### SWAGGER (disabled) ###
SWAGGER_PATH=/docs
SCALAR_PATH=/scalar
IS_DOCS_ENABLED=false

### PROMETHEUS ###
METRICS_USER=${METRICS_USER}
METRICS_PASS=${METRICS_PASS}

### WEBHOOK ###
WEBHOOK_ENABLED=false
WEBHOOK_URL=https://your-webhook-url.com/endpoint
WEBHOOK_SECRET_HEADER=vsmu67Kmg6R8FjIOF1WUY8LWBHie4scdEqrfsKmyf4IAf8dY3nFS0wwYHkhh6ZvQ

### BANDWIDTH NOTIFICATIONS ###
BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED=false
BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD=[60, 80]

### NOT-CONNECTED USERS ###
NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED=false
NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS=[6, 24, 48]

### DATABASE (Docker) ###
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
EOF
}

_write_panel_compose() {
    cat > /opt/remnawave/docker-compose.yml <<EOF
x-common: &common
  ulimits:
    nofile:
      soft: 1048576
      hard: 1048576
  restart: always

x-networks: &networks
  networks:
    - remnawave-network

x-logging: &logging
  logging:
    driver: json-file
    options:
      max-size: 100m
      max-file: 5

x-env: &env
  env_file: .env

services:
  remnawave-db:
    image: postgres:18.3
    container_name: remnawave-db
    hostname: remnawave-db
    <<: [*common, *logging, *env, *networks]
    environment:
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=\${POSTGRES_DB}
      - TZ=UTC
    ports:
      - '127.0.0.1:6767:5432'
    volumes:
      - remnawave-db-data:/var/lib/postgresql
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U \$\${POSTGRES_USER} -d \$\${POSTGRES_DB}']
      interval: 3s
      timeout: 10s
      retries: 3

  remnawave:
    image: remnawave/backend:2
    container_name: remnawave
    hostname: remnawave
    <<: [*common, *logging, *env, *networks]
    volumes:
      - valkey-socket:/var/run/valkey
    ports:
      - '127.0.0.1:3000:\${APP_PORT:-3000}'
      - '127.0.0.1:3001:\${METRICS_PORT:-3001}'
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:\${METRICS_PORT:-3001}/health']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy

  remnawave-redis:
    image: valkey/valkey:9.0.3-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    <<: [*common, *logging, *networks]
    volumes:
      - valkey-socket:/var/run/valkey
    command: >
      valkey-server
      --save ""
      --appendonly no
      --maxmemory-policy noeviction
      --loglevel warning
      --unixsocket /var/run/valkey/valkey.sock
      --unixsocketperm 777
      --port 0
    healthcheck:
      test: ['CMD', 'valkey-cli', '-s', '/var/run/valkey/valkey.sock', 'ping']
      interval: 3s
      timeout: 10s
      retries: 3

  remnawave-subscription-page:
    image: remnawave/subscription-page:latest
    container_name: remnawave-subscription-page
    hostname: remnawave-subscription-page
    <<: [*common, *logging, *networks]
    depends_on:
      remnawave:
        condition: service_healthy
    environment:
      - REMNAWAVE_PANEL_URL=http://remnawave:3000
      - APP_PORT=3010
      - REMNAWAVE_API_TOKEN=PLACEHOLDER
    ports:
      - '127.0.0.1:3010:3010'

  remnawave-nginx:
    image: nginx:1.28
    container_name: remnawave-nginx
    hostname: remnawave-nginx
    <<: [*common, *logging]
    network_mode: host
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt/live/${PANEL_CERT}/fullchain.pem:/etc/nginx/ssl/${PANEL_CERT}/fullchain.pem:ro
      - /etc/letsencrypt/live/${PANEL_CERT}/privkey.pem:/etc/nginx/ssl/${PANEL_CERT}/privkey.pem:ro
      - /etc/letsencrypt/live/${SUB_CERT}/fullchain.pem:/etc/nginx/ssl/${SUB_CERT}/fullchain.pem:ro
      - /etc/letsencrypt/live/${SUB_CERT}/privkey.pem:/etc/nginx/ssl/${SUB_CERT}/privkey.pem:ro

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    external: false

volumes:
  remnawave-db-data:
    driver: local
    external: false
    name: remnawave-db-data
  valkey-socket:
    name: valkey-socket
    driver: local
    external: false
EOF
}

_write_panel_nginx() {
    cat > /opt/remnawave/nginx.conf <<EOF
server_names_hash_bucket_size 64;

upstream remnawave { server 127.0.0.1:3000; }
upstream json      { server 127.0.0.1:3010; }

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ""      close;
}

map \$http_cookie \$auth_cookie {
    default 0;
    "~*${COOKIE_KEY}=${COOKIE_VAL}" 1;
}

map \$arg_${COOKIE_KEY} \$auth_query {
    default 0;
    "${COOKIE_VAL}" 1;
}

map "\$auth_cookie\$auth_query" \$authorized {
    "~1" 1;
    default 0;
}

map \$arg_${COOKIE_KEY} \$set_cookie_header {
    "${COOKIE_VAL}" "${COOKIE_KEY}=${COOKIE_VAL}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000";
    default "";
}

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;

server {
    server_name ${PANEL_DOMAIN};
    listen 443 ssl;
    http2 on;

    ssl_certificate     "/etc/nginx/ssl/${PANEL_CERT}/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/${PANEL_CERT}/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/${PANEL_CERT}/fullchain.pem";

    add_header Set-Cookie \$set_cookie_header;

    location / {
        if (\$authorized = 0) { return 444; }
        proxy_http_version 1.1;
        proxy_pass http://remnawave;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location ^~ /oauth2/ {
        if (\$http_referer !~ "^https://oauth\\.telegram\\.org/") { return 444; }
        proxy_http_version 1.1;
        proxy_pass http://remnawave;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    server_name ${SUB_DOMAIN};
    listen 443 ssl;
    http2 on;

    ssl_certificate     "/etc/nginx/ssl/${SUB_CERT}/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/${SUB_CERT}/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/${SUB_CERT}/fullchain.pem";

    location / {
        proxy_http_version 1.1;
        proxy_pass http://json;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_intercept_errors on;
        error_page 400 404 500 502 @fallback;
    }

    location @fallback { return 444; }
}

server {
    listen 443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
}
EOF
}
