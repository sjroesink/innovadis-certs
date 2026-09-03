#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export LEGO_PATH="$TMP/data"
export PFX_PASSWORD="test-password"
export CONTACT_EMAIL="test@example.com"
export RENEW_DAYS=30
export LEGO_BIN="$TMP/lego"
export LEGO_ARGS_FILE="$TMP/lego-args"

cat > "$LEGO_BIN" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$LEGO_ARGS_FILE"
path=""
first_domain=""
while (($#)); do
  case "$1" in
    --path) path="$2"; shift 2 ;;
    --domains) [[ -n "$first_domain" ]] || first_domain="$2"; shift 2 ;;
    *) shift ;;
  esac
done
name=${first_domain/\*/_}
mkdir -p "$path/certificates"
printf 'pfx' > "$path/certificates/$name.pfx"
MOCK
chmod +x "$LEGO_BIN"

source "$ROOT/certificate-lib.sh"
issue_private_wildcard '*.innovadis.sander.ninja'

args=$(<"$LEGO_ARGS_FILE")
[[ "$args" == *$'--domains\n*.innovadis.sander.ninja'* ]]
[[ "$args" == *$'--domains\ninnovadis.sander.ninja'* ]]
[[ "$args" == *$'--path\n'"$LEGO_PATH/private"* ]]
[[ "$args" == *$'--pfx\n'* ]]
[[ "$args" == *$'run\n'* || "$args" == *$'run' ]]
[[ -s "$LEGO_PATH/private/certificates/_.innovadis.sander.ninja.pfx" ]]
[[ ! -e "$LEGO_PATH/certificates/_.innovadis.sander.ninja.pfx" ]]

printf 'crt' > "$LEGO_PATH/private/certificates/_.innovadis.sander.ninja.crt"
: > "$LEGO_ARGS_FILE"
issue_private_wildcard '*.innovadis.sander.ninja'
renew_args=$(<"$LEGO_ARGS_FILE")
[[ "$renew_args" == *$'renew\n'* || "$renew_args" == *$'renew' ]]
[[ "$renew_args" == *$'--days\n30'* ]]
[[ "$renew_args" == *$'--no-random-sleep'* ]]

printf 'private wildcard issuance and renewal test: ok\n'
