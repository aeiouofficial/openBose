param([string]$RepositoryRoot = 'D:\openBose')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'workspace-env.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not ($root.Equals('D:\openBose', [StringComparison]::OrdinalIgnoreCase) -or
          $root.StartsWith('D:\openBose\', [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Project root must be inside D:\openBose.'
}
$workflowDir = Join-Path $root '.github\workflows'
if (Test-Path -LiteralPath $workflowDir) {
    $files = @(Get-ChildItem -LiteralPath $workflowDir -File -Recurse)
    if ($files.Count -gt 0) {
        throw ('GitHub Actions prohibited: found ' + $files.Count +
            ' workflow files. Do not run or restore them.')
    }
}
$tracked = @(& git -C $root ls-files -- '.github/workflows/*')
if ($LASTEXITCODE -ne 0) { throw 'Could not check tracked workflow files.' }
if ($tracked.Count -gt 0) {
    throw 'Tracked GitHub Actions workflows found. Delete them before continuing.'
}
Write-Output 'PASS: No GitHub Actions workflow files or tracked CI jobs.'
