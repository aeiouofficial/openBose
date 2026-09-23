# Dot-source first: . .\scripts\workspace-env.ps1
$ProjectRoot = 'D:\openBose'
$Scratch = Join-Path $ProjectRoot '.tmp'
New-Item -ItemType Directory -Path $Scratch -Force | Out-Null
$env:TEMP = $Scratch
$env:TMP = $Scratch
$env:TMPDIR = $Scratch
$env:XDG_CACHE_HOME = Join-Path $Scratch 'xdg-cache'
$env:GRADLE_USER_HOME = Join-Path $Scratch 'gradle'
$env:NPM_CONFIG_CACHE = Join-Path $Scratch 'npm'
$env:PIP_CACHE_DIR = Join-Path $Scratch 'pip'
$env:CARGO_HOME = Join-Path $Scratch 'cargo'
$env:CARGO_TARGET_DIR = Join-Path $Scratch 'cargo-target'
$env:ANDROID_USER_HOME = Join-Path $Scratch 'android-user'
$env:POETRY_CACHE_DIR = Join-Path $Scratch 'poetry'
$env:NUGET_PACKAGES = Join-Path $Scratch 'nuget-packages'
$env:DOTNET_CLI_HOME = Join-Path $Scratch 'dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
# Preserve any preinstalled RUSTUP_HOME/toolchain; only project build artifacts are redirected.
# pip creates its own per-run build tracker under TEMP; do not set PIP_BUILD_TRACKER.
Remove-Item Env:PIP_BUILD_TRACKER -ErrorAction SilentlyContinue
Set-Location -LiteralPath $ProjectRoot
Write-Host "OpenBose workspace: $ProjectRoot; temp/cache: $Scratch"
