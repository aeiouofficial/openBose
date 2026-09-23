# Portable JDK 17; all downloads/extraction stay under D:\openBose\.tmp.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
$zip = Join-Path $env:TEMP 'openjdk17-win-x64.zip'
$dir = Join-Path $env:TEMP 'jdk17'
$marker = Join-Path $dir '.ready'
if (Test-Path -LiteralPath $marker) {
    $jdkRoot = (Get-Content -LiteralPath $marker -Raw).Trim()
    if (Test-Path -LiteralPath (Join-Path $jdkRoot 'bin\javac.exe')) {
        $env:JAVA_HOME = $jdkRoot
        $env:PATH = (Join-Path $jdkRoot 'bin') + ';' + $env:PATH
        & (Join-Path $jdkRoot 'bin\javac.exe') -version
        Write-Output 'Portable JDK17 is already ready. Gradle wrapper uses project-local GRADLE_USER_HOME.'
        return
    }
}
$api = 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&jvm_impl=hotspot&os=windows&vendor=eclipse'
$release = @(Invoke-RestMethod -Uri $api -TimeoutSec 30)[0]
$pkg = $release.binary.package
if (-not $pkg.link -or -not $pkg.checksum) { throw 'Adoptium metadata missing package URL or SHA-256.' }
$expected = [string]$pkg.checksum
if (Test-Path -LiteralPath $zip) {
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if (-not [string]::Equals($actual, $expected, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $zip -Force
    }
}
if (-not (Test-Path -LiteralPath $zip)) {
    Write-Output 'Downloading verified JDK17 zip into D:\openBose\.tmp only.'
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $pkg.link -OutFile $zip -UseBasicParsing -MaximumRedirection 10
}
$actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
if (-not [string]::Equals($actual, $expected, [StringComparison]::OrdinalIgnoreCase)) {
    throw "JDK checksum mismatch. Expected $expected, received $actual."
}
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
$javac = Get-ChildItem -LiteralPath $dir -Filter javac.exe -Recurse -File | Select-Object -First 1
if (-not $javac) { throw 'Verified archive contained no javac.exe.' }
$jdkRoot = $javac.Directory.Parent.FullName
Set-Content -LiteralPath $marker -Value $jdkRoot -Encoding UTF8
$env:JAVA_HOME = $jdkRoot
$env:PATH = (Join-Path $jdkRoot 'bin') + ';' + $env:PATH
& (Join-Path $jdkRoot 'bin\javac.exe') -version
Write-Output ('JDK17 ready under '+$jdkRoot)
