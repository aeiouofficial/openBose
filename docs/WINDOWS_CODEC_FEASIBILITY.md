# Windows-first codec feasibility test

Updated 2026-09-28. This is the **first hardware feasibility path** for OpenBose.
Android codec experiments stay blocked until the Windows baseline below is complete.

## What we can prove on this Windows host

Observed locally, read-only:

- Windows 11 Pro for Workstations, build `26200`.
- Bluetooth radio: **Intel(R) Wireless Bluetooth(R)**, USB VID `8087`, PID `0026`.
- Bose NC 700 HP is paired; Bose product ID `0x4024` appears in Windows PnP.
- At the latest check there was **no active Bose AudioEndpoint**, so the NC 700
  was paired but not currently selected/connected as a Windows media output.
- Project code, package caches and captures remain under `D:\openBose`.

Microsoft's current Bluetooth Classic Audio documentation says Windows chooses
the first mutually supported A2DP codec from its priority list. Windows 11
supports AAC, aptX Classic and SBC; aptX Adaptive/Lossless support is limited
to Windows 11 24H2 on selected systems with compatible **Qualcomm** Bluetooth
radios. This laptop has an Intel radio, therefore we must **not** treat
aptX Adaptive as an available in-box host test path here.

Microsoft does not list LDAC as an in-box Windows A2DP codec. A Windows LDAC
test would therefore require a separately audited third-party A2DP driver and
would still only prove host+headphone negotiation, not that OpenBose itself
installed a decoder in the headphones.

References:

- https://learn.microsoft.com/windows-hardware/drivers/bluetooth/bluetooth-classic-audio
- https://learn.microsoft.com/windows-hardware/drivers/audio/audio-sideband-a2dp-offload
- https://learn.microsoft.com/windows-hardware/drivers/bluetooth/microsoft-defined-bluetooth-hci-commands-and-events

## Stage W1 — current negotiated codec (implemented)

`windows/src/OpenBose.CodecProbe` passively subscribes to the Windows
TraceLogging provider:

- provider GUID: `8776ad1e-5022-4451-a566-f47e708b9075`
- provider name: `Microsoft.Windows.Bluetooth.BthA2dp`
- event: `A2dpStreaming`
- codec fields: `A2dpStandardCodecId`, `A2dpVendorId`,
  `A2dpVendorCodecId`

The provider/event shape was independently cross-checked against the MIT
licensed Windows codec-inspector implementations below. OpenBose uses its own
minimal parser and tests rather than importing their applications.

- https://github.com/yossyl3oy/rust-btcodec-inspector
- https://github.com/A-BenLi06/Bluetooth-Audio-Codec-Viewer-WinUI3
- https://github.com/imbushuo/BluetoothAudioCodecInspector

The ETW session requires Administrator elevation on Windows. The probe itself
does **not** connect to Bluetooth, send BMAP, choose a codec, install a driver,
write the registry, or change headphone firmware/settings.

Important limitation: observing **AAC** does not prove aptX Classic is absent.
Microsoft documents AAC ahead of aptX Classic in the Windows preference order,
so a headset advertising both may still negotiate AAC. W1 establishes the
current stream, not the full sink capability set.

## Stage W2 — actual NC 700 sink capability advertisement

To answer whether the current NC 700 firmware advertises aptX/other vendor
codecs, capture its real AVDTP `Discover` + `GetCapabilities` exchange.
That is stronger evidence than a Windows codec dropdown or the selected codec.

Windows can expose raw Bluetooth HCI traffic through ETW. Wireshark documents
a Windows `etwdump` Bluetooth Host Radio capture using
`Microsoft-Windows-BTH-BTHPORT`; Microsoft's public `busiotools`
BluetoothStack WPR profile also enables BTHPORT/BthA2dp providers.

- https://wiki.wireshark.org/CaptureSetup/Bluetooth
- https://github.com/microsoft/busiotools/blob/master/bluetooth/tracing/BluetoothStack.wprp

Current machine state: WPR/WPA are installed, but Wireshark/`tshark`/
`etwdump` are not. Do not install them to C:. If needed, a portable/captured
toolchain must live under `D:\openBose\.tmp\tools`.

Raw HCI/ETL captures can contain MAC addresses and other identifiers. They
belong only in `D:\openBose\captures\private` and are never committed.

## Stage W3 — discriminating aptX Classic from AAC

Only after W1/W2:

1. If AVDTP capabilities explicitly contain aptX Classic
   (vendor `0x004F`, codec `0x0001`), the NC 700 already exposes aptX and
   the question becomes host negotiation/firmware configuration rather than
   decoder installation.
2. If only SBC/AAC are advertised, an AAC stream alone cannot tell us whether
   aptX code is dormant in firmware. Continue with offline firmware analysis.
3. A community-documented Windows registry switch named
   `BluetoothAacEnable` can disable AAC and may make Windows fall through to
   aptX Classic. It is **undocumented by Microsoft**, changes machine state,
   usually requires reconnect/reboot, and is therefore not part of the
   read-only baseline. OpenBose must snapshot and restore the previous value
   before any such experiment, and it must not be run implicitly.
4. Do not test LDAC with the stock Windows stack because Microsoft does not
   list LDAC as an in-box source codec. If later required, isolate a
   third-party-driver experiment from the normal app.

## Pass/fail interpretation

| Evidence | What it proves |
| --- | --- |
| ETW reports SBC/AAC | Current Windows stream uses that codec only. |
| ETW reports aptX | Windows + current NC 700 negotiated aptX: strong proof the headset advertises/accepts it. |
| AVDTP sink capabilities contain aptX/LDAC | Headset advertises that codec on the current firmware. Still verify actual playback. |
| Codec is absent from AVDTP capabilities | Current firmware does not advertise it; does **not** yet prove silicon/firmware cannot be patched. |
| Firmware contains an authenticated dormant decoder/config path | Candidate for a later reversible headphone-side experiment. |
| Phone/Windows source supports a codec | Host capability only; not evidence of NC 700 decoder support. |

No firmware flashing, downgrade, blind vendor-channel traffic or registry
mutation belongs in W1/W2.
