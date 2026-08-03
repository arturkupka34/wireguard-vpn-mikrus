#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

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
    if old not in text:
        raise SystemExit(f"Brak oczekiwanej linii do podmiany: {old}")
    text = text.replace(old, new, 1)
path.write_text(text)
PY

mkdir -p "$TMP/state/clients" "$TMP/bin" "$TMP/wireguard"
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

for last_octet in 2 3 4 5 6 7; do
  client_dir="$TMP/state/clients/client-${last_octet}"
  mkdir -p "$client_dir"
  printf '10.77.77.%s\n' "$last_octet" >"$client_dir/ip"
  if (( last_octet <= 6 )); then
    printf 'admin\n' >"$client_dir/role"
  else
    printf 'member\n' >"$client_dir/role"
  fi
  chmod 700 "$client_dir"
  chmod 600 "$client_dir/ip" "$client_dir/role"
done

cat >"$TMP/bin/iptables" <<'EOF_IPTABLES'
#!/usr/bin/env bash
printf '%s ' "$@" >>"$IPTABLES_LOG"
printf '\n' >>"$IPTABLES_LOG"
if [[ -n ${IPTABLES_FAIL_PATTERN:-} && "$*" == *"$IPTABLES_FAIL_PATTERN"* ]]; then
  exit 42
fi
for argument in "$@"; do
  [[ "$argument" == "-C" ]] && exit 1
done
exit 0
EOF_IPTABLES
chmod +x "$TMP/bin/iptables"

run_firewall() {
  local policy=$1 custom_ports=${2:-} fail_pattern=${3:-}
  sed -i "s/^POLICY=.*/POLICY=${policy}/" "$TMP/state/settings"
  sed -i "s/^CUSTOM_PORTS=.*/CUSTOM_PORTS=${custom_ports}/" "$TMP/state/settings"
  : >"$TMP/iptables.log"
  # shellcheck disable=SC2016
  IPTABLES_LOG="$TMP/iptables.log" IPTABLES_FAIL_PATTERN="$fail_pattern" PATH="$TMP/bin:$PATH" \
    bash -c 'source "$1"; require_root() { :; }; firewall_up' _ "$TMP/mikrus-wg"
}

run_firewall acl

for last_octet in 2 3 4 5 6; do
  grep -Fq -- "-i wg0 -o wg0 -s 10.77.77.${last_octet}/32 -d 10.77.77.0/24 -j ACCEPT" "$TMP/iptables.log"
done
if grep -Fq -- "-s 10.77.77.7/32 -d 10.77.77.0/24 -j ACCEPT" "$TMP/iptables.log"; then
  echo "Klient member otrzymał regułę inicjowania połączeń." >&2
  exit 1
fi

grep -Fq -- "-i wg0 -o wg0 -s 10.77.77.0/24 -d 10.77.77.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" "$TMP/iptables.log"
if grep -Eq -- '^-w -A MIKRUS_WG_FORWARD_NEXT -m conntrack ' "$TMP/iptables.log"; then
  echo "Reguła ESTABLISHED nie jest ograniczona do interfejsu WireGuard." >&2
  exit 1
fi

reject_line=$(grep -Fn -- "-i wg0 -s 10.77.77.0/24 -j REJECT" "$TMP/iptables.log" | head -n1 | cut -d: -f1)
accept_line=$(grep -Fn -- "-p udp --dport 20504 -j ACCEPT" "$TMP/iptables.log" | head -n1 | cut -d: -f1)
[[ -n "$reject_line" && -n "$accept_line" && "$reject_line" -lt "$accept_line" ]]

grep -Fq -- "-i wg0 ! -o wg0 -j REJECT" "$TMP/iptables.log"
grep -Fq -- "! -i wg0 -o wg0 -j REJECT" "$TMP/iptables.log"
forward_reject_line=$(grep -Fn -- "-i wg0 ! -o wg0 -j REJECT" "$TMP/iptables.log" | head -n1 | cut -d: -f1)
admin_accept_line=$(grep -Fn -- "-s 10.77.77.2/32 -d 10.77.77.0/24 -j ACCEPT" "$TMP/iptables.log" | head -n1 | cut -d: -f1)
[[ -n "$forward_reject_line" && -n "$admin_accept_line" && "$forward_reject_line" -lt "$admin_accept_line" ]]

run_firewall mesh
grep -Fq -- "-i wg0 -o wg0 -s 10.77.77.0/24 -d 10.77.77.0/24 -j ACCEPT" "$TMP/iptables.log"

run_firewall rdp
grep -Fq -- "-p icmp -j ACCEPT" "$TMP/iptables.log"
grep -Fq -- "-p tcp --dport 3389 -j ACCEPT" "$TMP/iptables.log"
grep -Fq -- "-p udp --dport 3389 -j ACCEPT" "$TMP/iptables.log"

run_firewall custom 'tcp:22,udp:53,icmp'
grep -Fq -- "-p tcp --dport 22 -j ACCEPT" "$TMP/iptables.log"
grep -Fq -- "-p udp --dport 53 -j ACCEPT" "$TMP/iptables.log"
grep -Fq -- "-p icmp -j ACCEPT" "$TMP/iptables.log"

grep -Fq -- "-I INPUT 1 -j MIKRUS_WG_INPUT_NEXT" "$TMP/iptables.log"
grep -Fq -- "-E MIKRUS_WG_INPUT_NEXT MIKRUS_WG_INPUT" "$TMP/iptables.log"
grep -Fq -- "-I FORWARD 1 -j MIKRUS_WG_FORWARD_NEXT" "$TMP/iptables.log"
grep -Fq -- "-E MIKRUS_WG_FORWARD_NEXT MIKRUS_WG_FORWARD" "$TMP/iptables.log"

# Awaria podczas budowania nowego łańcucha nie może aktywować częściowej polityki.
if run_firewall rdp '' '--dport 3389' >/dev/null 2>&1; then
  echo "Firewall zaakceptował kontrolowaną awarię reguły RDP." >&2
  exit 1
fi
if grep -Eq -- '^-w -I (INPUT|FORWARD) 1 -j MIKRUS_WG_' "$TMP/iptables.log"; then
  echo "Częściowy firewall został podłączony przed zakończeniem budowania." >&2
  exit 1
fi

if grep -Eq -- '-j (MASQUERADE|SNAT|DNAT)' "$TMP/iptables.log"; then
  echo "Test wykrył niedozwoloną regułę NAT." >&2
  exit 1
fi

echo "Firewall mock tests: OK"
