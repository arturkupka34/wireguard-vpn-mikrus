#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  printf 'Config mock FAILED: %s\n' "$*" >&2
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

mkdir -p "$TMP/state/clients" "$TMP/wireguard" "$TMP/bin"
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
printf '%s\n' 'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=' >"$TMP/state/server.key"
printf '%s\n' 'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE=' >"$TMP/state/server.pub"
chmod 600 "$TMP/state/server.key" "$TMP/state/server.pub"
cp "$TMP/mikrus-wg" "$TMP/installed-mikrus-wg"
chmod 755 "$TMP/installed-mikrus-wg"

cat >"$TMP/bin/wg" <<'EOF_WG'
#!/usr/bin/env bash
set -Eeuo pipefail

next_counter() {
  local current=0
  [[ -f "$WG_COUNTER_FILE" ]] && current=$(<"$WG_COUNTER_FILE")
  current=$((current + 1))
  printf '%s\n' "$current" >"$WG_COUNTER_FILE"
  printf '%s\n' "$current"
}

key_from_text() {
  python3 -c 'import base64, hashlib, sys; print(base64.b64encode(hashlib.sha256(sys.stdin.buffer.read()).digest()).decode())'
}

case "${1:-}" in
  genkey)
    next_counter | key_from_text
    ;;
  pubkey)
    key_from_text
    ;;
  genpsk)
    { printf 'psk:'; next_counter; } | key_from_text
    ;;
  syncconf)
    [[ ${WG_FAIL_SYNC:-0} == 0 ]]
    ;;
  show) exit 0 ;;
  *) exit 0 ;;
esac
EOF_WG

cat >"$TMP/bin/wg-quick" <<'EOF_WG_QUICK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${1:-} == strip && -n ${2:-} ]]; then
  cat "$2"
fi
EOF_WG_QUICK

cat >"$TMP/bin/systemctl" <<'EOF_SYSTEMCTL'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  is-active) exit 0 ;;
  restart) [[ ${SYSTEMCTL_FAIL_RESTART:-0} == 0 ]] ;;
  start|enable|disable|show-environment|status) exit 0 ;;
  *) exit 0 ;;
esac
EOF_SYSTEMCTL

cat >"$TMP/bin/iptables" <<'EOF_IPTABLES'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${IPTABLES_FAIL:-0} == 1 ]]; then
  exit 1
fi
for argument in "$@"; do
  [[ "$argument" == -C ]] && exit 1
done
exit 0
EOF_IPTABLES
chmod +x "$TMP/bin/"*

# shellcheck disable=SC1090
source "$TMP/mikrus-wg"
require_root() { :; }
export PATH="$TMP/bin:$PATH"
export WG_COUNTER_FILE="$TMP/wg-counter"

load_settings
[[ "$ENDPOINT" == xander504.mikr.us.xyz ]]
[[ "$WG_PORT" == 20504 ]]
[[ "$ORIGINAL_IP_FORWARD" == 0 ]]

for name in admin-1 admin-2 admin-3 admin-4 admin-5 member-1; do
  add_client "$name" auto >/dev/null
done

expected=(
  'admin-1:10.77.77.2:admin'
  'admin-2:10.77.77.3:admin'
  'admin-3:10.77.77.4:admin'
  'admin-4:10.77.77.5:admin'
  'admin-5:10.77.77.6:admin'
  'member-1:10.77.77.7:member'
)
for row in "${expected[@]}"; do
  IFS=: read -r name address role <<<"$row"
  client_dir="$TMP/state/clients/$name"
  [[ $(<"$client_dir/ip") == "$address" ]] || fail "zły adres klienta $name"
  [[ $(<"$client_dir/role") == "$role" ]] || fail "zła rola klienta $name"
  config="$client_dir/$name.conf"
  grep -Fq "Address = ${address}/32" "$config"
  grep -Fq 'Endpoint = xander504.mikr.us.xyz:20504' "$config"
  grep -Fq 'AllowedIPs = 10.77.77.0/24' "$config"
  grep -Fq 'PersistentKeepalive = 25' "$config"
  if grep -Eq 'AllowedIPs[[:space:]]*=[[:space:]]*(0\.0\.0\.0/0|::/0)' "$config"; then
    fail "profil $name zawiera trasę domyślną"
  fi
done

server_config="$TMP/wireguard/wg0.conf"
grep -Fq 'Address = 10.77.77.1/24' "$server_config"
grep -Fq 'ListenPort = 20504' "$server_config"
[[ $(grep -c '^\[Peer\]$' "$server_config") -eq 6 ]]
[[ $(grep -c '^AllowedIPs = 10\.77\.77\.[2-7]/32$' "$server_config") -eq 6 ]]
if grep -Eq 'MASQUERADE|SNAT|DNAT|0\.0\.0\.0/0|::/0' "$server_config"; then
  fail "konfiguracja serwera zawiera NAT albo pełny tunel"
fi

# Cały stan peerów jest walidowany przed utworzeniem nowego pliku konfiguracji.
admin2_ip=$(<"$TMP/state/clients/admin-2/ip")
printf '%s\n' "$(<"$TMP/state/clients/admin-1/ip")" >"$TMP/state/clients/admin-2/ip"
expect_fail "render zaakceptował powtórzony adres IP" render_server_config
if compgen -G "$TMP/wireguard/wg0.conf.tmp.*" >/dev/null; then
  fail "po błędzie walidacji pozostał plik tymczasowy konfiguracji"
fi
printf '%s\n' "$admin2_ip" >"$TMP/state/clients/admin-2/ip"
chmod 600 "$TMP/state/clients/admin-2/ip"

admin2_public=$(<"$TMP/state/clients/admin-2/public.key")
printf '%s\n' "$(<"$TMP/state/clients/admin-1/public.key")" >"$TMP/state/clients/admin-2/public.key"
expect_fail "render zaakceptował powtórzony klucz publiczny" render_server_config
printf '%s\n' "$admin2_public" >"$TMP/state/clients/admin-2/public.key"
chmod 600 "$TMP/state/clients/admin-2/public.key"

chmod 644 "$TMP/state/clients/admin-2/public.key"
expect_fail "render zaakceptował zbyt szerokie uprawnienia klucza klienta" render_server_config
chmod 600 "$TMP/state/clients/admin-2/public.key"

ln -s "$TMP/state/clients/admin-1" "$TMP/state/clients/link-client"
expect_fail "render zaakceptował dowiązanie jako klienta" render_server_config
expect_fail "usuwanie zaakceptowało dowiązanie jako klienta" remove_client link-client
rm -f "$TMP/state/clients/link-client"

ln -s "$TMP/missing-client" "$TMP/state/clients/dangling"
expect_fail "dodawanie zaakceptowało istniejące dowiązanie docelowe" add_client dangling member
rm -f "$TMP/state/clients/dangling"

mkdir "$TMP/state/clients/.unfinished-transaction"
render_server_config
[[ $(grep -c '^\[Peer\]$' "$server_config") -eq 6 ]] ||
  fail "ukryty katalog transakcyjny został potraktowany jak klient"
expect_fail "operacja modyfikująca zignorowała niedokończoną transakcję" add_client blocked-by-transaction member
rmdir "$TMP/state/clients/.unfinished-transaction"

set_client_role member-1 admin >/dev/null
[[ $(<"$TMP/state/clients/member-1/role") == admin ]]
set_client_role member-1 member >/dev/null
[[ $(<"$TMP/state/clients/member-1/role") == member ]]

IPTABLES_FAIL=1 expect_fail "zmiana roli nie zgłosiła awarii firewalla" set_client_role member-1 admin
[[ $(<"$TMP/state/clients/member-1/role") == member ]] || fail "nie wycofano roli po awarii firewalla"

IPTABLES_FAIL=1 expect_fail "zmiana polityki nie zgłosiła awarii firewalla" set_policy mesh
load_settings
[[ "$POLICY" == acl ]] || fail "nie wycofano polityki po awarii firewalla"

SYSTEMCTL_FAIL_RESTART=1 expect_fail "zmiana endpointu nie zgłosiła awarii restartu" set_endpoint vpn.example.test 20504
load_settings
[[ "$ENDPOINT" == xander504.mikr.us.xyz ]] || fail "nie wycofano endpointu po awarii restartu"
grep -Fq 'Endpoint = xander504.mikr.us.xyz:20504' "$TMP/state/clients/admin-1/admin-1.conf" ||
  fail "nie odtworzono profilu klienta po awarii endpointu"

WG_FAIL_SYNC=1 expect_fail "usunięcie klienta nie wycofało awarii synchronizacji" remove_client admin-4
[[ -d "$TMP/state/clients/admin-4" ]] || fail "nie przywrócono klienta po awarii usuwania"

mkdir "$TMP/state/clients/bad name"
expect_fail "render zaakceptował nieprawidłową nazwę katalogu klienta" render_server_config
rmdir "$TMP/state/clients/bad name"

remove_client admin-5 >/dev/null
[[ ! -e "$TMP/state/clients/admin-5" ]]
[[ $(grep -c '^\[Peer\]$' "$server_config") -eq 5 ]]

exported="$TMP/exported.conf"
export_client admin-1 "$exported" >/dev/null 2>&1
[[ -s "$exported" ]]
[[ $(stat -c '%a' "$exported") == 600 ]]
ln -s "$TMP/real-target" "$TMP/export-link"
expect_fail "eksport zaakceptował dowiązanie symboliczne" export_client admin-1 "$TMP/export-link"

cp "$TMP/state/settings" "$TMP/state/settings.safe"
printf 'EVIL=$(touch %s/pwned)\n' "$TMP" >>"$TMP/state/settings"
expect_fail "parser ustawień zaakceptował nieznany klucz" load_settings
[[ ! -e "$TMP/pwned" ]] || fail "plik ustawień wykonał kod powłoki"
mv "$TMP/state/settings.safe" "$TMP/state/settings"
chmod 600 "$TMP/state/settings"

chmod 644 "$TMP/state/settings"
expect_fail "parser ustawień zaakceptował zbyt szerokie uprawnienia" load_settings
chmod 600 "$TMP/state/settings"

WG_FAIL_SYNC=1 expect_fail "dodanie klienta nie wycofało błędu synchronizacji" add_client rollback-test member
[[ ! -e "$TMP/state/clients/rollback-test" ]] || fail "pozostał klient po nieudanej synchronizacji"

printf 'Config mock tests: OK\n'
