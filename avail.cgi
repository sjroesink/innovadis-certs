#!/bin/bash
# CGI endpoint (/avail.json): serves availability of all domains, re-running
# the checks at most once per AVAIL_TTL_SECONDS (concurrent requests wait on
# the lock and then serve the freshly written cache).
set -uo pipefail

CACHE="${AVAIL_CACHE:-/tmp/avail-cache.json}"
LOCK="${CACHE}.lock"
TTL="${AVAIL_TTL_SECONDS:-10}"

fresh() {
    [[ -f "$CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$CACHE") < TTL ))
}

if ! fresh; then
    exec 9>"$LOCK"
    flock -x 9
    if ! fresh; then
        if /usr/local/bin/check-avail.sh > "${CACHE}.tmp"; then
            mv "${CACHE}.tmp" "$CACHE"
        fi
    fi
    exec 9>&-
fi

printf 'Content-Type: application/json\r\n'
printf 'Cache-Control: public, max-age=%s\r\n' "$TTL"
printf '\r\n'
if [[ -f "$CACHE" ]]; then
    cat "$CACHE"
else
    printf '{"checkedAt":null,"domains":{}}\n'
fi
