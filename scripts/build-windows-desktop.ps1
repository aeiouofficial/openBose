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
    $zip = Join-Path $root '.tmp\dist\openbose-windows-readonly-alpha.zip'
    if (Test-Path -LiteralPath $dist) { Remove-Item -LiteralPath $dist -Recurse -Force }
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    dotnet publish $project -c Release -r win-x64 --self-contained false --output $dist
    if ($LASTEXITCODE -ne 0) { throw 'Windows WPF publish failed.' }
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $dist '*') -DestinationPath $zip -CompressionLevel Optimal
    Write-Output ('LOCAL_ALPHA_ZIP=' + $zip)
    Write-Output ('SHA256=' + (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash)
    $codecDist = Join-Path $root '.tmp\dist\windows-codec-probe'
    $codecZip = Join-Path $root '.tmp\dist\openbose-windows-codec-probe-alpha.zip'
    if (Test-Path -LiteralPath $codecDist) { Remove-Item -LiteralPath $codecDist -Recurse -Force }
    New-Item -ItemType Directory -Path $codecDist -Force | Out-Null
    dotnet publish $codecProbe -c Release -r win-x64 --self-contained false --output $codecDist
    if ($LASTEXITCODE -ne 0) { throw 'Windows A2DP codec probe publish failed.' }
    if (Test-Path -LiteralPath $codecZip) { Remove-Item -LiteralPath $codecZip -Force }
    Compress-Archive -Path (Join-Path $codecDist '*') -DestinationPath $codecZip -CompressionLevel Optimal
    Write-Output ('LOCAL_CODEC_PROBE_ZIP=' + $codecZip)
    Write-Output ('CODEC_PROBE_SHA256=' + (Get-FileHash -LiteralPath $codecZip -Algorithm SHA256).Hash)
}
Write-Output 'Windows desktop / protocol / host-EQ / A2DP codec-probe local gates PASS. Live ETW and hardware acceptance remain pending.'
