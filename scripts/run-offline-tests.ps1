param([switch]$SkipAndroid, [switch]$SkipWindows)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
$repo = 'D:\openBose'
function Assert-LastExit([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed (exit $LASTEXITCODE)." }
}
Write-Output '[1/3] Shared BMAP contract (no Bluetooth I/O)'
python (Join-Path $PSScriptRoot 'check-contract.py')
Assert-LastExit 'Shared BMAP contract'
python -O (Join-Path $PSScriptRoot 'test_contract.py')
Assert-LastExit 'Optimized-mode BMAP negative fixtures'
Write-Output '[offline] AVDTP synthetic codec decoder (no device I/O)'
python -B -m unittest discover -s (Join-Path $repo 'tools\avdtp') -p 'test_*.py' -v
Assert-LastExit 'AVDTP synthetic decoder tests'
if (-not $SkipWindows) {
    Write-Output '[2/3] Windows .NET BMAP smoke tests'
    dotnet run --project (Join-Path $repo 'windows\tests\OpenBose.Protocol.SmokeTests\OpenBose.Protocol.SmokeTests.csproj') -c Release
    Assert-LastExit 'Windows BMAP smoke'
}
if (-not $SkipAndroid) {
    Write-Output '[3/3] Android Kotlin/JUnit BMAP tests'
    $jdkMarker = Join-Path $repo '.tmp\jdk17\.ready'
    $portableGradle = Join-Path $repo '.tmp\gradle-dist\gradle-8.13\bin\gradle.bat'
    $wrapper = Join-Path $repo 'android\gradlew.bat'
    if (-not (Test-Path -LiteralPath $jdkMarker)) {
        throw 'Portable JDK 17 not installed under D:\openBose\.tmp\jdk17. Run scripts/bootstrap-android.ps1 first.'
    }
    $env:JAVA_HOME = (Get-Content -LiteralPath $jdkMarker -Raw).Trim()
    $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH
    if (Test-Path -LiteralPath $portableGradle) {
        & $portableGradle -p (Join-Path $repo 'android') --no-daemon --console plain :bmap:test
    } elseif (Test-Path -LiteralPath $wrapper) {
        & $wrapper -p (Join-Path $repo 'android') --no-daemon --console plain :bmap:test
    } else { throw 'No Gradle wrapper or project-local Gradle distribution.' }
    Assert-LastExit 'Android Kotlin/JUnit BMAP'
}
Write-Output 'PASS: All requested offline OpenBose tests completed.'
