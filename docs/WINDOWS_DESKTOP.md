# Windows WPF desktop shell

Status: **read-only alpha UI**, no firmware access and no native Bose settings writes. The NC 700's actual Windows SDP baseline lacks the older channel-8 BMAP endpoint, so the UI intentionally disables GETs unless an advertised channel-8 service is discovered.

Source: `windows/src/OpenBose.Desktop`, .NET 8 WPF. It links the reviewed WinRT RFCOMM read-only diagnostic implementation and `OpenBose.Protocol`; there is no raw-packet text input, hidden vendor-channel probe or firmware updater.

The UI lets the user refresh paired Bluetooth devices, select a Bose NC 700 candidate, inspect **published** SDP service UUIDs and parsed RFCOMM channels, and request one of seven allowlisted GETs if channel 8 is actually advertised. An error or missing channel leaves controls disabled. Codec Lab and native EQ are explicitly identified as **pending evidence**, not operational toggles.

Build on the authorized Windows machine **after** dot-sourcing `D:\openBose\scripts\workspace-env.ps1`:

    dotnet build D:\openBose\windows\src\OpenBose.Desktop\OpenBose.Desktop.csproj -c Release
    dotnet run --project D:\openBose\windows\src\OpenBose.Desktop\OpenBose.Desktop.csproj -c Release

The project-wide Directory.Build.props redirects intermediate/output directories under `D:\openBose\.tmp`. Never run the build without the strict D-only preflight. Actual GUI runtime, multiple-adapter reliability, screen-reader usability and headset acceptance remain separate release gates.
