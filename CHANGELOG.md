# OpenBose changelog

## 0.2.0-alpha — Android development build (2026-09-28)

- Added an Android app-owned PCM16 WAV player with Play, Pause, Stop,
  three-band temporary host EQ and a system document picker. No headphone
  settings are written, and no other app's audio is intercepted.
- Added Kotlin DSP and streaming WAV parser unit tests and a D-only local
  debug APK, Android Lint and manifest-permission audit.
- Added Android media audio-focus handling: loss stops playback; transient
  loss pauses without unexpectedly auto-resuming after calls or notifications.
- Preserved the selected WAV file and EQ settings across normal screen
  rotation, while stopping playback when the Activity leaves the foreground.
- Android 12+ no-backup data-extraction rules and a local vector app icon.
- This is an **alpha source/build milestone**, not a production-signed
  release or confirmation of working NC 700 native controls/aptX/LDAC.

## Earlier alpha milestones

- Windows .NET BMAP read-only core and RFCOMM/SDP diagnostics.
- Native Windows WPF shell, safe channel-8 guard, app-owned WAV player and
  locally tested three-band host EQ.
- Offline Android/Windows protocol contract tests and an AVDTP codec decoder
  for sanitized, manually extracted sink-capability evidence.
- Strict D:\openBose workspace and zero-GitHub-Actions local build policy.

Release gates and outstanding hardware dependencies: [release status](docs/RELEASE_GATES.md).
