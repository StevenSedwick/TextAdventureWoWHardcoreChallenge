# WoW Map Extraction Verification Tool
# Run this after extraction to verify folder structure is correct

param(
    [Parameter(Mandatory=$true)]
    [string]$ExtractionRoot,
    
    [switch]$Detailed
)

Write-Output "=========================================="
Write-Output "WoW Map Extraction Verifier"
Write-Output "=========================================="
Write-Output "Checking: $ExtractionRoot"
Write-Output ""

if (-not (Test-Path $ExtractionRoot -PathType Container)) {
    Write-Error "Extraction root not found: $ExtractionRoot"
    exit 1
}

$mapFolders = @(Get-ChildItem $ExtractionRoot -Directory)

if ($mapFolders.Count -eq 0) {
    Write-Error "No map folders found in $ExtractionRoot"
    Write-Error "Did extraction complete successfully?"
    exit 1
}

$issueCount = 0
$warningCount = 0

foreach ($folder in $mapFolders) {
    Write-Output "Map: $($folder.Name)"
    
    # Check for WDT
    $wdtFile = Join-Path $folder.FullName "world.wdt"
    if (Test-Path $wdtFile) {
        $wdtSize = (Get-Item $wdtFile).Length / 1KB
        Write-Output "  ✓ WDT: $([math]::Round($wdtSize, 1)) KB"
    } else {
        Write-Output "  ✗ WDT: NOT FOUND (required)"
        $issueCount++
    }
    
    # Count ADT files (base + variants)
    $baseAdts = @(Get-ChildItem $folder.FullName -Filter "world_[0-9]_[0-9].adt" -ErrorAction SilentlyContinue)
    $variantAdts = @(Get-ChildItem $folder.FullName -Filter "world_[0-9]_[0-9]_*.adt" -ErrorAction SilentlyContinue)
    $allAdts = $baseAdts + $variantAdts
    
    if ($baseAdts.Count -gt 0) {
        Write-Output "  ✓ Base ADTs: $($baseAdts.Count) files"
        if ($variantAdts.Count -gt 0) {
            Write-Output "  ℹ Variant ADTs: $($variantAdts.Count) files (will be auto-merged)"
        }
    } else {
        Write-Output "  ✗ ADTs: NOT FOUND (required)"
        $issueCount++
    }
    
    # Verify expected tile count (usually 32x32 = 1024 for full maps)
    $expectedTiles = 1024  # 32 x 32
    if ($baseAdts.Count -lt 100) {
        Write-Output "  ⚠ Low ADT count: $($baseAdts.Count) (expected ~$expectedTiles for full map)"
        $warningCount++
    }
    
    # Check for other file types (indicator of over-extraction)
    $otherFiles = @(Get-ChildItem $folder.FullName -File | Where-Object {
        $_.Extension -notin @('.wdt', '.adt')
    })
    if ($otherFiles.Count -gt 0 -and -not $Detailed) {
        Write-Output "  ℹ Other files: $($otherFiles.Count) (textures, models, etc.) - using extra space"
    }
    
    Write-Output ""
}

# Summary
Write-Output "=========================================="
Write-Output "Summary"
Write-Output "=========================================="
Write-Output "Maps checked: $($mapFolders.Count)"
Write-Output "Issues found: $issueCount"
Write-Output "Warnings: $warningCount"
Write-Output ""

if ($issueCount -eq 0) {
    Write-Output "✓ Extraction structure looks valid!"
    Write-Output "You can now run: .\compile_maps.ps1 -InputRoot '$ExtractionRoot' -Maps @(...)"
    exit 0
} else {
    Write-Error "✗ Extraction structure has errors. Re-extract or check wow.export settings."
    exit 1
}
