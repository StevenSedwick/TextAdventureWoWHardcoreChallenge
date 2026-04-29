# Download and install Lua 5.1 for Windows
# This script downloads Lua from GitHub and extracts it to a local directory

param(
    [string]$InstallPath = "C:\Tools\Lua"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=================================================="
Write-Host "Lua 5.1 Installation Script"
Write-Host "=================================================="
Write-Host ""

# Create install directory
if (-not (Test-Path $InstallPath)) {
    Write-Host "[CREATE] Creating directory: $InstallPath"
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Download Lua for Windows
$luaUrl = "https://github.com/rjpcomputing/luaforwindows/releases/download/v5.1.5-52/LuaForWindows_v5.1.5-52.exe"
$downloadPath = "$env:TEMP\lua-installer.exe"

Write-Host "[DOWNLOAD] Downloading Lua from GitHub..."
Write-Host "URL: $luaUrl"

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($luaUrl, $downloadPath)
    Write-Host "[OK] Download complete"
    Write-Host "     Size: $((Get-Item $downloadPath).Length) bytes"
} catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    exit 1
}

# Install Lua
Write-Host ""
Write-Host "[INSTALL] Running Lua installer..."
Write-Host "This will open the Lua installer window."
Write-Host "Please follow the prompts and install to: $InstallPath"
Write-Host ""

try {
    Start-Process -FilePath $downloadPath -Wait
    Write-Host "[OK] Lua installation completed"
} catch {
    Write-Host "[ERROR] Installation failed: $_" -ForegroundColor Red
    exit 1
}

# Verify Lua installation
Write-Host ""
Write-Host "[VERIFY] Checking Lua installation..."

$luaExe = "$InstallPath\lua.exe"
if (Test-Path $luaExe) {
    Write-Host "[OK] Lua found at: $luaExe"
    & $luaExe -v
} else {
    Write-Host "[WARNING] Lua executable not found at: $luaExe" -ForegroundColor Yellow
    Write-Host "Check your installation path and try again."
}

# Add to PATH if not already there
Write-Host ""
Write-Host "[PATH] Adding Lua to system PATH..."

$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$InstallPath*") {
    $newPath = "$InstallPath;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "[OK] Added to PATH (restart terminal to take effect)"
} else {
    Write-Host "[OK] Already in PATH"
}

Write-Host ""
Write-Host "=================================================="
Write-Host "Installation Complete!"
Write-Host "=================================================="
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Close this terminal completely"
Write-Host "2. Open a new terminal"
Write-Host "3. Verify: lua -v"
Write-Host "4. Run tests: lua test\test-runner.lua . interactive"
Write-Host ""
