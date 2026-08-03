#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
cleanup() { rm -rf -- "$TMP"; }
trap cleanup EXIT

fail() {
  printf 'Update mock FAILED: %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local description=$1
  shift
  if ("$@" >/dev/null 2>&1); then
    fail "$description"
  fi
}

cp "$ROOT/src/mikrus-wg" "$TMP/mikrus-wg"
python3 - "$TMP/mikrus-wg" "$TMP" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
tmp = sys.argv[2]
text = path.read_text()
replacements = {
    'readonly INSTALL_PATH="/usr/local/sbin/${APP_NAME}"': f'readonly INSTALL_PATH="{tmp}/installed-mikrus-wg"',
    'readonly STATE_DIR="/etc/mikrus-wg"': f'readonly STATE_DIR="{tmp}/state"',
    'readonly WIREGUARD_DIR="/etc/wireguard"': f'readonly WIREGUARD_DIR="{tmp}/wireguard"',
    'readonly SYSCTL_FILE="/etc/sysctl.d/99-mikrus-wireguard.conf"': f'readonly SYSCTL_FILE="{tmp}/sysctl.conf"',
    'readonly LOCK_FILE="/run/lock/${APP_NAME}.lock"': f'readonly LOCK_FILE="{tmp}/lock"',
}
for old, new in replacements.items():
    if text.count(old) != 1:
        raise SystemExit(f"Oczekiwano dokładnie jednej linii do podmiany: {old}")
    text = text.replace(old, new, 1)
path.write_text(text)
PY

mkdir -p "$TMP/state/clients" "$TMP/wireguard" "$TMP/bin" "$TMP/payload"
chmod 700 "$TMP/state" "$TMP/state/clients" "$TMP/wireguard"
cat >"$TMP/state/settings" <<'EOF_SETTINGS'
ENDPOINT=xander504.mikr.us.xyz
WG_PORT=20504
NETWORK_BASE=10.77.77
VPN_CIDR=10.77.77.0/24
SERVER_VPN_IP=10.77.77.1
WG_IF=wg0
POLICY=acl
CUSTOM_PORTS=
KEEPALIVE=25
MIKRUS_ID=504
ADMIN_SLOTS=5
SOURCE_REPOSITORY=arturkupka34/wireguard-vpn-mikrus
SOURCE_REF=main
ORIGINAL_IP_FORWARD=0
EOF_SETTINGS
chmod 600 "$TMP/state/settings"
printf 'stara-wersja\n' >"$TMP/installed-mikrus-wg"
chmod 755 "$TMP/installed-mikrus-wg"

cat >"$TMP/payload/mikrus-wg" <<'EOF_PAYLOAD'
#!/usr/bin/env bash
set -Eeuo pipefail
readonly APP_NAME="mikrus-wg"
readonly VERSION="9.9.9"
if [[ ${1:-} == version ]]; then
  printf 'mikrus-wg 9.9.9\n'
fi
EOF_PAYLOAD
chmod 755 "$TMP/payload/mikrus-wg"
(
  cd "$TMP/payload"
  sha256sum mikrus-wg | awk '{print $1 "  mikrus-wg"}' >mikrus-wg.sha256
)

cat >"$TMP/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
set -Eeuo pipefail
url=''
output=''
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    http*) url=$1; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */mikrus-wg) cp -- "$UPDATE_SOURCE" "$output" ;;
  */mikrus-wg.sha256) cp -- "$UPDATE_CHECKSUM" "$output" ;;
  *) exit 22 ;;
esac
EOF_CURL
chmod 755 "$TMP/bin/curl"

export PATH="$TMP/bin:$PATH"
export UPDATE_SOURCE="$TMP/payload/mikrus-wg"
export UPDATE_CHECKSUM="$TMP/payload/mikrus-wg.sha256"
# shellcheck disable=SC1090
source "$TMP/mikrus-wg"
require_root() { :; }

self_update >/dev/null
grep -Fqx 'readonly VERSION="9.9.9"' "$TMP/installed-mikrus-wg" ||
  fail "nie zainstalowano poprawnej aktualizacji"
[[ ! -L "$TMP/installed-mikrus-wg" ]] || fail "aktualizacja utworzyła dowiązanie"

printf 'stara-wersja\n' >"$TMP/installed-mikrus-wg"
printf '%064d  mikrus-wg\n' 0 >"$TMP/payload/mikrus-wg.sha256"
expect_fail "update zaakceptował błędną sumę SHA-256" self_update
[[ $(<"$TMP/installed-mikrus-wg") == 'stara-wersja' ]] ||
  fail "błędna aktualizacja zmieniła zainstalowany program"

rm -f -- "$TMP/installed-mikrus-wg"
ln -s "$TMP/symlink-target" "$TMP/installed-mikrus-wg"
(
  cd "$TMP/payload"
  sha256sum mikrus-wg | awk '{print $1 "  mikrus-wg"}' >mikrus-wg.sha256
)
expect_fail "update zaakceptował dowiązanie jako ścieżkę programu" self_update
[[ -L "$TMP/installed-mikrus-wg" ]] || fail "update zmienił dowiązanie mimo odmowy"

printf 'Update mock tests: OK\n'
