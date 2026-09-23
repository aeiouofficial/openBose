# OpenBose — NC 700 higher-codec feasibility ledger (2026-09-23)

This file separates **hardware platform capability**, **Bose product configuration**, **host encoding**, and **real measured A2DP link behavior**. At the time of writing no NC 700 live capture has been taken and no extra codec has been enabled.

## Evidence already available

- [iclemens/bose](https://github.com/iclemens/bose) and [a 52audio teardown](https://www.52audio.com/archives/31642.html) identify a **Qualcomm CSRA68105** inside NC 700; actual physical revision still needs verification on the unit.
- [Qualcomm CSRA68105 product documentation](https://www.qualcomm.com/audio/products/csra68105) identifies Bluetooth 5.0, **two 240 MHz Kalimba DSPs**, a 120 MHz OEM processor, ROM functions and DSP capabilities loadable from **RAM/QSPI** at the *chip platform* level.
- [Qualcomm's product comparison](https://www.qualcomm.com/audio/applications/bluetooth-wireless-speakers/product-list) contains the 2×240 MHz Bluetooth 5.0 audio SoC family with aptX Audio and aptX HD in the product options. This supports the hypothesis that the silicon family **can** offer aptX/HD; it does not establish that Bose's firmware has enabled or licensed them.
- Third-party NC 700 specifications list **SBC and AAC** as the shipping A2DP codecs: https://www.soundguys.com/bose-noise-cancelling-headphones-700-24897/ . Treat this as product-level reporting pending the actual headset's advertisement capture.
- [Goodyear archive](https://github.com/bosefirmware/ced/tree/master/goodyear) has eight encrypted-named .bin images plus a version/CRC/length index. No verified decryption, firmware signing key, editable codec configuration or safe custom-loader procedure has been found.
- [iclemens firmware prototype](https://github.com/iclemens/bose/tree/master/firmware) unpacks partition records and documents an update transport. It is not a general-purpose firmware writer, decoder installer or proven recovery tool.
- [bose-dfu explicitly excludes the NC 700](https://github.com/bosefirmware/bose-dfu/blob/main/README.md); don't route NC 700 through its incompatible updater to try installing codecs.

## Questions, evidence required, decision state

| Question | What would establish it | Current state |
| --- | --- | --- |
| What codecs are advertised now? | AVDTP sink SEP discovery and capabilities, complete with firmware revision | **UNMEASURED** |
| Does actual Bose firmware contain aptX decoder? | Plaintext firmware/ROM evidence, trusted symbol/config mapping or observed live aptX negotiation | **UNVERIFIED** |
| Is aptX HD available in Bose build? | Distinct aptX HD codec data and advertised A2DP profile | **UNVERIFIED** |
| Is LDAC available? | Independent Bose firmware decoder/support evidence plus advertisement | **NO EVIDENCE FOUND** |
| Can a normal BMAP command toggle codecs? | NC 700-specific documented request, response, capabilities change and post-reconnect result | **NO VERIFIED COMMAND** |
| Can a codec be installed only into RAM? | Documented user-accessible loader, valid compatible binary, authentication and rollback proof | **NO VERIFIED PATH** |
| Can the stock headphones recover after a bad patch? | Reproducible NC 700-specific recovery on a sacrificial test unit | **NOT DEMONSTRATED** |
## Feasibility branches

**A. Dormant codec already installed:** Confirm decoder and AVDTP settings offline, derive a *documented* and reversible enablement operation if it exists, then capture changed advertisement and actual aptX/HD playback. Never treat an on-screen toggle as success.

**B. Codec missing but installable:** Requires an architecture-matched DSP executable and dependencies, memory/CPU budget alongside ANC, access to ROM/QSPI interfaces, a loader and any required authentication/signature. Qualcomm documenting downloadable capabilities does **not** mean owners can send arbitrary code to Bose's device.

**C. Firmware patch required:** Dedicated lab project, not the consumer controls app. Verify image authenticity, partition maps, signature handling, device-specific fail-safe and rescue procedure *before* any hardware flash. Risk includes non-recoverable hardware failure.

**D. Host-only workaround:** Software EQ improves tonal response, but has no effect on the codec accepted by the headphones. Optional Android/Windows software encoding higher than the headphones' advertised decoders cannot complete an A2DP connection.

## Most actionable initial experiment

1. Generate the [read-only baseline and HCI capture](PROTOCOL_CAPTURE_PLAN.md), with AAC/SBC as control runs.
2. Confirm the 0x4024 product/firmware identity before reading any device-dependent BMAP functions.
3. Parse the known-good Goodyear *container only* offline; verify each file length/CRC against index. Note the original unpacker is not a decryptor.
4. Investigate available public Qualcomm ADK/chip documentation for decoder configuration and privileges **without** modifying firmware. Do not assume the NC 700 accepts general DSP uploads.
5. Issue a per-codec verdict only after headset advertised codec, source selected it, headphone decoded audio and fallback/reconnection tests succeeded.

**Guardrail:** An NC 700-specific unknown BMAP write, direct DSP loader, USB reset or OTA command is never triggered by starting OpenBose. Advanced investigation must be separately staged with verified recovery and explicit user approval.
