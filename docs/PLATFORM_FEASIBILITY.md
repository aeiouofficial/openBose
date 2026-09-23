# OpenBose — Android and Windows platform feasibility (2026-09-23)

**Scope:** NC 700 Bluetooth settings, read-only codec diagnostics, temporary host EQ. No firmware manipulation in the initial application. Supporting hardware/codec research: [deep research](DEEP_RESEARCH_2026-09-23.md).

## Architecture decision for MVP

- **Protocol contract:** A versioned BMAP command registry, canonical packet fixtures, parser/error-state tests and NC 700-only capability map in `spec/`.
- **Android:** Kotlin + Jetpack Compose, coroutines, Bluetooth Classic RFCOMM, optional Media3/AudioTrack sample player for isolated host EQ.
- **Windows:** C#/.NET desktop (WPF initially, following proven SaorCon integration), Windows RFCOMM transport, optional WASAPI sample player.
- **Shared contract instead of premature cross-platform FFI:** both clients must pass the same binary fixtures and operation-policy tests. A Rust library/JNI bridge can be evaluated if independently maintained parsers become costly.
- **BMAP request coordination:** single reader, stream reassembly, one writer/transaction mutex, bounded timeouts, address/operator reply matching, unsolicited event queue and disconnect cancellation.
- **Safety layers:** read-only device diagnostics; separately gated verified Bose settings; independent host-EQ bypass; advanced codec research offline only.
- **Version gating:** check product ID, firmware version and supported functions before allowing any persisted write.

## Android Bluetooth transport

- Android 12+ apps need runtime `BLUETOOTH_CONNECT` to communicate with already-paired headphones; request `BLUETOOTH_SCAN` only if doing active scanning. For Android 11 or lower, declare legacy permissions with bounded `maxSdkVersion`. Official reference: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions
- Public `BluetoothDevice.createRfcommSocketToServiceRecord(UUID)` performs SDP lookup and creates an authenticated RFCOMM socket. Start with SPP UUID `00001101-0000-1000-8000-00805F9B34FB` as demonstrated by actual NC 700 Android app `noisecancel`.
- The older Python and Windows NC 700 clients report RFCOMM **channel 8**. Use discovery where possible; channel-specific private Android reflection must **not** be the only production route.
- Run blocking socket reads off the UI thread; use an explicit connection lifecycle; coordinate with A2DP music playback and the official Bose app.
- Production discovery should support already-paired NC 700 with clear permission and Bluetooth-disabled/error states. No background scanning without the user's instruction.

## Android codec reporting and temporary host EQ

- A2DP codec negotiation is managed by the system Bluetooth stack, separate from the SPP/BMAP settings socket. OpenBose must never imply that a system-supported **encoder** is a codec installed on NC 700.
- Public `BluetoothA2dp` provides profile connection status and (on supported API levels) platform codec-type information; it does **not** provide a universally portable third-party API for setting arbitrary A2DP codec or inspecting every vendor-specific sink capability.
- **Public SDK compatibility:** `BluetoothCodecStatus` and `BluetoothCodecStatus.EXTRA_CODEC_STATUS` are documented as **added in API 33** in the [current Android API reference](https://developer.android.com/reference/android/bluetooth/BluetoothCodecStatus). The public `BluetoothA2dp` reference does not list `ACTION_CODEC_CONFIG_CHANGED` as an ordinary third-party broadcast; older AOSP platform/internal interfaces are not equivalent to public SDK guarantees. On API 33+, use only public methods actually available to the app; on earlier versions, use Android Developer Options and explicit sanitized HCI snoop captures instead of promising a public codec-status getter or broadcast. Confirm the actual NC 700 sink advertisement via AVDTP, not merely a phone-side codec option.
- Temporary EQ phase one: app-owned playback through Android Media3/AudioTrack and a software biquad filter. Bypass closes processing and writes **no headphone EQ command**.
- **Not a standard system-wide Android EQ:** capturing other apps' audio through MediaProjection requires per-session consent, RECORD_AUDIO and target-app capture permission; some audio is uncapturable. Global output-mix audio effects are not a supported blanket interception solution on modern Android. Official documentation: https://developer.android.com/media/platform/av-capture and https://developer.android.com/reference/kotlin/android/media/AudioPlaybackCaptureConfiguration
- Treat audio focus, Bluetooth headset microphone/HFP transitions, phone-call interruption, MediaProjection cancellation and power management as distinct test cases.
- Android production UX: persistent controls are explicitly labeled **Headphone EQ**; temporary processing is explicitly labeled **Phone EQ (OpenBose player only)** until wider routing is actually verified.

## Windows Bluetooth transport

- SaorCon's dedicated NC 700 code provides an existing C#/WPF baseline with channel 8, ANC and battery support: https://github.com/platinum95/SaorCon/blob/main/SaorCon/BoseDevices.cs
- Use the Windows Bluetooth RFCOMM APIs or a maintained .NET Bluetooth library with service discovery; write a transport adapter independent of BMAP parsing.
- **Known failure mode:** SaorCon documents intermittent Windows C# RFCOMM *receive* failures. Test a second USB adapter and repeated reconnects, not just successful `connect()` and sends.
- Ensure independent control socket and A2DP playback operation, suspend/reconnect handling, multiple paired Bose devices and graceful behavior when Bose Music is already connected on another host.
- Windows sample-player host EQ: own WASAPI render pipeline is feasible without rewriting Bluetooth drivers. Optional integration with an already installed user-selected EQ service is a separate mode.
- System-wide Windows EQ is a larger installable component, not a trivial flag: Microsoft documents in-process Audio Processing Objects (APOs), their INF registration and driver packaging; do **not** ship an APO silently. Reference: https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/implementing-audio-processing-objects

## Compatibility and UX gates

| Area | Initial supported path | Deferred or blocked until evidence |
| --- | --- | --- |
| Android app | Paired NC 700, Bluetooth controls, battery/ANC/EQ, read-only diagnostics | Global interception of unrelated apps, codec override |
| Windows app | Paired NC 700, Bluetooth controls, battery/ANC/EQ, read-only diagnostics | System APO installer, guaranteed codec selection across adapters |
| Codec laboratory | Collect real A2DP sink advertisement and negotiated codec, offline archive analysis | aptX/HD/LDAC activation, DSP loading, firmware flashing |
| Temporary host EQ | App-owned playback on each OS, explicit bypass | Any suggestion that it upgrades the Bluetooth transfer format |
| Firmware update | **Absent** from the initial app | NC 700-compatible authenticated loader/recovery must be demonstrated first |

## Suggested source layout

```text
D:\openBose\
  android/                 # Gradle + Kotlin + Compose
  windows/                 # .NET solution + WPF
  spec/bmap/               # packet vectors, typed commands and schema
  docs/                    # research, requirements and captures procedure
  captures/private/        # privacy-sensitive traces; ignored by Git
  scripts/workspace-env.ps1
  .tmp/                    # ALL project temp files/caches; ignored by Git
```

**Local workspace rule:** all generated source, captures, downloads, builds, test output and transient caches belong under `D:\openBose`; dot-source `scripts/workspace-env.ps1` before local tool commands to redirect TEMP/TMP, Gradle, npm, pip and Cargo. Tools may still contain preexisting system installations; don't modify or create external workspaces.

## Acceptance checks before feature branch merges

1. Both platforms pass identical packet fixture tests and reject malformed/truncated packets with no writes.
2. Real NC 700 GET-only session works on the specific firmware; redact Bluetooth address and serial from logs.
3. Only individually verified NC 700 controls become writable. Direct headphone EQ must be marked persistent.
4. Temporary EQ stops processing on bypass, app shutdown and Bluetooth reconnection; headphone-stored EQ is unchanged.
5. Windows two-adapter regression plus Android Bluetooth-permission matrix; no unreviewed OTA, DFU or opaque opcode trial.
