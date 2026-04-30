$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $workspaceRoot
$settingsPath = Join-Path $workspaceRoot "settings.json"
$luarcPath = Join-Path $projectRoot ".luarc.json"
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

$annotationsFrameXML = Join-Path $latestWowApi.FullName "Annotations\FrameXML"
$hasFrameXML = Test-Path -Path $annotationsFrameXML

$portableCore = "`${env:USERPROFILE}/.vscode/extensions/$($latestWowApi.Name)/Annotations/Core"
$portableFrameXML = "`${env:USERPROFILE}/.vscode/extensions/$($latestWowApi.Name)/Annotations/FrameXML"

function Set-JsonArrayProperty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonPath,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyValues
    )

    if (Test-Path -Path $JsonPath) {
        $jsonRaw = Get-Content -Path $JsonPath -Raw
        $jsonObject = $jsonRaw | ConvertFrom-Json
    } else {
        $jsonObject = [pscustomobject]@{}
    }

    $newArray = @($PropertyValues)
    $property = $jsonObject.PSObject.Properties[$PropertyName]
    if (-not $property) {
        $jsonObject | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $newArray -Force
    } else {
        $property.Value = $newArray
    }

    $updatedJson = $jsonObject | ConvertTo-Json -Depth 100
    Set-Content -Path $JsonPath -Value $updatedJson -Encoding UTF8
}

$libraryPaths = @($portableCore)
if ($hasFrameXML) {
    $libraryPaths += $portableFrameXML
}

Set-JsonArrayProperty -JsonPath $settingsPath -PropertyName "Lua.workspace.library" -PropertyValues $libraryPaths
Set-JsonArrayProperty -JsonPath $luarcPath -PropertyName "workspace.library" -PropertyValues $libraryPaths

Write-Output "Updated Lua.workspace.library and workspace.library to:"
$libraryPaths | ForEach-Object { Write-Output "  $_" }
