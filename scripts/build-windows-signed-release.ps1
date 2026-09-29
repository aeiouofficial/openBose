# Optional production Windows Authenticode signing gate. Requires user-owned secrets/tools under D:\openBose.
param([string]$RepositoryRoot = 'D:\openBose')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not ($root.Equals('D:\openBose', [StringComparison]::OrdinalIgnoreCase) -or
          $root.StartsWith('D:\openBose\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Release root must stay inside D:\openBose.'
}
& (Join-Path $root 'scripts\check-no-actions.ps1') -RepositoryRoot $root
& (Join-Path $root 'scripts\check-release-metadata.ps1') -RepositoryRoot $root

$dirty = @(& git -C $root status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git worktree state.' }
if ($dirty.Count -ne 0) { throw 'Signed release requires a clean Git worktree.' }

$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$pfxRaw = [Environment]::GetEnvironmentVariable('OPENBOSE_WINDOWS_PFX')
$pfxPassword = [Environment]::GetEnvironmentVariable('OPENBOSE_WINDOWS_PFX_PASSWORD')
$signtoolRaw = [Environment]::GetEnvironmentVariable('OPENBOSE_SIGNTOOL')
$timestampUrl = [Environment]::GetEnvironmentVariable('OPENBOSE_WINDOWS_TIMESTAMP_URL')
if ([string]::IsNullOrWhiteSpace($timestampUrl)) {
    $timestampUrl = 'http://timestamp.digicert.com'
}
if ([string]::IsNullOrWhiteSpace($pfxRaw) -or
    [string]::IsNullOrWhiteSpace($pfxPassword) -or
    [string]::IsNullOrWhiteSpace($signtoolRaw)) {
    throw 'Set OPENBOSE_WINDOWS_PFX, OPENBOSE_WINDOWS_PFX_PASSWORD and OPENBOSE_SIGNTOOL.'
}
if ($timestampUrl -notmatch '^https?://') { throw 'Timestamp URL must use HTTP or HTTPS.' }

$pfx = [IO.Path]::GetFullPath($pfxRaw)
$secretRoot = 'D:\openBose\.secrets\'
if (-not $pfx.StartsWith($secretRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Windows signing PFX must stay under D:\openBose\.secrets\.'
}
if (-not (Test-Path -LiteralPath $pfx)) { throw 'Windows signing PFX file not found.' }

$signtool = [IO.Path]::GetFullPath($signtoolRaw)
$toolRoot = 'D:\openBose\.tmp\tools\'
if (-not $signtool.StartsWith($toolRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'signtool.exe must run from D:\openBose\.tmp\tools\.'
}
if (-not (Test-Path -LiteralPath $signtool)) { throw 'D-only signtool.exe not found.' }

& (Join-Path $root 'scripts\build-windows-desktop.ps1') -RepositoryRoot $root

$dist = Join-Path $root '.tmp\dist'
$unsignedDesktop = Join-Path $dist 'windows'
$unsignedProbe = Join-Path $dist 'windows-codec-probe'
foreach ($dir in @($unsignedDesktop,$unsignedProbe)) {
    if (-not (Test-Path -LiteralPath $dir)) { throw "Unsigned Windows publish directory missing: $dir" }
}

$signedDesktop = Join-Path $dist 'windows-signed'
$signedProbe = Join-Path $dist 'windows-codec-probe-signed'
foreach ($pair in @(@($unsignedDesktop,$signedDesktop),@($unsignedProbe,$signedProbe))) {
    if (Test-Path -LiteralPath $pair[1]) { Remove-Item -LiteralPath $pair[1] -Recurse -Force }
    New-Item -ItemType Directory -Path $pair[1] -Force | Out-Null
    Copy-Item -Path (Join-Path $pair[0] '*') -Destination $pair[1] -Recurse -Force
}

$signTargets = @(
    Get-ChildItem -LiteralPath $signedDesktop -File | Where-Object {
        $_.Name -like 'OpenBose.*.exe' -or $_.Name -like 'OpenBose.*.dll'
    }
    Get-ChildItem -LiteralPath $signedProbe -File | Where-Object {
        $_.Name -like 'OpenBose.*.exe' -or $_.Name -like 'OpenBose.*.dll'
    }
)
if ($signTargets.Count -lt 2) { throw 'No OpenBose-owned Windows binaries found to sign.' }

foreach ($file in $signTargets) {
    & $signtool sign /fd SHA256 /f $pfx /p $pfxPassword /tr $timestampUrl /td SHA256 $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "Authenticode signing failed: $($file.Name)" }
    & $signtool verify /pa /all /v $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "Authenticode verification failed: $($file.Name)" }
}

$signedDesktopZip = Join-Path $dist ('openbose-windows-' + $version + '-signed.zip')
$signedProbeZip = Join-Path $dist ('openbose-windows-codec-probe-' + $version + '-signed.zip')
foreach ($zip in @($signedDesktopZip,$signedProbeZip)) {
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
}
Compress-Archive -Path (Join-Path $signedDesktop '*') -DestinationPath $signedDesktopZip -CompressionLevel Optimal
Compress-Archive -Path (Join-Path $signedProbe '*') -DestinationPath $signedProbeZip -CompressionLevel Optimal

Write-Output ('SIGNED_WINDOWS_ZIP=' + $signedDesktopZip)
Write-Output ('SIGNED_WINDOWS_SHA256=' + (Get-FileHash -LiteralPath $signedDesktopZip -Algorithm SHA256).Hash)
Write-Output ('SIGNED_CODEC_PROBE_ZIP=' + $signedProbeZip)
Write-Output ('SIGNED_CODEC_PROBE_SHA256=' + (Get-FileHash -LiteralPath $signedProbeZip -Algorithm SHA256).Hash)
Write-Output 'PASS: project-owned Windows binaries are timestamped and Authenticode verification passed.'
Write-Output 'Manual install/runtime/hardware acceptance is still required before publication.'
