#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
cleanup() { rm -rf -- "$TMP"; }
trap cleanup EXIT

fail() {
  printf 'Bootstrap mock FAILED: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$TMP/repo/src"
cp "$ROOT/install.sh" "$TMP/repo/install.sh"
cat >"$TMP/repo/src/mikrus-wg" <<'EOF_STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
readonly APP_NAME="mikrus-wg"
readonly VERSION="9.9.9"
printf 'repository=%s\n' "${MIKRUS_WG_SOURCE_REPOSITORY:-}" >"$CAPTURE_FILE"
printf 'ref=%s\n' "${MIKRUS_WG_SOURCE_REF:-}" >>"$CAPTURE_FILE"
printf 'args=%s\n' "$*" >>"$CAPTURE_FILE"
EOF_STUB
chmod 755 "$TMP/repo/src/mikrus-wg"
(
  cd "$TMP/repo/src"
  sha256sum mikrus-wg | awk '{print $1 "  mikrus-wg"}' >mikrus-wg.sha256
)

CAPTURE_FILE="$TMP/capture" bash "$TMP/repo/install.sh" --no-client >/dev/null
grep -Fqx 'repository=arturkupka34/wireguard-vpn-mikrus' "$TMP/capture"
grep -Fqx 'ref=main' "$TMP/capture"
grep -Fqx 'args=install --no-client' "$TMP/capture"

rm -f -- "$TMP/capture"
printf '# uszkodzenie\n' >>"$TMP/repo/src/mikrus-wg"
if CAPTURE_FILE="$TMP/capture" bash "$TMP/repo/install.sh" --no-client >/dev/null 2>&1; then
  fail "bootstrap zaakceptował źródło niezgodne z sumą SHA-256"
fi
[[ ! -e "$TMP/capture" ]] || fail "bootstrap uruchomił źródło mimo złej sumy"

printf 'nieprawidłowa suma\n' >"$TMP/repo/src/mikrus-wg.sha256"
if CAPTURE_FILE="$TMP/capture" bash "$TMP/repo/install.sh" --no-client >/dev/null 2>&1; then
  fail "bootstrap zaakceptował nieprawidłowy manifest"
fi

printf 'Bootstrap mock tests: OK\n'
