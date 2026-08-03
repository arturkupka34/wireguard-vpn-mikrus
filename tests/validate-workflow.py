#!/usr/bin/env python3
"""Minimalna walidacja struktury workflow GitHub Actions."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover - komunikat dla lokalnego uruchomienia
    raise SystemExit("Brak modułu PyYAML. Zainstaluj pakiet python3-yaml.") from exc


def fail(message: str) -> None:
    raise SystemExit(f"Workflow validation FAILED: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("użycie: validate-workflow.py PLIK")

    path = Path(sys.argv[1])
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError) as exc:
        fail(str(exc))

    if not isinstance(data, dict):
        fail("główny dokument musi być mapą")
    if data.get("name") != "CI":
        fail("brak nazwy CI")

    events = data.get("on")
    if not isinstance(events, dict):
        fail("sekcja on musi być mapą")
    for event in ("push", "pull_request", "workflow_dispatch"):
        if event not in events:
            fail(f"brak zdarzenia {event}")

    permissions = data.get("permissions")
    if permissions != {"contents": "read"}:
        fail("workflow powinien mieć wyłącznie contents: read")

    jobs = data.get("jobs")
    if not isinstance(jobs, dict):
        fail("brak sekcji jobs")
    for job_name in ("bash-audit", "powershell-audit"):
        job = jobs.get(job_name)
        if not isinstance(job, dict):
            fail(f"brak zadania {job_name}")
        steps = job.get("steps")
        if not isinstance(steps, list) or not steps:
            fail(f"zadanie {job_name} nie ma kroków")

    checkout_sha = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"
    for job_name, job in jobs.items():
        for step in job.get("steps", []):
            if isinstance(step, dict) and str(step.get("uses", "")).startswith("actions/checkout@"):
                if step["uses"] != checkout_sha:
                    fail(f"zadanie {job_name} używa niezatwierdzonej wersji checkout")
                if step.get("with", {}).get("persist-credentials") is not False:
                    fail(f"zadanie {job_name} nie wyłącza persist-credentials")

    print("Workflow validation: OK")


if __name__ == "__main__":
    main()
