# Windows temporary host EQ — app-owned WAV preview

**Status:** host equalizer and Windows WAV player are under local implementation
and test. No Bose headphone settings are written, no codec is installed, and
OpenBose does not intercept system-wide audio.

## Operation

Open the Windows desktop app, choose a WAV file **inside D:\openBose** and
press Play. Output goes to the Windows default playback device, which the user
must select in Windows Sound Settings if they want the NC 700. Changing the
source device or A2DP codec is not part of OpenBose's host EQ.

The three sliders control app-owned peaking filters at about 100 Hz, 1 kHz and
8 kHz (the last band is reduced at low sampling rates). Each band is limited
to -10 through +10 dB. Enable host EQ and click Apply to change the processing
of **this player only**. Unchecking the box and clicking Apply bypasses the
DSP. Stop, file changes and app shutdown release the player and its DSP
state without changing the Bose-stored three-band EQ.

For the initial preview, only .wav files within the project workspace are
accepted. Streaming other apps, MP3, streaming services, recording/microphone
input and system-wide EQ are intentionally excluded.

## Implementation and safety

- Pure managed .NET 8 DSP in `windows/src/OpenBose.Audio`, with one independent
  filter state per channel, continuous interleaved-stream fragment tracking,
  a bit-exact disabled path and strict range/sample-format validation.
- NAudio is used only for reading the selected WAV and playing its filtered
  samples through Windows' default output. The DSP is independent of NAudio.
- The highest positive band gain is pre-compensated as playback headroom.
  The output is clamped to [-1,1] for finite PCM; heavy multi-band boosts
  can still cause distortion and are not a mastering limiter.
- No Bluetooth RFCOMM or BMAP operation is initiated by playing a WAV.
  The normal Bose read-only channel-8 capability guard remains in place.
- All generated package caches, build intermediates and local ZIP artifacts
  remain under `D:\openBose\.tmp`. **GitHub Actions must not be used**;
  the workflow files were removed from master.

## Local-only gates

From PowerShell, initialize `scripts/workspace-env.ps1` and run:

    dotnet run --project windows/tests/OpenBose.Audio.SmokeTests -c Release
    dotnet run --project windows/tests/OpenBose.Protocol.SmokeTests -c Release
    dotnet build windows/src/OpenBose.Desktop -c Release
    & .\scripts\build-windows-desktop.ps1

The DSP test covers exact bypass, frequency response, stereo separation,
partial-buffer handling, invalid settings and finite bounded output.
The executable still requires **manual** testing with a project-local WAV
at 44.1/48 kHz, playback controls, Bluetooth disconnect/reconnect, host-EQ
bypass and verification that headphone EQ is unchanged.

Do not publish a stable user release until device-level audio and UI
acceptance gates are completed and the headphone control channel is verified.
