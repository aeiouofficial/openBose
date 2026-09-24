# OpenBose — roadmap and acceptance gates

Date: 2026-09-23. Target: **Bose NC 700**, Android and Windows. [Research and provenance](RESEARCH.md) is the technical source of truth.

## Product requirements

1. Implement useful official Bose controls with audited NC 700 commands: status, battery, ANC, EQ, voice prompts, pairing/source management where supported.
2. Build Android and Windows clients around an isolated, testable BMAP protocol core; prevent accidentally sending incompatible QC35 commands to an NC 700.
3. Support a separately identified **temporary host-side EQ** experiment. When bypassed/closed, it no longer processes audio and **must not** change headphone-stored EQ. Platform coverage must be demonstrated; don't promise third-party app/system-wide audio interception on Android.
4. Investigate actual **headphone-side** aptX, aptX HD, LDAC and other better-codec feasibility. Any new codec must be advertised by the headphones and decode actual audio; source-side encoding alone is insufficient.
5. Keep firmware experimentation outside the control-app MVP. No implicit flashing, forced downgrade, blind opcode probing or claim of zero bricking risk.

## Phase 0 — source audit [done for named repositories]

- [x] Inspect iclemens/bose; verify bosefirmware/Bose-NC700 fork has identical commit/tree and only listed master branch.
- [x] Audit directly related Linux, Android and Windows BMAP app implementations.
- [x] Verify Goodyear firmware archive, index manifest, and bose-dfu's explicit NC 700 incompatibility.
- [x] Check listed branches for the named key research repos.
- [ ] Identify and audit the original repo's other advertised fork if GitHub exposes it.
- [~] Establish sanitized **actual-device** baseline: Windows paired-state/SDP enumeration captured and redacted; hardware product/firmware GET, Android AVDTP capture and firmware dump still pending.

**Gate P0:** research dossier versioned, sources linked, assumptions labeled, read-only first.

## Phase 1 — safe protocol core (in progress; offline foundation tested)

**Completed:** C# and Kotlin BMAP packet parsers and fragmented decoders, matching seven-command read-only allowlists, shared fixtures, Windows .NET smoke tests and Android Kotlin/JUnit tests. Windows read-only CLI, RFCOMM SDP decoder and paired-device WinRT fallback are implemented. **Hardware discovery confirmed no advertised channel 8** on the connected NC700; both WinRT and legacy channel-8 GET attempts failed before a BMAP packet could be sent. No headphone configuration was changed. **Still pending:** authenticated device-specific transport mapping, real BMAP GET/readback, Android AVDTP capture, and more complete cancellation/reconnect tests. See [Windows diagnostic](WINDOWS_DIAGNOSTIC.md).

- Implement strict BMAP framing, partial response reassembly, bounded timeouts, unsolicited events, disconnect/reconnect and packet-length validation.
- Add Android Bluetooth and Windows RFCOMM channel-8 adapters (maintain distinct transports from BMAP parser); use SaorCon's real Windows behavior as a regression fixture.
- Implement GET-only real-device discovery: product identity, firmware version, battery, ANC and EQ reads. Test product/firmware-specific differences.
- Enforce a read-only policy at the **transport boundary**: deny SET, SETGET, START and all firmware-update function blocks for research sessions.
- Tests: normal framing, fragmented/multi-packet, invalid length, unsupported operation, unexpected response, reconnect, timeout and platform codec-capability parsing.
- Correct original script bugs offline; do not execute unreviewed USB startup/reset routines on user hardware.

**Gate P1:** automated tests pass and a live device responds to audited GET commands; zero headphone configuration/firmware writes; logs redact MAC and serial.

## Phase 2 — cross-platform settings and temporary EQ (not started)

- Native Android device discovery/status, audited settings and EQ for **app-owned playback** initially.
- Windows RFCOMM controls plus app-owned playback EQ initially; system-wide EQ requires an independently designed/integrated audio layer.
- Explicit modes: **read-only research**, **temporary host audio**, **confirmed persistent headphone settings**. Never imply that leaving the app running makes a headphone command ephemeral.
- Only enable individually verified NC 700 settings writes; record old value before each user-initiated change and verify device readback.
- No codec selector shown as functional unless A2DP sink and host confirm mutual support.
- All paths handle app crash, disconnect, simultaneous Bose official app connections and Bluetooth reconnection.

**Gate P2:** Android/Windows real-device acceptance tests, verified persistence classification, host EQ bypass A/B comparison, headphone-stored EQ unchanged by temporary mode.

## Phase 3 — codec evidence, offline first (offline analyzer added; device capture pending)

**New foundation:** a standard-library Python decoder and synthetic unit tests identify SBC, AAC, aptX, aptX HD and LDAC from the AVDTP Media Codec service category for **one manually identified SEP**. It rejects truncated TLVs and unknown vendor interpretations, and never accesses headphones or writes capture files. GitHub source is staged for local tests; no actual AVDTP packet has been captured yet. See [offline analysis](AVDTP_OFFLINE_ANALYSIS.md).

1. Collect actual A2DP sink SEP advertisements/negotiation on Android and Windows, with firmware and Bluetooth adapter versions.
2. Fetch archival Goodyear images into an isolated offline research workspace; check size/CRC against index, split container, inspect architecture, encryption and signature structure.
3. Reproducibly find actual decoder symbols, modules, configuration and licensing/build flags, if accessible. Cross-check Qualcomm documentation.
4. Look for a device-specific dormant-codec enablement interface with **read-only discovery**, never a live blind opcode sweep.
5. Publish a per-codec evidence table: actual decoder, A2DP advertisement, connection negotiation, playback result, persistence after app exit/power cycle, rollback route.

**Gate P3:** documented reproducible codec activation test path OR explicit blocked/unverified conclusion. Better EQ cannot satisfy codec gate.

## Phase 4 — conditional activation experiment (blocked on Phase 3)

- If dormant codec and reversible activation are **proven**, test on a recoverable device with explicit user approval and capture before/after advertisements + audio.
- If decoder must be installed, separate firmware engineering project: compatible DSP binary, memory map, authentication/signing, verified loader, ephemeral-state proof, power-loss handling and recovery procedure.
- **Do not** test an unproven flashing/loader path on the user's only NC 700.
- Validate reset, power-cycle, multipoint, stable AAC/SBC fallback, Windows/Android reconnection and full rollback before considering an installable update feature.

**Gate P4:** headphone advertises codec, host negotiates it and headphone audibly decodes it; rollback demonstrated. Otherwise feature remains experimental/blocked.

## Phase 5 — release readiness (not started)

- Automated parser and platform tests, HCI/BMAP capture fixtures, permission gates, crash recovery, manual device matrix, package/signing and traceable README/release notes.
- Structured logs: trace/correlation ID, operation, location, device model/firmware, result, impact, cause/exception, fallback/follow-up and Info/Warning/Critical. Default privacy: redacted MACs/serials and never record private audio.
- Separate deliverables and claims for (a) Bose control, (b) host temporary EQ, and (c) independently verified new Bluetooth codec support.

## Open blockers

- No actual NC 700 codec advertisement or HCI baseline captured.
- No proven NC 700 aptX/LDAC decoder activation command, RAM loader or custom firmware recovery method.
- Generic bose-dfu **excludes** NC 700; iclemens' alternative updater is only partially documented.
- Android and Windows implementation, actual-device tests, offline firmware binary analysis and second-fork inspection still pending.

## Next work item

Capture a **sanitized Android HCI/AVDTP trace** for the actual NC 700 and its current firmware; manually extract each audio sink SEP's service-capability TLVs plus the actual SetConfiguration. Validate them with the project-local offline decoder and correlate with actual AAC playback. Continue the Android read-only UI and Windows transport identification independently. No speculative BMAP traffic on unverified Windows vendor RFCOMM channels.
