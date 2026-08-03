#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)

fail() {
  printf 'Smoke test FAILED: %s\n' "$*" >&2
  exit 1
}

expect_fail() {
  local description=$1
  shift
  if ("$@" >/dev/null 2>&1); then
    fail "$description"
  fi
}

scripts=(
  install.sh
  preflight.sh
  configure-repository.sh
  src/mikrus-wg
  tests/smoke.sh
  tests/firewall-mock.sh
  tests/config-mock.sh
  tests/install-mock.sh
  tests/bootstrap-mock.sh
  tests/update-mock.sh
)

for script in "${scripts[@]}"; do
  bash -n "$ROOT/$script"
  if grep -q $'\r' "$ROOT/$script"; then
    fail "plik $script zawiera zakończenia linii CRLF"
  fi
done

version=$(bash "$ROOT/src/mikrus-wg" version)
[[ "$version" == "mikrus-wg 3.2.3" ]] || fail "nieprawidłowa wersja: $version"

help=$(bash "$ROOT/src/mikrus-wg" --help)
grep -q "prywatny split-tunnel" <<<"$help" || fail "brak opisu split-tunnel"
grep -q "nie tworzy NAT ani MASQUERADE" <<<"$help" || fail "brak informacji o NAT"
grep -q "pierwsze N adresów klientów" <<<"$help" || fail "brak opisu slotów administratorów"
grep -q "klienci nie mają dostępu" <<<"$help" || fail "brak informacji o blokadzie VPS"

if grep -RqsE \
  'PrivateKey[[:space:]]*=[[:space:]]*[A-Za-z0-9+/]{40,}={0,2}' \
  "$ROOT"; then
  fail "w repozytorium wykryto prawdopodobny klucz prywatny"
fi

if grep -RqsE '^AllowedIPs[[:space:]]*=[[:space:]]*(0\.0\.0\.0/0|::/0)' \
  "$ROOT/src" "$ROOT/config" "$ROOT/examples"; then
  fail "w repozytorium wykryto profil pełnego tunelu"
fi

grep -Fq 'DEFAULT_ENDPOINT="xander504.mikr.us.xyz"' "$ROOT/src/mikrus-wg"
grep -Fq 'DEFAULT_REPOSITORY="arturkupka34/wireguard-vpn-mikrus"' "$ROOT/src/mikrus-wg"
grep -Fq 'DEFAULT_MIKRUS_ID="504"' "$ROOT/src/mikrus-wg"
grep -Fq 'local network_base="10.77.77" interface="wg0" policy="acl"' "$ROOT/src/mikrus-wg"
grep -Fq 'port=$((20000 + mikrus_id))' "$ROOT/src/mikrus-wg"
grep -Fq 'bash "$SOURCE_TMP" install "$@"' "$ROOT/install.sh"
if grep -Eq 'exec[[:space:]]+bash[[:space:]]+"?\$(TMP_FILE|SOURCE_TMP)' "$ROOT/install.sh"; then
  fail "bootstrap używa exec i może pozostawić plik tymczasowy"
fi
(
  cd "$ROOT/src"
  sha256sum -c mikrus-wg.sha256 >/dev/null
) || fail "suma src/mikrus-wg nie zgadza się"
if grep -Eq 'exec 9>&-[[:space:]]+2>/dev/null' "$ROOT/src/mikrus-wg"; then
  fail "release_lock trwale przekierowuje stderr"
fi
grep -Fq 'ORIGINAL_IP_FORWARD=' "$ROOT/src/mikrus-wg"
grep -Fq 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' "$ROOT/.github/workflows/ci.yml"
if grep -Fq 'source "$SETTINGS_FILE"' "$ROOT/src/mikrus-wg"; then
  fail "plik ustawień jest wykonywany jako kod powłoki"
fi

# Lekkie testy funkcji bez wprowadzania zmian systemowych.
# shellcheck source=../src/mikrus-wg
# shellcheck disable=SC1090
source "$ROOT/src/mikrus-wg"

validate_name "laptop-01"
validate_interface "wg0"
validate_endpoint "xander504.mikr.us.xyz"
validate_endpoint "192.0.2.1"
validate_endpoint "2001:db8::1"
validate_endpoint "[2001:db8::1]"
validate_network_base "10.77.77"
validate_network_base "172.16.1"
validate_network_base "192.168.50"
validate_policy "acl"
validate_policy "mesh"
validate_policy "rdp"
validate_policy "custom"
validate_role "auto"
validate_role "admin"
validate_role "member"
validate_mikrus_id "504"
validate_port "20504"
validate_keepalive "0"
validate_keepalive "25"
validate_admin_slots "5"
validate_custom_ports "tcp:3389,udp:3389,tcp:22,icmp"
validate_ref "v3.2.3"
validate_repository "arturkupka34/wireguard-vpn-mikrus"
validate_wg_key "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
# Zmienna jest odczytywana przez validate_client_ip z dołączonego skryptu.
# shellcheck disable=SC2034
NETWORK_BASE="10.77.77"
validate_client_ip "10.77.77.2"
validate_client_ip "10.77.77.254"

[[ "$(format_endpoint "2001:db8::1")" == "[2001:db8::1]" ]]
[[ "$(format_endpoint "[2001:db8::1]")" == "[2001:db8::1]" ]]
[[ "$(format_endpoint "xander504.mikr.us.xyz")" == "xander504.mikr.us.xyz" ]]

expect_fail "zaakceptowano pustą nazwę klienta" validate_name ""
expect_fail "zaakceptowano nazwę klienta ze spacją" validate_name "zła nazwa"
expect_fail "zaakceptowano zbyt długą nazwę interfejsu" validate_interface "interfejs-wireguard"
expect_fail "zaakceptowano URL zamiast hosta" validate_endpoint "https://example.com"
expect_fail "zaakceptowano host ze spacją" validate_endpoint "bad host"
expect_fail "zaakceptowano host z pustą etykietą" validate_endpoint "example..com"
expect_fail "zaakceptowano host zaczynający się myślnikiem" validate_endpoint "-bad.example"
expect_fail "zaakceptowano błędny IPv4" validate_endpoint "999.1.1.1"
expect_fail "zaakceptowano błędny IPv6" validate_endpoint "2001:::1"
expect_fail "zaakceptowano niepełny IPv6" validate_endpoint "2001:db8:1"
expect_fail "zaakceptowano IPv6 z końcowym pojedynczym dwukropkiem" validate_endpoint "2001:db8::1:"
expect_fail "zaakceptowano IPv6 z początkowym pojedynczym dwukropkiem" validate_endpoint ":2001:db8::1"
expect_fail "zaakceptowano niedomknięty IPv6" validate_endpoint "[2001:db8::1"
expect_fail "zaakceptowano publiczną podsieć" validate_network_base "8.8.8"
expect_fail "zaakceptowano oktet z zerem wiodącym" validate_network_base "10.077.77"
expect_fail "zaakceptowano zbyt duży oktet" validate_network_base "10.256.1"
expect_fail "zaakceptowano port zero" validate_port "0"
expect_fail "zaakceptowano port z zerem wiodącym" validate_port "020504"
expect_fail "zaakceptowano port spoza zakresu" validate_port "65536"
expect_fail "zaakceptowano złą rolę" validate_role "root"
expect_fail "zaakceptowano błędne ID" validate_mikrus_id "10000"
expect_fail "zaakceptowano ID z zerem wiodącym" validate_mikrus_id "0504"
expect_fail "zaakceptowano zero slotów administratorów" validate_admin_slots "0"
expect_fail "zaakceptowano błędną regułę custom" validate_custom_ports "tcp:99999"
expect_fail "zaakceptowano końcowy przecinek w custom" validate_custom_ports "tcp:22,"
expect_fail "zaakceptowano pustą regułę custom" validate_custom_ports "tcp:22,,udp:53"
expect_fail "zaakceptowano powtórzoną regułę custom" validate_custom_ports "tcp:22,tcp:22"
expect_fail "zaakceptowano niebezpieczny ref" validate_ref "../main"
expect_fail "zaakceptowano ref z podwójnym ukośnikiem" validate_ref "feature//bad"
expect_fail "zaakceptowano ref kończący się .lock" validate_ref "main.lock"
expect_fail "zaakceptowano repozytorium z kropkami" validate_repository "../repo"
expect_fail "zaakceptowano nieprawidłowy klucz WireGuard" validate_wg_key "krótki-klucz"
expect_fail "zaakceptowano adres serwera jako adres klienta" validate_client_ip "10.77.77.1"
expect_fail "zaakceptowano adres klienta z innej podsieci" validate_client_ip "10.77.78.2"

printf 'Smoke tests: OK\n'
