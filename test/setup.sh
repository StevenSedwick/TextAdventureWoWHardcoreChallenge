#!/bin/bash
# TextAdventurer Test Environment Quick Start (macOS/Linux)

set -e

echo ""
echo "============================================================"
echo "TextAdventurer Test Environment Setup (macOS/Linux)"
echo "============================================================"
echo ""

# Check for Lua
echo "[CHECK] Looking for Lua 5.1..."

if command -v lua &> /dev/null; then
    echo "[OK] Lua is installed"
    lua -v
else
    echo "[ERROR] Lua is not installed"
    echo ""
    echo "Please install Lua 5.1:"
    echo ""
    echo "macOS (via Homebrew):"
    echo "  brew install lua"
    echo ""
    echo "Ubuntu/Debian:"
    echo "  sudo apt-get install lua5.1"
    echo ""
    echo "Fedora/RHEL:"
    echo "  sudo dnf install lua"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

echo ""
echo "[CHECK] Verifying test files..."

# Find the TextAdventurer directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FILES=(
    "test/wow-api-mock.lua"
    "test/test-runner.lua"
    "test/README.md"
    "test/SETUP.md"
)

for file in "${FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "[OK]   $file"
    else
        echo "[MISS] $file"
    fi
done

echo ""
echo "============================================================"
echo "Setup Complete!"
echo "============================================================"
echo ""
echo "Run the test environment:"
echo ""
echo "  Interactive mode (REPL):"
echo "    lua test/test-runner.lua . interactive"
echo ""
echo "  Batch tests:"
echo "    lua test/test-runner.lua . batch"
echo ""
echo "For detailed setup instructions:"
echo "  cat test/SETUP.md"
echo ""
echo "For technical documentation:"
echo "  cat test/README.md"
echo ""
