# Fail closed if an OpenBose task would place its generated files outside D:\openBose.
$root = 'D:\openBose'
$required = @(
    'TEMP','TMP','TMPDIR','HOME','USERPROFILE','APPDATA','LOCALAPPDATA',
    'XDG_CACHE_HOME','XDG_CONFIG_HOME','GRADLE_USER_HOME','ANDROID_HOME',
    'ANDROID_SDK_ROOT','ANDROID_USER_HOME','ANDROID_EMULATOR_HOME',
    'NUGET_PACKAGES','NUGET_HTTP_CACHE_PATH','NUGET_SCRATCH',
    'DOTNET_CLI_HOME','NPM_CONFIG_CACHE','NPM_CONFIG_PREFIX',
    'PNPM_HOME','COREPACK_HOME','YARN_CACHE_FOLDER','PIP_CACHE_DIR',
    'CONDA_PKGS_DIRS','CONDA_ENVS_PATH','UV_CACHE_DIR','PYTHONUSERBASE',
    'PYTHONPYCACHEPREFIX','POETRY_CACHE_DIR','CARGO_HOME',
    'CARGO_TARGET_DIR','RUSTUP_HOME','GIT_CONFIG_GLOBAL'
)
foreach ($name in $required) {
    $path = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrWhiteSpace($path) -or
        -not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "OpenBose D-only policy violation: $name is not under D:\openBose."
    }
}
$javaOptions = $env:JAVA_TOOL_OPTIONS
if (!$javaOptions.Contains('-Djava.io.tmpdir=D:/openBose/.tmp/java-temp') -or
    !$javaOptions.Contains('-Duser.home=D:/openBose/.tmp/home')) {
    throw 'OpenBose Java temp/home override is missing or invalid.'
}
if (![IO.Path]::GetTempPath().StartsWith($root + '\',
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OpenBose .NET process temp path is outside D:\openBose.'
}
Write-Output 'PASS: OpenBose project temp, home and all tool caches are D-only.'
