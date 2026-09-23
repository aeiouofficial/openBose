# OpenBose — reproducible NC 700 baseline and protocol capture

Date: 2026-09-23. This is a **procedure**, not a report that live captures were already obtained. No firmware write or unknown BMAP operation belongs in this phase.

## Project-private capture layout

```text
D:\openBose\captures\private\YYYY-MM-DD\session-01\
  manifest.json
  android-bugreport.zip
  bluetooth-hci.log
  wireshark-notes.md
  sanitized-codec-findings.md
```

All captures, downloads and intermediates remain inside `D:\openBose`, under `captures/private` or `.tmp`; these paths are ignored by Git. HCI traces can include MAC addresses, device IDs and packet payloads; never upload raw traces without explicitly sanitizing them.

## Read-only NC 700 baseline

1. Record headphone model, reported hardware/product ID (`0x4024` is the Goodyear archive identity, **not** a substitute for a device read), installed firmware string, ANC mode, three EQ bands and available function blocks.
2. Record phone model, Android release, Bluetooth stack/adapter/driver and current Android Developer Options codec indication. Record Windows edition/build, PC Bluetooth adapter and driver.
3. Record ANC/EQ state **before** testing. No unreviewed SETGET/START commands, no firmware commands (function block 3), no USB reset.
4. Record connection topology: NC 700 paired only with the phone, only with the PC, then multipoint with both. In the first capture avoid simultaneous other Bose app connections.
5. Baseline a short known test audio file and AAC/SBC as currently negotiated; do not claim LDAC or aptX from a phone dropdown alone.

## Android HCI/A2DP capture: recommended primary evidence

1. Pair the NC 700 in the Android system UI. In Developer Options **enable Bluetooth HCI snoop log** and toggle Bluetooth off/on to apply it.
2. Fully disconnect/reconnect the headphones to trigger AVDTP `Discover`, `GetCapabilities/GetAllCapabilities`, `SetConfiguration` and `Open/Start`. Start playback; change only normal OS codec options if presented.
3. Use `adb devices` and `adb shell dumpsys bluetooth_manager` to check connectivity and service state. On stock phones, non-root access to raw `/data/misc/bluetooth/logs` is restricted.
4. In a terminal **after** dot-sourcing `D:\openBose\scripts\workspace-env.ps1`, save `adb bugreport 'D:\openBose\captures\private\YYYY-MM-DD\session-01\android-bugreport.zip'`. If ADB writes multiple files or a directory, place the specified output directory under that same private session.
5. Extract BTSnoop from the bugreport if available. Some Android builds expose `FS/data/log/bt/btsnoop_hci.log` or `FS/data/misc/bluetooth/logs/btsnoop_hci.log`; AOSP also documents `btsnooz.py` extraction from a text bugreport. Keep any extraction temp directory under `.tmp`.
6. Open a sanitized copy in Wireshark and filter for `bthci_acl`, `btl2cap` and `avdtp` as appropriate; exact dissector labels vary with Wireshark version.
7. For **each** source/sink SEP, record codec type and vendor-specific identifiers, advertised rates/channels and actual selected codec from `SetConfiguration` plus first decoded playback packet.
8. Turn HCI snoop logging off afterward; keep the raw trace private. Official instructions: https://source.android.com/docs/core/connect/bluetooth/verifying_debugging

## Bluetooth codec identifiers to look for

- A2DP standard SBC uses assigned codec type `0x00`, and MPEG-2/4 AAC uses `0x02`; verify in the actual AVDTP payload.
- Vendor-specific codec IDs in the A2DP payload are conventionally expressed as **32-bit vendor ID plus 16-bit codec ID**, little-endian on the wire. Example hypotheses to verify with AOSP decoder headers: aptX classic `0x0000004F / 0x0001`; aptX HD `0x000000D7 / 0x0024`; LDAC `0x0000012D / 0x00AA`.
- Distinguish `A2DP sink advertises codec`, `source offers codec`, `SetConfiguration selects codec`, and `actual audio plays`. All four are separate results.

## Separate BMAP settings capture (only documented user controls)

1. On a clean session, connect over classic SPP/RFCOMM and issue **GET-only** product identity, firmware, function blocks, battery, ANC and EQ requests using the reviewed protocol parser.
2. Compare user-facing settings in the official Bose app without leaving independent experimental writes running. If capturing app transactions, change only one documented user setting at a time and restore baseline afterward.
3. Parse unframed Bluetooth BMAP packet as `block / function / operator / payload length / bytes`; the USB transport uses a different envelope. Validate reply block/function and operator; do not read the first four bytes of an incomplete TCP-like stream as a whole packet.
4. For ANC, the documented NC 700 setter uses `01 05 02 02 [10 - level] [on/off]` and may require a second command on an off→on transition. Record ACK/state and restoration. References: https://github.com/danielgjackson/noisecancel/blob/master/README.md and https://github.com/platinum95/SaorCon
5. Bose EQ has three persisted bands and supports -10 to +10 on firmware 1.4.12+. Record before/after GET, not a UI-only screenshot. Reference: https://support.bose.com/s/article/nc700-headphonearn-adjusting-the-tone-controls-on-your-product---ka08c000001pxamaae?language=en_US
6. Do not issue a blind opcode sweep, connect on undocumented channels, enter OTA mode or flash firmware to "discover" codec support.

## Windows evidence collection

- Capture paired-device profile/driver identity, installed Windows build and USB Bluetooth adapter chipset/driver; test two adapters if RFCOMM receive fails.
- Use a **known-safe** NC 700 GET-only transaction to validate the Windows socket and subsequent responses; SaorCon reports occasional C# receive failure even when writes appear to succeed.
- Windows codec diagnosis from OS UI or diagnostic traces is auxiliary; the Android **A2DP negotiation capture** is primary if Windows capture lacks packet visibility.
- Any elevated ETW/netsh or driver-level collection must be an explicit diagnostic action, not silently started by a normal OpenBose launch.

## Acceptance: the evidence packet

A useful result contains: device firmware, OS/build, anonymized adapter identity, capture timestamp, peer profiles, full sink capabilities, selected codec, playback outcome, BMAP GET results, reproducibility (second reconnect) and references to *private* raw capture IDs. If codecs remain SBC/AAC, that is evidence of current **advertisement**, not a proof of permanent silicon incapability.
