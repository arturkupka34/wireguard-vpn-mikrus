#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  printf 'Install mock FAILED: %s\n' "$*" >&2
  exit 1
}

cp "$ROOT/src/mikrus-wg" "$TMP/mikrus-wg"
python3 - "$TMP/mikrus-wg" "$TMP" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
tmp = sys.argv[2]
text = path.read_text()
replacements = {
    'readonly INSTALL_PATH="/usr/local/sbin/${APP_NAME}"': f'readonly INSTALL_PATH="{tmp}/usr/local/sbin/mikrus-wg"',
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

mkdir -p "$TMP/usr/local/sbin"
printf 'poprzednia-wersja\n' >"$TMP/usr/local/sbin/mikrus-wg"
chmod 755 "$TMP/usr/local/sbin/mikrus-wg"

# shellcheck disable=SC1090
source "$TMP/mikrus-wg"
require_root() { :; }
install_packages() { :; }
check_systemd() { :; }
check_install_conflicts() { :; }
check_wireguard_capability() { :; }
journalctl() { :; }

wg() {
  case "${1:-}" in
    genkey) printf '%s\n' 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' ;;
    pubkey) cat >/dev/null; printf '%s\n' 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=' ;;
    genpsk) printf '%s\n' 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=' ;;
    *) return 0 ;;
  esac
}

systemctl() {
  printf 'systemctl %s %s\n' "${1:-}" "${2:-}" >>"$TMP/systemctl.log"
  return 0
}

sysctl() {
  case "${1:-}" in
    -n) printf '0\n' ;;
    -w) printf 'sysctl %s\n' "$*" >>"$TMP/sysctl.log" ;;
    *) return 0 ;;
  esac
}

iptables() {
  local argument
  for argument in "$@"; do
    [[ "$argument" == "-C" ]] && return 1
  done
  return 0
}

# Awaria po zapisaniu pliku sysctl musi wycofać cały stan i przywrócić program.
configure_forwarding() {
  printf 'net.ipv4.ip_forward = 1\n' >"$SYSCTL_FILE"
  return 77
}

if (install_server install --no-client >/dev/null 2>&1); then
  fail "instalacja nie zgłosiła kontrolowanej awarii"
fi
[[ ! -e "$STATE_DIR" ]] || fail "po awarii pozostał katalog stanu"
[[ ! -e "$WIREGUARD_DIR/wg0.conf" ]] || fail "po awarii pozostała konfiguracja WireGuard"
[[ ! -e "$SYSCTL_FILE" ]] || fail "po awarii pozostał plik sysctl"
[[ $(<"$INSTALL_PATH") == "poprzednia-wersja" ]] || fail "nie przywrócono poprzedniego programu"
grep -Fq 'net.ipv4.ip_forward=0' "$TMP/sysctl.log" || fail "nie przywrócono poprzedniej wartości ip_forward"
if grep -Fq 'systemctl start' "$TMP/systemctl.log"; then
  fail "instalacja kontynuowała po awarii kroku configure_forwarding"
fi

# Druga próba z poprawnym krokiem ma utworzyć spójny serwer bez klienta.
: >"$TMP/systemctl.log"
configure_forwarding() {
  printf 'net.ipv4.ip_forward = 1\n' >"$SYSCTL_FILE"
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
}
install_server install --no-client >/dev/null

[[ -s "$SETTINGS_FILE" ]] || fail "brak ustawień po udanej instalacji"
[[ -s "$SERVER_PRIVATE_KEY_FILE" ]] || fail "brak klucza prywatnego serwera"
[[ -s "$SERVER_PUBLIC_KEY_FILE" ]] || fail "brak klucza publicznego serwera"
[[ -s "$WIREGUARD_DIR/wg0.conf" ]] || fail "brak konfiguracji serwera"
[[ -x "$INSTALL_PATH" ]] || fail "program nie został zainstalowany"
grep -Fq 'ListenPort = 20504' "$WIREGUARD_DIR/wg0.conf"
grep -Fq 'Address = 10.77.77.1/24' "$WIREGUARD_DIR/wg0.conf"
grep -Fq 'systemctl enable wg-quick@wg0' "$TMP/systemctl.log"
grep -Fq 'systemctl start wg-quick@wg0' "$TMP/systemctl.log"

# Awaria usuwania firewalla nie może skasować stanu i powinna odtworzyć usługę.
if (
  firewall_down() { return 1; }
  uninstall_server --yes >/dev/null 2>&1
); then
  fail "deinstalacja nie zgłosiła kontrolowanej awarii firewalla"
fi
[[ -d "$STATE_DIR" ]] || fail "awaria firewalla usunęła stan"
grep -Fq 'systemctl enable wg-quick@wg0' "$TMP/systemctl.log" ||
  fail "nie próbowano odtworzyć włączenia usługi po awarii deinstalacji"
grep -Fq 'systemctl start wg-quick@wg0' "$TMP/systemctl.log" ||
  fail "nie próbowano odtworzyć działania usługi po awarii deinstalacji"

# Deinstalacja ma usunąć stan i przywrócić ip_forward.
uninstall_server --yes >/dev/null
[[ ! -e "$STATE_DIR" ]] || fail "deinstalacja pozostawiła stan"
[[ ! -e "$WIREGUARD_DIR/wg0.conf" ]] || fail "deinstalacja pozostawiła konfigurację"
[[ ! -e "$SYSCTL_FILE" ]] || fail "deinstalacja pozostawiła plik sysctl"
[[ ! -e "$INSTALL_PATH" ]] || fail "deinstalacja pozostawiła program"

printf 'Install mock tests: OK\n'
