#!/bin/bash
# Remnawave Installer — modular, self-contained
set -euo pipefail

SCRIPT_VERSION="1.0.0"

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo bash ...)." >&2
    exit 1
fi

RW_DIR="/usr/local/remnawave"
LANG_FILE="${RW_DIR}/language"
LIB_DIR="${RW_DIR}/lib"

GITHUB_RAW="https://raw.githubusercontent.com/yousufzoda/remnawave-installer/main"
MODULES=(core packages certs api panel node add_node manage)

# ── Module loader ─────────────────────────────────────────────────────────────
# When run via curl (bash <(curl ...)), BASH_SOURCE[0] is /dev/fd/N.
# Detect local vs remote mode and download libs if needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || SCRIPT_DIR=""
LOCAL_LIB="${SCRIPT_DIR}/lib"

_download_lib() {
    local mod="$1"
    local dest="${LIB_DIR}/${mod}.sh"
    local url="${GITHUB_RAW}/lib/${mod}.sh"

    mkdir -p "$LIB_DIR"

    local mirrors=(
        "$url"
        "https://cdn.jsdelivr.net/gh/yousufzoda/remnawave-installer@main/lib/${mod}.sh"
    )

    for mirror in "${mirrors[@]}"; do
        if curl -fsSL --max-time 15 "$mirror" -o "${dest}.tmp" 2>/dev/null; then
            if [ -s "${dest}.tmp" ] && head -1 "${dest}.tmp" | grep -q "^#!/bin/bash"; then
                mv "${dest}.tmp" "$dest"
                return 0
            fi
        fi
    done
    rm -f "${dest}.tmp"
    echo "ERROR: Failed to download lib/${mod}.sh" >&2
    exit 1
}

_load_modules() {
    for mod in "${MODULES[@]}"; do
        local local_file="${LOCAL_LIB}/${mod}.sh"
        local cached_file="${LIB_DIR}/${mod}.sh"

        if [ -f "$local_file" ]; then
            # Running from cloned repo
            source "$local_file"
        elif [ -f "$cached_file" ]; then
            # Previously downloaded
            source "$cached_file"
        else
            # First run via curl — download
            echo "Downloading lib/${mod}.sh..." >&2
            _download_lib "$mod"
            source "${LIB_DIR}/${mod}.sh"
        fi
    done
}

_load_modules

# ── Install script to /usr/local/bin so user can type `remnawave` ─────────────
_install_shortcut() {
    mkdir -p "$LIB_DIR"

    # Copy main script to persistent location
    local target="${RW_DIR}/remnawave.sh"
    if [ ! -f "$target" ] || [ "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null)" != "$(realpath "$target" 2>/dev/null)" ]; then
        if [ -f "${BASH_SOURCE[0]}" ] && [ -f "${SCRIPT_DIR}/remnawave.sh" ]; then
            cp "${SCRIPT_DIR}/remnawave.sh" "$target"
        else
            # Downloaded via curl — save this script
            curl -fsSL "${GITHUB_RAW}/remnawave.sh" -o "$target" 2>/dev/null || true
        fi
        chmod +x "$target" 2>/dev/null || true
    fi

    # Symlink to /usr/local/bin/remnawave
    if [ ! -e /usr/local/bin/remnawave ]; then
        ln -sf "$target" /usr/local/bin/remnawave 2>/dev/null || true
        echo "  Installed: remnawave (run it from anywhere)" >&2
    fi
}

# ── Language selection ────────────────────────────────────────────────────────
_load_saved_lang() {
    [ -f "$LANG_FILE" ] || return 1
    case $(cat "$LANG_FILE") in
        1) load_lang_en; return 0 ;;
        2) load_lang_ru; return 0 ;;
    esac
    return 1
}

_select_lang() {
    echo ""
    echo -e "\033[1;36m╭──────────────────────────────────────────╮\033[0m"
    echo -e "\033[1;36m│   \033[1;33mREMNAWAVE INSTALLER  v${SCRIPT_VERSION}\033[1;36m           │\033[0m"
    echo -e "\033[1;36m╰──────────────────────────────────────────╯\033[0m"
    echo ""
    echo -e "\033[1;33mSelect language / Выберите язык:\033[0m"
    echo -e "\033[1;32m1.\033[0m English"
    echo -e "\033[1;32m2.\033[0m Русский"
    echo ""
    while true; do
        read -rp " [1/2]: " _choice
        case "$_choice" in
            1) load_lang_en; mkdir -p "$RW_DIR"; echo "1" > "$LANG_FILE"; break ;;
            2) load_lang_ru; mkdir -p "$RW_DIR"; echo "2" > "$LANG_FILE"; break ;;
            *) echo "Invalid / Неверный выбор" ;;
        esac
    done
    clear
}

_load_saved_lang || _select_lang

# ── Pre-flight ────────────────────────────────────────────────────────────────
check_root
check_os
_install_shortcut

# ── Main menu ─────────────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo -e "${COLOR_CYAN}╭──────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│   \033[1;33mREMNAWAVE INSTALLER  v${SCRIPT_VERSION}\033[1;36m           │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰──────────────────────────────────────────╯${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}1.${COLOR_RESET} ${LANG[MENU_1]}"
    echo -e "${COLOR_YELLOW}2.${COLOR_RESET} ${LANG[MENU_2]}"
    echo -e "${COLOR_YELLOW}3.${COLOR_RESET} ${LANG[MENU_3]}"
    echo ""
    echo -e "${COLOR_YELLOW}4.${COLOR_RESET} ${LANG[MENU_4]}"
    echo -e "${COLOR_YELLOW}5.${COLOR_RESET} ${LANG[MENU_5]}"
    echo -e "${COLOR_YELLOW}6.${COLOR_RESET} ${LANG[MENU_6]}"
    echo ""
    echo -e "${COLOR_YELLOW}0.${COLOR_RESET} ${LANG[MENU_0]}"
    echo ""
}

main() {
    while true; do
        show_menu
        reading "${LANG[PROMPT_ACTION]}" OPTION
        case "$OPTION" in
            1) install_panel ;;
            2) install_node ;;
            3) add_node_to_panel ;;
            4) show_manage_menu ;;
            5) manage_certificates ;;
            6) show_ipv6_menu ;;
            0) echo -e "${COLOR_YELLOW}${LANG[EXIT]}${COLOR_RESET}"; exit 0 ;;
            *) warn "${LANG[INVALID_CHOICE]}"; sleep 1 ;;
        esac
    done
}

main
