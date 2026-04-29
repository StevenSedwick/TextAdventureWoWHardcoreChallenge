# TextAdventurer Standalone Test Environment

A lightweight Lua test harness for TextAdventurer that runs without the full WoW game client. This enables fast iteration on addon code, command routing, calculations, and UI logic.

## Quick Start

### Prerequisites
- **Lua 5.1** installed on your system
  - **Windows**: Install via [Lua for Windows](https://github.com/rjpcomputing/luaforwindows) or [Chocolatey](https://chocolatey.org/packages/lua)
  - **macOS**: `brew install lua`
  - **Linux**: `apt-get install lua5.1`

### Interactive Test Console

Run the addon in an interactive terminal where you can type commands and see output in real-time:

**Via VS Code:**
- Open Command Palette: `Ctrl+Shift+P`
- Search for "Run Interactive Test Console"
- Or use keyboard shortcut if defined

**Via Terminal:**
```bash
cd c:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\TextAdventurer
lua test/test-runner.lua . interactive
```

Once running, you can type any TextAdventurer command:
```
> health
> stats
> gear
> actions 1 12
> warriorprompt status
> sealdps list
> help combat
```

### Batch Tests

Run predefined test cases to validate core functionality:

**Via VS Code:**
- Open Command Palette: `Ctrl+Shift+P`
- Search for "Run Batch Tests"

**Via Terminal:**
```bash
lua test/test-runner.lua . batch
```

Output example:
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

## Architecture

### Components

#### `wow-api-mock.lua`
Provides realistic mocks of WoW APIs that the addon depends on:

- **Item System**: `GetItemInfo`, `GetItemStats`, `C_Container.*`
- **Unit System**: `UnitHealth`, `UnitMana`, `UnitLevel`, `UnitName`, `UnitClass`
- **Spell System**: `GetSpellInfo`, `GetSpellCooldown`
- **UI Framework**: `CreateFrame`, `CreateFramePool`, chat functions
- **Economy**: `GetMoney`, `FormatMoney`
- **Libraries**: Ace3 stubs (`LibStub`, event/console interfaces)

Pre-populated with test data:
- Default player (Warrior level 60)
- Sample inventory items (Perdition's Blade, Nightblade, etc.)
- Sample spells (Mortal Strike, Thunder Clap, etc.)

#### `test-runner.lua`
Main entry point that:
1. Loads WoW API mocks
2. Injects them into the global environment
3. Loads the full TextAdventurer addon code
4. Provides a test harness for command execution
5. Supports interactive and batch testing modes

### Data Flow

```
test-runner.lua
    ↓
[Load WoW API Mocks]
    ↓
[Inject into _G]
    ↓
[Load TextAdventurer.lua]
    ↓
[Load Modules/* files]
    ↓
[User Input] → [TA_ProcessInputCommand] → [Output Capture]
```

## Testing Patterns

### Interactive Testing

Useful for exploratory testing and debugging:

```
> health
[CHAT] Health: 2000 / 2000 (100%)

> actions bar1
[CHAT] Bar 1: [Empty] [Empty] [Empty] [Empty] [Empty] [Empty] [Empty] [Empty] [Empty] [Empty] [Empty] [Empty]

> warriorprompt status
[CHAT] Warrior Prompt: Enabled

> # multiline with comments
> health
> stats
[OUTPUT] (executes both lines, skips comment)
```

### Batch Testing

The test harness includes predefined tests for core functionality. Add new tests in `test-runner.lua`:

```lua
local tests = {
  {
    name = "My Feature",
    command = "mycommand arg1 arg2",
    expectOutput = true,
  },
  -- ...
}
```

## Customizing the Mock Environment

### Modify Player Stats

In `wow-api-mock.lua`:

```lua
local units = {
  player = {
    name = "TestCharacter",
    level = 60,
    class = "MAGE",  -- Change class
    health = 1500,
    healthMax = 1500,
    mana = 2000,
    manaMax = 2000,
  },
  -- ...
}
```

### Add Items to Inventory

```lua
local itemDatabase = {
  [18832] = { name = "Perdition's Blade", rarity = 4, level = 60, ... },
  [99999] = { name = "My Custom Item", rarity = 3, level = 50, ... },
}

local inventorySlots = {
  [1] = { itemID = 18832, ... },
  [2] = { itemID = 99999, ... },
}
```

### Add Spells

```lua
local spellDatabase = {
  [100] = { name = "Mortal Strike", ... },
  [9999] = { name = "My Custom Spell", icon = "...", school = "fire" },
}
```

### Add Frames for UI Testing

The `CreateFrame` mock supports:
- Showing/hiding: `frame:Show()`, `frame:Hide()`, `frame:IsVisible()`
- Sizing: `frame:SetSize(w, h)`, `frame:GetSize()`
- Positioning: `frame:SetPoint()`
- Text: `frame:SetText()`, `frame:GetText()`
- Textures: `frame:SetTexture()`, `frame:SetNormalTexture()`
- Events: `frame:SetScript()`, `frame:GetScript()`

## Extending Tests

### Adding a Custom Test

Edit `test-runner.lua` and add to the `tests` table:

```lua
{
  name = "Warlock DPS Calculation",
  command = "warlockdps",
  expectOutput = true,
}
```

### Programmatic Test Execution

```lua
local TestHarness = require("test.test-runner")
local success, output, chatMessages = TestHarness.ExecuteCommand("mycommand")

if success then
  print("Command executed successfully")
  for _, msg in ipairs(chatMessages) do
    print("Output: " .. msg)
  end
else
  print("Error: " .. tostring(output))
end
```

## Limitations

The mock environment provides **functional testing** but not full **integration testing**:

- ✅ Command routing and handlers
- ✅ Data lookups and calculations
- ✅ String formatting and output
- ✅ Logic branches and state management
- ❌ Real WoW UI rendering
- ❌ Protected function calls (CastSpellByName, secure actions)
- ❌ Real event system with frame registration
- ❌ Texture/font rendering
- ❌ Real network calls

For UI/rendering validation, test in-game in WoW Classic Era.

## Performance

The test environment loads and runs commands in **milliseconds** (vs. 10-60 seconds for game client):

- Initial load: ~100-200ms
- Per-command execution: 1-5ms
- Full batch test suite: ~50ms

This enables **rapid iteration** on logic and calculations.

## Troubleshooting

### "Lua not found"
Ensure Lua 5.1 is installed and in your PATH.

```bash
lua -v  # Should print version 5.1.x
```

### Command execution fails silently
Check that:
1. `TextAdventurer.lua` loads without errors (check console output)
2. Command name is correct (case-sensitive)
3. Mock functions are properly registered in `wow-api-mock.lua`

### Missing WoW API
Add the missing function to `wow-api-mock.lua`:

```lua
function MyMissingFunction(arg)
  return someValue
end

MockWoWAPI.GetMockGlobals = function()
  return {
    -- ...
    MyMissingFunction = MyMissingFunction,
  }
end
```

## Future Enhancements

Potential improvements:
- [ ] Visual UI preview (ASCII rendering of frames)
- [ ] Performance profiling (execution time per command)
- [ ] Code coverage analysis
- [ ] CI/CD integration (GitHub Actions, GitLab CI)
- [ ] Snapshot testing (capture output and compare)
- [ ] Memory profiling (detect leaks)
- [ ] Debugger integration (breakpoints, step-through)

## See Also

- [TextAdventurer README](../README.md)
- [WoW Classic API Documentation](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [Lua 5.1 Manual](https://www.lua.org/manual/5.1/)
