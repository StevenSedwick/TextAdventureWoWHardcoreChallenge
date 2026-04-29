param(
    [string]$WorkspaceFolder = $(Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = "Stop"

$luaCandidates = @(
    "lua",
    "C:\Program Files (x86)\Lua\5.1\lua.exe",
    "C:\Program Files\Lua\5.1\lua.exe"
)

$luaCommand = $null
foreach ($candidate in $luaCandidates) {
    if ($candidate -eq "lua") {
        try {
            $null = & lua -v 2>$null
            if ($LASTEXITCODE -eq 0) {
                $luaCommand = "lua"
                break
            }
        } catch {
        }
    } elseif (Test-Path $candidate) {
        $luaCommand = $candidate
        break
    }
}

if (-not $luaCommand) {
    Write-Error "Lua not found. Run the 'Setup Test Environment' task first."
    exit 1
}

$runnerPath = Join-Path $WorkspaceFolder "test\test-runner.lua"
if (-not (Test-Path $runnerPath)) {
    Write-Error "Test runner not found at $runnerPath"
    exit 1
}

Write-Host "Running batch tests with: $luaCommand"
& $luaCommand $runnerPath $WorkspaceFolder "batch"
exit $LASTEXITCODE
