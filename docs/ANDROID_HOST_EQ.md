# Android temporary host EQ and WAV preview

**Scope:** experimental app-owned Android playback. It cannot override the NC 700's
Bluetooth codec, process music from other apps, control Bose's native EQ, or
flash the headphones. It requires no storage, microphone, location or Internet
permission. Audio output follows Android's active media route, not a forced
Bluetooth connection.

## What is implemented

- A separate, non-exported `HostAudioActivity`, opened explicitly from the
  paired-device screen. It never connects to an NC 700 automatically.
- Android's document picker grants access to **one user-selected file** without
  broad storage permission. The PCM16 RIFF/WAVE parser verifies the format,
  chunk lengths, sample rate and mono/stereo frame alignment before playback.
- A streaming `AudioTrack` float PCM renderer plays the file through the
  current Android media output. Play/resume, pause and stop are present.
  Playback ends and resources are released when the user leaves the screen.
- Independent three-band peaking filters (about 100 Hz, 1 kHz and 8 kHz),
  gain limits of -10 to +10 dB, a headroom adjustment and output clamp.
  Host EQ is disabled by default. **Bypass does no signal processing.**
- Biquad state is independent per channel and maintained across arbitrarily
  fragmented PCM buffers. Settings changes are synchronized with processing.
  The app stores no selected audio or captured sound on disk.

## Local build and checks (no GitHub Actions)

```powershell
. .\scripts\workspace-env.ps1
& .\scripts\bootstrap-android.ps1
& .\scripts\bootstrap-android-sdk.ps1
& .\scripts\build-android-local.ps1 -RepositoryRoot D:\openBose
```

The local build runs the Kotlin BMAP and audio tests, assembles a debug APK,
executes Android Lint and audits declared APK permissions. The debug artifact
is copied to `D:\openBose\.tmp\dist\android\`. The project-local JDK,
Gradle installation, Android SDK, caches and intermediate build outputs
remain under `D:\openBose`. No remote CI minutes are consumed.

## Acceptance required before a stable Android release

1. Install the debug APK on a supported Android device. Confirm the document
   picker works for a **PCM16 WAV** at 44.1 kHz and 48 kHz, mono and stereo.
2. Pair an NC 700, select it as Android's active media output and audibly
   verify playback and bass/mid/treble changes. Check the same WAV plays
   unchanged with host EQ bypassed.
3. Verify pause/resume, stop, home/back navigation, reconnection and an
   unexpected Bluetooth disconnect. Confirm the headphone's stored EQ is
   unchanged after closing OpenBose and restarting the headphones.
4. Validate permission denial/revocation in the paired-device screen. Host
   playback must function without granting `BLUETOOTH_CONNECT` when using
   Android's ordinary media route.
5. Record an actual, sanitized AVDTP sink capability advertisement and
   selection to establish the real negotiated A2DP codec separately.

**Not implemented:** background playback, streaming other applications'
audio, DSP upload, headset-side aptX/LDAC activation, persistent Bose setting
writes, equalizer presets, or a production-signed release.
