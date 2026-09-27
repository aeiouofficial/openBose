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
| Android alpha APK | Local PASS on merged `master` | API 35 debug assembly, Kotlin BMAP/audio JUnit tests, lint and packaged-permission audit all passed on `1e34ad1`; only legacy Bluetooth (max SDK 30) and Android 12+ Bluetooth Connect declared. Device installation/audio acceptance remains pending. |
| Project privacy | PASS | Local strict D: environment and fail-closed zero-GitHub-Actions script; no audio/MAC data uploaded to GitHub. |
| Android real-device acceptance | BLOCKED | No authorized Android device was connected over local ADB at the last check. Test audio routing, focus loss, rotation, permission denial/revocation, Bluetooth disconnect and app termination. |
| NC 700 native settings | BLOCKED | Actual Windows NC 700 SDP baseline did not advertise legacy RFCOMM channel 8. Identify its real control transport, then verify known GET responses before permitting any settings writes. |
| Bluetooth codec upgrade | UNVERIFIED | Obtain actual A2DP sink advertisements, configuration and audible codec-negotiated playback. Silicon capabilities and Android encoder options alone are insufficient. |
| Release signing, localization and accessibility | PENDING | Production signing is intentionally not initialized; Android single-language UI still has nonfatal text-resource localization lint warnings. Physical UI, focus and accessibility acceptance remain unverified. |

## Locally verified merged-source artifacts (28 September 2026)

The following binaries were rebuilt from **GitHub `master` at commit
`1e34ad159e2e94acd74a67819ce2a859c741aaa9`** in the canonical
`D:\openBose` checkout. Both packaging scripts enforce D-only storage and
zero GitHub Actions. These are **local alpha binaries**, not tested shipping
installers; the Windows ZIP is framework-dependent and the Android APK uses
local debug signing.

| Artifact / gate | Local evidence |
| --- | --- |
| Windows WPF alpha ZIP | `D:\openBose\.tmp\dist\openbose-windows-readonly-alpha.zip`; SHA-256 `84F9248DF7BE265FEFE7CE4BC638B5C1E30C37E3F95983122A8EE4DC8D38A4EE`. |
| Windows build and tests | Release WPF build: zero warnings, zero errors; C# BMAP and host-DSP smoke PASS; diagnostic CLI help PASS; ZIP publish PASS. |
| Android debug alpha APK | `D:\openBose\.tmp\dist\android\openbose-android-host-eq-alpha.apk`; 847,806 bytes; SHA-256 `3DDAD1D4838403F278E3306282C8327A670E08B34E236C36C77988296CF56042`. |
| Android build and tests | Gradle `:audio:test :bmap:test :app:assembleDebug :app:lintDebug`: BUILD SUCCESSFUL, 53 actionable tasks. APK manifest audit: exactly the two declared legacy/modern Bluetooth permissions. |
| Full cross-platform offline suite | On the feature tree that was squash-merged *without source changes*: shared seven-GET policy checker and optimized negative cases PASS; 18/18 AVDTP synthetic tests PASS; Windows .NET BMAP and DSP smoke PASS; Kotlin BMAP and audio JUnit suites PASS. |
| Hardware availability | Local `adb devices -l`: zero authorized/unauthorized Android devices, so phone UI/playback and actual NC 700 AVDTP negotiation cannot be claimed tested. |

Rebuild against a future release commit after any source, dependency or
toolchain change; these checksums apply **only** to the binaries above. Local
Android Lint has nonfatal hard-coded-English string warnings and the Gradle
8.13 build reports future Gradle 9 deprecations; these remain technical debt,
not reasons to claim release readiness.

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
