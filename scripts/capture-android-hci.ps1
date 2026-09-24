# Manually invoked; never toggles Bluetooth, snooping, pairing or NC700 state.
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._:-]{1,80}$')]
    [string]$DeviceSerial,
    [ValidatePattern('^[A-Za-z0-9_-]{1,32}$')]
    [string]$SessionName = 'nc700'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
$root = 'D:\openBose'
$adb = Join-Path $root '.tmp\android-sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) {
    throw 'Project-local adb.exe is missing. Install Android platform-tools under D:\openBose\.tmp\android-sdk only.'
}
$devices = @(& $adb devices)
if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
$entry = @($devices | Where-Object { $_ -match ('^' + [regex]::Escape($DeviceSerial) + '\s+device(\s|$)') })
if ($entry.Count -ne 1) {
    throw 'Supplied phone is not listed as one authorized ADB device. Run project-local adb devices and confirm USB debugging first.'
}
$stamp = Get-Date -Format 'yyyyMMddTHHmmss'
$session = Join-Path $root ('captures\private\' + $stamp + '_' + $SessionName)
if (Test-Path -LiteralPath $session) { throw 'Capture session already exists; choose a new name.' }
New-Item -ItemType Directory -Path $session -Force | Out-Null
$zip = Join-Path $session 'android-bugreport.zip'
Write-Output "Collecting an Android bugreport under: $session"
Write-Output 'Enable Bluetooth HCI snoop logging manually before reconnecting the NC700. Disable it after capture.'
& $adb -s $DeviceSerial bugreport $zip
if ($LASTEXITCODE -ne 0) {
    throw "Bugreport failed; inspect private session folder under D:\openBose."
}
if (-not (Test-Path -LiteralPath $zip)) {
    Write-Warning 'ADB finished but no ZIP at expected path; inspect the session directory for an alternative output filename.'
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $snoop = @($archive.Entries | Where-Object {
            $_.FullName -match '(?i)btsnoop|btsnooz'
        })
        if ($snoop.Count -gt 0) {
            Write-Output ('HCI_LOG_CANDIDATES=' + ($snoop.Count))
        } else {
            Write-Warning 'No BTSnoop/BTSnooz filename detected. Check firmware-specific Android bugreport text, HCI logging configuration and capture plan.'
        }
    } finally { $archive.Dispose() }
}
Write-Output 'Private bugreport collection finished. DO NOT commit the raw ZIP, MAC addresses or device serial.'
Write-Output 'Next: manually extract one audio sink SEP capabilities TLV and decode with tools/avdtp/decode_caps.py.'
