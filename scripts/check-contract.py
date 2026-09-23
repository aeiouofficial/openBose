#!/usr/bin/env python3
"""Validate shared NC700 read-only contract and source allowlists; no Bluetooth I/O."""
from __future__ import annotations
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = ROOT / "spec" / "bmap"
CSHARP = ROOT / "windows" / "src" / "OpenBose.Protocol" / "ReadOnlyCommands.cs"
KOTLIN = ROOT / "android" / "bmap" / "src" / "main" / "kotlin" / "dev" / "openbose" / "bmap" / "ReadOnlyCommands.kt"

def decode_hex(s: str) -> bytes:
    return bytes.fromhex(s)

def main() -> int:
    commands = json.loads((SPEC / "read-only-commands.json").read_text("utf-8"))
    fixtures = json.loads((SPEC / "synthetic-fixtures.json").read_text("utf-8"))
    expected: dict[str, tuple[int, int]] = {}
    for record in commands["commands"]:
        name, block, function = record["name"], record["block"], record["function"]
        assert name not in expected, f"Duplicate allowlist name: {name}"
        assert (block, function) not in expected.values(), f"Duplicate BMAP address: {(block, function)}"
        expected[name] = (block, function)
        assert decode_hex(record["requestHex"]) == bytes([block, function, 1, 0]), name
        assert block != 3, "Firmware update block must never be allowlisted"
    assert commands["productId"] == "0x4024", "Unexpected Goodyear product"
    cs = CSHARP.read_text("utf-8")
    kt = KOTLIN.read_text("utf-8")
    cs_entries = {m[0]: (int(m[1]), int(m[2])) for m in re.findall(
        r'\["([^"]+)"\]\s*=\s*\((\d+),\s*(\d+)\)', cs)}
    kt_entries = {m[0]: (int(m[1]), int(m[2])) for m in re.findall(
        r'"([^"]+)"\s+to\s+\((\d+)\s+to\s+(\d+)\)', kt)}
    assert cs_entries == expected, f"C# allowlist drift: {cs_entries} != {expected}"
    assert kt_entries == expected, f"Kotlin allowlist drift: {kt_entries} != {expected}"
    assert "RequireAllowed" in cs and "requireAllowed" in kt
    for row in fixtures["fullFrames"]:
        wire = decode_hex(row["hex"])
        payload = decode_hex(row["payloadHex"])
        assert len(wire) == 4 + wire[3]
        assert wire[:3] == bytes([row["block"], row["function"], row["operator"]])
        assert wire[4:] == payload
    expected_wire = [decode_hex(x) for x in fixtures["fragmented"]["expectedFramesHex"]]
    joined_chunks = b"".join(decode_hex(x) for x in fixtures["fragmented"]["chunksHex"])
    assert joined_chunks == b"".join(expected_wire), "Fragmentation fixture mismatch"
    for row in fixtures["invalidSingleFrames"]:
        wire = decode_hex(row["hex"])
        assert len(wire) < 4 or len(wire) != 4 + wire[3], row["name"]
    for hex_value in fixtures["blockedOutbound"]:
        wire = decode_hex(hex_value)
        assert len(wire) >= 4 and len(wire) == 4 + wire[3]
        assert not (wire[2] == 1 and wire[3] == 0 and (wire[0], wire[1]) in expected.values())
    print(f"PASS: {len(expected)} GETs; C# and Kotlin allowlists identical; shared fixtures valid.")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, ValueError, KeyError) as exc:
        print(f"FAIL: shared BMAP contract: {exc}", file=sys.stderr)
        sys.exit(1)
