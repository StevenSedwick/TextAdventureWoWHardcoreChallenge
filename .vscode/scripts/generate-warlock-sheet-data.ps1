$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$inventoryPath = Join-Path $workspaceRoot "release\warlock_formula_inventory.txt"
$outputPath = Join-Path $workspaceRoot "WarlockSheetData.lua"

if (-not (Test-Path -Path $inventoryPath)) {
    throw "warlock_formula_inventory.txt not found at $inventoryPath"
}

$targetMappings = @(
    @{ Key = "sheetCritSnapshot"; Sheet = "Main"; Cell = "E23"; Note = "Spreadsheet crit snapshot for the active lane." },
    @{ Key = "sheetHitSnapshot"; Sheet = "Main"; Cell = "E24"; Note = "Spreadsheet hit snapshot after rating and gear caps." },
    @{ Key = "shadowDamageMult"; Sheet = "Main"; Cell = "E25"; Note = "Shadow lane total damage multiplier." },
    @{ Key = "fireDamageMult"; Sheet = "Main"; Cell = "E26"; Note = "Fire lane total damage multiplier." },
    @{ Key = "threatAdjustment"; Sheet = "Main"; Cell = "H34"; Note = "Threat delta used to derive reduction/increase assumptions." },
    @{ Key = "spellPowerBuffSnapshot"; Sheet = "Buff"; Cell = "E52"; Note = "Workbook spell power buff aggregate snapshot." },
    @{ Key = "spellHitBuffSnapshot"; Sheet = "Buff"; Cell = "J52"; Note = "Workbook hit bonus aggregate snapshot." }
)

$values = @{}
$currentSheet = ""
foreach ($line in Get-Content -Path $inventoryPath) {
    if ($line -match '^=== SHEET: ([^\s]+) ') {
        $currentSheet = $Matches[1]
        continue
    }
    if ($line -match '^([A-Z]+[0-9]+)\s+\|\s+F=.*\|\s+V=(.+)$') {
        $key = "$currentSheet!$($Matches[1])"
        if (-not $values.ContainsKey($key)) {
            $raw = $Matches[2].Trim()
            $num = 0.0
            if ([double]::TryParse($raw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
                $values[$key] = $num
            }
        }
    }
}

foreach ($mapping in $targetMappings) {
    $lookup = "$($mapping.Sheet)!$($mapping.Cell)"
    if (-not $values.ContainsKey($lookup)) {
        throw "Missing mapped spreadsheet value for $lookup"
    }
    $mapping.Value = [double]$values[$lookup]
}

$defaults = @{
    sheetCritSnapshot = ($targetMappings | Where-Object Key -eq "sheetCritSnapshot").Value
    sheetHitSnapshot = ($targetMappings | Where-Object Key -eq "sheetHitSnapshot").Value
    shadowDamageMult = ($targetMappings | Where-Object Key -eq "shadowDamageMult").Value
    fireDamageMult = ($targetMappings | Where-Object Key -eq "fireDamageMult").Value
    threatAdjustment = ($targetMappings | Where-Object Key -eq "threatAdjustment").Value
    shadowThreatMult = 1.0 - (($targetMappings | Where-Object Key -eq "threatAdjustment").Value)
    fireThreatMult = 1.0
    spellPowerBuffSnapshot = ($targetMappings | Where-Object Key -eq "spellPowerBuffSnapshot").Value
    spellHitBuffSnapshot = ($targetMappings | Where-Object Key -eq "spellHitBuffSnapshot").Value
}

function Format-LuaNumber([double]$value) {
    return $value.ToString("0.###############", [System.Globalization.CultureInfo]::InvariantCulture)
}

$generatedAt = Get-Date -Format 'yyyy-MM-dd'
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('TextAdventurerWarlockSheetData = {')
$lines.Add('  sourceWorkbook = "release/Zephans_Warlock_Simulation.xlsx",')
$lines.Add('  sourceInventory = "release/warlock_formula_inventory.txt",')
$lines.Add(('  generatedAt = "{0}",' -f $generatedAt))
$lines.Add('  defaults = {')
foreach ($key in 'sheetCritSnapshot','sheetHitSnapshot','shadowDamageMult','fireDamageMult','threatAdjustment','shadowThreatMult','fireThreatMult','spellPowerBuffSnapshot','spellHitBuffSnapshot') {
    $lines.Add(('    {0} = {1},' -f $key, (Format-LuaNumber([double]$defaults[$key]))))
}
$lines.Add('  },')
$lines.Add('  mappings = {')
foreach ($mapping in $targetMappings) {
    $lines.Add(('    {0} = {{' -f $mapping.Key))
    $lines.Add(('      sheet = "{0}",' -f $mapping.Sheet))
    $lines.Add(('      cell = "{0}",' -f $mapping.Cell))
    $lines.Add(('      value = {0},' -f (Format-LuaNumber([double]$mapping.Value))))
    $lines.Add(('      note = "{0}",' -f $mapping.Note))
    $lines.Add('    },')
}
$lines.Add('  },')
$lines.Add('}')

Set-Content -Path $outputPath -Value ($lines -join "`r`n") -Encoding UTF8
Write-Output "Generated $outputPath from $inventoryPath"