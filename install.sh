#!/usr/bin/env bash
# Bootstrap instalacyjny dla mikrus-wg.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly DEFAULT_REPOSITORY="arturkupka34/wireguard-vpn-mikrus"
readonly DEFAULT_REF="main"
readonly SOURCE_FILE="mikrus-wg"
readonly CHECKSUM_FILE="mikrus-wg.sha256"
readonly MAX_SOURCE_SIZE=1048576
readonly MAX_CHECKSUM_SIZE=256

log() {
  printf '[INFO] %s\n' "$*"
}

die() {
  printf '[BŁĄD] %s\n' "$*" >&2
  exit 1
}

validate_repository() {
  local value=${1:-} owner repo extra
  IFS='/' read -r owner repo extra <<<"$value"
  [[ -n "$owner" && -n "$repo" && -z "${extra:-}" ]] || return 1
  [[ "$owner" =~ ^[A-Za-z0-9_.-]+$ && "$repo" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
  [[ "$owner" != "." && "$owner" != ".." && "$repo" != "." && "$repo" != ".." ]]
}

validate_ref() {
  local value=${1:-}
  [[ "$value" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "$value" != /* && "$value" != */ && "$value" != *//* && "$value" != *".."* ]] || return 1
  [[ "$value" != *'@{'* && "$value" != *.lock && "$value" != '.' ]]
}

[[ ${EUID} -eq 0 ]] ||
  die "Uruchom instalator jako root, np. curl ... | sudo bash."

for command in bash sha256sum stat awk grep mktemp cp rm; do
  command -v "$command" >/dev/null 2>&1 || die "Brak wymaganego polecenia: $command"
done

REPOSITORY=${MIKRUS_WG_REPOSITORY:-$DEFAULT_REPOSITORY}
REF=${MIKRUS_WG_REF:-$DEFAULT_REF}
validate_repository "$REPOSITORY" || die "Repozytorium musi mieć bezpieczną postać OWNER/REPO."
validate_ref "$REF" || die "Nieprawidłowa gałąź lub tag GitHub."

if [[ ${1:-} == "install" ]]; then
  shift
fi

SCRIPT_DIR=""
if [[ -n ${BASH_SOURCE[0]:-} &&
      ${BASH_SOURCE[0]} != "bash" &&
      ${BASH_SOURCE[0]} != "/dev/stdin" ]]; then
  if ! SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P); then
    SCRIPT_DIR=""
  fi
fi

SOURCE_TMP=$(mktemp)
CHECKSUM_TMP=$(mktemp)
cleanup() {
  rm -f -- "$SOURCE_TMP" "$CHECKSUM_TMP"
}
trap cleanup EXIT

if [[ -n "$SCRIPT_DIR" &&
      -f "$SCRIPT_DIR/src/$SOURCE_FILE" && ! -L "$SCRIPT_DIR/src/$SOURCE_FILE" &&
      -f "$SCRIPT_DIR/src/$CHECKSUM_FILE" && ! -L "$SCRIPT_DIR/src/$CHECKSUM_FILE" ]]; then
  log "Używam lokalnych plików src/${SOURCE_FILE} i src/${CHECKSUM_FILE}."
  cp -- "$SCRIPT_DIR/src/$SOURCE_FILE" "$SOURCE_TMP"
  cp -- "$SCRIPT_DIR/src/$CHECKSUM_FILE" "$CHECKSUM_TMP"
else
  command -v curl >/dev/null 2>&1 ||
    die "Brak polecenia curl. Zainstaluj pakiet curl i uruchom ponownie."

  BASE_URL="https://raw.githubusercontent.com/${REPOSITORY}/${REF}/src"
  log "Pobieram program i sumę kontrolną z ${REPOSITORY}@${REF}."
  curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
    "${BASE_URL}/${SOURCE_FILE}" --output "$SOURCE_TMP"
  curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
    "${BASE_URL}/${CHECKSUM_FILE}" --output "$CHECKSUM_TMP"
fi

source_size=$(stat -c '%s' "$SOURCE_TMP")
checksum_size=$(stat -c '%s' "$CHECKSUM_TMP")
(( source_size > 0 && source_size <= MAX_SOURCE_SIZE )) || die "Program ma nieprawidłowy rozmiar."
(( checksum_size > 0 && checksum_size <= MAX_CHECKSUM_SIZE )) || die "Plik sumy kontrolnej ma nieprawidłowy rozmiar."

manifest_line=$(<"$CHECKSUM_TMP")
if [[ ! "$manifest_line" =~ ^([a-f0-9]{64})[[:space:]][[:space:]]mikrus-wg$ ]]; then
  die "Nieprawidłowy format pliku sumy kontrolnej."
fi
expected=${BASH_REMATCH[1]}
actual=$(sha256sum "$SOURCE_TMP" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || die "Suma SHA-256 programu nie zgadza się."

bash -n "$SOURCE_TMP"
grep -Fqx 'readonly APP_NAME="mikrus-wg"' "$SOURCE_TMP" || die "Pobrany plik nie jest programem mikrus-wg."
grep -Eq '^readonly VERSION="[0-9]+\.[0-9]+\.[0-9]+"$' "$SOURCE_TMP" ||
  die "Pobrany plik nie zawiera poprawnego numeru wersji."

log "Składnia i suma SHA-256 są poprawne. Rozpoczynam instalację."
MIKRUS_WG_SOURCE_REPOSITORY="$REPOSITORY" \
MIKRUS_WG_SOURCE_REF="$REF" \
  bash "$SOURCE_TMP" install "$@"
