# OpenBose local release process

OpenBose deliberately uses **local release gates under `D:\openBose`**. GitHub Actions remain disabled and production signing credentials are not stored in the repository.

## Versioning

The repository root `VERSION` file is the release-version source of truth. Android reads it as `versionName`; Windows MSBuild uses it for `Version` and `InformationalVersion`. Android `versionCode` and Windows numeric assembly/file versions still need an intentional bump when the public version changes.

Current development version: **0.2.0-alpha**.

## One-command alpha bundle

Run from a **clean** checkout or worktree contained within `D:\openBose`:

```powershell
. .\scripts\workspace-env.ps1
& .\scripts\build-release-local.ps1 -RepositoryRoot D:\openBose
```

The release script fails closed if the worktree is dirty, if a GitHub Actions workflow is tracked, if the version is malformed, or if an expected artifact is absent. It executes:

1. shared BMAP policy/negative tests and the offline AVDTP parser tests;
2. Windows protocol, host-EQ DSP and codec-probe tests;
3. Windows WPF build and framework-dependent win-x64 packaging;
4. Android BMAP/audio tests, debug APK build, Android Lint and packaged-permission audit;
5. Windows and Android version/identity checks against `VERSION`;
6. SHA-256 calculation and a machine-readable release manifest.

Generated files remain under `<checkout>\.tmp\dist`:

- `openbose-windows-<version>.zip`
- `openbose-windows-codec-probe-<version>.zip`
- `android\openbose-android-<version>.apk`
- `release-manifest-<version>.json`
- `openbose-<version>-local-alpha-bundle.zip`

The manifest records the exact Git commit, file sizes/hashes and explicit unresolved manual gates. The bundle is **not** declared stable merely because all automated gates pass.

## Production signing

No signing key, keystore, certificate, password or token belongs in Git history or project documentation.

For a later production release:

- Android: create a user-owned release keystore outside the repository and pass it through a local, explicitly configured release-signing step. Never replace the checked debug artifact with a file called “release” unless signature verification and install/upgrade tests pass.
- Windows: use a user/organization-owned code-signing certificate in a dedicated packaging step. Verify the Authenticode signature after packaging and before publication.
- Record only certificate public metadata/fingerprint and artifact hashes in release evidence; never store private-key material.

## Manual hardware gates before stable

Automated source/build success cannot substitute for these:

- install the Android APK on a supported phone and exercise Bluetooth permission denial/revocation, rotation, foreground/background transitions, WAV playback, audio focus, disconnect/reconnect and host-EQ bypass;
- run the Windows WPF player against the NC 700, including default-device changes, Bluetooth disconnect/reconnect and host-EQ bypass;
- verify the Bose-stored EQ is unchanged after temporary host-EQ testing;
- identify the actual NC 700 control transport and obtain audited GET/readback before enabling persistent ANC/EQ writes;
- capture sanitized AVDTP sink capabilities and the selected codec on the actual headset/firmware;
- complete accessibility keyboard/screen-reader checks on Windows and TalkBack checks on Android;
- create and verify production-signed artifacts.

Until these are complete, OpenBose remains an **alpha/research build**, even if the local release bundle is reproducible.
