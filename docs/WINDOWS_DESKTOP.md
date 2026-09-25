# Windows WPF desktop shell

Status: **read-only Bose diagnostics and app-owned host-EQ preview**, no firmware access and no native Bose settings writes. The temporary WAV player and EQ affect only audio decoded inside OpenBose; set NC 700 as the Windows default playback device manually. The NC 700's actual Windows SDP baseline lacks the older channel-8 BMAP endpoint, so the UI intentionally disables GETs unless an advertised channel-8 service is discovered.

Source: `windows/src/OpenBose.Desktop`, .NET 8 WPF. It links the reviewed WinRT RFCOMM read-only diagnostic implementation and `OpenBose.Protocol`; there is no raw-packet text input, hidden vendor-channel probe or firmware updater.

The UI lets the user refresh paired Bluetooth devices, select a Bose NC 700 candidate, inspect **published** SDP service UUIDs and parsed RFCOMM channels, and request one of seven allowlisted GETs if channel 8 is actually advertised. An error or missing channel leaves controls disabled. Codec Lab and native EQ are explicitly identified as **pending evidence**, not operational toggles.

The reproducible D-only pipeline is `& .\scripts\build-windows-desktop.ps1` on the local laptop after initializing the workspace. It compiles WPF, runs .NET protocol smoke tests, verifies CLI help, and publishes a framework-dependent win-x64 alpha ZIP under `D:\openBose\.tmp\dist`. A separate Windows GitHub Actions workflow builds the same ZIP on an ephemeral runner and attaches it as a workflow artifact. Neither build verifies the GUI against a real NC700 control channel.

Build on the authorized Windows machine **after** dot-sourcing `D:\openBose\scripts\workspace-env.ps1`:

    dotnet build D:\openBose\windows\src\OpenBose.Desktop\OpenBose.Desktop.csproj -c Release
    dotnet run --project D:\openBose\windows\src\OpenBose.Desktop\OpenBose.Desktop.csproj -c Release

The project-wide Directory.Build.props redirects intermediate/output directories under `D:\openBose\.tmp`. Never run the build without the strict D-only preflight. Actual GUI runtime, multiple-adapter reliability, screen-reader usability and headset acceptance remain separate release gates.
