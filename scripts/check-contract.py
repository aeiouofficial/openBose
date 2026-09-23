#!/usr/bin/env python3
"""Validate NC700 GET-only contract without assertions optimized away by python -O."""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = ROOT / "spec" / "bmap"
CSHARP = ROOT / "windows" / "src" / "OpenBose.Protocol" / "ReadOnlyCommands.cs"
KOTLIN = ROOT / "android" / "bmap" / "src" / "main" / "kotlin" / "dev" / "openbose" / "bmap" / "ReadOnlyCommands.kt"


def check(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def decode_hex(value: str) -> bytes:
    return bytes.fromhex(value)


def main() -> int:
    commands = json.loads((SPEC / "read-only-commands.json").read_text("utf-8"))
    fixtures = json.loads((SPEC / "synthetic-fixtures.json").read_text("utf-8"))
    expected: dict[str, tuple[int, int]] = {}
    for record in commands["commands"]:
        name, block, function = record["name"], record["block"], record["function"]
        check(name not in expected, f"Duplicate allowlist name: {name}")
        check((block, function) not in expected.values(), f"Duplicate BMAP address: {(block, function)}")
        check(block != 3, "Firmware update block must never be allowlisted")
        check(decode_hex(record["requestHex"]) == bytes([block, function, 1, 0]),
              f"Nonzero-payload or unsafe command: {name}")
        expected[name] = (block, function)
    check(commands["productId"] == "0x4024", "Unexpected Goodyear product")

    cs = CSHARP.read_text("utf-8")
    kt = KOTLIN.read_text("utf-8")
    cs_entries = {m[0]: (int(m[1]), int(m[2])) for m in re.findall(
        r'\["([^"]+)"\]\s*=\s*\((\d+),\s*(\d+)\)', cs)}
    kt_entries = {m[0]: (int(m[1]), int(m[2])) for m in re.findall(
        r'"([^"]+)"\s+to\s+\((\d+)\s+to\s+(\d+)\)', kt)}
    check(cs_entries == expected, f"C# allowlist drift: {cs_entries} != {expected}")
    check(kt_entries == expected, f"Kotlin allowlist drift: {kt_entries} != {expected}")
    check("RequireAllowed" in cs and "requireAllowed" in kt, "Missing transport guard")

    for row in fixtures["fullFrames"]:
        wire = decode_hex(row["hex"])
        payload = decode_hex(row["payloadHex"])
        check(len(wire) >= 4 and len(wire) == 4 + wire[3], "Invalid complete-frame length")
        check(wire[:3] == bytes([row["block"], row["function"], row["operator"]]),
              f"Incorrect frame header: {row['name']}")
        check(wire[4:] == payload, f"Incorrect frame payload: {row['name']}")
    expected_wire = [decode_hex(x) for x in fixtures["fragmented"]["expectedFramesHex"]]
    joined = b"".join(decode_hex(x) for x in fixtures["fragmented"]["chunksHex"])
    check(joined == b"".join(expected_wire), "Fragmentation fixture mismatch")
    for row in fixtures["invalidSingleFrames"]:
        wire = decode_hex(row["hex"])
        check(len(wire) < 4 or len(wire) != 4 + wire[3],
              f"Invalid-frame vector is actually valid: {row['name']}")
    for hex_value in fixtures["blockedOutbound"]:
        wire = decode_hex(hex_value)
        check(len(wire) >= 4 and len(wire) == 4 + wire[3], "Malformed forbidden-frame fixture")
        check(not (wire[2] == 1 and wire[3] == 0 and (wire[0], wire[1]) in expected.values()),
              "Forbidden-frame fixture accidentally allowlisted")
    print(f"PASS: {len(expected)} GETs; C# and Kotlin allowlists identical; shared fixtures valid.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, TypeError) as exc:
        print(f"FAIL: shared BMAP contract: {exc}", file=sys.stderr)
        sys.exit(1)
