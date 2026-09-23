#!/usr/bin/env python3
"""Regression check: optimized Python must not silently accept unsafe BMAP fixtures."""
from __future__ import annotations
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_SCRIPT = ROOT / "scripts" / "check-contract.py"
SOURCE_SPEC = ROOT / "spec" / "bmap"
CS_REL = pathlib.Path("windows/src/OpenBose.Protocol/ReadOnlyCommands.cs")
KT_REL = pathlib.Path("android/bmap/src/main/kotlin/dev/openbose/bmap/ReadOnlyCommands.kt")

with tempfile.TemporaryDirectory(dir=ROOT / ".tmp", prefix="contract-regression-") as scratch:
    sandbox = pathlib.Path(scratch)
    (sandbox / "scripts").mkdir(parents=True)
    (sandbox / "spec" / "bmap").mkdir(parents=True)
    shutil.copy2(SOURCE_SCRIPT, sandbox / "scripts" / "check-contract.py")
    for file in SOURCE_SPEC.glob("*.json"):
        shutil.copy2(file, sandbox / "spec" / "bmap" / file.name)
    for relative in (CS_REL, KT_REL):
        destination = sandbox / relative
        destination.parent.mkdir(parents=True)
        shutil.copy2(ROOT / relative, destination)

    def check(expect_pass: bool, description: str) -> None:
        result = subprocess.run(
            [sys.executable, "-O", str(sandbox / "scripts" / "check-contract.py")],
            cwd=sandbox, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            check=False, timeout=15,
        )
        if (result.returncode == 0) != expect_pass:
            raise RuntimeError(
                f"{description}: unexpected exit {result.returncode}: "
                f"{result.stdout} {result.stderr}"
            )

    commands_path = sandbox / "spec" / "bmap" / "read-only-commands.json"
    original = commands_path.read_text("utf-8")
    check(True, "unmodified optimized contract")
    data = json.loads(original)
    data["commands"][1]["block"] = data["commands"][0]["block"]
    data["commands"][1]["function"] = data["commands"][0]["function"]
    commands_path.write_text(json.dumps(data), encoding="utf-8")
    check(False, "duplicate BMAP address under -O")
    commands_path.write_text(original, encoding="utf-8")
    data = json.loads(original)
    data["commands"][0]["block"] = 3
    commands_path.write_text(json.dumps(data), encoding="utf-8")
    check(False, "firmware block under -O")
    commands_path.write_text(original, encoding="utf-8")
    original_cs = (sandbox / CS_REL).read_text("utf-8")
    (sandbox / CS_REL).write_text(original_cs.replace('["battery"] = (2, 2)', '["battery"] = (3, 2)'),
                                  encoding="utf-8")
    check(False, "cross-language allowlist drift under -O")

print("PASS: optimized mode rejects duplicated, firmware and drifted BMAP contracts.")
