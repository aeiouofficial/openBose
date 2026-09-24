# Mandatory launcher for OpenBose work. All project-generated files belong to D:\openBose.
$ProjectRoot = 'D:\openBose'
$Scratch = Join-Path $ProjectRoot '.tmp'
$folders = @(
    $Scratch, (Join-Path $Scratch 'home'), (Join-Path $Scratch 'appdata'),
    (Join-Path $Scratch 'localappdata'), (Join-Path $Scratch 'java-temp'),
    (Join-Path $Scratch 'gradle'), (Join-Path $Scratch 'android-sdk'),
    (Join-Path $Scratch 'android-user'), (Join-Path $Scratch 'nuget-packages'),
    (Join-Path $Scratch 'nuget-http'), (Join-Path $Scratch 'nuget-scratch'),
    (Join-Path $Scratch 'dotnet-home'), (Join-Path $Scratch 'pip'),
    (Join-Path $Scratch 'xdg-cache'), (Join-Path $Scratch 'xdg-config'),
    (Join-Path $Scratch 'git'), (Join-Path $Scratch 'pycache'),
    (Join-Path $Scratch 'conda-pkgs'), (Join-Path $Scratch 'conda-envs'),
    (Join-Path $Scratch 'uv-cache'), (Join-Path $Scratch 'python-user'),
    (Join-Path $Scratch 'npm-prefix'), (Join-Path $Scratch 'pnpm'),
    (Join-Path $Scratch 'corepack'), (Join-Path $Scratch 'yarn')
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}
$env:TEMP = $Scratch
$env:TMP = $Scratch
$env:TMPDIR = $Scratch
$env:HOME = Join-Path $Scratch 'home'
$env:USERPROFILE = $env:HOME
$env:APPDATA = Join-Path $Scratch 'appdata'
$env:LOCALAPPDATA = Join-Path $Scratch 'localappdata'
$env:XDG_CACHE_HOME = Join-Path $Scratch 'xdg-cache'
$env:XDG_CONFIG_HOME = Join-Path $Scratch 'xdg-config'
$env:GRADLE_USER_HOME = Join-Path $Scratch 'gradle'
$env:ANDROID_HOME = Join-Path $Scratch 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $Scratch 'android-user'
$env:ANDROID_EMULATOR_HOME = Join-Path $Scratch 'android-user\avd'
$env:NUGET_PACKAGES = Join-Path $Scratch 'nuget-packages'
$env:NUGET_HTTP_CACHE_PATH = Join-Path $Scratch 'nuget-http'
$env:NUGET_SCRATCH = Join-Path $Scratch 'nuget-scratch'
$env:DOTNET_CLI_HOME = Join-Path $Scratch 'dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = '1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:MSBUILDDISABLENODEREUSE = '1'
$env:NPM_CONFIG_CACHE = Join-Path $Scratch 'npm'
$env:NPM_CONFIG_PREFIX = Join-Path $Scratch 'npm-prefix'
$env:PNPM_HOME = Join-Path $Scratch 'pnpm'
$env:COREPACK_HOME = Join-Path $Scratch 'corepack'
$env:YARN_CACHE_FOLDER = Join-Path $Scratch 'yarn'
$env:PIP_CACHE_DIR = Join-Path $Scratch 'pip'
$env:CONDA_PKGS_DIRS = Join-Path $Scratch 'conda-pkgs'
$env:CONDA_ENVS_PATH = Join-Path $Scratch 'conda-envs'
$env:UV_CACHE_DIR = Join-Path $Scratch 'uv-cache'
$env:PYTHONUSERBASE = Join-Path $Scratch 'python-user'
$env:PYTHONPYCACHEPREFIX = Join-Path $Scratch 'pycache'
$env:POETRY_CACHE_DIR = Join-Path $Scratch 'poetry'
$env:CARGO_HOME = Join-Path $Scratch 'cargo'
$env:CARGO_TARGET_DIR = Join-Path $Scratch 'cargo-target'
$env:RUSTUP_HOME = Join-Path $Scratch 'rustup'
$env:GIT_CONFIG_GLOBAL = Join-Path $Scratch 'git\global.gitconfig'
$env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$($Scratch -replace '\\','/')/java-temp -Duser.home=$($Scratch -replace '\\','/')/home -XX:HeapDumpPath=$($Scratch -replace '\\','/')/java-temp"
$env:GRADLE_OPTS = "-Dgradle.user.home=$($Scratch -replace '\\','/')/gradle"
Remove-Item Env:PIP_BUILD_TRACKER -ErrorAction SilentlyContinue
if (!(Test-Path -LiteralPath $ProjectRoot)) { throw 'D:\openBose workspace unavailable.' }
if ($env:TEMP -notlike "$ProjectRoot*") { throw 'Temporary path outside D:\openBose.' }
. (Join-Path $PSScriptRoot 'assert-d-only.ps1')
Set-Location -LiteralPath $ProjectRoot
Write-Output ("OpenBose STRICT D: workspace=$ProjectRoot scratch=$Scratch")
