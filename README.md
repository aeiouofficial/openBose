# openBose

Android + Windows Bose NC 700 control app and research project investigating whether the headphones can support additional Bluetooth audio codecs (such as aptX or LDAC) beyond their reported AAC/SBC implementation.

**Status (2026-09-28): Android and Windows now have separately implemented app-owned temporary WAV players with three-band host EQ. The Android debug APK and Windows alpha package build locally; both protocol and DSP test suites pass. The Windows NC 700 baseline does not advertise RFCOMM channel 8, so live BMAP controls remain blocked pending verified transport identification. Real-device Android playback and AVDTP codec-capability capture remain outstanding. No headphone settings or firmware were modified; no new Bluetooth decoder has been activated.**

## Project documentation

- [Research dossier](docs/RESEARCH.md) — NC 700 chipset and BMAP protocol findings; identical `iclemens/bose` fork comparison; relevant Android/Windows/Linux projects; Goodyear firmware archive; DFU incompatibility; audited branches; confirmed facts versus unverified codec hypotheses.
- [Roadmap and acceptance gates](docs/ROADMAP.md) — read-only parser, cross-platform controls, temporary host-side EQ, offline firmware/codec feasibility and conditional activation testing.
- [Deep source audit](docs/DEEP_RESEARCH_2026-09-23.md) — hardware, related app repositories, archived Goodyear firmware and evidence gaps.
- [Android and Windows feasibility](docs/PLATFORM_FEASIBILITY.md) — platform architecture, permissions, transport and temporary audio processing.
- [Codec feasibility](docs/CODEC_FEASIBILITY.md) — aptX/aptX HD chip-vs-product evidence and required validation gates.
- [Capture procedure](docs/PROTOCOL_CAPTURE_PLAN.md) — privacy-conscious baseline and reproducible Android A2DP/BMAP capture.
- [Offline codec evidence tool](docs/AVDTP_OFFLINE_ANALYSIS.md) — parse one sanitized AVDTP SEP capability/configuration record (SBC, AAC, aptX, aptX HD, LDAC); synthetic test fixtures; **no device I/O**.
- [Live Windows RFCOMM findings](docs/WINDOWS_DIAGNOSTIC.md) — tested read-only CLI, paired-device WinRT fallback, actual SDP channel mapping and the channel-8 compatibility blocker.
- [Native Windows desktop](docs/WINDOWS_DESKTOP.md) — WPF paired-device GUI, safe SDP inspection, channel-gated BMAP reads, D-only alpha ZIP build.
- [Windows temporary host EQ](docs/HOST_EQ_WINDOWS.md) — app-owned WAV playback, independent three-band DSP, exact bypass and no Bose settings writes.
- [Android temporary host EQ](docs/ANDROID_HOST_EQ.md) — user-selected WAV playback through AudioTrack, local PCM16 decoder, Play/Pause/Stop, three-band DSP and safe bypass.
- [Release acceptance matrix](docs/RELEASE_GATES.md) — exact offline gate results, remaining real-device tests and codec/control blockers.
- [Changelog](CHANGELOG.md) — implemented Android/Windows alpha milestones and explicit non-shipping scope.

## Objectives

1. Reimplement useful Bose-app controls for the **Bose NC 700** on Android and Windows.
2. Provide optional **temporary host-side EQ** that leaves headphones' persistent settings unchanged.
3. Investigate actual **headphone-side decoder and A2DP support** for higher-quality Bluetooth codecs. A software EQ or a phone-side encoder does not count as a headphone codec unlock.
4. Keep unknown firmware writes, unsupported update protocols and unverified loader experiments out of the normal application.

## Source projects

- [iclemens/bose](https://github.com/iclemens/bose) — direct NC 700 BMAP and firmware-container reverse engineering.
- [bosefirmware/Bose-NC700](https://github.com/bosefirmware/Bose-NC700) — unchanged fork of the above.
- [bosefirmware/SaorCon-Win-BT-QC35-NC700](https://github.com/bosefirmware/SaorCon-Win-BT-QC35-NC700) — working Windows NC 700 control reference.
- [bosefirmware/OpenBose-Connect](https://github.com/bosefirmware/OpenBose-Connect) — Python/BlueZ protocol and interface reference.
- [bosefirmware/BoseConnect-Android_Basic-control](https://github.com/bosefirmware/BoseConnect-Android_Basic-control) — **QC35-specific** Kotlin Bluetooth reference.
- [bosefirmware/ced](https://github.com/bosefirmware/ced/tree/master/goodyear) — archived Goodyear NC 700 firmware and update manifests.
- [bosefirmware/bose-dfu](https://github.com/bosefirmware/bose-dfu) — firmware updater **incompatible with NC 700**.
- [bosefirmware/bosectl](https://github.com/bosefirmware/bosectl) — multi-language BMAP tooling (NC 700 catalogued, not yet supported/verified).

See the research dossier for evidence, detailed comparisons and branch audit.

**Current implementation:** reviewed C# and Kotlin read-only BMAP protocol cores; Windows SDP diagnostics and WPF desktop alpha; Android paired-device diagnostics and locally compiled debug APK; temporary three-band host EQ and app-owned WAV playback on both platforms. Native NC 700 control remains read-only and blocked until a live, correctly mapped transport is verified. Next: install and test the Android APK, complete audio-routing acceptance, collect an actual sanitized NC 700 AVDTP capture and identify the working BMAP control channel.

## GitHub Actions disabled — local tests only

All three GitHub Actions workflow files were removed from `master` and this active development branch. Historical branches may still contain them and must not be merged wholesale. **Do not add, trigger or consume GitHub Actions:** usage is exhausted. Build, lint, test and package locally under `D:\openBose` after running `scripts/workspace-env.ps1`; commit verified source and results to GitHub without CI. No project temp or cache files are permitted on `C:`.

## Local development and tests

In PowerShell, from `D:\openBose`, run `. .\scripts\workspace-env.ps1`, then `& .\scripts\run-offline-tests.ps1` for C#/Kotlin BMAP and host-EQ tests and the offline codec parser. For the Android alpha, use `& .\scripts\build-android-local.ps1` after the project-local JDK 17 and Android SDK have been bootstrapped. For the Windows alpha, use `& .\scripts\build-windows-desktop.ps1`. Both build scripts keep project caches and artifacts on D: and never run GitHub Actions. Hardware-dependent acceptance is separate; tests do not establish that native Bose controls or additional headphone codecs work.

## Branch workflow

- [`master`](https://github.com/aeiouofficial/openBose/tree/master) contains reviewed project documentation and validated code brought back through focused pull requests; it never receives a wholesale copy of the legacy code.
- [`reference/original-bose-code`](https://github.com/aeiouofficial/openBose/tree/reference/original-bose-code) preserves the complete original code, Wireshark script, firmware parser and project documentation at the pre-cleanup commit. Treat this as a **read-only reference**, not an integration branch.
- Bring back only an audited file or function into a feature branch, for example: `git restore --source reference/original-bose-code -- python/bose_proto.py`. Review and test before merging a focused pull request into `master`.
- **Do not merge the reference branch wholesale.** Start with the offline read-only BMAP parser as described in [the roadmap](docs/ROADMAP.md).

## Local workspace

**All** OpenBose project work, source checkouts, caches, diagnostic captures and temporary files belong under `D:\openBose`. Before running local build, capture or analysis commands in PowerShell, dot-source `. .\scripts\workspace-env.ps1` to redirect TEMP/TMP and tool-specific caches into `D:\openBose\.tmp`. Keep raw logs under the Git-ignored `captures/private/`; do not create a second checkout or a project scratch directory elsewhere.
