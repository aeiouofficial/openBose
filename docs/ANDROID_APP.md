# Android app — paired-device diagnostics and temporary host EQ

Updated 2026-09-27. Android 8+ (`minSdk 26`), initially targeting the
Redmi Note 10 5G and a paired Bose NC 700. **The locally compiled debug APK
is an alpha, not a validated Bose-control application or codec upgrade.**

## Implemented and verified locally

- The main native Kotlin Activity lists paired Bluetooth devices and cached
  service UUIDs. It never automatically connects, sends BMAP commands or
  treats an Android-side codec option as NC 700 codec support.
- Android 12+ requests `BLUETOOTH_CONNECT` on demand; earlier releases use
  legacy install-time Bluetooth permission. Permission denied/revoked and
  Bluetooth disabled are handled without sending a packet.
- A second, non-exported Activity provides a user-initiated document picker,
  app-owned PCM16 WAV playback through Android AudioTrack, three-band
  temporary host EQ, explicit bypass and Play/Pause/Stop.
- The independent Kotlin `:audio` module contains a bounded streaming WAV
  parser and synchronized float-PCM EQ. Tests cover malformed/truncated WAV,
  fragmentation, stereo separation, exact bypass and finite output.
- Both Kotlin JVM suites (`:audio:test`, `:bmap:test`), Android
  `:app:assembleDebug` and `:app:lintDebug` passed locally. The packaged
  APK requests **only** legacy `BLUETOOTH` (max SDK 30) and
  `BLUETOOTH_CONNECT`; no storage, Internet, microphone or location access.

## Build and artifact — D: only, no GitHub Actions

```powershell
. .\scripts\workspace-env.ps1
& .\scripts\bootstrap-android.ps1
& .\scripts\bootstrap-android-sdk.ps1
& .\scripts\build-android-local.ps1
& .\scripts\run-offline-tests.ps1
```

Android SDK API 35, build-tools 35.0.0, JDK 17, Gradle, all build intermediates
and the debug APK reside under `D:\openBose`. The local packaging script
runs tests, lint, the permissions audit and copies the APK into
`D:\openBose\.tmp\dist\android\` for a normal `master` checkout.
The debug build uses local development signing; no production signing key
or release installer is included.

See [Android host EQ](ANDROID_HOST_EQ.md) for scope and safety constraints
and [capture procedure](PROTOCOL_CAPTURE_PLAN.md) for real codec evidence.

## Hardware acceptance remains open

1. Install on the user's Android device and test paired/unpaired NC 700,
   Bluetooth disabled, permission denial/revocation, rotation and reopening.
2. Test PCM16 mono/stereo WAV playback at 44.1/48 kHz through the NC 700,
   controls, EQ A/B comparison, app exit and Bluetooth disconnect/reconnect.
   Verify the NC 700's **persistent** EQ never changes.
3. Capture real Android SDP/AVDTP sink capabilities before enabling any
   headset-specific setting writes or claiming new native codecs.
4. The real Windows NC 700 baseline did not advertise legacy RFCOMM
   channel 8. Do **not** send BMAP GETs or unknown opcodes to other vendor
   service channels without a validated transport mapping.

No background player, system-wide EQ, streaming interception, firmware
updater, aptX/LDAC activation or production-signed release is present.
