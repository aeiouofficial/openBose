# Installs Android SDK only under D:\openBose\.tmp; requires portable JDK17.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
& (Join-Path $PSScriptRoot 'bootstrap-android.ps1')
$sdkRoot = $env:ANDROID_HOME
$tools = Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
$platformJar = Join-Path $sdkRoot 'platforms\android-35\android.jar'
$buildTool = Join-Path $sdkRoot 'build-tools\35.0.0\aapt2.exe'
if ((Test-Path $tools) -and (Test-Path $platformJar) -and (Test-Path $buildTool)) {
    Write-Output ('Android SDK already ready: ' + $sdkRoot)
    return
}
$env:JAVA_HOME = (Get-Content 'D:\openBose\.tmp\jdk17\.ready' -Raw).Trim()
$env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH
if (-not (Test-Path $tools)) {
    $zip = Join-Path $env:TEMP 'android-commandline-tools.zip'
    $unpack = Join-Path $env:TEMP 'android-cli-unpack'
    $uri = 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip'
    if (-not (Test-Path $zip)) {
        Write-Output 'Downloading official Android command-line tools into project scratch.'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $uri -OutFile $zip -UseBasicParsing
    }
    if ((Get-Item $zip).Length -ne 143040480) {
        throw 'Android CLI tools archive size mismatch; refusing extraction.'
    }
    New-Item -ItemType Directory -Path $unpack -Force | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $unpack -Force
    $source = Join-Path $unpack 'cmdline-tools'
    if (-not (Test-Path (Join-Path $source 'bin\sdkmanager.bat'))) {
        throw 'Unexpected Android command-line tools archive layout.'
    }
    $destinationParent = Join-Path $sdkRoot 'cmdline-tools'
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    Move-Item -LiteralPath $source -Destination (Join-Path $destinationParent 'latest')
}
if (-not (Test-Path $tools)) { throw 'sdkmanager missing after extraction.' }
Write-Output 'Accepting Android SDK package licenses needed for local app compilation.'
$answers = (1..60 | ForEach-Object { 'y' }) -join [Environment]::NewLine
$answers | & $tools --sdk_root=$sdkRoot --licenses
if ($LASTEXITCODE -ne 0) { throw 'Android SDK license setup failed.' }
& $tools --sdk_root=$sdkRoot 'platforms;android-35' 'build-tools;35.0.0' 'platform-tools'
if ($LASTEXITCODE -ne 0) { throw 'Android SDK package installation failed.' }
if (-not (Test-Path $platformJar) -or -not (Test-Path $buildTool)) {
    throw 'Expected Android SDK platform/build-tools files are missing.'
}
Write-Output ('Android SDK ready under '+$sdkRoot)
