-- Modules/SettingsAndPerformance.lua
-- CVar read/write helpers, FPS reporting, performance-mode frame
-- suppression + ticker-profile switching, game-settings snapshot,
-- setting-command dispatcher, and path/exploration-memory narration.
--
-- Extracted from textadventurer.lua. Owns:
--   * TA_ParseOnOffValue        -- "on"/"off"/1/0/true/false -> bool
--   * TA_SetToggleSetting       -- set a boolean CVar by label
--   * TA_ReportNamedCVar        -- read and print one CVar
--   * TA_SetNamedCVar           -- write one CVar
--   * TA_ReportGameSettings     -- print snapshot of common settings
--   * TA_ReportFPS              -- print current framerate
--   * TA_SetTickerProfile       -- (module-local) low/high-freq ticker intervals
--   * TA_ApplyPerformanceFrameSuppression -- (global) hide Blizzard frames
--   * TA_RestoreSuppressedFrames          -- (module-local) restore hidden frames
--   * TA_ReportPerformanceStatus -- print performance mode status
--   * TA_EnablePerformanceMode  -- turn on performance mode
--   * TA_DisablePerformanceMode -- turn off performance mode
--   * TA_HandleSettingCommand   -- "set <name> <value>" dispatcher
--   * ReportPathMemory          -- (promoted) path-repeat narration
--   * ReportExplorationMemory   -- (promoted) exploration-bucket narration
--
-- ReportPathMemory and ReportExplorationMemory are promoted from local
-- to global because NavigationCommands.lua calls them directly.
-- TA_SetTickerProfile and TA_ApplyPerformanceFrameSuppression are promoted
-- to globals because PLAYER_LOGIN and DF mode toggles in textadventurer.lua
-- call them. TA_RestoreSuppressedFrames stays module-local (only used
-- within this file). Their redundant _G.X = X mirrors are removed.
--
-- Depends on: AddLine, TA (tickerIntervals, performanceModeEnabled,
-- performancePendingApply, performanceHiddenFrames, performanceFrameHooks,
-- recentCells, dfModeGridSize, dfModeRenderRadiusOverride,
-- lastPathNarration, lastExplorationBucket),
-- GetPlayerMapCell, CellKey, GetExplorationData,
-- TA_RestartRuntimeTickers (called when ticker intervals change).
--
-- Loads after textadventurer.lua and before Modules/NavigationCommands.lua
-- and Modules/SettingsCommands.lua.
-- .toc slot: between Modules/Routing.lua and Modules/Awareness.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2951-3335 ----
function TA_ParseOnOffValue(value)
  local v = (value or ""):match("^%s*(.-)%s*$"):lower()
  if v == "on" or v == "1" or v == "true" or v == "yes" then
    return true
  end
  if v == "off" or v == "0" or v == "false" or v == "no" then
    return false
  end
  return nil
end

function TA_SetToggleSetting(cvar, label, value)
  if not SetCVar then
    AddLine("system", "CVar API unavailable.")
    return
  end
  local flag = TA_ParseOnOffValue(value)
  if flag == nil then
    AddLine("system", string.format("Usage: set %s on|off", label:lower()))
    return
  end
  SetCVar(cvar, flag and "1" or "0")
  AddLine("system", string.format("%s set to %s.", label, flag and "on" or "off"))
end

function TA_ReportNamedCVar(cvarName)
  if not GetCVar then
    AddLine("system", "CVar API unavailable.")
    return
  end
  local name = (cvarName or ""):match("^%s*(.-)%s*$")
  if name == "" then
    AddLine("system", "Usage: cvar <name>")
    return
  end
  local value = GetCVar(name)
  if value == nil then
    AddLine("system", string.format("CVar '%s' not found.", name))
    return
  end
  AddLine("system", string.format("%s = %s", name, tostring(value)))
end

function TA_SetNamedCVar(cvarName, rawValue)
  if not SetCVar or not GetCVar then
    AddLine("system", "CVar API unavailable.")
    return
  end
  local name = (cvarName or ""):match("^%s*(.-)%s*$")
  if name == "" then
    AddLine("system", "Usage: cvar <name> <value>")
    return
  end
  local value = (rawValue or ""):match("^%s*(.-)%s*$")
  if value == "" then
    AddLine("system", "Usage: cvar <name> <value>")
    return
  end

  SetCVar(name, value)
  local now = GetCVar(name)
  if now == nil then
    AddLine("system", string.format("Attempted to set %s = %s.", name, value))
  else
    AddLine("system", string.format("%s set to %s.", name, tostring(now)))
  end
end

function TA_ReportGameSettings()
  if not GetCVar then
    AddLine("system", "CVar API unavailable.")
    return
  end
  local function OnOff(cvar)
    local raw = tostring(GetCVar(cvar) or "0")
    return (raw == "1") and "on" or "off"
  end
  local masterRaw = tonumber(GetCVar("Sound_MasterVolume") or "0") or 0
  local masterPct = math.floor((masterRaw * 100) + 0.5)
  local graphics = tostring(GetCVar("graphicsQuality") or "?")
  local spellQueue = tostring(GetCVar("SpellQueueWindow") or "?")
  local maxFps = tostring(GetCVar("maxfps") or "?")
  local maxFpsBk = tostring(GetCVar("maxfpsbk") or "?")

  AddLine("system", "Game settings snapshot:")
  AddLine("system", string.format("  autoloot: %s", OnOff("autoLootDefault")))
  AddLine("system", string.format("  sound: %s", OnOff("Sound_EnableAllSound")))
  AddLine("system", string.format("  sfx: %s", OnOff("Sound_EnableSFX")))
  AddLine("system", string.format("  music: %s", OnOff("Sound_EnableMusic")))
  AddLine("system", string.format("  ambience: %s", OnOff("Sound_EnableAmbience")))
  AddLine("system", string.format("  master volume: %d%%", masterPct))
  AddLine("system", string.format("  graphics quality: %s", graphics))
  AddLine("system", string.format("  spellqueue: %s ms", spellQueue))
  AddLine("system", string.format("  maxfps: %s | maxfpsbk: %s", maxFps, maxFpsBk))
  AddLine("system", "Use: set <name> <value> for shortcuts, or cvar <name> [value] for any CVar")
end

function TA_ReportFPS()
  if not GetFramerate then
    AddLine("system", "FPS API unavailable.")
    return
  end
  local fps = GetFramerate() or 0
  local maxFps = GetCVar and tostring(GetCVar("maxfps") or "?") or "?"
  local maxFpsBk = GetCVar and tostring(GetCVar("maxfpsbk") or "?") or "?"
  AddLine("system", string.format("Current FPS: %.1f (maxfps: %s, maxfpsbk: %s)", fps, maxFps, maxFpsBk))
end

local PERFORMANCE_FRAME_NAMES = {
  -- Keep this list to non-protected UI elements only.
  -- Protected frames (unit/action bars) must never be force-hidden by addon code.
  "MinimapCluster",
  "BuffFrame", "CastingBarFrame", "DurabilityFrame", "ObjectiveTrackerFrame", "QuestWatchFrame",
}

function TA_SetTickerProfile(profile)
  -- "responsive" runs the awareness/DF tickers at higher frequency than the
  -- "normal" baseline. Despite the legacy name on the public "performance"
  -- command (TA_EnablePerformanceMode), this branch increases CPU work in
  -- exchange for snappier updates. Rename was deliberate so the branch label
  -- reflects what the values actually do.
  if profile == "responsive" then
    TA.tickerIntervals.move = 0.05
    TA.tickerIntervals.nearby = 0.10
    TA.tickerIntervals.memory = 0.10
    TA.tickerIntervals.df = 0.10
    TA.tickerIntervals.warlockPrompt = 1.50
    TA.tickerIntervals.warriorPrompt = 1.50
    -- Tighten the DF render radius to match the higher tick frequency: fewer
    -- cells to paint per tick keeps the per-tick budget roughly the same while
    -- delivering faster updates. Override is a conservative 85% of the current
    -- grid half-size (e.g. radius 17→14 for gridSize=35). The world grid
    -- (innerRadius) stays the same size so no grid reallocation occurs.
    TA.dfModeRenderRadiusOverride = math.floor(math.floor((TA.dfModeGridSize or 35) / 2) * 0.85)
  else
    TA.tickerIntervals.move = 0.2
    TA.tickerIntervals.nearby = 0.25
    TA.tickerIntervals.memory = 0.5
    TA.tickerIntervals.df = 0.15
    TA.tickerIntervals.warlockPrompt = 0.75
    TA.tickerIntervals.warriorPrompt = 0.75
    TA.dfModeRenderRadiusOverride = nil
  end
end

function TA_ApplyPerformanceFrameSuppression()
  if InCombatLockdown and InCombatLockdown() then
    TA.performancePendingApply = true
    AddLine("system", "Performance frame suppression queued until you leave combat.")
    return
  end
  TA.performancePendingApply = false
  for i = 1, #PERFORMANCE_FRAME_NAMES do
    local frameName = PERFORMANCE_FRAME_NAMES[i]
    local frame = _G[frameName]
    if frame and frame.Hide then
      local isProtected = false
      if frame.IsProtected then
        isProtected = frame:IsProtected() and true or false
      elseif IsProtectedFrame then
        isProtected = IsProtectedFrame(frame) and true or false
      end
      if isProtected then
        -- Never touch protected frames; this causes ADDON_ACTION_BLOCKED.
      else
      if TA.performanceHiddenFrames[frameName] == nil and frame.IsShown then
        TA.performanceHiddenFrames[frameName] = frame:IsShown() and true or false
      end
      if not TA.performanceFrameHooks[frameName] and frame.HookScript then
        frame:HookScript("OnShow", function(self)
          if TA.performanceModeEnabled then
            self:Hide()
          end
        end)
        TA.performanceFrameHooks[frameName] = true
      end
      pcall(function() frame:Hide() end)
      end
    end
  end
end

local function TA_RestoreSuppressedFrames()
  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "Cannot restore all protected frames in combat. Try again after combat.")
    return
  end
  for frameName, wasShown in pairs(TA.performanceHiddenFrames) do
    local frame = _G[frameName]
    if frame and frame.Show and wasShown then
      local isProtected = false
      if frame.IsProtected then
        isProtected = frame:IsProtected() and true or false
      elseif IsProtectedFrame then
        isProtected = IsProtectedFrame(frame) and true or false
      end
      if isProtected then
        -- Skip protected frames; they were never intentionally suppressed.
      else
      pcall(function() frame:Show() end)
      end
    end
  end
  TA.performanceHiddenFrames = {}
end

function TA_ReportPerformanceStatus()
  AddLine("system", "Performance mode: " .. (TA.performanceModeEnabled and "ON" or "OFF"))
  AddLine("system", string.format("Tickers (move/nearby/memory/df): %.2f / %.2f / %.2f / %.2f",
    TA.tickerIntervals.move or 0, TA.tickerIntervals.nearby or 0, TA.tickerIntervals.memory or 0, TA.tickerIntervals.df or 0))
  if TA.performancePendingApply then
    AddLine("system", "Frame suppression is pending until combat ends.")
  end
end

function TA_EnablePerformanceMode()
  TA.performanceModeEnabled = true
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.performanceModeEnabled = true
  TA_SetTickerProfile("responsive")
  if TA_RestartRuntimeTickers then TA_RestartRuntimeTickers() end
  TA_ApplyPerformanceFrameSuppression()
  AddLine("system", "Performance mode enabled: suppressed Blizzard frames and switched to responsive (higher-frequency) ticker profile.")
end

function TA_DisablePerformanceMode()
  TA.performanceModeEnabled = false
  TA.performancePendingApply = false
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.performanceModeEnabled = false
  TA_SetTickerProfile("normal")
  if TA_RestartRuntimeTickers then TA_RestartRuntimeTickers() end
  TA_RestoreSuppressedFrames()
  AddLine("system", "Performance mode disabled: restored frame visibility and normal ticker profile.")
end

function TA_HandleSettingCommand(settingName, rawValue)
  if not settingName then
    AddLine("system", "Usage: set <autoloot|sound|sfx|music|ambience|master|graphics> <value>")
    return
  end
  local key = (settingName or ""):lower():gsub("_", ""):gsub("%s+", "")

  if key == "autoloot" then
    TA_SetToggleSetting("autoLootDefault", "Auto Loot", rawValue)
    return
  elseif key == "sound" then
    TA_SetToggleSetting("Sound_EnableAllSound", "Sound", rawValue)
    return
  elseif key == "sfx" then
    TA_SetToggleSetting("Sound_EnableSFX", "SFX", rawValue)
    return
  elseif key == "music" then
    TA_SetToggleSetting("Sound_EnableMusic", "Music", rawValue)
    return
  elseif key == "ambience" or key == "ambient" then
    TA_SetToggleSetting("Sound_EnableAmbience", "Ambience", rawValue)
    return
  elseif key == "spellqueue" or key == "spellqueuewindow" then
    local ms = tonumber((rawValue or ""):match("^%s*(.-)%s*$"))
    if not ms then
      AddLine("system", "Usage: set spellqueue <0-400>")
      return
    end
    ms = math.max(0, math.min(400, math.floor(ms + 0.5)))
    TA_SetNamedCVar("SpellQueueWindow", tostring(ms))
    return
  elseif key == "master" or key == "mastervolume" then
    local pct = tonumber((rawValue or ""):match("^%s*(.-)%s*$"))
    if not pct then
      AddLine("system", "Usage: set master <0-100>")
      return
    end
    pct = math.max(0, math.min(100, math.floor(pct + 0.5)))
    if not SetCVar then
      AddLine("system", "CVar API unavailable.")
      return
    end
    SetCVar("Sound_MasterVolume", string.format("%.2f", pct / 100))
    AddLine("system", string.format("Master volume set to %d%%.", pct))
    return
  elseif key == "graphics" or key == "quality" then
    local q = tonumber((rawValue or ""):match("^%s*(.-)%s*$"))
    if not q then
      AddLine("system", "Usage: set graphics <1-10>")
      return
    end
    q = math.max(1, math.min(10, math.floor(q + 0.5)))
    if not SetCVar then
      AddLine("system", "CVar API unavailable.")
      return
    end
    SetCVar("graphicsQuality", tostring(q))
    AddLine("system", string.format("Graphics quality set to %d.", q))
    return
  elseif key == "maxfps" then
    local fps = tonumber((rawValue or ""):match("^%s*(.-)%s*$"))
    if not fps then
      AddLine("system", "Usage: set maxfps <0-300>")
      return
    end
    fps = math.max(0, math.min(300, math.floor(fps + 0.5)))
    TA_SetNamedCVar("maxfps", tostring(fps))
    return
  elseif key == "maxfpsbk" or key == "backgroundfps" then
    local fps = tonumber((rawValue or ""):match("^%s*(.-)%s*$"))
    if not fps then
      AddLine("system", "Usage: set maxfpsbk <0-300>")
      return
    end
    fps = math.max(0, math.min(300, math.floor(fps + 0.5)))
    TA_SetNamedCVar("maxfpsbk", tostring(fps))
    return
  end

  TA_SetNamedCVar(settingName, rawValue)
end

function ReportPathMemory(force)
  local mapID, cellX, cellY = GetPlayerMapCell()
  if not mapID then return end
  local currentKey = tostring(mapID) .. ":" .. CellKey(cellX, cellY)
  local seenEarlier = false
  local repeatCount = 0
  for i = 1, math.max(0, #TA.recentCells - 1) do
    if TA.recentCells[i] == currentKey then
      seenEarlier = true
      repeatCount = repeatCount + 1
    end
  end
  local pathText = nil
  if #TA.recentCells >= 3 then
    local prev = TA.recentCells[#TA.recentCells - 1]
    local prev2 = TA.recentCells[#TA.recentCells - 2]
    if currentKey == prev2 and currentKey ~= prev then
      pathText = "You seem to be doubling back."
    elseif seenEarlier and repeatCount >= 2 then
      pathText = "You are following a well-worn route."
    elseif seenEarlier then
      pathText = "You retrace familiar ground."
    end
  elseif seenEarlier then
    pathText = "You retrace familiar ground."
  end
  if force or (pathText and pathText ~= TA.lastPathNarration) then
    if pathText then
      AddLine("place", pathText)
      TA.lastPathNarration = pathText
    elseif force then
      TA.lastPathNarration = nil
    end
  end
end

function ReportExplorationMemory(force)
  local mapID, cellX, cellY = GetPlayerMapCell()
  if not mapID then return end
  local data = GetExplorationData(mapID)
  local key = CellKey(cellX, cellY)
  local visits = data.visits[key] or 0
  local messages = {}
  if visits <= 1 then
    table.insert(messages, "This place feels unfamiliar.")
  elseif visits < 5 then
    table.insert(messages, "You return to somewhat familiar ground.")
  else
    table.insert(messages, "You walk along a well-traveled path.")
  end
  if data.minX and data.maxX and data.minY and data.maxY then
    local centerX = (data.minX + data.maxX) / 2
    local centerY = (data.minY + data.maxY) / 2
    local dx = math.abs(cellX - centerX)
    local dy = math.abs(cellY - centerY)
    if dx <= 1 and dy <= 1 then
      table.insert(messages, "You are near the center of your explored territory.")
    elseif cellX == data.minX or cellX == data.maxX or cellY == data.minY or cellY == data.maxY then
      table.insert(messages, "You are near the edge of what you have explored.")
    end
  end
  local bucket = table.concat(messages, " | ")
  if force or bucket ~= TA.lastExplorationBucket then
    for i = 1, #messages do AddLine("place", messages[i]) end
    TA.lastExplorationBucket = bucket
  end
end

