#!/bin/bash
# Module: Add node to existing panel (run on panel server)

add_node_to_panel() {
    echo ""
    echo -e "${COLOR_RED}${LANG[WARNING_LABEL]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}${LANG[WARNING_NODE_PANEL]}${COLOR_RESET}"
    echo ""
    reading "${LANG[CONFIRM_SERVER_PANEL]}" _c
    [[ "$_c" != "y" && "$_c" != "Y" ]] && { echo -e "${COLOR_YELLOW}${LANG[EXIT]}${COLOR_RESET}"; return; }

    local domain_url="127.0.0.1:3000"

    info "${LANG[ADD_NODE_TO_PANEL]}"
    local token
    token=$(get_panel_token) || return 1

    # Node domain
    local NODE_DOMAIN
    while true; do
        reading "${LANG[ENTER_NODE_DOMAIN]}" NODE_DOMAIN
        check_node_domain_exists "$domain_url" "$token" "$NODE_DOMAIN" && break
        warn "${LANG[TRY_ANOTHER_DOMAIN]}"
    done

    # Node name
    local NODE_NAME
    while true; do
        reading "${LANG[ENTER_NODE_NAME]}" NODE_NAME
        if ! [[ "$NODE_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
            warn "${LANG[CF_INVALID_CHARS]}"; continue
        fi
        if (( ${#NODE_NAME} < 3 || ${#NODE_NAME} > 20 )); then
            warn "${LANG[CF_INVALID_LENGTH]}"; continue
        fi
        local existing_profiles
        existing_profiles=$(_api GET "http://$domain_url/api/config-profiles" "$token")
        if echo "$existing_profiles" \
            | jq -e --arg n "$NODE_NAME" '.response.configProfiles[]|select(.name==$n)' \
            >/dev/null 2>&1; then
            warn "$(printf "${LANG[CF_INVALID_NAME]}" "$NODE_NAME")"
            continue
        fi
        break
    done

    info "${LANG[GENERATE_KEYS]}"
    local private_key
    private_key=$(generate_xray_keys "$domain_url" "$token")
    ok "${LANG[GENERATE_KEYS_SUCCESS]}"

    info "${LANG[CREATING_CONFIG_PROFILE]}"
    local cfg_uuid ib_uuid
    read cfg_uuid ib_uuid <<< "$(create_config_profile \
        "$domain_url" "$token" "$NODE_NAME" "$NODE_DOMAIN" "$private_key" "$NODE_NAME")"
    ok "${LANG[CONFIG_PROFILE_CREATED]}: $NODE_NAME"

    info "${LANG[CREATING_NODE]}"
    create_node "$domain_url" "$token" "$cfg_uuid" "$ib_uuid" "$NODE_DOMAIN" "$NODE_NAME"

    info "${LANG[CREATE_HOST]}"
    create_host "$domain_url" "$token" "$ib_uuid" "$NODE_DOMAIN" "$cfg_uuid" "$NODE_NAME"

    info "${LANG[GET_DEFAULT_SQUAD]}"
    local squads
    squads=$(get_squads "$domain_url" "$token")
    if [ -z "$squads" ]; then
        warn "${LANG[NO_SQUADS_TO_UPDATE]}"
    else
        while IFS= read -r sq; do
            [ -z "$sq" ] && continue
            info "${LANG[UPDATING_SQUAD]} $sq"
            update_squad "$domain_url" "$token" "$sq" "$ib_uuid" \
                && ok "${LANG[UPDATE_SQUAD]} $sq" \
                || warn "${LANG[ERROR_UPDATE_SQUAD]} $sq"
        done <<< "$squads"
    fi

    echo ""
    ok "${LANG[NODE_ADDED_SUCCESS]}"
    echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_RED}${LANG[POST_PANEL_INSTRUCTION]}${COLOR_RESET}"
    echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
}
