#!/bin/bash
# Module: Remnawave REST API helpers

_api() {
    local method="$1" url="$2" token="$3" data="${4:-}"
    local args=(
        -s -X "$method" "$url"
        -H "Authorization: Bearer $token"
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1"
        -H "X-Forwarded-Proto: https"
        -H "X-Remnawave-Client-Type: browser"
    )
    if [ -n "$data" ]; then
        curl "${args[@]}" -d "$data"
    else
        curl "${args[@]}"
    fi
}

register_remnawave() {
    local domain_url="$1" username="$2" password="$3"
    local resp
    resp=$(_api POST "http://$domain_url/api/auth/register" "" \
        "{\"username\":\"$username\",\"password\":\"$password\"}")
    if [ -z "$resp" ]; then
        error "${LANG[ERROR_EMPTY_RESPONSE_REGISTER]}"
    fi
    local tok
    tok=$(echo "$resp" | jq -r '.response.accessToken // empty')
    if [ -z "$tok" ]; then
        error "${LANG[ERROR_REGISTER]}: $(echo "$resp" | jq -r '.message // .')"
    fi
    echo "$tok"
}

get_panel_token() {
    local domain_url="127.0.0.1:3000"
    local TOKEN_FILE="${RW_DIR}/token"
    local token=""

    if [ -f "$TOKEN_FILE" ]; then
        token=$(cat "$TOKEN_FILE")
        info "${LANG[USING_SAVED_TOKEN]}"
        local test
        test=$(_api GET "http://$domain_url/api/config-profiles" "$token")
        if ! echo "$test" | jq -e '.response.configProfiles' >/dev/null 2>&1; then
            warn "${LANG[INVALID_SAVED_TOKEN]}"
            token=""
        fi
    fi

    if [ -z "$token" ]; then
        reading "${LANG[ENTER_PANEL_USERNAME]}" _user
        reading "${LANG[ENTER_PANEL_PASSWORD]}" _pass
        local resp
        resp=$(_api POST "http://$domain_url/api/auth/login" "" \
            "{\"username\":\"$_user\",\"password\":\"$_pass\"}")
        token=$(echo "$resp" | jq -r '.response.accessToken // .accessToken // empty')
        if [ -z "$token" ] || [ "$token" = "null" ]; then
            error "${LANG[ERROR_TOKEN]}: $(echo "$resp" | jq -r '.message // .')"
        fi
        mkdir -p "$RW_DIR"
        echo "$token" > "$TOKEN_FILE"
        ok "${LANG[TOKEN_RECEIVED_AND_SAVED]}"
    else
        ok "${LANG[TOKEN_USED_SUCCESSFULLY]}"
    fi

    echo "$token"
}

generate_xray_keys() {
    local domain_url="$1" token="$2"
    local resp
    resp=$(_api GET "http://$domain_url/api/system/tools/x25519/generate" "$token")
    if [ -z "$resp" ]; then error "${LANG[ERROR_GENERATE_KEYS]}"; fi
    local pk
    pk=$(echo "$resp" | jq -r '.response.keypairs[0].privateKey // empty')
    if [ -z "$pk" ] || [ "$pk" = "null" ]; then
        error "${LANG[ERROR_EXTRACT_PRIVATE_KEY]}"
    fi
    echo "$pk"
}

get_public_key() {
    local domain_url="$1" token="$2"
    local resp
    resp=$(_api GET "http://$domain_url/api/keygen" "$token")
    if [ -z "$resp" ]; then error "${LANG[ERROR_PUBLIC_KEY]}"; fi
    local pk
    pk=$(echo "$resp" | jq -r '.response.pubKey // empty')
    if [ -z "$pk" ] || [ "$pk" = "null" ]; then
        error "${LANG[ERROR_EXTRACT_PUBLIC_KEY]}"
    fi
    echo "$pk"
}

delete_default_profile() {
    local domain_url="$1" token="$2"
    local resp
    resp=$(_api GET "http://$domain_url/api/config-profiles" "$token")
    local uuid
    uuid=$(echo "$resp" | jq -r '.response.configProfiles[] | select(.name=="Default-Profile") | .uuid' 2>/dev/null)
    if [ -z "$uuid" ]; then
        info "${LANG[NO_DEFAULT_PROFILE]}"
        return 0
    fi
    _api DELETE "http://$domain_url/api/config-profiles/$uuid" "$token" >/dev/null
}

create_config_profile() {
    local domain_url="$1" token="$2" name="$3" domain="$4" private_key="$5"
    local inbound_tag="${6:-Steal}"
    local short_id
    short_id=$(openssl rand -hex 8)

    local body
    body=$(jq -n \
        --arg name "$name" \
        --arg domain "$domain" \
        --arg pk "$private_key" \
        --arg sid "$short_id" \
        --arg tag "$inbound_tag" \
    '{
        name: $name,
        config: {
            log: { loglevel: "warning" },
            dns: {
                queryStrategy: "UseIPv4",
                servers: [{ address: "https://dns.google/dns-query", skipFallback: false }]
            },
            inbounds: [{
                tag: $tag,
                port: 443,
                protocol: "vless",
                settings: { clients: [], decryption: "none" },
                sniffing: { enabled: true, destOverride: ["http","tls","quic"] },
                streamSettings: {
                    network: "tcp",
                    security: "reality",
                    realitySettings: {
                        show: false,
                        xver: 1,
                        dest: "/dev/shm/nginx.sock",
                        spiderX: "",
                        shortIds: [$sid],
                        privateKey: $pk,
                        serverNames: [$domain]
                    }
                }
            }],
            outbounds: [
                { tag: "DIRECT", protocol: "freedom" },
                { tag: "BLOCK",  protocol: "blackhole" }
            ],
            routing: { rules: [
                { ip: ["geoip:private"], type: "field", outboundTag: "BLOCK" },
                { type: "field", protocol: ["bittorrent"], outboundTag: "BLOCK" }
            ]}
        }
    }')

    local resp
    resp=$(_api POST "http://$domain_url/api/config-profiles" "$token" "$body")
    local config_uuid inbound_uuid
    config_uuid=$(echo "$resp" | jq -r '.response.uuid // empty')
    inbound_uuid=$(echo "$resp" | jq -r '.response.inbounds[0].uuid // empty')
    if [ -z "$config_uuid" ] || [ "$config_uuid" = "null" ] \
    || [ -z "$inbound_uuid" ] || [ "$inbound_uuid" = "null" ]; then
        error "${LANG[ERROR_CREATE_CONFIG_PROFILE]}: $(echo "$resp" | jq -r '.message // .')"
    fi
    echo "$config_uuid $inbound_uuid"
}

create_node() {
    local domain_url="$1" token="$2" cfg_uuid="$3" inbound_uuid="$4"
    local address="${5:-127.0.0.1}" name="${6:-Steal}"

    local body
    body=$(jq -n \
        --arg name "$name" \
        --arg addr "$address" \
        --arg cfg  "$cfg_uuid" \
        --arg ib   "$inbound_uuid" \
    '{
        name: $name,
        address: $addr,
        port: 2222,
        configProfile: {
            activeConfigProfileUuid: $cfg,
            activeInbounds: [$ib]
        },
        isTrafficTrackingActive: false,
        trafficLimitBytes: 0,
        notifyPercent: 0,
        trafficResetDay: 31,
        excludedInbounds: [],
        countryCode: "XX",
        consumptionMultiplier: 1.0
    }')

    local resp
    resp=$(_api POST "http://$domain_url/api/nodes" "$token" "$body")
    if [ -z "$resp" ]; then error "${LANG[ERROR_EMPTY_RESPONSE_NODE]}"; fi
    if ! echo "$resp" | jq -e '.response.uuid' >/dev/null; then
        error "${LANG[ERROR_CREATE_NODE]}: $(echo "$resp" | jq -r '.message // .')"
    fi
    ok "${LANG[NODE_CREATED]}"
}

create_host() {
    local domain_url="$1" token="$2" inbound_uuid="$3" address="$4"
    local cfg_uuid="$5" remark="${6:-Steal}"

    local body
    body=$(jq -n \
        --arg cfg  "$cfg_uuid" \
        --arg ib   "$inbound_uuid" \
        --arg rem  "$remark" \
        --arg addr "$address" \
    '{
        inbound: {
            configProfileUuid: $cfg,
            configProfileInboundUuid: $ib
        },
        remark: $rem,
        address: $addr,
        port: 443,
        path: "",
        sni: $addr,
        host: "",
        alpn: null,
        fingerprint: "chrome",
        allowInsecure: false,
        isDisabled: false,
        securityLayer: "DEFAULT"
    }')

    local resp
    resp=$(_api POST "http://$domain_url/api/hosts" "$token" "$body")
    if [ -z "$resp" ]; then error "${LANG[ERROR_EMPTY_RESPONSE_HOST]}"; fi
    if ! echo "$resp" | jq -e '.response.uuid' >/dev/null; then
        error "${LANG[ERROR_CREATE_HOST]}: $(echo "$resp" | jq -r '.message // .')"
    fi
    ok "${LANG[HOST_CREATED]}"
}

get_squads() {
    local domain_url="$1" token="$2"
    local resp
    resp=$(_api GET "http://$domain_url/api/internal-squads" "$token")
    if ! echo "$resp" | jq -e '.response.internalSquads' >/dev/null 2>&1; then
        warn "${LANG[ERROR_GET_SQUAD]}: $(echo "$resp" | jq -r '.message // .')"
        return 1
    fi
    echo "$resp" | jq -r '.response.internalSquads[].uuid' 2>/dev/null
}

update_squad() {
    local domain_url="$1" token="$2" squad_uuid="$3" inbound_uuid="$4"

    # Validate UUIDs
    local uuid_re='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    [[ "$squad_uuid"   =~ $uuid_re ]] || { warn "${LANG[INVALID_SQUAD_UUID]} $squad_uuid"; return 1; }
    [[ "$inbound_uuid" =~ $uuid_re ]] || { warn "${LANG[INVALID_INBOUND_UUID]} $inbound_uuid"; return 1; }

    # Fetch existing inbounds for this squad
    local resp
    resp=$(_api GET "http://$domain_url/api/internal-squads" "$token")
    local existing_arr
    existing_arr=$(echo "$resp" \
        | jq -r --arg uuid "$squad_uuid" \
        '.response.internalSquads[] | select(.uuid==$uuid) | .inbounds[].uuid' 2>/dev/null \
        | jq -R . | jq -s . 2>/dev/null)
    [ -z "$existing_arr" ] && existing_arr="[]"

    local new_arr
    new_arr=$(jq -n --argjson e "$existing_arr" --arg n "$inbound_uuid" '$e+[$n]|unique')

    local body
    body=$(jq -n --arg uuid "$squad_uuid" --argjson ib "$new_arr" '{uuid:$uuid,inbounds:$ib}')
    local patch_resp
    patch_resp=$(_api PATCH "http://$domain_url/api/internal-squads" "$token" "$body")
    if ! echo "$patch_resp" | jq -e '.response.uuid' >/dev/null 2>&1; then
        warn "${LANG[ERROR_UPDATE_SQUAD]} $squad_uuid: $(echo "$patch_resp" | jq -r '.message // .')"
        return 1
    fi
    ok "${LANG[UPDATE_SQUAD]} $squad_uuid"
}

create_api_token() {
    local domain_url="$1" token="$2" compose_file="$3"
    local token_name="${4:-subscription-page}"

    local resp
    resp=$(_api POST "http://$domain_url/api/tokens" "$token" \
        "{\"tokenName\":\"$token_name\"}")
    local api_tok
    api_tok=$(echo "$resp" | jq -r '.response.token // empty')
    if [ -z "$api_tok" ] || [ "$api_tok" = "null" ]; then
        error "${LANG[ERROR_CREATE_API_TOKEN]}: $(echo "$resp" | jq -r '.message // .')"
    fi
    sed -i "s|REMNAWAVE_API_TOKEN=.*|REMNAWAVE_API_TOKEN=$api_tok|" "$compose_file"
    ok "${LANG[API_TOKEN_ADDED]}"
}

check_node_domain_exists() {
    local domain_url="$1" token="$2" domain="$3"
    local resp
    resp=$(_api GET "http://$domain_url/api/nodes" "$token")
    if ! echo "$resp" | jq -e '.response' >/dev/null 2>&1; then
        warn "${LANG[ERROR_CHECK_DOMAIN]}: $(echo "$resp" | jq -r '.message // .')"
        return 1
    fi
    local existing
    existing=$(echo "$resp" | jq -r --arg d "$domain" '.response[]|select(.address==$d)|.address' 2>/dev/null)
    if [ -n "$existing" ]; then
        warn "${LANG[DOMAIN_ALREADY_EXISTS]}: $domain"
        return 1
    fi
    return 0
}
