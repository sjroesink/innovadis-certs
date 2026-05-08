#!/bin/bash
set -euo pipefail

: "${CLOUDFLARE_DNS_API_TOKEN:?required (Cloudflare token with Zone:DNS:Edit on the zone of every FQDN)}"
: "${PFX_PASSWORD:?required (password for the exported .pfx files)}"
: "${CONTACT_EMAIL:?required (ACME account contact email)}"
: "${DOMAINS:?required (comma-separated FQDN list)}"

LEGO_PATH="${LEGO_PATH:-/data}"
WEB_DIR="${WEB_DIR:-/web}"
RENEW_DAYS="${RENEW_DAYS:-30}"
RENEW_INTERVAL_SECONDS="${RENEW_INTERVAL_SECONDS:-43200}"
PORT="${PORT:-8080}"

mkdir -p "$LEGO_PATH/certificates" "$WEB_DIR"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }

issue_or_renew() {
    local domain="$1"
    local cert_path="$LEGO_PATH/certificates/${domain}.crt"

    if [[ -f "$cert_path" ]]; then
        log "renew: $domain (threshold ${RENEW_DAYS}d)"
        lego --accept-tos \
             --email "$CONTACT_EMAIL" \
             --domains "$domain" \
             --dns cloudflare \
             --path "$LEGO_PATH" \
             --pfx \
             --pfx.pass "$PFX_PASSWORD" \
             renew --days "$RENEW_DAYS" --no-random-sleep \
            || log "WARN: renew non-zero for $domain (likely not due, or transient)"
    else
        log "issue: $domain"
        lego --accept-tos \
             --email "$CONTACT_EMAIL" \
             --domains "$domain" \
             --dns cloudflare \
             --path "$LEGO_PATH" \
             --pfx \
             --pfx.pass "$PFX_PASSWORD" \
             run \
            || log "ERROR: issuance failed for $domain"
    fi
}

publish() {
    local cert_dir="$LEGO_PATH/certificates"
    local out_html="$WEB_DIR/index.html"

    rm -f "$WEB_DIR"/*.pfx
    if compgen -G "$cert_dir/*.pfx" > /dev/null; then
        cp "$cert_dir"/*.pfx "$WEB_DIR/"
    fi

    local rows=""
    for pfx in "$WEB_DIR"/*.pfx; do
        [[ -e "$pfx" ]] || continue
        local name size domain crt enddate
        name=$(basename "$pfx")
        size=$(stat -c '%s' "$pfx")
        domain="${name%.pfx}"
        crt="$cert_dir/$domain.crt"
        if [[ -f "$crt" ]]; then
            enddate=$(openssl x509 -in "$crt" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
        else
            enddate="-"
        fi
        rows+="<tr><td><a href=\"${name}\">${name}</a></td><td>${size}</td><td>${enddate}</td></tr>"$'\n'
    done

    cat > "$out_html" <<HTML
<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="robots" content="noindex,nofollow">
<title>Innovadis tenant test certificates</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; max-width: 60em; margin: 2em auto; padding: 0 1em; color: #111; }
  h1 { margin-bottom: 0.2em; }
  .meta { color: #555; font-size: .9em; }
  code { background:#eee; padding: .1em .35em; border-radius: .2em; }
  table { width: 100%; border-collapse: collapse; margin-top: 1em; font-size: .92em; }
  th, td { text-align: left; padding: .4em .8em; border-bottom: 1px solid #eee; }
  th { color: #555; font-weight: 600; }
  a { color: #0366d6; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .footer { margin-top: 2em; color: #888; font-size: .85em; }
</style>
</head>
<body>
<h1>Innovadis tenant test certificates</h1>
<p class="meta">
PFX-bestanden voor de pre-made tenant testdomeinen onder <code>innovadis.roes.ink</code>.<br>
Wachtwoord: <code>${PFX_PASSWORD}</code> &middot; laatst geactualiseerd: $(date -u +%FT%TZ)
</p>

<table>
<thead><tr><th>Bestand</th><th>Bytes</th><th>Geldig tot</th></tr></thead>
<tbody>
${rows}
</tbody>
</table>

<p class="footer">Beheerd door Sander Roesink &middot; auto-renewal via lego (Cloudflare DNS-01) &middot;
broncode: <a href="https://github.com/sjroesink/innovadis-certs">github.com/sjroesink/innovadis-certs</a></p>
</body>
</html>
HTML
}

run_all() {
    local -a arr
    IFS=',' read -ra arr <<< "$DOMAINS"
    for d in "${arr[@]}"; do
        d="${d// /}"
        [[ -n "$d" ]] && issue_or_renew "$d"
    done
    publish
    log "published $(ls -1 "$WEB_DIR"/*.pfx 2>/dev/null | wc -l) pfx files"
}

run_all

log "starting nginx on :${PORT}"
sed "s/__PORT__/${PORT}/g" /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp
mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
nginx -g 'daemon off;' &
NGINX_PID=$!
trap 'log "shutting down"; kill -TERM "$NGINX_PID" 2>/dev/null || true; exit 0' INT TERM

while true; do
    sleep "$RENEW_INTERVAL_SECONDS"
    log "scheduled renewal pass"
    run_all
done
