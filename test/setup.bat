@echo off
REM TextAdventurer Test Environment Setup Helper
REM Checks for Lua and provides installation guidance

setlocal enabledelayedexpansion

echo.
echo =============================================
echo TextAdventurer Test Environment Setup
echo =============================================
echo.

REM Check for Lua
where lua >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  echo [OK] Lua is installed
  echo.
  lua -v
  echo.
  echo You can now run:
  echo   lua test\test-runner.lua . interactive
  echo   lua test\test-runner.lua . batch
  echo.
  echo Or use VS Code tasks:
  echo   Ctrl+Shift+P ^> Run Interactive Test Console
  echo   Ctrl+Shift+P ^> Run Batch Tests
) else (
  echo [ERROR] Lua is not installed or not in PATH
  echo.
  echo Please install Lua 5.1:
  echo.
  echo Option 1: Chocolatey (recommended for Windows^)
  echo   choco install lua
  echo.
  echo Option 2: Manual Download
  echo   Download from: https://github.com/rjpcomputing/luaforwindows/releases
  echo   Extract and add to PATH
  echo.
  echo Option 3: Windows Package Manager
  echo   winget install Lua.Lua
  echo.
  echo After installation, restart VS Code and try again.
  echo.
  exit /b 1
)

endlocal
