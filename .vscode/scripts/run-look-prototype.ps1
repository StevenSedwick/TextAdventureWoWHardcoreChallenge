param(
    [string]$WorkspaceFolder = $(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$Mode = "placeholder",
    [string]$WeightsPath = "",
    [string]$LabelsPath = "",
    [string]$ModelDir = "",
    [string]$Zone = "",
    [string]$MapId = "",
    [string]$X = "",
    [string]$Y = "",
    [string]$Facing = "",
    [string]$Pitch = "",
    [string]$Zoom = "",
    [switch]$Watch = $false,
    [switch]$KeepScreenshot = $false
)

$ErrorActionPreference = "Stop"

$pythonCandidates = @("python", "py")
$pythonCmd = $null

foreach ($candidate in $pythonCandidates) {
    try {
        & $candidate --version *> $null
        if ($LASTEXITCODE -eq 0) {
            $pythonCmd = $candidate
            break
        }
    } catch {
    }
}

if (-not $pythonCmd) {
    Write-Error "Python not found. Install Python 3.10+ first."
    exit 1
}

$scriptPath = Join-Path $WorkspaceFolder "tools\look_accessibility\look_capture_service.py"
if (-not (Test-Path $scriptPath)) {
    Write-Error "Missing script: $scriptPath"
    exit 1
}

$args = @(
    $scriptPath,
    "--model-mode", $Mode,
    "--output-dir", (Join-Path $WorkspaceFolder "tools\look_accessibility\temp")
)

if ($Mode -eq "local") {
    if ([string]::IsNullOrWhiteSpace($WeightsPath)) {
        $WeightsPath = Join-Path $WorkspaceFolder "tools\look_accessibility\model\tiny_scene.onnx"
    }
    if ([string]::IsNullOrWhiteSpace($LabelsPath)) {
        $LabelsPath = Join-Path $WorkspaceFolder "tools\look_accessibility\model\labels.txt"
    }
    $args += @("--weights-path", $WeightsPath, "--labels-path", $LabelsPath)
}

if ($Mode -eq "joblib") {
    if ([string]::IsNullOrWhiteSpace($ModelDir)) {
        $ModelDir = Join-Path $WorkspaceFolder "tools\look_accessibility\model"
    }
    $args += @("--model-dir", $ModelDir)

    if (-not [string]::IsNullOrWhiteSpace($Zone)) { $args += @("--zone", $Zone) }
    if (-not [string]::IsNullOrWhiteSpace($MapId)) { $args += @("--map-id", $MapId) }
    if (-not [string]::IsNullOrWhiteSpace($X)) { $args += @("--x", $X) }
    if (-not [string]::IsNullOrWhiteSpace($Y)) { $args += @("--y", $Y) }
    if (-not [string]::IsNullOrWhiteSpace($Facing)) { $args += @("--facing", $Facing) }
    if (-not [string]::IsNullOrWhiteSpace($Pitch)) { $args += @("--pitch", $Pitch) }
    if (-not [string]::IsNullOrWhiteSpace($Zoom)) { $args += @("--zoom", $Zoom) }
}

if ($Watch) {
    $args += "--watch"
}

if ($KeepScreenshot) {
    $args += "--keep-screenshot"
}

Write-Host "Running /look prototype with $pythonCmd"
& $pythonCmd @args
exit $LASTEXITCODE
