"""Synthetic byte vectors; no recordings, hardware, firmware or network access."""
import unittest

from decode_caps import CapabilityError, parse_capabilities, parse_hex


def decode(raw: str, *, kind: str = "capabilities") -> dict:
    return parse_capabilities(
        parse_hex(raw), peer_role="sink", message_kind=kind
    )


class DecoderTests(unittest.TestCase):
    def test_sbc_capability_with_media_transport(self) -> None:
        got = decode("01 00 07 06 00 00 21 15 02 35")
        self.assertEqual(got["codec"]["codec"], "SBC")
        self.assertEqual(got["service_categories"], ["0x01", "0x07"])
        self.assertEqual(got["peer_role"], "sink")
        self.assertIn("NOT verified", got["interpretation"])

    def test_aac_configuration_is_not_proof_of_playback(self) -> None:
        got = decode("07 08 00 02 40 01 04 00 03 E8", kind="configuration")
        self.assertEqual(got["codec"]["codec"], "MPEG-2/4 AAC")
        self.assertIn("NOT proof", got["interpretation"])

    def test_vendor_classic_aptx(self) -> None:
        got = decode("07 09 00 FF 4F 00 00 00 01 00 21")
        self.assertEqual(got["codec"]["codec"], "aptX")
        self.assertEqual(got["codec"]["vendor_id"], "0x0000004F")
        self.assertEqual(got["codec"]["vendor_codec_id"], "0x0001")

    def test_vendor_aptx_hd(self) -> None:
        got = decode("07 0D 00 FF D7 00 00 00 24 00 20 00 00 00 00")
        self.assertEqual(got["codec"]["codec"], "aptX HD")
        self.assertEqual(got["codec"]["codec_specific_hex"], "20 00 00 00 00")

    def test_vendor_ldac(self) -> None:
        got = decode("07 0A 00 FF 2D 01 00 00 AA 00 30 03")
        self.assertEqual(got["codec"]["codec"], "LDAC")

    def test_unknown_vendor_does_not_claim_new_codec(self) -> None:
        got = decode("07 08 00 FF 34 12 00 00 88 00")
        self.assertEqual(got["codec"]["codec"], "Unknown vendor-specific codec")
        self.assertEqual(got["codec"]["vendor_id"], "0x00001234")

    def test_colon_separated_hex(self) -> None:
        self.assertEqual(parse_hex("07:06:00:00:21:15:02:35"), bytes.fromhex("0706000021150235"))

    def test_reject_non_audio_media_type_and_reserved_bits(self) -> None:
        for raw in ("07 06 10 00 21 15 02 35", "07 06 01 00 21 15 02 35"):
            with self.subTest(raw=raw), self.assertRaises(CapabilityError):
                decode(raw)

    def test_reject_truncated_category_header(self) -> None:
        with self.assertRaises(CapabilityError):
            decode("01 00 07")

    def test_reject_truncated_tlv(self) -> None:
        with self.assertRaises(CapabilityError):
            decode("07 08 00 FF 4F 00 00")

    def test_reject_truncated_standard_codec_ie(self) -> None:
        for raw in ("07 02 00 00", "07 02 00 02", "07 05 00 00 21 15 02",
                    "07 09 00 02 40 01 04 00 03 E8 00"):
            with self.subTest(raw=raw), self.assertRaises(CapabilityError):
                decode(raw)

    def test_reject_truncated_vendor_codec_ie(self) -> None:
        for raw in ("07 08 00 FF 4F 00 00 00 01 00",
                    "07 09 00 FF D7 00 00 00 24 00 20",
                    "07 08 00 FF 2D 01 00 00 AA 00"):
            with self.subTest(raw=raw), self.assertRaises(CapabilityError):
                decode(raw)

    def test_reject_short_vendor_ids(self) -> None:
        with self.assertRaises(CapabilityError):
            decode("07 07 00 FF 4F 00 00 00 01")

    def test_reject_multiple_media_codec_records_in_one_sep(self) -> None:
        with self.assertRaises(CapabilityError):
            decode("07 06 00 00 21 15 02 35 07 08 00 02 40 01 04 00 03 E8")

    def test_reject_missing_media_codec_record(self) -> None:
        with self.assertRaises(CapabilityError):
            decode("01 00")

    def test_reject_bad_roles_and_kind(self) -> None:
        with self.assertRaises(CapabilityError):
            parse_capabilities(b"\x07\x02\x00\x00", peer_role="guessed", message_kind="capabilities")
        with self.assertRaises(CapabilityError):
            parse_capabilities(b"\x07\x02\x00\x00", peer_role="sink", message_kind="guessed")

    def test_reject_odd_hex_and_untrusted_text(self) -> None:
        for invalid in ("07 0", "07:0x02", "Bluetooth 07", "", "00" * 4097):
            with self.subTest(invalid=invalid[:30]), self.assertRaises(CapabilityError):
                parse_hex(invalid)

    def test_byte_length_bounds(self) -> None:
        with self.assertRaises(CapabilityError):
            parse_capabilities(b"", peer_role="sink", message_kind="capabilities")
        with self.assertRaises(CapabilityError):
            parse_capabilities(b"\x00" * 4097, peer_role="sink", message_kind="capabilities")


if __name__ == "__main__":
    unittest.main()
