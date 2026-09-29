# Optional production Android signing gate. Requires user-owned secrets in D:\openBose\.secrets.
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
$keystoreRaw = [Environment]::GetEnvironmentVariable('OPENBOSE_ANDROID_KEYSTORE')
$keyAlias = [Environment]::GetEnvironmentVariable('OPENBOSE_ANDROID_KEY_ALIAS')
$storePassword = [Environment]::GetEnvironmentVariable('OPENBOSE_ANDROID_STORE_PASSWORD')
$keyPassword = [Environment]::GetEnvironmentVariable('OPENBOSE_ANDROID_KEY_PASSWORD')
if ([string]::IsNullOrWhiteSpace($keystoreRaw) -or
    [string]::IsNullOrWhiteSpace($keyAlias) -or
    [string]::IsNullOrWhiteSpace($storePassword) -or
    [string]::IsNullOrWhiteSpace($keyPassword)) {
    throw 'Set OPENBOSE_ANDROID_KEYSTORE, OPENBOSE_ANDROID_KEY_ALIAS, OPENBOSE_ANDROID_STORE_PASSWORD and OPENBOSE_ANDROID_KEY_PASSWORD.'
}

$keystore = [IO.Path]::GetFullPath($keystoreRaw)
$secretRoot = 'D:\openBose\.secrets\'
if (-not $keystore.StartsWith($secretRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Android release keystore must stay under D:\openBose\.secrets\.'
}
if (-not (Test-Path -LiteralPath $keystore)) { throw 'Android release keystore file not found.' }

$sdk = 'D:\openBose\.tmp\android-sdk'
$jdkFile = 'D:\openBose\.tmp\jdk17\.ready'
$gradle = 'D:\openBose\.tmp\gradle-dist\gradle-8.13\bin\gradle.bat'
$apksigner = Join-Path $sdk 'build-tools\35.0.0\apksigner.bat'
$aapt = Join-Path $sdk 'build-tools\35.0.0\aapt.exe'
foreach ($tool in @($jdkFile,$gradle,$apksigner,$aapt)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Required D-only Android tool missing: $tool" }
}

$env:JAVA_HOME = (Get-Content -LiteralPath $jdkFile -Raw).Trim()
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

& $gradle -p (Join-Path $root 'android') -PwithAndroidApp=true --no-daemon --console plain :audio:test :bmap:test :app:lintRelease :app:assembleRelease
if ($LASTEXITCODE -ne 0) { throw 'Android release tests/lint/build failed.' }

$unsigned = Join-Path $root 'android\app\build\outputs\apk\release\app-release-unsigned.apk'
if (-not (Test-Path -LiteralPath $unsigned)) { throw 'Unsigned release APK was not generated.' }
$dist = Join-Path $root '.tmp\dist\android'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$signed = Join-Path $dist ('openbose-android-' + $version + '-signed.apk')
if (Test-Path -LiteralPath $signed) { Remove-Item -LiteralPath $signed -Force }

& $apksigner sign --ks $keystore --ks-key-alias $keyAlias --ks-pass env:OPENBOSE_ANDROID_STORE_PASSWORD --key-pass env:OPENBOSE_ANDROID_KEY_PASSWORD --out $signed $unsigned
if ($LASTEXITCODE -ne 0) { throw 'APK signing failed.' }

$verify = @(& $apksigner verify --verbose --print-certs $signed)
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$verify | ForEach-Object { Write-Output $_ }
if (-not ($verify | Where-Object { $_ -match 'Verified using v2 scheme.*true' })) {
    throw 'Signed APK did not verify with APK Signature Scheme v2.'
}

$permissions = @(& $aapt dump permissions $signed)
if ($LASTEXITCODE -ne 0) { throw 'Signed APK permission audit failed.' }
$forbidden = $permissions | Where-Object {
    $_ -match "uses-permission: name='android.permission." -and
    $_ -notmatch "(android.permission.BLUETOOTH'|android.permission.BLUETOOTH_CONNECT')"
}
if ($forbidden) { throw ('Signed APK requests unexpected permissions: ' + ($forbidden -join '; ')) }

$badging = @(& $aapt dump badging $signed)
$packageLine = $badging | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
if (-not $packageLine -or
    $packageLine -notmatch "name='dev\.openbose\.app'" -or
    $packageLine -notmatch ("versionName='" + [regex]::Escape($version) + "'")) {
    throw 'Signed APK identity/version audit failed.'
}

Write-Output ('SIGNED_ANDROID_APK=' + $signed)
Write-Output ('SIGNED_ANDROID_SHA256=' + (Get-FileHash -LiteralPath $signed -Algorithm SHA256).Hash)
Write-Output 'PASS: Android release APK is signed and signature/identity/permission checks passed.'
Write-Output 'Manual device install/upgrade and hardware acceptance are still required before publication.'
