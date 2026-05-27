#!/bin/bash
# Module: SSL certificate management

check_cf_api() {
    local attempts=3 attempt=1
    while (( attempt <= attempts )); do
        local resp
        if [[ "$CF_API_KEY" =~ [A-Z] ]]; then
            resp=$(curl -s --max-time 10 \
                -H "Authorization: Bearer ${CF_API_KEY}" \
                -H "Content-Type: application/json" \
                https://api.cloudflare.com/client/v4/zones)
        else
            resp=$(curl -s --max-time 10 \
                -H "X-Auth-Key: ${CF_API_KEY}" \
                -H "X-Auth-Email: ${CF_EMAIL}" \
                -H "Content-Type: application/json" \
                https://api.cloudflare.com/client/v4/zones)
        fi
        if echo "$resp" | grep -q '"success":true'; then
            ok "${LANG[CF_VALIDATING]}"
            return 0
        fi
        warn "$(printf "${LANG[CF_INVALID_ATTEMPT]}" "$attempt" "$attempts")"
        (( attempt < attempts )) && reading "${LANG[ENTER_CF_TOKEN]}" CF_API_KEY
        (( attempt++ ))
    done
    error "$(printf "${LANG[CF_INVALID]}" "$attempts")"
}

get_cert_cloudflare() {
    local domain="$1"
    local base_domain
    base_domain=$(extract_domain "$domain")

    mkdir -p ~/.secrets/certbot
    if [[ "$CF_API_KEY" =~ [A-Z] ]]; then
        cat > ~/.secrets/certbot/cloudflare.ini <<EOF
dns_cloudflare_api_token = ${CF_API_KEY}
EOF
    else
        cat > ~/.secrets/certbot/cloudflare.ini <<EOF
dns_cloudflare_email = ${CF_EMAIL}
dns_cloudflare_api_key = ${CF_API_KEY}
EOF
    fi
    chmod 600 ~/.secrets/certbot/cloudflare.ini

    info "$(printf "${LANG[GENERATING_CERTS]}" "*.${base_domain}")"
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
        --dns-cloudflare-propagation-seconds 60 \
        -d "$base_domain" \
        -d "*.${base_domain}" \
        --email "$CF_EMAIL" \
        --agree-tos \
        --non-interactive \
        --key-type ecdsa \
        --elliptic-curve secp384r1
}

get_cert_acme() {
    local domain="$1"
    local email="$2"
    info "$(printf "${LANG[GENERATING_CERTS]}" "$domain")"
    ufw allow 80/tcp comment 'ACME challenge' >/dev/null 2>&1
    certbot certonly \
        --standalone \
        -d "$domain" \
        --email "$email" \
        --agree-tos \
        --non-interactive \
        --http-01-port 80 \
        --key-type ecdsa \
        --elliptic-curve secp384r1
    ufw delete allow 80/tcp >/dev/null 2>&1
    ufw reload >/dev/null 2>&1
}

check_cert_exists() {
    local domain="$1"
    local cert_dir="/etc/letsencrypt/live"

    local live_dir
    live_dir=$(find "$cert_dir" -maxdepth 1 -type d -name "${domain}*" 2>/dev/null | sort -V | tail -n 1)
    if [ -n "$live_dir" ] && [ -d "$live_dir" ]; then
        for f in cert.pem chain.pem fullchain.pem privkey.pem; do
            [ -f "$live_dir/$f" ] || return 1
        done
        ok "${LANG[CERT_FOUND]}$(basename "$live_dir")"
        return 0
    fi

    local base_domain
    base_domain=$(extract_domain "$domain")
    if [ "$base_domain" != "$domain" ] && is_wildcard_cert "$base_domain"; then
        ok "${LANG[WILDCARD_CERT_FOUND]}${base_domain} ${LANG[FOR_DOMAIN]} ${domain}"
        return 0
    fi

    warn "${LANG[CERT_NOT_FOUND]} $domain"
    return 1
}

cert_days_left() {
    local domain="$1"
    local live_dir
    live_dir=$(find /etc/letsencrypt/live -maxdepth 1 -type d -name "${domain}*" 2>/dev/null | sort -V | tail -n 1)
    [ -d "$live_dir" ] || return 1
    local cert="$live_dir/fullchain.pem"
    [ -f "$cert" ] || return 1
    local exp
    exp=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    [ -n "$exp" ] || return 1
    local exp_epoch now_epoch
    exp_epoch=$(TZ=UTC date -d "$exp" +%s 2>/dev/null) || return 1
    now_epoch=$(date +%s)
    echo $(( (exp_epoch - now_epoch) / 86400 ))
}

# Returns the cert domain to use in nginx ssl_certificate paths.
# For wildcard certs: base domain. For per-domain: the domain itself.
resolve_cert_domain() {
    local domain="$1"
    local base
    base=$(extract_domain "$domain")
    if [ -d "/etc/letsencrypt/live/$base" ] && is_wildcard_cert "$base"; then
        echo "$base"
    else
        echo "$domain"
    fi
}

# Collect cert inputs and generate certs for all provided domains.
# Sets CERT_METHOD, CF_API_KEY, CF_EMAIL, ACME_EMAIL as globals.
# Usage: handle_certs domain1 domain2 ...
handle_certs() {
    local domains=("$@")

    local need_certs=false
    for d in "${domains[@]}"; do
        check_cert_exists "$d" || need_certs=true
    done

    if [ "$need_certs" = false ]; then
        ok "${LANG[CERTS_SKIPPED]}"
        return 0
    fi

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
            check_cf_api

            declare -A _bases
            for d in "${domains[@]}"; do
                local base; base=$(extract_domain "$d")
                _bases["$base"]=1
            done
            for base in "${!_bases[@]}"; do
                check_cert_exists "$base" \
                    || get_cert_cloudflare "$base" \
                    || { warn "${LANG[CERT_GENERATION_FAILED]} $base"; return 1; }
            done
            ;;
        2)
            reading "${LANG[EMAIL_PROMPT]}" ACME_EMAIL
            for d in "${domains[@]}"; do
                check_cert_exists "$d" \
                    || get_cert_acme "$d" "$ACME_EMAIL" \
                    || { warn "${LANG[CERT_GENERATION_FAILED]} $d"; return 1; }
            done
            ;;
        *)
            warn "${LANG[INVALID_CHOICE]}"
            return 1
            ;;
    esac

    setup_cert_cron
}

setup_cert_cron() {
    info "${LANG[ADDING_CRON]}"
    if crontab -u root -l 2>/dev/null | grep -q "/usr/bin/certbot renew"; then
        return
    fi
    if [ "$CERT_METHOD" = "2" ]; then
        add_cron_rule "0 5 * * 0 ufw allow 80 && /usr/bin/certbot renew --quiet && ufw delete allow 80 && ufw reload"
    else
        add_cron_rule "0 5 * * 0 /usr/bin/certbot renew --quiet"
    fi
}

fix_letsencrypt_structure() {
    local domain="$1"
    local live_dir="/etc/letsencrypt/live/$domain"
    local archive_dir="/etc/letsencrypt/archive/$domain"
    local renewal_conf="/etc/letsencrypt/renewal/$domain.conf"

    [ -d "$live_dir" ] && [ -d "$archive_dir" ] && [ -f "$renewal_conf" ] || return 1

    local latest
    latest=$(ls -1 "$archive_dir" | grep -E 'cert[0-9]+\.pem' | sort -V | tail -n 1 | sed -E 's/.*cert([0-9]+)\.pem/\1/')
    [ -n "$latest" ] || return 1

    for f in cert chain fullchain privkey; do
        local src="$archive_dir/${f}${latest}.pem"
        local lnk="$live_dir/${f}.pem"
        [ -f "$src" ] || return 1
        [ -f "$lnk" ] && [ ! -L "$lnk" ] && rm "$lnk"
        ln -sf "$src" "$lnk"
    done
}

# --- Manage certificates menu ---

manage_certificates() {
    echo ""
    echo -e "${COLOR_GREEN}${LANG[CERT_MENU_TITLE]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}1. ${LANG[CERT_RENEW]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[CERT_NEW]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}0. ${LANG[MENU_0]}${COLOR_RESET}"
    echo ""
    reading "${LANG[PROMPT_ACTION]}" _opt
    case "$_opt" in
        1) renew_all_certificates ;;
        2) generate_new_certificate ;;
        0) return ;;
        *) warn "${LANG[INVALID_CHOICE]}"; sleep 1; manage_certificates ;;
    esac
}

renew_all_certificates() {
    local cert_dir="/etc/letsencrypt/live"
    [ -d "$cert_dir" ] || { warn "${LANG[CERT_NOT_FOUND]:-No certificates found.}"; return; }

    echo ""
    echo -e "${COLOR_YELLOW}${LANG[CERT_RESULTS]}${COLOR_RESET}"

    for domain_dir in "$cert_dir"/*/; do
        local domain; domain=$(basename "$domain_dir")
        fix_letsencrypt_structure "$domain" 2>/dev/null || true

        local days
        days=$(cert_days_left "$domain" 2>/dev/null)
        if [ $? -ne 0 ]; then
            warn "${LANG[CERT_EXPIRY_ERROR]} $domain"
            continue
        fi

        if (( days > 30 )); then
            echo -e "  ${COLOR_GRAY}$domain — ${LANG[RENEW_SKIPPED]} $days ${LANG[DAYS_LEFT]}${COLOR_RESET}"
            continue
        fi

        local renewal="/etc/letsencrypt/renewal/$domain.conf"
        if [ -f "$renewal" ] && grep -q "dns_cloudflare" "$renewal"; then
            certbot renew --cert-name "$domain" --no-random-sleep-on-renew -q
        elif [ -f "$renewal" ]; then
            ufw allow 80/tcp >/dev/null 2>&1
            certbot renew --cert-name "$domain" --no-random-sleep-on-renew -q
            ufw delete allow 80/tcp >/dev/null 2>&1
            ufw reload >/dev/null 2>&1
        fi

        local new_days; new_days=$(cert_days_left "$domain" 2>/dev/null)
        if [ -n "$new_days" ] && (( new_days > days )); then
            ok "  $domain — ${LANG[RENEWED]}"
        else
            warn "  $domain — ${LANG[RENEW_FAILED]}"
        fi
    done
}

generate_new_certificate() {
    reading "${LANG[CERT_DOMAIN_PROMPT]}" _new_domain
    echo ""
    echo -e "${COLOR_YELLOW}${LANG[CERT_METHOD_PROMPT]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}1. ${LANG[CERT_METHOD_CF]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[CERT_METHOD_ACME]}${COLOR_RESET}"
    echo ""
    reading "${LANG[CERT_METHOD_CHOOSE]}" _method
    case "$_method" in
        1)
            reading "${LANG[ENTER_CF_TOKEN]}" CF_API_KEY
            reading "${LANG[ENTER_CF_EMAIL]}" CF_EMAIL
            check_cf_api
            get_cert_cloudflare "$_new_domain"
            ;;
        2)
            reading "${LANG[EMAIL_PROMPT]}" _email
            get_cert_acme "$_new_domain" "$_email"
            ;;
        *)
            warn "${LANG[INVALID_CHOICE]}"; return ;;
    esac
    check_cert_exists "$_new_domain" && ok "${LANG[CERT_NEW_OK]}"
}
