# TextAdventurer Test Environment Setup Script
# Checks for Lua and offers to install it via Chocolatey

param(
    [switch]$InstallLua = $false,
    [switch]$RunTests = $false
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=" * 60
Write-Host "TextAdventurer Test Environment Setup"
Write-Host "=" * 60
Write-Host ""

# ============================================================================
# Check for Lua
# ============================================================================

Write-Host "[CHECK] Looking for Lua 5.1..."

$luaFound = $null
try {
    $luaVersion = lua -v 2>&1
    if ($LASTEXITCODE -eq 0) {
        $luaFound = $true
        Write-Host "[OK] Lua is installed" -ForegroundColor Green
        Write-Host "     $luaVersion" -ForegroundColor Gray
    }
} catch {
    $luaFound = $false
}

if (-not $luaFound) {
    Write-Host "[ERROR] Lua is not installed or not in PATH" -ForegroundColor Red
    Write-Host ""
    
    # Check if Chocolatey is available
    $chocoFound = $null
    try {
        $chocoVersion = choco --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $chocoFound = $true
        }
    } catch {
        $chocoFound = $false
    }
    
    if ($chocoFound -and -not $InstallLua) {
        Write-Host "Chocolatey is installed. Would you like to install Lua 5.1?" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Option 1: Install via Chocolatey (recommended)"
        Write-Host "  Run: $PSCommandPath -InstallLua"
        Write-Host ""
        Write-Host "Option 2: Install manually"
        Write-Host "  Download: https://github.com/rjpcomputing/luaforwindows/releases"
        Write-Host "  Extract and add to PATH"
        Write-Host ""
        
        $response = Read-Host "Install Lua via Chocolatey now? (y/n)"
        if ($response -eq 'y' -or $response -eq 'yes') {
            $InstallLua = $true
        }
    }
    
    if ($InstallLua) {
        if (-not $chocoFound) {
            Write-Host "[ERROR] Chocolatey not found. Please install it first:" -ForegroundColor Red
            Write-Host "  https://chocolatey.org/install"
            Write-Host ""
            exit 1
        }
        
        Write-Host ""
        Write-Host "[INSTALL] Installing Lua via Chocolatey..." -ForegroundColor Cyan
        Write-Host "(This may require administrator privileges)"
        Write-Host ""
        
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if (-not $isAdmin) {
            Write-Host "[ERROR] Please run PowerShell as Administrator to install Lua" -ForegroundColor Red
            exit 1
        }
        
        try {
            choco install lua -y
            Write-Host ""
            Write-Host "[OK] Lua installation complete!" -ForegroundColor Green
            Write-Host "Please restart your terminal or VS Code for changes to take effect."
            Write-Host ""
            $luaFound = $true
        } catch {
            Write-Host "[ERROR] Failed to install Lua: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Please install Lua 5.1 manually and try again." -ForegroundColor Yellow
        exit 1
    }
}

# ============================================================================
# Verify Test Environment
# ============================================================================

if ($luaFound) {
    Write-Host ""
    Write-Host "[CHECK] Verifying test environment files..."
    Write-Host ""
    
    $workspaceFolder = Split-Path -Parent $PSScriptRoot | Split-Path -Parent
    $testFiles = @(
        "test\wow-api-mock.lua",
        "test\test-runner.lua",
        "test\README.md",
        "test\SETUP.md",
        ".vscode\tasks.json"
    )
    
    $allFound = $true
    foreach ($file in $testFiles) {
        $filePath = Join-Path $workspaceFolder $file
        if (Test-Path $filePath) {
            Write-Host "[OK]   $file" -ForegroundColor Green
        } else {
            Write-Host "[MISS] $file" -ForegroundColor Yellow
            $allFound = $false
        }
    }
    
    Write-Host ""
    
    if ($allFound) {
        Write-Host "=" * 60
        Write-Host "Test Environment is Ready!" -ForegroundColor Green
        Write-Host "=" * 60
        Write-Host ""
        Write-Host "You can now run tests:"
        Write-Host ""
        Write-Host "  Interactive mode (REPL):"
        Write-Host "    lua test\test-runner.lua . interactive"
        Write-Host ""
        Write-Host "  Batch tests:"
        Write-Host "    lua test\test-runner.lua . batch"
        Write-Host ""
        Write-Host "Or via VS Code:"
        Write-Host "  Ctrl+Shift+P > Run Interactive Test Console"
        Write-Host "  Ctrl+Shift+P > Run Batch Tests"
        Write-Host ""
        Write-Host "For detailed documentation:"
        Write-Host "  - test/SETUP.md     (Setup and usage guide)"
        Write-Host "  - test/README.md    (Technical documentation)"
        Write-Host ""
        
        if ($RunTests) {
            Write-Host "[RUN] Running batch tests..."
            Write-Host ""
            & lua test\test-runner.lua $workspaceFolder batch
        }
    } else {
        Write-Host "Some test files are missing. Please ensure you're in the TextAdventurer" -ForegroundColor Yellow
        Write-Host "addon folder and that all test files were created correctly."
        Write-Host ""
        exit 1
    }
}

Write-Host ""
