#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  printf 'Użycie: %s OWNER/REPO\n' "$0"
}

repository=${1:-}
owner=${repository%%/*}
repo=${repository#*/}

if [[ "$repository" != */* || "$owner" == "$repository" || "$repo" == */* ||
      ! "$owner" =~ ^[A-Za-z0-9_.-]+$ || ! "$repo" =~ ^[A-Za-z0-9_.-]+$ ||
      "$owner" == "." || "$owner" == ".." || "$repo" == "." || "$repo" == ".." ]]; then
  usage >&2
  exit 1
fi

for command in python3 sha256sum awk; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Brak wymaganego polecenia: %s\n' "$command" >&2
    exit 1
  }
done

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
source_file="$root/src/mikrus-wg"
checksum_file="$root/src/mikrus-wg.sha256"
[[ -f "$source_file" && ! -L "$source_file" ]] || {
  printf 'Brak bezpiecznego pliku src/mikrus-wg.\n' >&2
  exit 1
}

current=$(python3 - "$source_file" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
matches = re.findall(r'^readonly DEFAULT_REPOSITORY="([^"]+)"$', text, flags=re.MULTILINE)
if len(matches) != 1:
    raise SystemExit("Nie można jednoznacznie odczytać DEFAULT_REPOSITORY.")
print(matches[0])
PY
)

files=(
  "$root/install.sh"
  "$source_file"
  "$root/config/install.env.example"
  "$root/README.md"
)

for file in "${files[@]}"; do
  [[ -f "$file" && ! -L "$file" ]] || continue
  python3 - "$file" "$current" "$repository" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace(sys.argv[2], sys.argv[3]), encoding="utf-8", newline="\n")
PY
done

sha256sum "$source_file" | awk '{print $1 "  mikrus-wg"}' >"$checksum_file"
chmod 644 "$checksum_file"

printf 'Ustawiono repozytorium: %s\n' "$repository"
printf 'Przeliczono src/mikrus-wg.sha256.\n'
printf 'Sprawdź zmiany poleceniem: git diff\n'
