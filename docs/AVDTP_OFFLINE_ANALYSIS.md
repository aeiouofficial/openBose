# Offline AVDTP codec-evidence tool

Status: source and **synthetic tests** added; not yet validated against a real NC 700 HCI capture. No Bluetooth connections, headset writes or firmware updates are performed by this tool.

## Purpose

The NC 700's Windows SDP records did not advertise the older reverse-engineered RFCOMM channel 8. The next independent evidence source is **Android's HCI snoop log**, specifically the headset's AVDTP **sink** GetCapabilities / GetAllCapabilities replies and the later SetConfiguration request. The decoder prevents confusing an option listed in Android Developer Options with a codec actually advertised by the headphones.

The Python program takes **only one SEP's AVDTP Service Capabilities TLV list**. It does not parse BTSnoop, HCI, ACL, L2CAP or AVDTP signaling headers; Wireshark or BlueZ must locate and isolate those bytes first.

## Procedure

1. Dot-source the project-local PowerShell workspace-env script before running any tool. All generated files belong under D:\openBose.
2. Follow [the Android HCI capture plan](PROTOCOL_CAPTURE_PLAN.md), retaining the raw bugreport and BTSnoop under D:\openBose\captures\private. Disable HCI logging afterward; never commit raw identifiers or unrelated traffic.
3. In Wireshark identify the NC 700's **audio sink SEP**, GetCapabilities/GetAllCapabilities **accept** message and SetConfiguration. Verify packet direction independently, not from a presumed codec identity.
4. Extract only Service Capabilities TLV bytes for **one SEP**: category, length and value. Exclude AVDTP signaling headers, ACP/INT SEID and HCI/L2CAP headers. Do not concatenate separate SEPs.
5. Run the decoder once per advertised sink SEP and once on the actual configuration, explicitly specifying role and message kind.

PowerShell examples (all byte strings here are **synthetic**, not actual NC 700 observations):

    . .\scripts\workspace-env.ps1
    python -B tools/avdtp/decode_caps.py --peer-role sink --message-kind capabilities --caps-hex "01 00 07 06 00 00 21 15 02 35"
    python -B tools/avdtp/decode_caps.py --peer-role sink --message-kind configuration --caps-hex "07 08 00 02 40 01 04 00 03 E8"
    python -B -m unittest discover -s tools/avdtp -p "test_*.py" -v

All output goes to stdout; redirect only to a project-local file, preferably a sanitized report.

## Evidence limits

- The reported peer role and message kind are **operator-provided**, not independently derived.
- A capabilities result does not prove that the provided bytes originated from NC 700, that the codec was negotiated, or that a decoder ran.
- A configuration result does not prove successful streaming or playback.
- Native aptX/HD/LDAC support requires correlated sink advertisement, selected configuration, actual playback and reconnect behavior, with firmware version.
- Unknown vendor codes are preserved as *unknown*, not guessed.
- Truncated TLVs, incomplete vendor IDs and concatenated codec categories fail closed.

## Protocol references

[AOSP's codec identifier definitions](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/system/stack/include/a2dp_constants.h) and [BlueZ's A2DP structures](https://github.com/bluez/bluez/blob/master/profiles/audio/a2dp-codecs.h) define aptX (0000004F/0001), aptX HD (000000D7/0024), LDAC (0000012D/00AA), and little-endian vendor and codec IDs. [BlueZ's AVDTP service-capability layout](https://kernel.googlesource.com/pub/scm/bluetooth/bluez/+/125a2e237e7c2b688f1cf26e1a3b3c7279ff5b06/android/avdtp.h) documents the category-length-value records. These protocol IDs are **not evidence** that Bose ships the corresponding decoders.
