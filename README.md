# openBose

Android + Windows Bose NC 700 control app and research project investigating whether the headphones can support additional Bluetooth audio codecs (such as aptX or LDAC) beyond their reported AAC/SBC implementation.

**Status (2026-09-24): Android Kotlin and Windows .NET BMAP protocol test suites pass; the Windows read-only diagnostic successfully enumerates the actual paired NC700's SDP services. On this firmware/Windows pairing, channel 8 is **not advertised**, so live BMAP GET remains blocked pending transport identification. No headphone settings or firmware were modified and no additional codec has been activated.**

## Project documentation

- [Research dossier](docs/RESEARCH.md) — NC 700 chipset and BMAP protocol findings; identical `iclemens/bose` fork comparison; relevant Android/Windows/Linux projects; Goodyear firmware archive; DFU incompatibility; audited branches; confirmed facts versus unverified codec hypotheses.
- [Roadmap and acceptance gates](docs/ROADMAP.md) — read-only parser, cross-platform controls, temporary host-side EQ, offline firmware/codec feasibility and conditional activation testing.
- [Deep source audit](docs/DEEP_RESEARCH_2026-09-23.md) — hardware, related app repositories, archived Goodyear firmware and evidence gaps.
- [Android and Windows feasibility](docs/PLATFORM_FEASIBILITY.md) — platform architecture, permissions, transport and temporary audio processing.
- [Codec feasibility](docs/CODEC_FEASIBILITY.md) — aptX/aptX HD chip-vs-product evidence and required validation gates.
- [Capture procedure](docs/PROTOCOL_CAPTURE_PLAN.md) — privacy-conscious baseline and reproducible Android A2DP/BMAP capture.
- [Offline codec evidence tool](docs/AVDTP_OFFLINE_ANALYSIS.md) — parse one sanitized AVDTP SEP capability/configuration record (SBC, AAC, aptX, aptX HD, LDAC); synthetic test fixtures; **no device I/O**.
- [Live Windows RFCOMM findings](docs/WINDOWS_DIAGNOSTIC.md) — tested read-only CLI, paired-device WinRT fallback, actual SDP channel mapping and the channel-8 compatibility blocker.

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

**Current implementation:** reviewed Windows .NET BMAP parser and smoke tests; Kotlin BMAP module with equivalent allowlist and JUnit fixtures. These components are **offline protocol foundations**, not yet device-connected apps or a codec unlock. Next: add explicitly read-only RFCOMM transports, capture actual NC 700 A2DP advertisements, then implement the Android and Windows interfaces.

## Local development and tests

In PowerShell, from `D:\openBose`, run `& .\scripts\bootstrap-android.ps1` (downloads an official SHA-256-verified portable JDK 17 into `.tmp` only when missing), followed by `& .\scripts\run-offline-tests.ps1`. The second script checks the identical Kotlin/C# command allowlists and fixtures, runs the Windows .NET smoke tests and executes the Android Kotlin/JUnit suite with Gradle 8.13. The checked-in `android/gradlew.bat` can bootstrap Gradle under the project-local `.tmp` cache if a portable copy is not present. No actual headset communication occurs during these tests.

## Branch workflow

- [`master`](https://github.com/aeiouofficial/openBose/tree/master) contains reviewed project documentation and validated code brought back through focused pull requests; it never receives a wholesale copy of the legacy code.
- [`reference/original-bose-code`](https://github.com/aeiouofficial/openBose/tree/reference/original-bose-code) preserves the complete original code, Wireshark script, firmware parser and project documentation at the pre-cleanup commit. Treat this as a **read-only reference**, not an integration branch.
- Bring back only an audited file or function into a feature branch, for example: `git restore --source reference/original-bose-code -- python/bose_proto.py`. Review and test before merging a focused pull request into `master`.
- **Do not merge the reference branch wholesale.** Start with the offline read-only BMAP parser as described in [the roadmap](docs/ROADMAP.md).

## Local workspace

**All** OpenBose project work, source checkouts, caches, diagnostic captures and temporary files belong under `D:\openBose`. Before running local build, capture or analysis commands in PowerShell, dot-source `. .\scripts\workspace-env.ps1` to redirect TEMP/TMP and tool-specific caches into `D:\openBose\.tmp`. Keep raw logs under the Git-ignored `captures/private/`; do not create a second checkout or a project scratch directory elsewhere.
