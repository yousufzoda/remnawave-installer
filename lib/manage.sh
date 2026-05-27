#!/bin/bash
# Module: Service management

_find_dir() {
    if   [ -d /opt/remnawave ]; then echo /opt/remnawave
    elif [ -d /opt/remnanode ]; then echo /opt/remnanode
    else error "${LANG[DIR_NOT_FOUND]}"
    fi
}

show_manage_menu() {
    echo ""
    echo -e "${COLOR_GREEN}${LANG[MANAGE_TITLE]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}1. ${LANG[MANAGE_1]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[MANAGE_2]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}3. ${LANG[MANAGE_3]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}4. ${LANG[MANAGE_4]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}5. ${LANG[MANAGE_5]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}6. ${LANG[MANAGE_6]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}0. ${LANG[MENU_0]}${COLOR_RESET}"
    echo ""
    reading "${LANG[PROMPT_ACTION]}" _opt
    case "$_opt" in
        1) start_services;      sleep 1; show_manage_menu ;;
        2) stop_services;       sleep 1; show_manage_menu ;;
        3) update_services;     sleep 1; show_manage_menu ;;
        4) view_logs ;;
        5) run_remnawave_cli;   sleep 1; show_manage_menu ;;
        6) manage_port_8443;    sleep 1; show_manage_menu ;;
        0) return ;;
        *) warn "${LANG[INVALID_CHOICE]}"; sleep 1; show_manage_menu ;;
    esac
}

start_services() {
    local dir; dir=$(_find_dir)
    if docker ps -q --filter "name=remnawave" | grep -q . \
    || docker ps -q --filter "name=remnanode"  | grep -q .; then
        ok "${LANG[PANEL_RUNNING]}"
        return
    fi
    info "${LANG[STARTING_SERVICES]}"
    cd "$dir"
    docker compose up -d >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"
    ok "${LANG[SERVICES_STARTED]}"
}

stop_services() {
    local dir; dir=$(_find_dir)
    if ! docker ps -q --filter "name=remnawave" | grep -q . \
    && ! docker ps -q --filter "name=remnanode"  | grep -q .; then
        ok "${LANG[PANEL_STOPPED]}"
        return
    fi
    info "${LANG[STOPPING_SERVICES]}"
    cd "$dir"
    docker compose down >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"
    ok "${LANG[SERVICES_STOPPED]}"
}

update_services() {
    local dir; dir=$(_find_dir)
    cd "$dir"
    info "${LANG[UPDATING_IMAGES]}"

    local before after
    before=$(docker compose config --images 2>/dev/null | sort -u \
        | xargs -I{} docker images -q {} 2>/dev/null | sort -u)

    docker compose pull >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"

    after=$(docker compose config --images 2>/dev/null | sort -u \
        | xargs -I{} docker images -q {} 2>/dev/null | sort -u)

    if [ "$before" != "$after" ]; then
        info "${LANG[NEW_IMAGES]}"
        docker compose down >/dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        sleep 3
        docker compose up -d >/dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        docker image prune -f >/dev/null 2>&1
        ok "${LANG[UPDATE_DONE]}"
    else
        ok "${LANG[ALREADY_LATEST]}"
    fi
}

view_logs() {
    local dir; dir=$(_find_dir)
    cd "$dir"
    info "${LANG[MANAGE_4]}"
    docker compose logs -f -t
}

run_remnawave_cli() {
    docker ps --format '{{.Names}}' | grep -q '^remnawave$' \
        || { warn "${LANG[CONTAINER_NOT_RUNNING]}"; return; }
    exec 3>&1 4>&2; exec > /dev/tty 2>&1
    info "${LANG[RUNNING_CLI]}"
    docker exec -it -e TERM=xterm-256color remnawave remnawave \
        && ok "${LANG[CLI_DONE]}" \
        || warn "${LANG[CLI_FAILED]}"
    exec 1>&3 2>&4
}

# ─── Port 8443 ───────────────────────────────────────────────────────────────

manage_port_8443() {
    echo ""
    echo -e "${COLOR_GREEN}${LANG[PORT_8443_TITLE]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}1. ${LANG[PORT_8443_OPEN_OPT]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[PORT_8443_CLOSE_OPT]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}0. ${LANG[MENU_0]}${COLOR_RESET}"
    echo ""
    reading "${LANG[PROMPT_ACTION]}" _opt
    case "$_opt" in
        1) open_port_8443 ;;
        2) close_port_8443 ;;
        0) return ;;
        *) warn "${LANG[INVALID_CHOICE]}" ;;
    esac
}

open_port_8443() {
    [ -d /opt/remnawave ] || { warn "${LANG[DIR_NOT_FOUND]}"; return; }
    local nginx_conf=/opt/remnawave/nginx.conf
    [ -f "$nginx_conf" ] || { warn "${LANG[NGINX_CONF_PARSE_FAIL]}"; return; }

    if ss -tuln 2>/dev/null | grep -q ":8443" \
    || netstat -tuln 2>/dev/null | grep -q ":8443"; then
        warn "${LANG[PORT_8443_IN_USE]}"; return
    fi

    local panel_domain
    panel_domain=$(grep -B 20 "proxy_pass http://remnawave" "$nginx_conf" \
        | grep "server_name" | grep -v "server_name _" \
        | awk '{print $2}' | sed 's/;//' | head -n 1)
    [ -n "$panel_domain" ] || { warn "${LANG[NGINX_CONF_PARSE_FAIL]}"; return; }

    local ck cv
    local cookie_line
    cookie_line=$(grep -A 2 "map \$http_cookie \$auth_cookie" "$nginx_conf" | grep "~\*")
    ck=$(echo "$cookie_line" | grep -oP '~\*\K\w+(?==)')
    cv=$(echo "$cookie_line" | grep -oP '=\K\w+(?=")')

    # Insert 'listen 8443 ssl;' after the existing 'listen 443 ssl;' in the panel server block
    sed -i "/server_name $panel_domain;/,/}/{s/listen 8443 ssl;//}" "$nginx_conf"
    sed -i "/server_name $panel_domain;/a \    listen 8443 ssl;" "$nginx_conf"

    cd /opt/remnawave
    docker compose down remnawave-nginx >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"
    docker compose up -d remnawave-nginx >/dev/null 2>&1 &
    spinner $! "${LANG[WAITING]}"

    ufw allow from 0.0.0.0/0 to any port 8443 proto tcp >/dev/null 2>&1
    ufw reload >/dev/null 2>&1

    local link="https://${panel_domain}:8443/auth/login?${ck}=${cv}"
    ok "${LANG[EMERGENCY_LINK]}"
    echo -e "  ${COLOR_WHITE}$link${COLOR_RESET}"
    echo -e "  ${COLOR_RED}${LANG[PORT_8443_WARNING]}${COLOR_RESET}"
}

close_port_8443() {
    [ -d /opt/remnawave ] || { warn "${LANG[DIR_NOT_FOUND]}"; return; }
    local nginx_conf=/opt/remnawave/nginx.conf
    [ -f "$nginx_conf" ] || { warn "${LANG[NGINX_CONF_PARSE_FAIL]}"; return; }

    local panel_domain
    panel_domain=$(grep -B 20 "proxy_pass http://remnawave" "$nginx_conf" \
        | grep "server_name" | grep -v "server_name _" \
        | awk '{print $2}' | sed 's/;//' | head -n 1)

    if [ -n "$panel_domain" ] && grep -A 10 "server_name $panel_domain;" "$nginx_conf" \
        | grep -q "listen 8443 ssl;"; then
        sed -i "/server_name $panel_domain;/,/}/{s/listen 8443 ssl;//}" "$nginx_conf"
        cd /opt/remnawave
        docker compose down remnawave-nginx >/dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
        docker compose up -d remnawave-nginx >/dev/null 2>&1 &
        spinner $! "${LANG[WAITING]}"
    else
        warn "${LANG[PORT_8443_NOT_OPEN]}"
    fi

    if ufw status | grep -q "8443.*ALLOW"; then
        ufw delete allow from 0.0.0.0/0 to any port 8443 proto tcp >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
        ok "${LANG[PORT_8443_CLOSED]}"
    else
        warn "${LANG[PORT_8443_ALREADY_CLOSED]}"
    fi
}

# ─── IPv6 management ─────────────────────────────────────────────────────────

show_ipv6_menu() {
    echo ""
    echo -e "${COLOR_GREEN}${LANG[IPV6_TITLE]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}1. ${LANG[IPV6_ENABLE_OPT]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}2. ${LANG[IPV6_DISABLE_OPT]}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}0. ${LANG[MENU_0]}${COLOR_RESET}"
    echo ""
    reading "${LANG[PROMPT_ACTION]}" _opt
    case "$_opt" in
        1) enable_ipv6 ;;
        2) disable_ipv6 ;;
        0) return ;;
        *) warn "${LANG[INVALID_CHOICE]}"; sleep 1; show_ipv6_menu ;;
    esac
}

enable_ipv6() {
    if grep -q "net.ipv6.conf.all.disable_ipv6 = 0" /etc/sysctl.conf 2>/dev/null \
    && ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf 2>/dev/null; then
        ok "${LANG[IPV6_ALREADY_ON]}"; return
    fi
    sed -i 's/net.ipv6.conf.all.disable_ipv6 = 1/net.ipv6.conf.all.disable_ipv6 = 0/g' \
        /etc/sysctl.conf 2>/dev/null || true
    grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf \
        || echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    ok "${LANG[IPV6_ENABLED]}"
}

disable_ipv6() {
    if grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf 2>/dev/null; then
        ok "${LANG[IPV6_ALREADY_OFF]}"; return
    fi
    sed -i 's/net.ipv6.conf.all.disable_ipv6 = 0/net.ipv6.conf.all.disable_ipv6 = 1/g' \
        /etc/sysctl.conf 2>/dev/null || true
    grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf \
        || echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    ok "${LANG[IPV6_DISABLED]}"
}
