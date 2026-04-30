-- Loot roll commands: see and respond to active group-loot Need/Greed popups
-- from chat. Multiple items can be rolling at once; each has a stable rollID
-- assigned by the server. We expose a numbered table of active rolls so you
-- never have to memorize raw IDs.
--
-- /ta rolls                  -> list every active roll (index, item, eligible buttons, time left)
-- /ta need [#]               -> Need on roll # (defaults to 1 when only one is active)
-- /ta greed [#]              -> Greed on roll # (defaults to 1)
-- /ta pass [#]               -> Pass on roll # (defaults to 1)
-- /ta de [#]                 -> Disenchant on roll # (only if eligible)
--
-- Indexes are positional within the current pending-rolls list (sorted by
-- rollID for stability). Use /ta rolls to see them; the index of a given
-- item shifts as other rolls expire, so re-list before acting if unsure.

local function RollLine(text)
  if AddLine then AddLine("system", text) end
end

-- Snapshot of currently pending loot rolls. Each entry: { rollID, link, name, quality, canNeed, canGreed, canDE, timeLeftMs }
-- rollIDs are server-assigned and surfaced via START_LOOT_ROLL; we cache them
-- in TA.activeLootRolls and prune entries whose item info has gone away.
local function TA_GetActiveLootRolls()
  local rolls = {}
  if not GetLootRollItemInfo then
    return rolls
  end
  if type(TA) == "table" and type(TA.activeLootRolls) == "table" then
    for rollID, _ in pairs(TA.activeLootRolls) do
      local texture, name, count2, quality, bindOnPickUp, canNeed, canGreed, canDE = GetLootRollItemInfo(rollID)
      if name then
        local link = GetLootRollItemLink and GetLootRollItemLink(rollID) or name
        local timeLeft = GetLootRollTimeLeft and GetLootRollTimeLeft(rollID) or nil
        rolls[#rolls + 1] = {
          rollID = rollID,
          link = link,
          name = name,
          quality = quality or 0,
          count = count2 or 1,
          canNeed = canNeed and true or false,
          canGreed = canGreed and true or false,
          canDE = canDE and true or false,
          timeLeftMs = timeLeft,
        }
      else
        -- Item info gone -> roll expired. Drop it from tracking.
        TA.activeLootRolls[rollID] = nil
      end
    end
  end
  table.sort(rolls, function(a, b) return a.rollID < b.rollID end)
  return rolls
end

local function FormatRollLine(idx, r)
  local opts = {}
  if r.canNeed then opts[#opts + 1] = "need" end
  if r.canGreed then opts[#opts + 1] = "greed" end
  if r.canDE then opts[#opts + 1] = "de" end
  opts[#opts + 1] = "pass"
  local optStr = table.concat(opts, "/")
  local timeStr = ""
  if r.timeLeftMs and r.timeLeftMs > 0 then
    timeStr = string.format(" (%ds)", math.floor(r.timeLeftMs / 1000))
  end
  local countStr = (r.count and r.count > 1) and (" x" .. r.count) or ""
  return string.format("  [%d] %s%s%s  -> %s", idx, r.link or r.name, countStr, timeStr, optStr)
end

local function TA_ListLootRolls()
  local rolls = TA_GetActiveLootRolls()
  if #rolls == 0 then
    RollLine("No active loot rolls.")
    return
  end
  RollLine(string.format("=== %d active loot roll(s) ===", #rolls))
  for i, r in ipairs(rolls) do
    RollLine(FormatRollLine(i, r))
  end
  RollLine("Use: ta need|greed|pass|de [index]  (default index = 1)")
end

-- Constants per Blizzard API: 0=pass, 1=need, 2=greed, 3=disenchant
local ROLL_PASS, ROLL_NEED, ROLL_GREED, ROLL_DE = 0, 1, 2, 3

local function TA_RollOnIndex(idx, choice, label)
  local rolls = TA_GetActiveLootRolls()
  if #rolls == 0 then
    RollLine("No active loot rolls.")
    return
  end
  idx = tonumber(idx) or 1
  if idx < 1 or idx > #rolls then
    RollLine(string.format("Invalid roll index %d (have %d active).", idx, #rolls))
    return
  end
  local r = rolls[idx]
  if choice == ROLL_NEED and not r.canNeed then
    RollLine(string.format("Cannot Need on %s (not eligible).", r.link or r.name))
    return
  end
  if choice == ROLL_GREED and not r.canGreed then
    RollLine(string.format("Cannot Greed on %s (not eligible).", r.link or r.name))
    return
  end
  if choice == ROLL_DE and not r.canDE then
    RollLine(string.format("Cannot Disenchant on %s (not eligible).", r.link or r.name))
    return
  end
  if not RollOnLoot then
    RollLine("RollOnLoot API unavailable.")
    return
  end
  RollOnLoot(r.rollID, choice)
  RollLine(string.format("Rolled %s on %s.", label, r.link or r.name))
  -- The server will fire CANCEL_LOOT_ROLL for this rollID shortly; clean up
  -- locally too so /ta rolls reflects the new state immediately.
  if TA.activeLootRolls then TA.activeLootRolls[r.rollID] = nil end
end

-- Event hookup: track START_LOOT_ROLL and CANCEL_LOOT_ROLL so we always know
-- which rollIDs are live without needing to brute-force probe IDs.
local function TA_EnsureLootRollEventFrame()
  if TA.lootRollEventFrame then return end
  TA.activeLootRolls = TA.activeLootRolls or {}
  local f = CreateFrame("Frame")
  f:RegisterEvent("START_LOOT_ROLL")
  f:RegisterEvent("CANCEL_LOOT_ROLL")
  f:SetScript("OnEvent", function(_, event, rollID)
    if event == "START_LOOT_ROLL" and rollID then
      TA.activeLootRolls[rollID] = true
      -- Auto-announce the new roll so the user sees it without polling.
      if GetLootRollItemInfo and GetLootRollItemLink then
        local _, name, count, quality, _, canNeed, canGreed, canDE = GetLootRollItemInfo(rollID)
        local link = GetLootRollItemLink(rollID) or name or "item"
        if name then
          local opts = {}
          if canNeed then opts[#opts + 1] = "need" end
          if canGreed then opts[#opts + 1] = "greed" end
          if canDE then opts[#opts + 1] = "de" end
          opts[#opts + 1] = "pass"
          RollLine(string.format("LOOT ROLL: %s%s  -> ta %s",
            link,
            (count and count > 1) and (" x" .. count) or "",
            table.concat(opts, "|")))
          RollLine("  (use 'ta rolls' for index, then 'ta need|greed|pass [#]')")
        end
      end
    elseif event == "CANCEL_LOOT_ROLL" and rollID then
      if TA.activeLootRolls then TA.activeLootRolls[rollID] = nil end
    end
  end)
  TA.lootRollEventFrame = f
end

function TA_RegisterLootRollCommandHandlers(exactHandlers, addPatternHandler)
  exactHandlers["rolls"] = function() TA_ListLootRolls() end
  exactHandlers["roll"]  = function() TA_ListLootRolls() end

  exactHandlers["need"]  = function() TA_RollOnIndex(1, ROLL_NEED, "Need") end
  exactHandlers["greed"] = function() TA_RollOnIndex(1, ROLL_GREED, "Greed") end
  exactHandlers["pass"]  = function() TA_RollOnIndex(1, ROLL_PASS, "Pass") end
  exactHandlers["de"]    = function() TA_RollOnIndex(1, ROLL_DE, "Disenchant") end
  exactHandlers["disenchant"] = function() TA_RollOnIndex(1, ROLL_DE, "Disenchant") end

  addPatternHandler("^need%s+(%d+)$",  function(i) TA_RollOnIndex(tonumber(i), ROLL_NEED,  "Need")  end)
  addPatternHandler("^greed%s+(%d+)$", function(i) TA_RollOnIndex(tonumber(i), ROLL_GREED, "Greed") end)
  addPatternHandler("^pass%s+(%d+)$",  function(i) TA_RollOnIndex(tonumber(i), ROLL_PASS,  "Pass")  end)
  addPatternHandler("^de%s+(%d+)$",    function(i) TA_RollOnIndex(tonumber(i), ROLL_DE,    "Disenchant") end)
  addPatternHandler("^disenchant%s+(%d+)$", function(i) TA_RollOnIndex(tonumber(i), ROLL_DE, "Disenchant") end)
end

-- Self-register: Modules\Commands.lua runs before this file, so its earlier
-- attempt to call this function was a no-op. Register now that the handler
-- tables already exist on TA. Also wire up the loot-roll event frame so
-- START_LOOT_ROLL is captured even before the user runs any roll command.
if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterLootRollCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
  TA_EnsureLootRollEventFrame()
end
