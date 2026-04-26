# Terrain Compiler Batch Helper
# Usage: .\compile_maps.ps1 -InputRoot "C:\wow-extracted" -Maps @("Azeroth", "Kalimdor")

param(
    [Parameter(Mandatory=$true)]
    [string]$InputRoot,
    
    [Parameter(Mandatory=$true)]
    [string[]]$Maps,
    
    [string]$OutputDir = $InputRoot,
    
    [int]$SampleStride = 4,
    
    [switch]$Verbose
)

# Setup Python environment
$pyRoot = "$env:LocalAppData\Programs\Python\Python312"
if (-not (Test-Path $pyRoot)) {
    Write-Error "Python 3.12 not found at $pyRoot. Install with: winget install -e --id Python.Python.3.12"
    exit 1
}

$env:Path = "$pyRoot;$pyRoot\Scripts;$env:Path"

# Verify terrain_compiler is installed
try {
    $help = & python -m terrain_compiler --help 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "terrain_compiler not available. Install with: cd tools/terrain_compiler; python -m pip install -e ."
        exit 1
    }
} catch {
    Write-Error "Failed to run terrain_compiler: $_"
    exit 1
}

# Verify input root exists
if (-not (Test-Path $InputRoot -PathType Container)) {
    Write-Error "Input root not found: $InputRoot"
    exit 1
}

Write-Output "================================"
Write-Output "WoW Terrain Compiler Batch Tool"
Write-Output "================================"
Write-Output "Input Root: $InputRoot"
Write-Output "Output Dir: $OutputDir"
Write-Output "Sample Stride: $SampleStride"
Write-Output "Maps to compile: $($Maps -join ', ')"
Write-Output ""

$successCount = 0
$failureCount = 0
$failedMaps = @()

foreach ($map in $Maps) {
    Write-Output "=========================================="
    Write-Output "Compiling: $map"
    Write-Output "=========================================="
    
    # Convert map name to zone key (lowercase, replace spaces with underscores)
    $zoneKey = $map.ToLower() -replace '\s+', '_'
    $outputFile = Join-Path $OutputDir "DFMode_$map.lua"
    
    # Verify map folder exists
    $mapPath = Join-Path $InputRoot $map
    if (-not (Test-Path $mapPath -PathType Container)) {
        Write-Warning "Map folder not found: $mapPath"
        Write-Warning "Skipping $map"
        $failureCount++
        $failedMaps += $map
        Write-Output ""
        continue
    }
    
    # Verify WDT file exists
    $wdtFile = Join-Path $mapPath "world.wdt"
    if (-not (Test-Path $wdtFile)) {
        Write-Warning "WDT file not found: $wdtFile"
        Write-Warning "Extraction may have failed. Skipping $map"
        $failureCount++
        $failedMaps += $map
        Write-Output ""
        continue
    }
    
    # Count ADT files
    $adtCount = @(Get-ChildItem $mapPath -Filter "world_*.adt" -ErrorAction SilentlyContinue).Count
    Write-Output "Found WDT + $adtCount ADT files"
    
    # Run compiler
    Write-Output "Compiling to: $outputFile"
    if ($Verbose) {
        & python -m terrain_compiler `
          --input-root $InputRoot `
          --map $map `
          --zone-key $zoneKey `
          --output $outputFile `
          --sample-stride $SampleStride
    } else {
        & python -m terrain_compiler `
          --input-root $InputRoot `
          --map $map `
          --zone-key $zoneKey `
          --output $outputFile `
          --sample-stride $SampleStride 2>&1 | Out-Null
    }
    
    if ($LASTEXITCODE -eq 0) {
        $fileSize = (Get-Item $outputFile).Length / 1MB
        Write-Output "✓ SUCCESS: Generated $([math]::Round($fileSize, 2)) MB"
        $successCount++
    } else {
        Write-Error "✗ FAILED: Compilation returned exit code $LASTEXITCODE"
        $failureCount++
        $failedMaps += $map
    }
    
    Write-Output ""
}

# Summary
Write-Output "=========================================="
Write-Output "Summary"
Write-Output "=========================================="
Write-Output "Successful: $successCount / $($Maps.Count)"
Write-Output "Failed: $failureCount / $($Maps.Count)"

if ($failedMaps.Count -gt 0) {
    Write-Output "Failed maps: $($failedMaps -join ', ')"
}

Write-Output ""
Write-Output "Output files written to: $OutputDir"
Write-Output ""

if ($failureCount -eq 0) {
    Write-Output "All maps compiled successfully!"
    exit 0
} else {
    Write-Warning "Some maps failed compilation. Check extraction folder structure."
    exit 1
}
