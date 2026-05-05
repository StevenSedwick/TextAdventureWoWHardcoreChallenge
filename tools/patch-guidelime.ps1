# patch-guidelime.ps1
#
# Re-applies the one-line TextAdventurer bridge patch to Guidelime so that
# `/ta route` can read the live guide step list. Idempotent. Run after every
# Guidelime update.
#
# Usage (from any working directory):
#   powershell -ExecutionPolicy Bypass -File "<path to>\patch-guidelime.ps1"
#
# What it does:
#   In Guidelime\Guidelime.lua, replaces
#       if addon.debugging then Guidelime.addon = addon end
#   with
#       Guidelime.addon = addon -- TEXTADVENTURER_PATCH: ...
#
# Exit codes:
#   0 = patch applied OR already present (success)
#   1 = Guidelime not found
#   2 = patch target line not found (Guidelime structure changed; manual edit needed)

[CmdletBinding()]
param(
    [string]$AddOnsDir = "${Env:ProgramFiles(x86)}\World of Warcraft\_classic_era_\Interface\AddOns",
    [string]$AlternateAddOnsDir
)

if ($AlternateAddOnsDir) { $AddOnsDir = $AlternateAddOnsDir }

$target = Join-Path $AddOnsDir 'Guidelime\Guidelime.lua'

if (-not (Test-Path -LiteralPath $target)) {
    Write-Error "Guidelime not found at: $target"
    exit 1
}

$content = Get-Content -LiteralPath $target -Raw
$marker  = 'TEXTADVENTURER_PATCH'

if ($content.Contains($marker)) {
    Write-Host "Guidelime patch already present. Nothing to do." -ForegroundColor Green
    exit 0
}

$old = 'if addon.debugging then Guidelime.addon = addon end'
$new = 'Guidelime.addon = addon -- TEXTADVENTURER_PATCH: unconditional export for /ta route bridge'

if (-not $content.Contains($old)) {
    Write-Error "Could not find the expected line in Guidelime.lua. Guidelime may have been updated. Add the following line near the end of Guidelime.addonLoaded() yourself:`n`n    $new"
    exit 2
}

$patched = $content.Replace($old, $new)
Set-Content -LiteralPath $target -Value $patched -NoNewline
Write-Host "Patched: $target" -ForegroundColor Green
Write-Host "Reload UI in WoW (/reload) for the change to take effect." -ForegroundColor Yellow
exit 0
