# Windows NC700 RFCOMM diagnostic — read-only research

Updated: 2026-09-24. The CLI is **not** the finished settings app or a codec installer. It never initiates a headphone connection on ordinary launch and cannot transmit settings or firmware commands. Local work and private capture files remain in `D:\openBose`.

## Implementation and offline gates

- `windows/src/OpenBose.Diagnostic`: .NET 8 Windows CLI. `--list` first attempts paired-only 32feet enumeration; if the provider rejects a Windows PnP record, it falls back to WinRT `DeviceInformation`/Bluetooth enumeration.
- `--services show --address <MAC>`: **read-only** WinRT SDP discovery; decode attribute 0x0004 (ProtocolDescriptorList) to report RFCOMM channels. Opaque `ConnectionServiceName` contains a Windows PnP path, **not** a decimal channel.
- `--read <allowlisted-name> --address <MAC>`: use WinRT RFCOMM only if SDP advertises the research-backed NC700 BMAP channel 8. Fail closed otherwise. `--legacy-read` is a separate explicit attempt through 32feet's documented channel-8 endpoint; neither path scans or writes unknown channels.
- `windows/src/OpenBose.Protocol`: shared strict seven-command zero-payload GET allowlist, bounded stream reassembly and a single-request asynchronous exchange. Unrelated STATUS packets become diagnostic events; writes/START/SETGET/firmware blocks are denied.
- `windows/tests/OpenBose.Protocol.SmokeTests`: synthetic fragmented duplex, unsolicited frames, forbidden writes, timeout and strict RFCOMM SDP fixtures captured from the user's paired NC700. Run `& .\scripts\run-offline-tests.ps1` after project-local environment setup.

## CLI usage (PowerShell)

```powershell
. .\scripts\workspace-env.ps1
dotnet run --project windows/src/OpenBose.Diagnostic/OpenBose.Diagnostic.csproj -c Release -- --help
dotnet run --project windows/src/OpenBose.Diagnostic/OpenBose.Diagnostic.csproj -c Release -- --list
dotnet run --project windows/src/OpenBose.Diagnostic/OpenBose.Diagnostic.csproj -c Release -- --services show --address <PAIRED_NC700_MAC>
# Explicit GET-only hardware probe when a known BMAP channel is actually advertised:
dotnet run --project windows/src/OpenBose.Diagnostic/OpenBose.Diagnostic.csproj -c Release -- --read product_id --address <PAIRED_NC700_MAC>
```

## Actual NC700 observations on this Windows machine

**Paired-device enumeration works using the WinRT fallback.** The Bose NC 700 is paired and was reported connected at the time of capture. No MAC or serial is committed.

**Direct read-only SDP capture:** WinRT returned eight services with these RFCOMM channels. This is a hardware/Windows observation, *not* proof of application protocol identity:

| SDP service UUID | RFCOMM channel | Identification |
| --- | ---: | --- |
| 00001108-0000-1000-8000-00805f9b34fb | 11 | HSP Headset |
| 9b26d8c0-a8ed-440b-95b0-c4714a518bcc | 25 | Vendor-specific, unverified |
| f8d1fbe4-7966-4334-8024-ff96c9330e15 | 20 | Commonly called Google Assistant/Gsound data |
| 81c2e72a-0591-443e-a1ff-05f988593351 | 21 | Commonly called Google Assistant/Gsound voice |
| 931c7e8a-540f-4686-b798-e8df0a2ad9f7 | 27 | Alexa Mobile Accessory reference |
| 85dbf2f9-73e3-43f5-a129-971b91c72f1e | 29 | Unknown vendor service |
| 00000000-deca-fade-deca-deafdecacaff | 14 | Generic wireless iAP UUID also used by non-Bose products: **do not assume BMAP** |
| 0000111e-0000-1000-8000-00805f9b34fb | 10 | Hands-Free |

**Critical incompatibility:** This actual SDP set did **not** advertise either the generic SPP service UUID `00001101-...` or RFCOMM channel **8**, although the older [iclemens/bose](https://github.com/iclemens/bose) and [SaorCon](https://github.com/platinum95/SaorCon) prototypes use channel 8. An explicit WinRT read-only `product_id` probe **refused to send** because its required channel was absent. The separate 32feet legacy channel-8 connection failed before any BMAP command (provider `AggregateException`/invalid device index). Neither result proves a codec or firmware limitation.

Do **not** send GET packets to channels 14, 20, 21, 25, 27 or 29 merely because they exist. The generic `deca-fade` UUID is also used for Apple/iAP-style connections by devices unrelated to Bose; its presence does not authenticate the Bose BMAP control protocol. See the [BlueZ UUID taxonomy discussion](https://github.com/bluez/bluez/issues/963).

## Next device work

1. Compare a **sanitized** Android Classic SDP record and HCI capture for the same headset and firmware. Check whether channel 8 appears under another pairing/firmware state and whether the official Bose app uses RFCOMM or another transport.
2. Offline-audit existing NC700-specific implementations and their exact service discovery code. If they all rely on fixed channel 8, treat this Windows baseline as a version/platform compatibility difference until independently reproduced.
3. Add a demonstrated and authenticated NC700 control-channel mapping only after observational proof. Never route experimental BMAP packets to generic HSP, Google Assistant, Alexa or iAP services.
4. When the correct channel is discovered, verify real read-only product ID, firmware, battery and EQ/ANC replies, then reconnection and a second Windows Bluetooth adapter. Keep persistent headset changes unavailable in the diagnostic CLI.

**Current milestone:** Windows CLI compiles and offline tests pass; paired-device listing and real SDP parsing work. A live BMAP GET is **blocked by the missing advertised channel 8** on this unit. No headphone configuration or firmware changes were made.
