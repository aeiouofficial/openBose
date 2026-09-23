# NC 700 baseline from user-supplied Android screenshots (2026-09-23)

**Evidence source:** conversation attachments `1000015808.jpg` (Bose Music home screen) and `1000015807.mp4` (Redmi Note 10 5G Developer Options screen recording). This is visual, user-supplied evidence, **not** a packet capture, Bluetooth service discovery or firmware interrogation. The original attachments remain in the conversation; no raw device identifiers are committed.

## Directly visible observations

| Observation | Visible value | What it does not establish |
| --- | --- | --- |
| Bose Music device card | `Bose NC 700 HP` | Product firmware revision or hardware revision |
| Bose Music battery estimate | `100%` | Independently polled battery level |
| Playback source | `Redmi Note 10 5G` | Host audio file format or sample quality |
| Audio title/source card | `Untitled audio` | Access to original audio file or bit-perfect playback |
| Android Developer Options current codec | `AAC`, `Streaming: AAC` | Full AVDTP sink capability listing |
| Current Android audio sample rate | `44.1 kHz` | Alternative sample-rate support |
| Current Android bit depth / channels | `16 bits/sample`, `Stereo` | High-resolution output, DAC performance |
| Android codec dropdown | aptX, aptX HD, LDAC, aptX Adaptive and LHDC options appear | **These entries represent Android options, not proof that NC 700 advertises/accepts those codecs** |

## Interpretation

The phone is visibly streaming AAC to the connected NC 700 during the recording. The Bose app device card confirms a functioning connection and a phone-origin playback source. **No successful aptX/HD, LDAC or LHDC negotiation is shown.** The screen-recorder notification about recording internal sound must not be mistaken for a Bluetooth codec failure message.

These attachments can be used as UI and current-state references when testing OpenBose against the official app. A definitive codec audit still requires A2DP GetCapabilities and SetConfiguration from a sanitized HCI capture; see [the capture plan](PROTOCOL_CAPTURE_PLAN.md).

## Additional baseline still needed

- Device firmware string, confirmed NC 700 product ID, stored EQ values, ANC value and MAC-redacted BMAP response sequence.
- Actual A2DP sink SEP advertisements; capture while reconnecting and starting AAC playback.
- Windows-side paired headset service and RFCOMM read-only response.
- The original test audio file, only if the user decides to share it. No need to upload unrelated private audio.
