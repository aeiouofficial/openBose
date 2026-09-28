# Passive Windows A2DP codec observation. No Bluetooth writes or codec selection.
param(
    [string]$RepositoryRoot = 'D:\openBose',
    [ValidateRange(5,300)][int]$TimeoutSeconds = 45,
    [switch]$CheckOnly,
    [switch]$Elevate
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not ($root.Equals('D:\openBose', [StringComparison]::OrdinalIgnoreCase) -or
          $root.StartsWith('D:\openBose\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'OpenBose work must remain inside D:\openBose.'
}
& (Join-Path $PSScriptRoot 'check-no-actions.ps1') -RepositoryRoot $root

$project = Join-Path $root 'windows\src\OpenBose.CodecProbe\OpenBose.CodecProbe.csproj'
$publish = Join-Path $root '.tmp\dist\windows-codec-probe'
$exe = Join-Path $publish 'OpenBose.CodecProbe.exe'
if (-not (Test-Path -LiteralPath $project)) { throw "Codec probe project missing: $project" }

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-HostBaseline {
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Output ('WINDOWS=' + $os.Caption)
    Write-Output ('BUILD=' + $os.BuildNumber)
    Write-Output ('ELEVATED=' + (Test-Administrator))

    $bt = @(Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'Intel.*Wireless Bluetooth|Qualcomm|Realtek|MediaTek' })
    foreach ($item in $bt) {
        Write-Output ('BT_RADIO=' + $item.FriendlyName + ' | ' + $item.InstanceId)
    }

    $bose = @(Get-PnpDevice -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -like 'Bose NC 700 HP*' })
    Write-Output ('BOSE_PNP_COUNT=' + $bose.Count)
    foreach ($item in $bose) {
        Write-Output ('BOSE_PNP=' + $item.Class + ' | ' + $item.Status + ' | ' + $item.FriendlyName)
    }

    $endpoints = @(Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -match 'Bose.*NC.*700|NC.*700.*Bose' })
    Write-Output ('BOSE_ACTIVE_AUDIO_ENDPOINTS=' + $endpoints.Count)
    foreach ($item in $endpoints) { Write-Output ('BOSE_AUDIO=' + $item.FriendlyName) }

    $aacPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\BthA2dp\Parameters'
    $aac = $null
    try { $aac = (Get-ItemProperty -LiteralPath $aacPath -Name BluetoothAacEnable -ErrorAction Stop).BluetoothAacEnable }
    catch { }
    Write-Output ('BLUETOOTH_AAC_ENABLE=' + $(if ($null -eq $aac) { 'NOT_SET' } else { $aac }))
}

Show-HostBaseline

New-Item -ItemType Directory -Path $publish -Force | Out-Null
dotnet publish $project -c Release -r win-x64 --self-contained false --output $publish --nologo
if ($LASTEXITCODE -ne 0) { throw 'Windows A2DP codec probe publish failed.' }
if (-not (Test-Path -LiteralPath $exe)) { throw "Published codec probe missing: $exe" }

& $exe --check
if ($LASTEXITCODE -ne 0) { throw 'Codec probe prerequisite check failed.' }
if ($CheckOnly) {
    Write-Output 'CHECK_ONLY_PASS: no ETW session or Bluetooth operation was started.'
    return
}

$activeBose = @(Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match 'Bose.*NC.*700|NC.*700.*Bose' })
if ($activeBose.Count -eq 0) {
    throw 'Bose NC 700 has no active Windows audio endpoint. Connect it as a media-output device, then rerun.'
}

$stamp = Get-Date -Format 'yyyyMMddTHHmmss'
$sessionDir = Join-Path $root ('captures\private\windows-a2dp\' + $stamp)
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
$result = Join-Path $sessionDir 'codec.json'
$stderr = Join-Path $sessionDir 'stderr.txt'
$exitFile = Join-Path $sessionDir 'exit-code.txt'

if (Test-Administrator) {
    & $exe --timeout $TimeoutSeconds --json 1> $result 2> $stderr
    $code = $LASTEXITCODE
    Set-Content -LiteralPath $exitFile -Value $code -Encoding ascii
} elseif ($Elevate) {
    $helper = Join-Path $root '.tmp\run-a2dp-codec-elevated.ps1'
    $dollarLastExit = '$LASTEXITCODE'
    $helperLines = @(
        '$ErrorActionPreference = ''Stop'''
        '. ''D:\openBose\scripts\workspace-env.ps1'' | Out-Null'
        "& '$exe' --timeout $TimeoutSeconds --json 1> '$result' 2> '$stderr'"
        "Set-Content -LiteralPath '$exitFile' -Value $dollarLastExit -Encoding ascii"
    )
    Set-Content -LiteralPath $helper -Value ($helperLines -join [Environment]::NewLine) -Encoding utf8
    Write-Output 'UAC_REQUIRED: approve the OpenBose codec listener. It only opens a read-only ETW session.'
    $arguments = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$helper)
    $proc = Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -PassThru -ArgumentList $arguments
    Write-Output ('ELEVATED_HELPER_EXIT=' + $proc.ExitCode)
} else {
    throw 'Live codec observation needs Administrator elevation. Rerun with -Elevate.'
}

if (-not (Test-Path -LiteralPath $exitFile)) {
    throw 'Elevated codec probe produced no exit-code file (UAC may have been cancelled).'
}
$probeExit = [int](Get-Content -LiteralPath $exitFile -Raw)
Write-Output ('CAPTURE_DIR=' + $sessionDir)
Write-Output ('CODEC_PROBE_EXIT=' + $probeExit)
if (Test-Path -LiteralPath $result) {
    Write-Output 'CODEC_RESULT_BEGIN'
    Get-Content -LiteralPath $result
    Write-Output 'CODEC_RESULT_END'
}
if (Test-Path -LiteralPath $stderr) {
    $err = (Get-Content -LiteralPath $stderr -Raw).Trim()
    if ($err) { Write-Output ('CODEC_STDERR=' + $err) }
}
if ($probeExit -ne 0) {
    throw "No usable negotiated-codec observation (probe exit $probeExit)."
}
