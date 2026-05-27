#!/bin/bash
# Module: Package installation

install_packages() {
    info "${LANG[INSTALL_PACKAGES]}"

    apt-get update -y || { warn "${LANG[ERROR_INSTALL_PACKAGES]}"; return 1; }

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates curl jq ufw wget gnupg unzip nano \
        certbot python3-certbot-dns-cloudflare \
        cron dnsutils openssl locales \
        || { warn "${LANG[ERROR_INSTALL_PACKAGES]}"; return 1; }

    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        info "Installing Docker via get.docker.com..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh \
            || { warn "${LANG[ERROR_INSTALL_DOCKER]}"; return 1; }
        sh /tmp/get-docker.sh \
            || { warn "${LANG[ERROR_INSTALL_DOCKER]}"; return 1; }
        rm -f /tmp/get-docker.sh
    fi

    systemctl enable --now docker >/dev/null 2>&1 \
        || { warn "${LANG[ERROR_INSTALL_DOCKER]}"; return 1; }

    docker info >/dev/null 2>&1 \
        || { warn "${LANG[ERROR_INSTALL_DOCKER]}"; return 1; }

    systemctl enable --now cron >/dev/null 2>&1 || true

    # BBR congestion control
    grep -q "net.core.default_qdisc = fq" /etc/sysctl.conf \
        || echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf \
        || echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1

    # UFW — allow SSH + HTTPS only
    ufw allow 22/tcp   comment 'SSH'   >/dev/null 2>&1
    ufw allow 443/tcp  comment 'HTTPS' >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1

    ok "${LANG[SUCCESS_INSTALL]}"
}
