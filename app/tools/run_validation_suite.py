#!/usr/bin/env python3
"""Run the ordered source/regression gates declared in validation_suite.txt."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath


APP = Path(__file__).resolve().parents[1]
REPOSITORY = APP.parent
MANIFEST = Path(__file__).with_name("validation_suite.txt")
WORKFLOW = REPOSITORY / ".github" / "workflows" / "build-apk.yml"
MINIMUM_VALIDATOR_COUNT = 108


def load_manifest() -> list[Path]:
    entries: list[Path] = []
    seen: set[str] = set()
    for line_number, raw in enumerate(
        MANIFEST.read_text(encoding="utf-8").splitlines(), start=1
    ):
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        posix = PurePosixPath(entry)
        if posix.is_absolute() or ".." in posix.parts:
            raise SystemExit(
                f"{MANIFEST.name}:{line_number}: unsafe path: {entry}"
            )
        if len(posix.parts) != 2 or posix.parts[0] != "tools":
            raise SystemExit(
                f"{MANIFEST.name}:{line_number}: expected tools/<validator>.py"
            )
        if not posix.name.startswith("validate_") or posix.suffix != ".py":
            raise SystemExit(
                f"{MANIFEST.name}:{line_number}: not a validator: {entry}"
            )
        if entry in seen:
            raise SystemExit(
                f"{MANIFEST.name}:{line_number}: duplicate validator: {entry}"
            )
        path = APP.joinpath(*posix.parts)
        if not path.is_file():
            raise SystemExit(
                f"{MANIFEST.name}:{line_number}: missing validator: {entry}"
            )
        seen.add(entry)
        entries.append(path)
    if not entries:
        raise SystemExit(f"{MANIFEST.name}: no validators declared")
    return entries


def check_repository_contract(validators: list[Path]) -> None:
    if len(validators) < MINIMUM_VALIDATOR_COUNT:
        raise SystemExit(
            f"{MANIFEST.name}: expected at least {MINIMUM_VALIDATOR_COUNT} "
            f"validators, found {len(validators)}"
        )
    workflow = WORKFLOW.read_text(encoding="utf-8")
    runner_call = "python3 tools/run_validation_suite.py"
    if workflow.count(runner_call) != 1:
        raise SystemExit(
            f"{WORKFLOW.relative_to(REPOSITORY)}: expected exactly one {runner_call!r}"
        )
    if re.search(r"^\s+python3 tools/validate_[^\s]+\.py\s*$", workflow, re.M):
        raise SystemExit(
            f"{WORKFLOW.relative_to(REPOSITORY)}: direct validator call bypasses "
            f"{MANIFEST.name}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="validate the manifest without executing its entries",
    )
    args = parser.parse_args()
    validators = load_manifest()
    check_repository_contract(validators)
    if args.check_only:
        print(f"validation manifest: OK ({len(validators)} validators)")
        return

    for index, validator in enumerate(validators, start=1):
        relative = validator.relative_to(APP)
        print(f"[{index}/{len(validators)}] {relative}", flush=True)
        subprocess.run([sys.executable, str(relative)], cwd=APP, check=True)
    print(f"validation suite: OK ({len(validators)} validators)")


if __name__ == "__main__":
    main()
