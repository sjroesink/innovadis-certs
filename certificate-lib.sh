#!/usr/bin/env bash

# Issue or renew one private wildcard certificate. The wildcard and its apex are
# kept in the same certificate so both *.example.com and example.com validate.
# Files live under $LEGO_PATH/private and are never copied to the public web dir.
issue_private_wildcard() {
    local wildcard="$1"
    local apex="${wildcard#*.}"
    local private_path="${LEGO_PATH}/private"
    local basename="${wildcard/\*/_}"
    local cert_path="$private_path/certificates/${basename}.crt"
    local lego_bin="${LEGO_BIN:-lego}"

    [[ "$wildcard" == \*.* ]] || {
        printf 'PRIVATE_WILDCARD_DOMAIN must start with *. (%s)\n' "$wildcard" >&2
        return 1
    }

    mkdir -p "$private_path/certificates"

    if [[ -f "$cert_path" ]]; then
        "$lego_bin" --accept-tos \
            --email "$CONTACT_EMAIL" \
            --domains "$wildcard" \
            --domains "$apex" \
            --dns cloudflare \
            --path "$private_path" \
            --pfx \
            --pfx.pass "$PFX_PASSWORD" \
            renew --days "$RENEW_DAYS" --no-random-sleep
    else
        "$lego_bin" --accept-tos \
            --email "$CONTACT_EMAIL" \
            --domains "$wildcard" \
            --domains "$apex" \
            --dns cloudflare \
            --path "$private_path" \
            --pfx \
            --pfx.pass "$PFX_PASSWORD" \
            run
    fi

    # A wildcard private key must never become world-readable on the host.
    find "$private_path" -type d -exec chmod 700 {} +
    find "$private_path" -type f -exec chmod 600 {} +
}
