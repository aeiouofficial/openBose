# Android app — initial read-only device baseline

Updated 2026-09-24. This app skeleton runs on Android 8+ and is intended first for the Redmi Note 10 5G and a paired Bose NC700. It is **not yet** an operational Bose settings app or a codec installer.

## Implemented

- `android/app`: native Kotlin Activity displaying paired Bluetooth device names and **cached** service UUIDs. The Bose entry appears first where names are available. Names/profile UUIDs are not sent to any server or written to files.
- Android 12+ requests `BLUETOOTH_CONNECT` only after tapping the paired-device button. Older releases use their install-time legacy `BLUETOOTH` permission. No permission for active scanning, microphone, storage or Internet.
- Launching OpenBose does **not** connect to headphones. It contains no BMAP output commands, raw-packet sender, codec override, firmware updater or persistent EQ writes. Cached service UUIDs must not be presented as confirmed codec capability.
- Existing `:bmap` Kotlin/JVM library remains separately tested against the shared Windows BMAP contract and synthetic fixtures.

## Local build (all files under D:\openBose)

```powershell
. .\scripts\workspace-env.ps1
& .\scripts\bootstrap-android.ps1
& .\scripts\bootstrap-android-sdk.ps1
& .\android\gradlew.bat -p .\android -PwithAndroidApp=true :app:assembleDebug
& .\scripts\run-offline-tests.ps1
```

`bootstrap-android-sdk.ps1` downloads official Google command-line tools, platform Android 35 and build tools 35 into `D:\openBose\.tmp\android-sdk`; project-local `JAVA_HOME`, Gradle cache and Android SDK user directory are configured without changing the user's system installations. The tooling download/bootstrap and the **APK build must pass locally before this draft feature may merge**.

## Next gates

1. Run `:app:assembleDebug` and Android Lint on the local SDK. Validate the APK manifest has no permission beyond `BLUETOOTH` (legacy) and `BLUETOOTH_CONNECT`.
2. Install on the Redmi and verify that permission denial/revocation, Bluetooth disabled, no paired device and a paired NC700 all behave correctly.
3. Record actual Android SDP and AVDTP sink capability/codec negotiation separately. The real Windows NC700 did not advertise the old channel-8 BMAP endpoint; **do not** blindly send even GET packets to another vendor RFCOMM service.
4. Once the correct NC700 control transport is demonstrated, implement a distinct user-confirmed read-only diagnostic connection, then validated persistent settings. Host-only temporary audio EQ is a separate playback subsystem and is not implemented in this skeleton.

**Status:** source scaffolded, Android compilation/device installation not verified at documentation time; no change to headphones.
