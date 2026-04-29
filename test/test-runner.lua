#!/usr/bin/env lua
-- TextAdventurer Standalone Test Runner
-- Loads the addon code and WoW API mocks to test commands without the game

local workspaceFolder = arg[1] or "."
local testMode = arg[2] or "interactive"

-- ============================================================================
-- Setup: Load WoW API Mocks
-- ============================================================================

print("=" .. string.rep("=", 78))
print("TextAdventurer Standalone Test Environment v0.3-alpha10")
print("=" .. string.rep("=", 78))
print()

-- Package path setup
package.path = package.path .. ";" .. workspaceFolder .. "/?.lua"

local MockWoWAPI = require("test.wow-api-mock")
local mockGlobals = MockWoWAPI.GetMockGlobals()

-- Inject mocks into global environment
for key, value in pairs(mockGlobals) do
  _G[key] = value
end

-- ============================================================================
-- Addon Code Loading
-- ============================================================================

print("[LOADING] TextAdventurer.lua...")
local ok, textAdventurer = pcall(function()
  -- Must set up package.path so requires work
  dofile(workspaceFolder .. "/TextAdventurer.lua")

  -- In-game .toc loading is not available here, so load command modules explicitly.
  local moduleFiles = {
    "Modules/AccessibilityCommands.lua",
    "Modules/Commands.lua",
    "Modules/EconomyCommands.lua",
    "Modules/HelpTopics.lua",
    "Modules/MacroRecipeCommands.lua",
    "Modules/NavigationCommands.lua",
    "Modules/QuestCommands.lua",
    "Modules/SettingsCommands.lua",
    "Modules/SocialCommands.lua",
    "Modules/WarlockMLCommands.lua",
  }

  for _, modulePath in ipairs(moduleFiles) do
    dofile(workspaceFolder .. "/" .. modulePath)
  end
end)

if not ok then
  print("[ERROR] Failed to load TextAdventurer.lua:")
  print(textAdventurer)
  os.exit(1)
end

print("[LOADED] TextAdventurer addon initialized")
print()

-- ============================================================================
-- Test Harness
-- ============================================================================

local TestHarness = {}

-- Output capture for test assertions
local capturedOutput = {}
function TestHarness.CaptureOutput(func)
  capturedOutput = {}
  local oldPrint = print
  local oldChatAdd = ChatFrame1.AddMessage
  
  function print(...)
    table.insert(capturedOutput, table.concat({...}, "\t"))
  end
  
  function ChatFrame1:AddMessage(msg, r, g, b)
    table.insert(capturedOutput, msg)
  end
  
  local ok, result = pcall(func)
  
  print = oldPrint
  ChatFrame1.AddMessage = oldChatAdd
  
  if not ok then
    return false, result, capturedOutput
  end
  return true, result, capturedOutput
end

-- Execute a command and capture output
function TestHarness.ExecuteCommand(command)
  MockWoWAPI.ClearChatMessages()
  
  local success, resultOrError, captured = TestHarness.CaptureOutput(function()
    if TA and TA_ProcessInputCommand then
      TA_ProcessInputCommand(command)
    else
      error("TextAdventurer command processor not found")
    end
  end)
  
  return success, resultOrError, captured, MockWoWAPI.GetChatMessages()
end

-- ============================================================================
-- Interactive Mode
-- ============================================================================

function TestHarness.InteractiveMode()
  print("[MODE] Interactive Test Console")
  print("Type commands to test. Press Ctrl+C to exit.")
  print()
  
  io.write("> ")
  for line in io.lines() do
    if line and line ~= "" then
      local success, output, chatMessages = TestHarness.ExecuteCommand(line)
      
      if not success then
        print("[ERROR]", output)
      else
        if #output > 0 then
          print("[OUTPUT]")
          for _, msg in ipairs(output) do
            print("  " .. msg)
          end
        end
        if #chatMessages > 0 then
          print("[CHAT]")
          for _, msg in ipairs(chatMessages) do
            print("  " .. msg)
          end
        end
      end
      print()
    end
    io.write("> ")
  end
end

-- ============================================================================
-- Batch Test Mode
-- ============================================================================

function TestHarness.RunBatchTests()
  print("[MODE] Batch Test Mode")
  print()
  
  local tests = {
    {
      name = "Health Status Command",
      command = "health",
      expectOutput = true,
    },
    {
      name = "Character Stats",
      command = "stats",
      expectOutput = true,
    },
    {
      name = "Equipment/Gear Info",
      command = "gear",
      expectOutput = true,
    },
    {
      name = "Action Bars (all)",
      command = "actions",
      expectOutput = true,
    },
    {
      name = "Action Bars (range 1-12)",
      command = "actions 1 12",
      expectOutput = true,
    },
    {
      name = "Warrior Prompt",
      command = "warriorprompt status",
      expectOutput = true,
    },
    {
      name = "Seal DPS List",
      command = "sealdps list",
      expectOutput = true,
    },
    {
      name = "Help - Main",
      command = "help",
      expectOutput = true,
    },
    {
      name = "Look Bridge Status",
      command = "look status",
      expectOutput = true,
    },
    {
      name = "Python Bridge Probe",
      command = "py status",
      expectOutput = true,
    },
    {
      name = "Multiline Block (comment + command)",
      command = "# This is a comment\nhealth",
      expectOutput = true,
    },
  }
  
  local passed = 0
  local failed = 0
  
  for _, test in ipairs(tests) do
    io.write(string.format("[TEST] %-40s ", test.name))
    
    local success, resultOrError, captured, chatMessages = TestHarness.ExecuteCommand(test.command)
    local hasOutput = (#captured > 0) or (#chatMessages > 0)
    
    if test.expectOutput then
      if success and hasOutput then
        print("✓ PASS")
        passed = passed + 1
      else
        print("✗ FAIL (no output)")
        failed = failed + 1
        if not success then
          print("  Error: " .. tostring(resultOrError))
        end
      end
    else
      if success then
        print("✓ PASS")
        passed = passed + 1
      else
        print("✗ FAIL")
        failed = failed + 1
      end
    end
  end
  
  print()
  print(string.rep("=", 78))
  print(string.format("Results: %d passed, %d failed", passed, failed))
  print(string.rep("=", 78))
  
  return failed == 0
end

-- ============================================================================
-- Main Entry Point
-- ============================================================================

if testMode == "interactive" or testMode == "repl" then
  TestHarness.InteractiveMode()
elseif testMode == "batch" or testMode == "test" then
  local success = TestHarness.RunBatchTests()
  os.exit(success and 0 or 1)
else
  print("Usage: lua test-runner.lua [workspace-folder] [mode]")
  print("  mode: interactive (default), batch, repl")
  os.exit(1)
end
