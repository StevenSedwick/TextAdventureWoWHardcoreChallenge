# Automated Lua 5.1 installation without GUI
# This downloads a portable Lua version and sets it up

$ErrorActionPreference = "Stop"

$InstallPath = "C:\Tools\Lua"
$downloadUrl = "https://github.com/rjpcomputing/luaforwindows/releases/download/v5.1.5-52/LuaForWindows_v5.1.5-52.exe"

Write-Host ""
Write-Host "=================================================="
Write-Host "Lua 5.1 Installation (Non-Interactive)"
Write-Host "=================================================="
Write-Host ""

# Kill any existing installer processes
Write-Host "[CLEANUP] Stopping any existing Lua installer processes..."
Get-Process lua* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Create install directory
if (-not (Test-Path $InstallPath)) {
    Write-Host "[CREATE] Creating: $InstallPath"
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Download
$downloadPath = "$env:TEMP\lua-installer.exe"
Write-Host "[DOWNLOAD] Getting Lua from GitHub..."

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $downloadPath)
    Write-Host "[OK] Downloaded: $downloadPath"
} catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    exit 1
}

# Try silent install with /S flag
Write-Host "[INSTALL] Installing Lua (silent mode)..."
try {
    $process = Start-Process -FilePath $downloadPath -ArgumentList "/S", "/D=$InstallPath" -Wait -PassThru -NoNewWindow
    Write-Host "[OK] Installation completed (exit code: $($process.ExitCode))"
} catch {
    Write-Host "[WARNING] Silent install may not be fully supported" -ForegroundColor Yellow
}

# Wait a moment for file system to settle
Start-Sleep -Seconds 2

# Check if Lua executable exists
$luaExe = "$InstallPath\lua.exe"
if (Test-Path $luaExe) {
    Write-Host "[OK] Lua executable found at: $luaExe"
    Write-Host ""
    Write-Host "Lua version:"
    & $luaExe -v 2>&1
} else {
    Write-Host "[ERROR] Lua.exe not found at expected location: $luaExe" -ForegroundColor Red
    Write-Host ""
    Write-Host "Contents of $InstallPath:"
    Get-ChildItem ${InstallPath} -ErrorAction SilentlyContinue
    exit 1
}

# Add to PATH
Write-Host ""
Write-Host "[PATH] Configuring system PATH..."
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($currentPath -notlike "*$InstallPath*") {
    Write-Host "Adding $InstallPath to PATH..."
    $newPath = "$InstallPath;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "[OK] PATH updated"
} else {
    Write-Host "[OK] Already in PATH"
}

# Verify global access
Write-Host ""
Write-Host "[VERIFY] Testing Lua from PATH..."
$testLua = & cmd /c "where lua.exe 2>nul || echo NOT_FOUND"

if ($testLua -like "*lua.exe*") {
    Write-Host "[OK] Lua is accessible globally:"
    Write-Host "     $testLua"
} else {
    Write-Host "[WARNING] Lua not yet accessible from PATH (terminal restart needed)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=================================================="
Write-Host "Installation Complete!"
Write-Host "=================================================="
Write-Host ""
Write-Host "IMPORTANT: Close this terminal and open a new one"
Write-Host "for the PATH changes to take effect."
Write-Host ""
Write-Host "Then test with: lua -v"
Write-Host ""

# Clean up
Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

Write-Host ""
