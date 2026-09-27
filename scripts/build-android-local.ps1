# Explicitly local-only Android alpha gate. NEVER invokes GitHub Actions.
param([string]$RepositoryRoot = 'D:\openBose')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not ($root.Equals('D:\openBose', [StringComparison]::OrdinalIgnoreCase) -or
    $root.StartsWith('D:\openBose\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Project root must remain inside D:\openBose.'
}
& (Join-Path $PSScriptRoot 'check-no-actions.ps1') -RepositoryRoot $root
$sdk = 'D:\openBose\.tmp\android-sdk'
$jdkFile = 'D:\openBose\.tmp\jdk17\.ready'
$gradle = 'D:\openBose\.tmp\gradle-dist\gradle-8.13\bin\gradle.bat'
if (-not (Test-Path $jdkFile)) { throw 'Run scripts/bootstrap-android.ps1 first.' }
if (-not (Test-Path $gradle)) { throw 'Missing project-local Gradle 8.13.' }
if (-not (Test-Path (Join-Path $sdk 'platforms\android-35\android.jar')) -or
    -not (Test-Path (Join-Path $sdk 'build-tools\35.0.0\aapt.exe'))) {
    throw 'Run scripts/bootstrap-android-sdk.ps1 first; no C: SDK fallback is allowed.'
}
$env:JAVA_HOME = (Get-Content $jdkFile -Raw).Trim()
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
& $gradle -p (Join-Path $root 'android') -PwithAndroidApp=true --no-daemon --console plain :audio:test :bmap:test :app:assembleDebug :app:lintDebug
if ($LASTEXITCODE -ne 0) { throw 'Android JVM, APK build or lint gate failed.' }
$apk = Join-Path $root 'android\app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path -LiteralPath $apk)) { throw 'APK was not generated.' }
$aapt = Join-Path $sdk 'build-tools\35.0.0\aapt.exe'
$permissions = @(& $aapt dump permissions $apk)
if ($LASTEXITCODE -ne 0) { throw 'aapt manifest audit failed.' }
Write-Output 'ANDROID_APK_MANIFEST_PERMISSIONS:'
$permissions | ForEach-Object { Write-Output $_ }
$forbidden = $permissions | Where-Object {
    $_ -match "uses-permission: name='android.permission." -and
    $_ -notmatch "(android.permission.BLUETOOTH'|android.permission.BLUETOOTH_CONNECT')"
}
if ($forbidden) { throw ('APK requests unexpected permissions: ' + ($forbidden -join '; ')) }
$dist = Join-Path $root '.tmp\dist\android'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$copy = Join-Path $dist 'openbose-android-host-eq-alpha.apk'
Copy-Item -LiteralPath $apk -Destination $copy -Force
Write-Output ('LOCAL_ALPHA_APK=' + $copy)
Write-Output ('APK_BYTES=' + (Get-Item $copy).Length)
Write-Output ('APK_SHA256=' + (Get-FileHash $copy -Algorithm SHA256).Hash)
Write-Output 'Local Android Kotlin, APK and lint gates passed; device acceptance remains separate.'
