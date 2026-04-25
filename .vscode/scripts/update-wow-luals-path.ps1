$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$settingsPath = Join-Path $workspaceRoot "settings.json"
$extensionsRoot = Join-Path $env:USERPROFILE ".vscode\extensions"

if (-not (Test-Path -Path $settingsPath)) {
    throw "settings.json not found at $settingsPath"
}

if (-not (Test-Path -Path $extensionsRoot)) {
    throw "VS Code extensions directory not found: $extensionsRoot"
}

$wowApiDirs = Get-ChildItem -Path $extensionsRoot -Directory |
    Where-Object { $_.Name -like "ketho.wow-api-*" }

if (-not $wowApiDirs -or $wowApiDirs.Count -eq 0) {
    throw "No ketho.wow-api extension found under $extensionsRoot"
}

$latestWowApi = $wowApiDirs |
    Sort-Object -Property @{ Expression = {
        $raw = $_.Name -replace '^ketho\.wow-api-', ''
        try { [version]$raw } catch { [version]'0.0.0' }
    }; Descending = $true } |
    Select-Object -First 1

$annotationsCore = Join-Path $latestWowApi.FullName "Annotations\Core"
if (-not (Test-Path -Path $annotationsCore)) {
    throw "Annotations\\Core not found in extension: $($latestWowApi.FullName)"
}

$portablePath = "`${env:USERPROFILE}/.vscode/extensions/$($latestWowApi.Name)/Annotations/Core"

$settingsRaw = Get-Content -Path $settingsPath -Raw
$settings = $settingsRaw | ConvertFrom-Json

if (-not $settings.PSObject.Properties.Name.Contains("Lua.workspace.library") -or -not $settings."Lua.workspace.library") {
    $settings | Add-Member -MemberType NoteProperty -Name "Lua.workspace.library" -Value @($portablePath)
} else {
    $library = @($settings."Lua.workspace.library")
    if ($library.Count -eq 0) {
        $library = @($portablePath)
    } else {
        $library[0] = $portablePath
    }
    $settings."Lua.workspace.library" = $library
}

$updatedJson = $settings | ConvertTo-Json -Depth 100
Set-Content -Path $settingsPath -Value $updatedJson -Encoding UTF8

Write-Output "Updated Lua.workspace.library to: $portablePath"
