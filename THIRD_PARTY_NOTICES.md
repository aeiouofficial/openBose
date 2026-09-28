# Third-party notices

OpenBose uses the following third-party libraries in locally built Windows
artifacts. Their upstream licenses remain controlling.

## Microsoft.Diagnostics.Tracing.TraceEvent

- Package: `Microsoft.Diagnostics.Tracing.TraceEvent` 3.2.6
- Project: https://github.com/microsoft/perfview
- License: MIT
- Copyright: .NET Foundation and Contributors

The package is used by the optional Windows A2DP ETW codec observer. OpenBose
does not redistribute or claim authorship of the upstream implementation.

## NAudio

- Package: `NAudio` 2.2.1
- Project: https://github.com/naudio/NAudio
- License: MIT

NAudio is used only by the Windows app-owned WAV playback path. The OpenBose
host EQ itself remains a separate managed DSP implementation.

## Research references, not vendored code

The Windows A2DP ETW provider GUID/event-field names were independently
cross-checked against public MIT-licensed codec-inspector projects:

- https://github.com/yossyl3oy/rust-btcodec-inspector
- https://github.com/imbushuo/BluetoothAudioCodecInspector
- https://github.com/A-BenLi06/Bluetooth-Audio-Codec-Viewer-WinUI3

OpenBose does not vendor those applications.
