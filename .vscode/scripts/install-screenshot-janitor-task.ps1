# Registers a Windows Scheduled Task that runs the WoW screenshot janitor
# at user logon, hidden, and keeps it running for the whole session.
# Idempotent: re-running replaces the existing task.

[CmdletBinding()]
param(
    [string]$TaskName = "TextAdventurer-ScreenshotJanitor",
    [string]$JanitorScript = "",
    [string]$PythonExe = "",
    [double]$Interval = 0.25
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path

if (-not $JanitorScript) {
    $JanitorScript = Join-Path $addonRoot "tools\look_accessibility\screenshot_janitor.py"
}
$JanitorScript = (Resolve-Path -LiteralPath $JanitorScript).Path

if (-not $PythonExe) {
    $venvPythonW = Join-Path $addonRoot ".venv\Scripts\pythonw.exe"
    $venvPython = Join-Path $addonRoot ".venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $venvPythonW) {
        $PythonExe = (Resolve-Path -LiteralPath $venvPythonW).Path
    } elseif (Test-Path -LiteralPath $venvPython) {
        $PythonExe = (Resolve-Path -LiteralPath $venvPython).Path
    } else {
        $cmd = Get-Command pythonw -ErrorAction SilentlyContinue
        if ($null -eq $cmd) { $cmd = Get-Command python -ErrorAction SilentlyContinue }
        if ($null -eq $cmd) { throw "python not found on PATH and no venv detected." }
        $PythonExe = $cmd.Source
    }
}

Write-Host "Task name : $TaskName"
Write-Host "Python    : $PythonExe"
Write-Host "Script    : $JanitorScript"
Write-Host "Interval  : $Interval s"

$pwshExe = (Get-Command powershell.exe).Source

# Have the task invoke pythonw.exe directly so the process persists.
# pythonw avoids any console window even on python.exe-style envs.
$action = New-ScheduledTaskAction -Execute $PythonExe `
    -Argument "`"$JanitorScript`" --interval $Interval --quiet"

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task."
}

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal | Out-Null

Write-Host "Registered. Starting now..."
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 1

$running = Get-Process -Name python -ErrorAction SilentlyContinue `
    | Where-Object { $_.Path -eq $PythonExe }
if ($running) {
    Write-Host "Janitor PID(s): $($running.Id -join ', ')"
} else {
    Write-Warning "No matching python process found yet. Check Task Scheduler if the screenshots don't clear."
}

Write-Host "Done. To remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
