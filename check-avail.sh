#!/bin/bash
# Checks availability ("vrij") of every FQDN in $DOMAINS in parallel and
# emits JSON: {"checkedAt":"...","domains":{"<fqdn>":"free|in_use",...}}
set -uo pipefail

DOMAINS="${DOMAINS:-$(cat /run/domains 2>/dev/null || true)}"

check_availability() {
    local fqdn="$1"
    local subject
    subject=$(timeout 4 openssl s_client -connect "${fqdn}:443" -servername "${fqdn}" </dev/null 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | sed 's/^subject=//')
    if [[ -z "$subject" ]]; then
        echo "free"
    elif [[ "$subject" =~ CN[[:space:]]*=[[:space:]]*${fqdn} ]]; then
        echo "in_use"
    else
        echo "free"
    fi
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

declare -a domains=()
IFS=',' read -ra arr <<< "$DOMAINS"
for d in "${arr[@]}"; do
    d="${d// /}"
    [[ -n "$d" ]] || continue
    domains+=("$d")
    check_availability "$d" > "$tmpdir/$d" &
done
wait

printf '{"checkedAt":"%s","domains":{' "$(date -u +%FT%TZ)"
sep=""
for d in "${domains[@]}"; do
    printf '%s"%s":"%s"' "$sep" "$d" "$(cat "$tmpdir/$d")"
    sep=","
done
printf '}}\n'
