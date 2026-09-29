# Build all locally verifiable OpenBose alpha deliverables from one clean commit.
param([string]$RepositoryRoot = 'D:\openBose')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not ($root.Equals('D:\openBose', [StringComparison]::OrdinalIgnoreCase) -or
          $root.StartsWith('D:\openBose\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Release root must stay inside D:\openBose.'
}
$versionFile = Join-Path $root 'VERSION'
if (-not (Test-Path -LiteralPath $versionFile)) { throw 'Missing VERSION file.' }
$version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Invalid VERSION value: $version"
}

$dirty = @(& git -C $root status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git worktree state.' }
if ($dirty.Count -ne 0) {
    throw ('Release build requires a clean worktree. Dirty entries: ' + ($dirty -join '; '))
}
$commit = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw 'Could not resolve exact Git commit.'
}

& (Join-Path $root 'scripts\check-no-actions.ps1') -RepositoryRoot $root
& (Join-Path $root 'scripts\check-release-metadata.ps1') -RepositoryRoot $root
& (Join-Path $root 'scripts\run-offline-tests.ps1')
& (Join-Path $root 'scripts\build-windows-desktop.ps1') -RepositoryRoot $root
& (Join-Path $root 'scripts\build-android-local.ps1') -RepositoryRoot $root

$dist = Join-Path $root '.tmp\dist'
$windowsZip = Join-Path $dist ('openbose-windows-' + $version + '.zip')
$codecZip = Join-Path $dist ('openbose-windows-codec-probe-' + $version + '.zip')
$androidApk = Join-Path $dist ('android\openbose-android-' + $version + '.apk')
$required = @($windowsZip, $codecZip, $androidApk)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Release artifact missing: $path" }
}

$artifacts = @()
$distPrefix = $dist.TrimEnd('\') + '\'
foreach ($path in $required) {
    $item = Get-Item -LiteralPath $path
    if (-not $item.FullName.StartsWith($distPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Artifact escaped release directory: $($item.FullName)"
    }
    $artifacts += [ordered]@{
        file = $item.Name
        relativePath = $item.FullName.Substring($distPrefix.Length)
        bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    project = 'OpenBose'
    version = $version
    channel = 'alpha-local'
    gitCommit = $commit
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    productionSigned = $false
    hardwareAcceptanceComplete = $false
    codecUnlockVerified = $false
    sourceWorktreeClean = $true
    artifacts = $artifacts
    remainingManualGates = @(
        'Android real-device UI/audio/permission/reconnect acceptance',
        'Windows NC700 real-device host-EQ and reconnect acceptance',
        'Actual NC700 control transport GET/readback mapping',
        'Sanitized AVDTP sink capability and negotiated-codec evidence',
        'User-owned production signing credentials'
    )
}
$manifestPath = Join-Path $dist ('release-manifest-' + $version + '.json')
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$bundle = Join-Path $dist ('openbose-' + $version + '-local-alpha-bundle.zip')
if (Test-Path -LiteralPath $bundle) { Remove-Item -LiteralPath $bundle -Force }
$bundleStage = Join-Path $dist ('bundle-' + $version)
if (Test-Path -LiteralPath $bundleStage) { Remove-Item -LiteralPath $bundleStage -Recurse -Force }
New-Item -ItemType Directory -Path $bundleStage -Force | Out-Null
Copy-Item -LiteralPath $windowsZip,$codecZip,$androidApk,$manifestPath -Destination $bundleStage -Force
Compress-Archive -Path (Join-Path $bundleStage '*') -DestinationPath $bundle -CompressionLevel Optimal
Remove-Item -LiteralPath $bundleStage -Recurse -Force

Write-Output ('RELEASE_VERSION=' + $version)
Write-Output ('RELEASE_COMMIT=' + $commit)
Write-Output ('RELEASE_MANIFEST=' + $manifestPath)
Write-Output ('RELEASE_BUNDLE=' + $bundle)
Write-Output ('RELEASE_BUNDLE_SHA256=' + (Get-FileHash -LiteralPath $bundle -Algorithm SHA256).Hash)
Write-Output 'PASS: all automatable local alpha gates and reproducible artifact checks completed.'
Write-Output 'NOT A STABLE RELEASE: manual hardware acceptance, codec evidence and production signing remain required.'
