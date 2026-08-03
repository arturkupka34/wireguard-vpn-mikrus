#!/usr/bin/env python3
"""Kontrole spójności i higieny całego repozytorium."""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXT_SUFFIXES = {".sh", ".py", ".ps1", ".yml", ".yaml", ".md", ".txt", ".example", ""}
EXPECTED_VERSION = "3.2.1"
CHECKOUT = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"


def fail(message: str) -> None:
    raise SystemExit(f"Repository audit FAILED: {message}")


def iter_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        relative = path.relative_to(ROOT)
        if ".git" in relative.parts or path.name in {"wireguard-vpn-mikrus-source.tar.gz"}:
            continue
        if path.is_symlink():
            fail(f"dowiązanie symboliczne w repozytorium: {relative}")
        if path.is_file():
            files.append(path)
    return sorted(files)


def read_text(path: Path) -> str:
    try:
        data = path.read_bytes()
    except OSError as exc:
        fail(f"nie można odczytać {path.relative_to(ROOT)}: {exc}")
    if b"\x00" in data:
        fail(f"bajt NUL w pliku {path.relative_to(ROOT)}")
    if b"\r" in data:
        fail(f"zakończenie CRLF/CR w pliku {path.relative_to(ROOT)}")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        fail(f"plik nie jest UTF-8: {path.relative_to(ROOT)}: {exc}")
    for line_number, line in enumerate(text.splitlines(), start=1):
        if line.rstrip(" \t") != line:
            fail(f"końcowe spacje: {path.relative_to(ROOT)}:{line_number}")
    return text


def main() -> None:
    files = iter_files()
    if not files:
        fail("repozytorium jest puste")

    texts: dict[Path, str] = {}
    for path in files:
        if path.suffix in TEXT_SUFFIXES or path.name in {"Makefile", "LICENSE", ".gitignore", ".gitattributes", ".shellcheckrc"}:
            texts[path] = read_text(path)

    main_script = ROOT / "src/mikrus-wg"
    main_text = texts[main_script]
    if f'readonly VERSION="{EXPECTED_VERSION}"' not in main_text:
        fail("niespójny numer wersji programu")
    if 'source "$SETTINGS_FILE"' in main_text:
        fail("plik ustawień byłby wykonywany jako kod Bash")
    if re.search(r"\beval\b", main_text):
        fail("program produkcyjny zawiera eval")

    checksum_line = (ROOT / "src/mikrus-wg.sha256").read_text(encoding="ascii").strip()
    match = re.fullmatch(r"([0-9a-f]{64})  mikrus-wg", checksum_line)
    if not match:
        fail("nieprawidłowy format src/mikrus-wg.sha256")
    actual = hashlib.sha256(main_script.read_bytes()).hexdigest()
    if actual != match.group(1):
        fail("src/mikrus-wg nie zgadza się z sumą SHA-256")

    workflow = texts[ROOT / ".github/workflows/ci.yml"]
    if workflow.count(CHECKOUT) != 2:
        fail("workflow nie używa zatwierdzonego SHA actions/checkout dokładnie dwa razy")
    if "persist-credentials: false" not in workflow:
        fail("workflow nie wyłącza persist-credentials")

    sensitive_roots = [ROOT / "src", ROOT / "config", ROOT / "examples"]
    private_key_pattern = re.compile(rb"PrivateKey\s*=\s*[A-Za-z0-9+/]{43}=")
    full_tunnel_pattern = re.compile(rb"AllowedIPs\s*=\s*(?:0\.0\.0\.0/0|::/0)")
    for base in sensitive_roots:
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            data = path.read_bytes()
            if private_key_pattern.search(data):
                fail(f"prawdopodobny klucz prywatny w {path.relative_to(ROOT)}")
            if full_tunnel_pattern.search(data):
                fail(f"pełny tunel w {path.relative_to(ROOT)}")

    required = {
        ".github/workflows/ci.yml",
        "install.sh",
        "preflight.sh",
        "src/mikrus-wg",
        "src/mikrus-wg.sha256",
        "tests/smoke.sh",
        "tests/firewall-mock.sh",
        "tests/config-mock.sh",
        "tests/install-mock.sh",
        "tests/bootstrap-mock.sh",
        "tests/update-mock.sh",
        "tests/validate-workflow.py",
    }
    present = {str(path.relative_to(ROOT)) for path in files}
    missing = sorted(required - present)
    if missing:
        fail(f"brak wymaganych plików: {', '.join(missing)}")

    print(f"Repository audit: OK ({len(files)} plików)")


if __name__ == "__main__":
    main()
