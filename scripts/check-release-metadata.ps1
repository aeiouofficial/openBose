param([string]$RepositoryRoot = 'D:\openBose')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not ($root.Equals('D:\openBose', [StringComparison]::OrdinalIgnoreCase) -or
          $root.StartsWith('D:\openBose\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Release metadata root must stay inside D:\openBose.'
}
& (Join-Path $root 'scripts\check-no-actions.ps1') -RepositoryRoot $root

$versionFile = Join-Path $root 'VERSION'
if (-not (Test-Path -LiteralPath $versionFile)) { throw 'Missing VERSION.' }
$version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "Invalid VERSION value: $version"
}

$androidGradle = Get-Content -LiteralPath (Join-Path $root 'android\app\build.gradle.kts') -Raw
if ($androidGradle -notmatch 'versionName\s*=\s*rootProject\.file\("\.\./VERSION"\)\.readText\(\)\.trim\(\)') {
    throw 'Android versionName is not sourced from repository VERSION.'
}
if ($androidGradle -notmatch 'versionCode\s*=\s*\d+') {
    throw 'Android versionCode is missing.'
}

$windowsProps = Get-Content -LiteralPath (Join-Path $root 'windows\Directory.Build.props') -Raw
if ($windowsProps -notmatch "ReadAllText\('\$\(MSBuildThisFileDirectory\)\.\.\\VERSION'\)") {
    throw 'Windows build metadata is not sourced from repository VERSION.'
}
if ($windowsProps -notmatch '<Version>\$\(OpenBoseVersion\)</Version>') {
    throw 'Windows Version property does not use OpenBoseVersion.'
}

$manifestPath = Join-Path $root 'android\app\src\main\AndroidManifest.xml'
$stringsPath = Join-Path $root 'android\app\src\main\res\values\strings.xml'
[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
[xml]$strings = Get-Content -LiteralPath $stringsPath -Raw
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$applicationLabel = $manifest.manifest.application.GetAttribute('label', $androidNamespace)
if ($applicationLabel -ne '@string/app_name') {
    throw 'Android application label is not localized through @string/app_name.'
}
$stringNames = @($strings.resources.string | ForEach-Object { $_.name })
foreach ($required in @('app_name','host_eq_activity_label','codec_evidence_note',
                         'enable_host_eq','wav_playback_finished')) {
    if ($required -notin $stringNames) { throw "Required Android string missing: $required" }
}

$xamlPath = Join-Path $root 'windows\src\OpenBose.Desktop\MainWindow.xaml'
[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw
$xamlText = Get-Content -LiteralPath $xamlPath -Raw
foreach ($label in @(
    'AutomationProperties.Name="Paired Bluetooth devices"',
    'AutomationProperties.Name="Bass host equalizer gain in decibels"',
    'AutomationProperties.LiveSetting="Polite"'
)) {
    if (-not $xamlText.Contains($label)) { throw "Windows accessibility metadata missing: $label" }
}

Write-Output ('PASS: release metadata/version/accessibility static gate for ' + $version)
