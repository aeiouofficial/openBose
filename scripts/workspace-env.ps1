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
Set-Location -LiteralPath $ProjectRoot
Write-Host "OpenBose workspace: $ProjectRoot; temp/cache: $Scratch"
