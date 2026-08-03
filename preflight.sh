#!/usr/bin/env bash
# Kontrola odczytowa przed instalacją. Nie zmienia konfiguracji systemu.

set -Eeuo pipefail
IFS=$'\n\t'

readonly DEFAULT_ENDPOINT="xander504.mikr.us.xyz"
readonly DEFAULT_MIKRUS_ID="504"
readonly DEFAULT_INTERFACE="wg0"
readonly STATE_DIR="/etc/mikrus-wg"
readonly SYSCTL_FILE="/etc/sysctl.d/99-mikrus-wireguard.conf"
readonly INSTALL_PATH="/usr/local/sbin/mikrus-wg"

endpoint=${MIKRUS_ENDPOINT:-$DEFAULT_ENDPOINT}
mikrus_id=${1:-$DEFAULT_MIKRUS_ID}
interface=${MIKRUS_WG_INTERFACE:-$DEFAULT_INTERFACE}
blockers=0
warnings=0

validate_interface() {
  [[ ${1:-} =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,14}$ ]]
}

validate_endpoint() {
  local value=${1:-}
  [[ -n "$value" && ${#value} -le 253 ]] || return 1
  [[ "$value" != *[[:space:]]* && "$value" != */* ]]
}

ok() { printf '[OK]     %s\n' "$*"; }
warn() { printf '[UWAGA]  %s\n' "$*"; warnings=$((warnings + 1)); }
block() { printf '[BLOKADA] %s\n' "$*"; blockers=$((blockers + 1)); }

if ! validate_endpoint "$endpoint"; then
  printf '[BŁĄD] Endpoint jest pusty albo zawiera niedozwoloną spację/ścieżkę.\n' >&2
  exit 2
fi
if ! validate_interface "$interface"; then
  printf '[BŁĄD] Nazwa interfejsu musi mieć 1–15 bezpiecznych znaków.\n' >&2
  exit 2
fi
if [[ ! "$mikrus_id" =~ ^[1-9][0-9]{0,3}$ ]]; then
  printf '[BŁĄD] ID Mikrusa musi być liczbą 1–9999 bez zer wiodących.\n' >&2
  exit 2
fi
mikrus_id=$((10#$mikrus_id))
wg_port=$((20000 + mikrus_id))
ssh_port=$((10000 + mikrus_id))
reserve_port=$((30000 + mikrus_id))

printf '=== Tożsamość instalacji ===\n'
printf 'Endpoint:       %s\n' "$endpoint"
printf 'ID Mikrusa:     %s\n' "$mikrus_id"
printf 'Port SSH:       %s/TCP\n' "$ssh_port"
printf 'WireGuard:      %s/UDP\n' "$wg_port"
printf 'Port rezerwowy: %s/UDP\n' "$reserve_port"

printf '\n=== System ===\n'
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  printf 'Dystrybucja:    %s\n' "${PRETTY_NAME:-nieznana}"
  case "${ID:-}" in
    debian|ubuntu) ok "obsługiwana rodzina systemu (${ID})" ;;
    *) block "obsługiwane są wyłącznie Debian i Ubuntu" ;;
  esac
else
  block "nie można odczytać /etc/os-release"
fi
printf 'Kernel:         %s\n' "$(uname -r)"
printf 'PID 1:          %s\n' "$(ps -p 1 -o comm= 2>/dev/null || printf 'nieznany')"

if [[ ${EUID} -eq 0 ]]; then
  ok "kontrola działa jako root"
else
  warn "kontrola nie działa jako root; część stanu może być niewidoczna"
fi

if command -v systemctl >/dev/null 2>&1 && systemctl show-environment >/dev/null 2>&1; then
  ok "systemd działa jako menedżer systemu"
else
  block "systemd nie działa; instalator wymaga systemd"
fi

printf '\n=== Sieć i endpoint ===\n'
if command -v getent >/dev/null 2>&1; then
  if dns_output=$(getent ahosts "$endpoint" 2>/dev/null); then
    ok "DNS rozwiązuje endpoint"
    awk '!seen[$1]++ {print "         " $1}' <<<"$dns_output"
  else
    warn "endpoint nie został rozwiązany przez DNS; porównaj nazwę z panelem Mikrusa"
  fi
else
  warn "brak polecenia getent; pomijam test DNS"
fi

if command -v ss >/dev/null 2>&1; then
  if ss -H -lun "sport = :${wg_port}" 2>/dev/null | grep -q .; then
    block "port UDP ${wg_port} jest już używany"
  else
    ok "port UDP ${wg_port} nie jest lokalnie zajęty"
  fi
else
  warn "brak polecenia ss; instalator doinstaluje iproute2, ale test portu został pominięty"
fi

printf '\n=== Konflikty WireGuard ===\n'
config="/etc/wireguard/${interface}.conf"
if [[ -e "$config" || -L "$config" ]]; then
  block "istnieje ${config}"
else
  ok "brak ${config}"
fi

if [[ -e "$STATE_DIR" || -L "$STATE_DIR" ]]; then
  block "istnieje ${STATE_DIR}; instalator nie nadpisze istniejącego stanu"
else
  ok "brak ${STATE_DIR}"
fi

if [[ -e "$SYSCTL_FILE" || -L "$SYSCTL_FILE" ]]; then
  block "istnieje ${SYSCTL_FILE}"
else
  ok "brak ${SYSCTL_FILE}"
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "wg-quick@${interface}" 2>/dev/null; then
  block "usługa wg-quick@${interface} jest aktywna"
else
  ok "usługa wg-quick@${interface} nie jest aktywna"
fi

if command -v ip >/dev/null 2>&1; then
  if ip link show "$interface" >/dev/null 2>&1; then
    block "interfejs ${interface} już istnieje"
  else
    ok "interfejs ${interface} nie istnieje"
  fi
else
  warn "brak polecenia ip; instalator doinstaluje iproute2"
fi

if [[ -L "$INSTALL_PATH" || -d "$INSTALL_PATH" ]]; then
  block "ścieżka ${INSTALL_PATH} jest dowiązaniem albo katalogiem"
elif [[ -e "$INSTALL_PATH" ]]; then
  warn "istnieje ${INSTALL_PATH}; instalator utworzy kopię i zastąpi zwykły plik"
else
  ok "brak ${INSTALL_PATH}"
fi

if command -v iptables >/dev/null 2>&1; then
  for chain in MIKRUS_WG_INPUT MIKRUS_WG_FORWARD MIKRUS_WG_INPUT_NEXT MIKRUS_WG_FORWARD_NEXT; do
    if iptables -w -S "$chain" >/dev/null 2>&1; then
      block "łańcuch firewalla ${chain} już istnieje"
    else
      ok "brak łańcucha firewalla ${chain}"
    fi
  done
else
  warn "brak polecenia iptables; instalator je doinstaluje"
fi

printf '\n=== Wynik ===\n'
printf 'Blokady:  %s\n' "$blockers"
printf 'Ostrzeżenia: %s\n' "$warnings"
printf 'Skrypt nie wprowadził żadnych zmian.\n'

if (( blockers > 0 )); then
  printf 'Usuń blokady przed instalacją. Niczego nie kasuj bez kopii zapasowej.\n' >&2
  exit 1
fi

printf 'Kontrola wstępna zakończona pomyślnie.\n'
