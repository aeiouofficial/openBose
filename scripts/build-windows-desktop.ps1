# Build and package the Windows read-only alpha using only D:\openBose.
param([string]$RepositoryRoot = 'D:\openBose', [switch]$SkipPackaging)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$prefix = 'D:\openBose\'
if (-not $root.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
    -not [string]::Equals($root.TrimEnd('\'), 'D:\openBose', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Only paths inside D:\openBose are permitted.'
}

$project = Join-Path $root 'windows\src\OpenBose.Desktop\OpenBose.Desktop.csproj'
$tests = Join-Path $root 'windows\tests\OpenBose.Protocol.SmokeTests\OpenBose.Protocol.SmokeTests.csproj'
$cli = Join-Path $root 'windows\src\OpenBose.Diagnostic\OpenBose.Diagnostic.csproj'
$audioTests = Join-Path $root 'windows\tests\OpenBose.Audio.SmokeTests\OpenBose.Audio.SmokeTests.csproj'
$codecProbe = Join-Path $root 'windows\src\OpenBose.CodecProbe\OpenBose.CodecProbe.csproj'
$codecTests = Join-Path $root 'windows\tests\OpenBose.CodecProbe.SmokeTests\OpenBose.CodecProbe.SmokeTests.csproj'

$versionFile = Join-Path $root 'VERSION'
if (-not (Test-Path -LiteralPath $versionFile)) { throw 'Missing repository VERSION file.' }
$version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Invalid release version: $version"
}

if (-not (Test-Path -LiteralPath $project)) { throw "Desktop project not found: $project" }
& (Join-Path $PSScriptRoot 'check-no-actions.ps1') -RepositoryRoot $root

Write-Output 'Building native Windows desktop with strict D-only environment...'
dotnet build $project -c Release --nologo
if ($LASTEXITCODE -ne 0) { throw 'Windows WPF build failed.' }
dotnet run --project $tests -c Release
if ($LASTEXITCODE -ne 0) { throw 'Windows protocol smoke tests failed.' }
dotnet run --project $audioTests -c Release
if ($LASTEXITCODE -ne 0) { throw 'Temporary host EQ safety smoke tests failed.' }
dotnet run --project $cli -c Release -- --help
if ($LASTEXITCODE -ne 0) { throw 'Read-only diagnostic CLI help smoke failed.' }
dotnet run --project $codecTests -c Release
if ($LASTEXITCODE -ne 0) { throw 'Windows A2DP codec parser smoke tests failed.' }
dotnet run --project $codecProbe -c Release -- --check
if ($LASTEXITCODE -ne 0) { throw 'Windows A2DP codec probe prerequisite check failed.' }

if (-not $SkipPackaging) {
    $dist = Join-Path $root '.tmp\dist\windows'
    $zip = Join-Path $root ('.tmp\dist\openbose-windows-' + $version + '.zip')
    if (Test-Path -LiteralPath $dist) { Remove-Item -LiteralPath $dist -Recurse -Force }
    New-Item -ItemType Directory -Path $dist -Force | Out-Null

    dotnet publish $project -c Release -r win-x64 --self-contained false --output $dist
    if ($LASTEXITCODE -ne 0) { throw 'Windows WPF publish failed.' }
    $desktopExe = Join-Path $dist 'OpenBose.Desktop.exe'
    if (-not (Test-Path -LiteralPath $desktopExe)) { throw 'Published desktop executable missing.' }
    $productVersion = (Get-Item -LiteralPath $desktopExe).VersionInfo.ProductVersion
    if ([string]::IsNullOrWhiteSpace($productVersion) -or
        -not $productVersion.StartsWith($version, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Windows product version mismatch: expected $version, got $productVersion"
    }

    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $dist '*') -DestinationPath $zip -CompressionLevel Optimal
    Write-Output ('LOCAL_ALPHA_ZIP=' + $zip)
    Write-Output ('SHA256=' + (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash)

    $codecDist = Join-Path $root '.tmp\dist\windows-codec-probe'
    $codecZip = Join-Path $root ('.tmp\dist\openbose-windows-codec-probe-' + $version + '.zip')
    if (Test-Path -LiteralPath $codecDist) { Remove-Item -LiteralPath $codecDist -Recurse -Force }
    New-Item -ItemType Directory -Path $codecDist -Force | Out-Null

    dotnet publish $codecProbe -c Release -r win-x64 --self-contained false --output $codecDist
    if ($LASTEXITCODE -ne 0) { throw 'Windows A2DP codec probe publish failed.' }
    $codecExe = Join-Path $codecDist 'OpenBose.CodecProbe.exe'
    if (-not (Test-Path -LiteralPath $codecExe)) { throw 'Published codec probe executable missing.' }
    $codecProductVersion = (Get-Item -LiteralPath $codecExe).VersionInfo.ProductVersion
    if ([string]::IsNullOrWhiteSpace($codecProductVersion) -or
        -not $codecProductVersion.StartsWith($version, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Codec-probe product version mismatch: expected $version, got $codecProductVersion"
    }

    if (Test-Path -LiteralPath $codecZip) { Remove-Item -LiteralPath $codecZip -Force }
    Compress-Archive -Path (Join-Path $codecDist '*') -DestinationPath $codecZip -CompressionLevel Optimal
    Write-Output ('LOCAL_CODEC_PROBE_ZIP=' + $codecZip)
    Write-Output ('CODEC_PROBE_SHA256=' + (Get-FileHash -LiteralPath $codecZip -Algorithm SHA256).Hash)
}

Write-Output 'Windows desktop / protocol / host-EQ / A2DP codec-probe local gates PASS. Live ETW and hardware acceptance remain pending.'
