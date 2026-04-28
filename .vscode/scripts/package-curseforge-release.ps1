param(
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tocPath = Join-Path $repoRoot "TextAdventurer.toc"
$releaseDir = Join-Path $repoRoot "release"

if (-not (Test-Path $tocPath)) {
    throw "TOC not found: $tocPath"
}

$tocLines = Get-Content -Path $tocPath
$versionLine = $tocLines | Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not read version from TextAdventurer.toc"
}

$version = ([regex]::Match($versionLine, '^##\s*Version:\s*(.+)$')).Groups[1].Value.Trim()
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "Version string in TOC is empty"
}

$dateTag = Get-Date -Format "yyyyMMdd"
$packageName = "TextAdventurer-v$version-$dateTag"
$stagingRoot = Join-Path $releaseDir $packageName
$stagedAddonRoot = Join-Path $stagingRoot "TextAdventurer"
$zipPath = Join-Path $releaseDir ($packageName + ".zip")

if (Test-Path $stagingRoot) {
    Remove-Item -Path $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stagedAddonRoot -Force | Out-Null

# Copy TOC always.
Copy-Item -Path $tocPath -Destination (Join-Path $stagedAddonRoot "TextAdventurer.toc") -Force

# Parse runtime include lines from TOC.
$includeLines = @()
foreach ($line in $tocLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "") { continue }
    if ($trimmed.StartsWith("#")) { continue }
    if ($trimmed.StartsWith("##")) { continue }
    $includeLines += $trimmed
}

$topLevelDirs = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
$topLevelFiles = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)

foreach ($entry in $includeLines) {
    $normalized = $entry -replace '/', '\\'
    $parts = $normalized.Split('\\')
    if ($parts.Count -gt 1) {
        $topLevelDirs.Add($parts[0]) | Out-Null
    }
    else {
        $topLevelFiles.Add($parts[0]) | Out-Null
    }
}

foreach ($dirName in $topLevelDirs) {
    $src = Join-Path $repoRoot $dirName
    $dst = Join-Path $stagedAddonRoot $dirName
    if (-not (Test-Path $src -PathType Container)) {
        throw "Expected directory from TOC not found: $src"
    }
    Copy-Item -Path $src -Destination $dst -Recurse -Force
}

foreach ($fileName in $topLevelFiles) {
    $src = Join-Path $repoRoot $fileName
    $dst = Join-Path $stagedAddonRoot $fileName
    if (-not (Test-Path $src -PathType Leaf)) {
        throw "Expected file from TOC not found: $src"
    }
    Copy-Item -Path $src -Destination $dst -Force
}

# Include README in package root when present for release notes context.
$readmePath = Join-Path $repoRoot "README.md"
if (Test-Path $readmePath -PathType Leaf) {
    Copy-Item -Path $readmePath -Destination (Join-Path $stagingRoot "README.md") -Force
}

if (-not $NoZip) {
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stagingRoot "TextAdventurer") -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Created zip: $zipPath"
}

Write-Host "Staged release folder: $stagingRoot"
