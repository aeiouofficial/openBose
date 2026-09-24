# OpenBose storage policy: D: only

All **OpenBose-generated** source, output, downloads, builds, captures, caches, temporary files, toolchain copies, and Git worktrees must be inside `D:\openBose`. The project default scratch root is `D:\openBose\.tmp`.

## Mandatory PowerShell initialization

Run `. .\scripts\workspace-env.ps1` before any OpenBose build, analysis, Android/Windows tooling, capture, or repository command. The launcher creates project-local directories and redirects `TEMP`, `TMP`, `TMPDIR`, `HOME`, `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, Gradle, Android SDK, NuGet, .NET CLI, Java, pip, npm, Cargo/rustup, Python bytecode, and Git configuration. `assert-d-only.ps1` fails if a required output location escapes `D:\openBose`.

Any toolchain that cannot operate with these paths **must stop**, not fall back to a shared C: cache. The default project SDK/JDK and Gradle copies reside under `.tmp`; do not reinstall the same packages in the Windows user profile.

## Existing C: state and audit
The 2026-09-24 audit found no **positively identifiable OpenBose-named files** in top-level user TEMP, NuGet cache, or Gradle daemon directories. A content check of 1,332 shared .NET workload logs found no `openBose` reference. Earlier shared `C:\Users\BigBr\.gradle`, `.nuget`, `.cargo`, `.rustup`, and Windows TEMP contain other projects' pre-existing files. Those must not be moved/deleted under this repository's cleanup because it could break unrelated work. OpenBose uses project-local equivalents and does not create new data there.

Do not mistake an existing OS/application binary installed on C: (read-only dependency) or unrelated Windows-managed activity for an OpenBose build artifact. If stronger whole-PC storage isolation is required, use a dedicated VM or a user-managed system-wide migration rather than changing other projects' caches from OpenBose.

## Storage acceptance checks

1. Launch `scripts/workspace-env.ps1`, ensure `assert-d-only.ps1` prints PASS and `[IO.Path]::GetTempPath()` points at `D:\openBose\.tmp`.
2. Test a temporary override of `TEMP=C:\Temp`; the policy must reject it. Restore `TEMP` to `D:\openBose\.tmp` before any further command.
3. Use `scripts/run-offline-tests.ps1` only after initializing the workspace; compile and dependency output must stay on D:. Sensitive raw captures remain under `D:\openBose\captures\private` (Git-ignored).
4. Audit any new third-party tool's cache/home options before its first execution. Do not create additional workspaces outside `D:\openBose`.
