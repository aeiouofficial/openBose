# OpenBose release gates — 2026-09-28

This is a **traceable alpha acceptance matrix**, not a claim that either
platform or any new Bluetooth codec is production-ready. All project builds,
outputs, downloads and diagnostics must stay inside D:\openBose; GitHub Actions
are disabled because no hosted CI minutes remain.

| Gate | State | Evidence / next verification |
| --- | --- | --- |
| Safe BMAP core | Offline PASS | Seven identical allowlisted C#/Kotlin GET operations; synthetic malformed/frame/timeout/SDP fixtures and local .NET/JUnit tests. |
| Windows desktop | Local build PASS | WPF Release compiled with zero warnings/errors; alpha ZIP includes NAudio and OpenBose.Audio. |
| Windows temporary EQ | Offline PASS | DSP bypass, frequency-response, stereo/fragment and range smoke tests. Real headphone audio A/B test outstanding. |
| Android DSP/WAV parser | Offline PASS | Kotlin JUnit tests: exact bypass, multiple filter bands, frame fragmentation, malformed/truncated PCM WAV. |
| Android alpha APK | Local PASS on feature implementation | API 35 debug assembly, lint and manifest permission audit; only legacy Bluetooth and Android 12+ Bluetooth Connect declared. The 0.2.0-alpha build needs its final commit-specific repeat. |
| Project privacy | PASS | Local strict D: environment and fail-closed zero-GitHub-Actions script; no audio/MAC data uploaded to GitHub. |
| Android real-device acceptance | BLOCKED | No authorized Android device was connected over local ADB at the last check. Test audio routing, focus loss, rotation, permission denial/revocation, Bluetooth disconnect and app termination. |
| NC 700 native settings | BLOCKED | Actual Windows NC 700 SDP baseline did not advertise legacy RFCOMM channel 8. Identify its real control transport, then verify known GET responses before permitting any settings writes. |
| Bluetooth codec upgrade | UNVERIFIED | Obtain actual A2DP sink advertisements, configuration and audible codec-negotiated playback. Silicon capabilities and Android encoder options alone are insufficient. |
| Release signing, localization and accessibility | PENDING | Production signing is intentionally not initialized; Android single-language UI still has nonfatal text-resource localization lint warnings. Physical UI, focus and accessibility acceptance remain unverified. |

## Required before declaring a stable release

1. Run `scripts/run-offline-tests.ps1`, local Windows package gate and
   `scripts/build-android-local.ps1` against the exact release commit.
2. Verify an authorized Redmi device's Android version and install the
   debug APK with the owner's agreement. Test with a real NC 700, actual
   WAV files at 44.1/48 kHz and both active headphone/speaker routes.
3. Collect a sanitized, user-approved Android HCI capture of actual NC 700
   AVDTP sink capabilities. Keep raw logs exclusively under
   `D:\openBose\captures\private` (ignored by Git).
4. Resolve the NC 700's actual control transport. Enable native ANC/EQ
   writes only after audited GET/readback and explicit recovery policy.
5. Run phone/Windows manual stability, battery, disconnect/reconnect,
   multipoint and headphone persistent-EQ-regression acceptance.
6. Address remaining localization/accessibility warnings, create user-owned
   release signing credentials when needed, and publish separately
   labeled Android/Windows deliverables. **Do not** substitute a locally
   compiled debug APK for a validated signed production release.

The original Bose firmware has not been patched, flashed or downgraded.
Generic bose-dfu explicitly excludes NC 700 and must not be used here.
