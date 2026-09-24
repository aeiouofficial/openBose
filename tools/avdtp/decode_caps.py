#!/usr/bin/env python3
"""Decode *one* AVDTP Service Capabilities TLV list, without device I/O.

Input must be the decoded service-capability payload of one GetCapabilities /
GetAllCapabilities response or one SetConfiguration command, not an HCI
packet or a whole AVDTP signaling PDU. The operator supplies peer role and
message type: neither is inferable from this byte string alone.
"""
from __future__ import annotations

import argparse
import json
import re
from typing import Any

MEDIA_CODEC_CATEGORY = 0x07
STANDARD_CODECS = {0x00: "SBC", 0x01: "MPEG-1/2 Audio", 0x02: "MPEG-2/4 AAC"}
VENDOR_CODECS = {
    (0x0000004F, 0x0001): "aptX",
    (0x000000D7, 0x0024): "aptX HD",
    (0x0000012D, 0x00AA): "LDAC",
}
MAX_PAYLOAD = 4096


class CapabilityError(ValueError):
    """Malformed input, rather than evidence about headphone capabilities."""


def parse_hex(text: str) -> bytes:
    """Accept hex byte pairs separated by whitespace or colons, not packet dumps."""
    if not text or not re.fullmatch(r"[0-9a-fA-F:\s]+", text):
        raise CapabilityError("Expected a nonempty hex-byte string (spaces/colons allowed).")
    normalized = text.replace(":", " ")
    try:
        data = bytes.fromhex(normalized)
    except ValueError as exc:
        raise CapabilityError("Invalid or incomplete hex byte pair.") from exc
    if not data or len(data) > MAX_PAYLOAD:
        raise CapabilityError(f"Capability payload must contain 1–{MAX_PAYLOAD} bytes.")
    return data


def parse_capabilities(data: bytes, *, peer_role: str, message_kind: str) -> dict[str, Any]:
    """Parse AVDTP Service Capabilities category/length/value records.

    One SEP's capabilities contain at most one Media Codec category. Do not
    concatenate capabilities from multiple SEPs before calling this function.
    """
    if peer_role not in {"sink", "source"}:
        raise CapabilityError("Peer role must be supplied explicitly: sink or source.")
    if message_kind not in {"capabilities", "configuration"}:
        raise CapabilityError("Message kind must be capabilities or configuration.")
    if not data or len(data) > MAX_PAYLOAD:
        raise CapabilityError(f"Capability payload must contain 1–{MAX_PAYLOAD} bytes.")

    offset = 0
    codec: dict[str, Any] | None = None
    categories: list[str] = []
    warnings: list[str] = []
    while offset < len(data):
        if len(data) - offset < 2:
            raise CapabilityError(f"Truncated category/length header at byte {offset}.")
        category, length = data[offset], data[offset + 1]
        offset += 2
        if length > len(data) - offset:
            raise CapabilityError(f"Truncated category 0x{category:02X} at byte {offset - 2}.")
        value = data[offset : offset + length]
        offset += length
        categories.append(f"0x{category:02X}")

        if category != MEDIA_CODEC_CATEGORY:
            continue
        if codec is not None:
            raise CapabilityError("Multiple Media Codec records: process each SEP separately.")
        if len(value) < 2:
            raise CapabilityError("Media Codec record must contain media type and codec type.")
        media_type = value[0] >> 4
        reserved = value[0] & 0x0F
        codec_type = value[1]
        codec = {
            "media_type": {0: "audio", 1: "video", 2: "multimedia"}.get(
                media_type, f"unknown 0x{media_type:X}"
            ),
            "codec_type": f"0x{codec_type:02X}",
            "codec": STANDARD_CODECS.get(codec_type, f"Unknown standard 0x{codec_type:02X}"),
            "codec_specific_hex": value[2:].hex(" ").upper(),
        }
        if reserved:
            warnings.append("Reserved bits in Media Codec media-type byte are nonzero.")
        if media_type != 0:
            warnings.append("Non-audio SEP: do not interpret it as a headphone audio codec.")
        if codec_type == 0xFF:
            if len(value) < 8:
                raise CapabilityError(
                    "Vendor Media Codec requires 4-byte little-endian vendor ID "
                    "and 2-byte little-endian codec ID."
                )
            vendor = int.from_bytes(value[2:6], "little")
            vendor_codec = int.from_bytes(value[6:8], "little")
            codec["vendor_id"] = f"0x{vendor:08X}"
            codec["vendor_codec_id"] = f"0x{vendor_codec:04X}"
            codec["codec"] = VENDOR_CODECS.get(
                (vendor, vendor_codec), "Unknown vendor-specific codec"
            )
            codec["codec_specific_hex"] = value[8:].hex(" ").upper()

    if codec is None:
        raise CapabilityError("No Media Codec service category (0x07) found.")
    return {
        "input": "one operator-extracted AVDTP service-capability TLV list",
        "peer_role": peer_role,
        "message_kind": message_kind,
        "codec": codec,
        "service_categories": categories,
        "warnings": warnings,
        "interpretation": (
            "User-labeled capabilities, NOT verified sink identity or successful negotiation."
            if message_kind == "capabilities"
            else "User-labeled configuration, NOT proof of completed streaming or decoding."
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--caps-hex", required=True, help="One SEP's TLV bytes, e.g. '01 00 07 06 ...'")
    parser.add_argument("--peer-role", choices=("sink", "source"), required=True)
    parser.add_argument("--message-kind", choices=("capabilities", "configuration"), required=True)
    args = parser.parse_args(argv)
    try:
        result = parse_capabilities(
            parse_hex(args.caps_hex),
            peer_role=args.peer_role,
            message_kind=args.message_kind,
        )
    except CapabilityError as exc:
        parser.exit(2, f"INVALID CAPABILITIES: {exc}\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
