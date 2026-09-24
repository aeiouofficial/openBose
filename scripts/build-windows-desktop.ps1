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
if (-not (Test-Path -LiteralPath $project)) { throw "Desktop project not found: $project" }
Write-Output 'Building native Windows desktop with strict D-only environment...'
dotnet build $project -c Release --nologo
if ($LASTEXITCODE -ne 0) { throw 'Windows WPF build failed.' }
dotnet run --project $tests -c Release --no-restore
if ($LASTEXITCODE -ne 0) { throw 'Windows protocol smoke tests failed.' }
dotnet run --project $cli -c Release -- --help
if ($LASTEXITCODE -ne 0) { throw 'Read-only diagnostic CLI help smoke failed.' }
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
}
Write-Output 'Windows desktop BUILD / protocol smoke PASS. Hardware GUI acceptance remains pending.'
