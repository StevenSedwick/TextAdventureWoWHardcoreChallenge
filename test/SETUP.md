# Setup and Installation Guide for TextAdventurer Test Environment

## Overview

The TextAdventurer test environment lets you iterate on addon code **without restarting the WoW client**. Changes reload in milliseconds instead of minutes.

## System Requirements

- **Lua 5.1** (the same version used by WoW)
- **Windows 10/11** (or any OS with Lua support)
- **VS Code** (optional, but provides task integration)

## Installation

### Step 1: Install Lua 5.1

#### Option A: Chocolatey (Recommended - Easiest)

If you have Chocolatey installed:

```powershell
choco install lua
```

Then restart your terminal/VS Code.

#### Option B: Automated PowerShell Setup

Run the included setup script:

```powershell
.vscode/scripts/setup-test-environment.ps1
```

This will:
- Check if Lua is installed
- Offer to install via Chocolatey
- Verify everything works

#### Option C: Manual Installation

1. Download [Lua for Windows](https://github.com/rjpcomputing/luaforwindows/releases)
2. Extract to a folder (e.g., `C:\Tools\Lua`)
3. Add to Windows PATH:
   - Right-click "This PC" → Properties → Advanced system settings
   - Environment Variables → System variables → Path → Edit
   - Add `C:\Tools\Lua` (or your extraction folder)
4. Restart terminal/VS Code

#### Verify Installation

Open PowerShell/CMD and run:

```cmd
lua -v
```

Should output: `Lua 5.1.x` or similar

### Step 2: Verify Test Environment

Run the setup verification:

```powershell
cd "c:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\TextAdventurer"
test/setup.bat
```

You should see: `[OK] Lua is installed`

## Using the Test Environment

### Interactive Console (Real-Time Testing)

```bash
lua test/test-runner.lua . interactive
```

This opens a REPL where you can type commands and see output instantly:

```
> health
Health: 2000 / 2000 (100%)

> stats
Character Stats:
  Level: 60
  Class: Warrior
  Race: Human
  ...

> help
Available commands:
  help              - Show this help
  health            - Show player health
  ...

> # Use Shift+Enter for multiline
> # Type a command on each line
> stats
> health
> actions bar1

> exit
[Exiting test console]
```

### Batch Test Suite

```bash
lua test/test-runner.lua . batch
```

Runs predefined tests and reports results:

```
[TEST] Health Status Command                   ✓ PASS
[TEST] Character Stats                        ✓ PASS
[TEST] Equipment/Gear Info                    ✓ PASS
[TEST] Action Bars (all)                      ✓ PASS
[TEST] Action Bars (range 1-12)               ✓ PASS
[TEST] Warrior Prompt                         ✓ PASS
[TEST] Seal DPS List                          ✓ PASS
[TEST] Help - Main                            ✓ PASS
[TEST] Multiline Block (comment + command)    ✓ PASS

Results: 9 passed, 0 failed
```

### VS Code Integration

If using VS Code:

1. Open Command Palette: `Ctrl+Shift+P`
2. Type "Run Interactive" or "Run Batch"
3. Press Enter

Or create keyboard shortcuts in `.vscode/keybindings.json`:

```json
[
  {
    "key": "ctrl+shift+alt+t",
    "command": "workbench.action.tasks.runTask",
    "args": "Run Interactive Test Console"
  },
  {
    "key": "ctrl+shift+alt+b",
    "command": "workbench.action.tasks.runTask",
    "args": "Run Batch Tests"
  }
]
```

## Workflow Examples

### Example 1: Quick Command Testing

You're implementing a new command handler and want to test it instantly:

```bash
lua test/test-runner.lua . interactive
> mycommand arg1 arg2
[OUTPUT] Command executed
> mycommand arg1 arg2 --flag
[OUTPUT] Command executed with flag
> exit
```

**Result**: Instant feedback without restarting WoW.

### Example 2: Debugging Command Routing

You added a pattern handler but it's not matching:

```bash
lua test/test-runner.lua . interactive
> help mypattern
[OUTPUT] Help for mypattern
> mypattern test
[OUTPUT] Pattern executed
```

**Result**: Identify issues without game restart.

### Example 3: Pre-Release Validation

Before releasing v0.3-alpha10, run the test suite:

```bash
lua test/test-runner.lua . batch
```

**Result**: Catch regressions in core commands.

## Architecture Details

### File Structure

```
TextAdventurer/
├── test/
│   ├── wow-api-mock.lua       # WoW API stubs & test data
│   ├── test-runner.lua        # Main test harness
│   ├── setup.bat              # Windows setup verification
│   └── README.md              # Detailed test documentation
├── .vscode/
│   ├── scripts/
│   │   ├── setup-test-environment.ps1  # Automated Lua setup
│   │   └── ...
│   └── tasks.json             # VS Code task definitions
├── textadventurer.lua         # Main addon
├── Modules/                   # Command handlers
└── ...
```

### How It Works

1. **`wow-api-mock.lua`** provides fake WoW functions:
   - `GetItemInfo()`, `UnitHealth()`, `CreateFrame()`, etc.
   - Pre-populated with test data (player, items, spells)
   - Mock output capture for assertions

2. **`test-runner.lua`** is the orchestrator:
   - Loads mocks and injects into global environment
   - Loads `TextAdventurer.lua` and all modules
   - Provides REPL or batch test execution
   - Captures output for analysis

3. **Command Flow**:
   ```
   User Input → TA_ProcessInputCommand() → Handlers → Output
   ```

## Customizing Tests

### Add Test Data

Edit `wow-api-mock.lua` to modify:

```lua
-- Change player stats
units.player.health = 1500
units.player.mana = 2000

-- Add inventory items
local itemDatabase = {
  [12345] = { name = "My Item", ... }
}

-- Add spells
local spellDatabase = {
  [9999] = { name = "My Spell", ... }
}
```

### Add Test Cases

Edit `test-runner.lua`:

```lua
local tests = {
  {
    name = "My New Feature",
    command = "mycommand arg1 arg2",
    expectOutput = true,
  },
  -- ...
}
```

## Troubleshooting

### Lua not found after installation

Restart VS Code completely (File → Close Window).

### Command fails with "Unknown input"

Make sure the command is registered in `Modules/Commands.lua`:

```lua
TA.EXACT_INPUT_HANDLERS.mycommand = function() ... end
```

### Test output is empty

Check that:
1. Mock functions are registered in `MockWoWAPI.GetMockGlobals()`
2. `CreateFrame` calls succeed
3. Command doesn't require UI frames (mock `CreateFrame` has limits)

### Performance is slow

Test environment should be <100ms per command. If slower:
1. Check for infinite loops in handlers
2. Reduce test data size (fewer items/spells)
3. Profile with `lua -l luadebug test-runner.lua`

## Next Steps

1. Install Lua 5.1
2. Run `test/setup.bat` to verify
3. Try interactive mode: `lua test/test-runner.lua . interactive`
4. Explore the test documentation: `test/README.md`
5. Add test cases for your new features
6. Integrate into your development workflow

## Advanced Usage

### Continuous Testing

Watch for file changes and auto-run tests:

```powershell
# PowerShell: watch and re-run tests every 2 seconds
while ($true) {
  lua test/test-runner.lua . batch
  Write-Host "Waiting 2s..."
  Start-Sleep -Seconds 2
}
```

### Performance Profiling

Time command execution:

```lua
local TestHarness = require("test.test-runner")
local start = os.clock()
TestHarness.ExecuteCommand("mycommand")
local elapsed = (os.clock() - start) * 1000
print(string.format("Execution time: %.2fms", elapsed))
```

### Export Test Results

```bash
lua test/test-runner.lua . batch > test_results.txt
```

## Support

For issues with the test environment:
- Check `test/README.md` for detailed documentation
- Review `wow-api-mock.lua` to understand available APIs
- Look at `test-runner.lua` implementation for testing patterns

---

**Happy testing! 🚀**
