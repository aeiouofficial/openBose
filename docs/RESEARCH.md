# OpenBose — NC 700 research and source audit

Updated: 2026-09-24. Scope: Bose Noise Cancelling Headphones 700 (NC 700), **not** generic Bose headphones. Includes source/firmware archive research and a **read-only Windows SDP discovery of the user's paired device**. No verified BMAP GET, decrypted firmware, modified headphone setting or new codec has been achieved. See [Windows device-specific findings](WINDOWS_DIAGNOSTIC.md).

## Objective

Develop an Android/Windows Bose-control app and investigate whether the NC 700 can actually decode and advertise Bluetooth audio codecs beyond its currently reported SBC/AAC implementation. Keep three different mechanisms separate:

- **BMAP control plane:** read/change Bose settings over RFCOMM (volume, ANC, EQ, battery).
- **Host audio plane:** source-device AAC/SBC/other encoding and optional software EQ. A new host encoder or host EQ does **not** add a decoder to the headphones.
- **Headphone firmware/DSP:** codec decoder, A2DP capabilities, configuration, possible firmware loader. Requires device-specific verification. Never presume codec activation or reversible RAM patching.

## Actual-device transport finding (2026-09-24)

WinRT discovered eight RFCOMM services on the user's paired NC700. Their redacted SDP ProtocolDescriptorList attributes decode to channels **10, 11, 14, 20, 21, 25, 27 and 29**. Neither channel **8** nor standard SPP UUID **00001101** was advertised at that time, despite older NC700 reverse-engineering scripts using channel 8. An explicit Windows BMAP GET refused to send, and a separate 32feet legacy channel-8 connection failed before any command. This difference requires firmware/profile-specific validation rather than blind probing of vendor-specific services. [Full anonymized findings](WINDOWS_DIAGNOSTIC.md).

## Direct NC 700 reverse-engineering repositories

| Source | Exact findings | Limitations |
| --- | --- | --- |
| [iclemens/bose](https://github.com/iclemens/bose) | Reports **Qualcomm CSRA68105** for NC 700; BMAP commands, Bluetooth RFCOMM channel **8**, USB alternative framing, Wireshark dissector; scripts for identity, firmware information, ANC, EQ read and volume. Firmware-transfer format is partially described. | Research scripts; not a finished cross-platform app or codec loader. |
| [bosefirmware/Bose-NC700](https://github.com/bosefirmware/Bose-NC700) | **Unchanged fork**: its only listed `master` branch and original's only listed `master` both resolve to `fed1311fc84aa53e59053abfc001e5fedade2ef7`; GitHub comparison returns **identical**, zero changed files; recursive trees match. | Adds no codec code, decoder, RAM loader or firmware-unlock mechanism. |
| [bosefirmware/SaorCon-Win-BT-QC35-NC700](https://github.com/bosefirmware/SaorCon-Win-BT-QC35-NC700) | Actual Windows NC 700 class in `SaorCon/BoseDevices.cs`: RFCOMM channel 8, battery and ANC; NC 700 ANC function `01:05`, whereas QC35 uses `01:06`. | README documents occasional **Windows RFCOMM receive failure** and early-stage crashes. |
| [bosefirmware/ced](https://github.com/bosefirmware/ced/tree/master/goodyear) | Archive for NC 700 codename **Goodyear**: eight `goodyear_encrypted_prod_*.bin` versions (1.0.9, 1.1.4, 1.2.11, 1.3.1, 1.4.12, 1.5.1, 1.7.0, 1.8.2). `goodyear/index.xml` identifies product ID **0x4024**, length and CRC metadata. [Release notes](https://github.com/bosefirmware/ced/blob/master/goodyear/README.md) describe 3-band EQ introduced with 1.4.12, and reported red/white LED problems. | Binary names suggest encryption; content and authenticity have **not** been independently established. No firmware flash recommended. |
| [bosefirmware/bose-dfu](https://github.com/bosefirmware/bose-dfu) | Its [README](https://github.com/bosefirmware/bose-dfu/blob/main/README.md) **explicitly lists NC 700 as incompatible** because of a different updater protocol. Its [device_ids.rs](https://github.com/bosefirmware/bose-dfu/blob/main/src/device_ids.rs) excludes USB PID **0x40fc**. | Not an NC 700 update or recovery route. Never apply this DFU method to NC 700. |

### Original repository technical audit

- [BMAP Bluetooth transport](https://github.com/iclemens/bose/blob/master/python/bose_bt.py): Python RFCOMM channel 8; hardcoded example MAC in the CLI must be removed.
- [BMAP framing](https://github.com/iclemens/bose/blob/master/python/bose_proto.py): four-byte block/function/operator/length prefix. `OPERATOR_GET=1`, `SETGET=2`, `START=5`; do **not** reuse commands without validating return packets, timeouts and firmware version.
- [ANC and prompts](https://github.com/iclemens/bose/blob/master/python/bose_settings.py): setter examples and language parser. Settings may persist on the headphone.
- [USB script](https://github.com/iclemens/bose/blob/master/python/bose_usb.py): provides GET requests for firmware identity, battery, ANC and EQ at **settings 01:07**. Its `parse_bass` uses the incorrect slice `data[i*4:4+i*4]`, and the script references `parse_prompt_language` without importing it. **Fix/test offline; do not run as-is against hardware.**
- [Firmware parser](https://github.com/iclemens/bose/blob/master/firmware/unpack.py): splits container parts including `APPUHDR5`, `PARTDATA` and `APPUPFTR`. It is **not** a decryptor, arbitrary-code loader, or patch installer. The original README documents partial firmware-transfer packet structure, **not** a safe downgrade/recovery mechanism.

## Additional app and protocol references

| Repository | Relevance | Porting caution |
| --- | --- | --- |
| [bosefirmware/OpenBose-Connect](https://github.com/bosefirmware/OpenBose-Connect) (parent: [sim642/openbose](https://github.com/sim642/openbose)) | Python packet classes, BMAP client, BlueZ/GTK app and [research links](https://github.com/bosefirmware/OpenBose-Connect/blob/master/LINKS.md). | Linux-oriented, no documented NC 700 codec switching. |
| [bosefirmware/BoseConnect-Linux_based-connect](https://github.com/bosefirmware/BoseConnect-Linux_based-connect) (parent: [Denton-L/based-connect](https://github.com/Denton-L/based-connect)) | C/BlueZ BMAP implementation, volume and connectivity packet notes; firmware lookup conventions. | README says tested with QC35 and SoundLink II; not demonstrated for NC 700. |
| [bosefirmware/BoseConnect-Android_Basic-control](https://github.com/bosefirmware/BoseConnect-Android_Basic-control) (parent: [DavidVentura/Bose_QC35_Android](https://github.com/DavidVentura/Bose_QC35_Android)) | Kotlin Bluetooth socket and BMAP parser: a concrete Android porting reference. | QC35-focused: ANC opcode differs from NC 700. |
| [bosefirmware/bosectl](https://github.com/bosefirmware/bosectl) (parent: [aaronsb/bosectl](https://github.com/aaronsb/bosectl)) | Typed BMAP libraries in Python, Rust, C++; device catalog maps NC 700 to **Goodyear / 0x4024**; [NOTES.md](https://github.com/bosefirmware/bosectl/blob/main/NOTES.md) details other devices' SETGET/auth behavior. | NC 700 is **catalogued, not verified** as a supported driver; another model's write permissions cannot be generalized to NC 700. |
| [bosefirmware/bosectl-qt](https://github.com/bosefirmware/bosectl-qt) | Desktop UI reference and EQ/ANC screens. | Not proof of NC 700 codec support. |
| [bosefirmware/ced-old](https://github.com/bosefirmware/ced-old) | Legacy Bose updater/software archives, including NC 700 UC USB Link material. | USB Link firmware is not automatically NC 700 headphone firmware. |
| [bosefirmware/cd-updates](https://github.com/bosefirmware/cd-updates) | Archived CD/DVD/Wave updates. | No NC 700 codec evidence in reviewed tree. |
| [bosefirmware/bosebuild](https://github.com/bosefirmware/bosebuild) | Legacy build archive. | No codec-unlock claim from filenames/README alone. |

## Branch audit

GitHub branch-list endpoint returned the following **only branches listed** on 2026-09-23; this does not include PR refs or unpublished worktrees:

| Repository | Listed branches |
| --- | --- |
| iclemens/bose | `master` |
| bosefirmware/Bose-NC700 | `master` |
| bosefirmware/OpenBose-Connect | `master` |
| bosefirmware/BoseConnect-Linux_based-connect | `master` |
| bosefirmware/BoseConnect-Android_Basic-control | `master` |
| bosefirmware/SaorCon-Win-BT-QC35-NC700 | `main` |
| bosefirmware/bose-dfu | `main` |
| bosefirmware/bosectl | `main` |
| bosefirmware/bosectl-qt | `main` |
| bosefirmware/ced | `master` |
| bosefirmware/ced-old | `master` |
| bosefirmware/cd-updates | `master` |
| bosefirmware/bosebuild | `master` |

The original GitHub metadata reports **two forks**; one (`bosefirmware/Bose-NC700`) is directly verified. The identity/content of the other advertised fork remains unverified because the fork-list endpoint was unavailable to the active GitHub integration. Do not call that fork audited.

## Codec feasibility: findings versus hypotheses

**Finding:** None of the inspected NC 700 code demonstrates headphone-side aptX, aptX HD, LDAC or LHDC activation, a compatible decoder installer, a temporary RAM loader or a working NC 700 recovery mechanism. No live A2DP advertisement or negotiation capture was obtained. **Do not convert repository silence into proof that the silicon is physically incapable.**

**Hypothesis A:** A decoder exists but is not advertised or enabled. Establish this from a real A2DP capability capture plus reproducible firmware/chip documentation evidence. A BMAP settings command, if any, must be device-specific and verified.

**Hypothesis B:** Decoder absent from shipping firmware. Adding one to the phone or a PC cannot make an NC 700 decode it. A headphone-side implementation would require code appropriate for the actual DSP/CPU, sufficient memory and compute, a valid load path, firmware permissions/signatures, and a reproducible recovery path. There is no evidence of an ephemeral loader for these headphones.

**Hypothesis C:** Host-side EQ improves perceived sound. This is a valid separate feature **but is not a new Bluetooth codec** and must never be represented as aptX/LDAC capability.

## Evidence and safety rules for subsequent research

1. Read-only baseline: real headphone firmware version, product/hardware IDs, function blocks, current EQ/ANC, and Android/Windows A2DP advertised codecs; redact MAC/serial in public captures.
2. Capture paired Android/Windows A2DP negotiations and Bose app BMAP transactions for documented controls, with direction/timestamps and firmware revision.
3. Analyze **offline copies** of archived Goodyear images: independently verify sizes/CRC, inspect container headers/partitions, classify encrypted versus plaintext contents and look for authenticated signatures. Never flash as an exploratory parsing step.
4. Validate Qualcomm CSRA68105 codec capability from trustworthy chip documentation **and** NC 700 implementation evidence; processing power alone is not support.
5. For every candidate codec require: headphone decoder evidence, headphone A2DP advertisement, successful host negotiation, actual playback, reconnection and persistence results.
6. Keep all unknown writes and firmware commands out of the default app. Any live mutation, RAM patch or flash requires a separate approved experiment with a proven rollback/recovery route.

**Research status:** protocol and app foundations found; NC 700 additional codec support **unverified**; no software/firmware changes executed on hardware.
