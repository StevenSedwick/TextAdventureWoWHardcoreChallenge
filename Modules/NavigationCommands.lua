---@diagnostic disable: undefined-global

function TA_RegisterNavigationCommandHandlers(exactHandlers, addPatternHandler)
  if TA.navigationCommandHandlersRegistered then
    return
  end

  exactHandlers["where"] = function() ReportLocation(true) end
  exactHandlers["location"] = function() ReportLocation(true) end
  exactHandlers["markcell"] = function() MarkCurrentCell() end
  exactHandlers["mark cell"] = function() MarkCurrentCell() end
  exactHandlers["cell"] = function() ReportCurrentCell(true) end
  exactHandlers["cellinfo"] = function() ReportCurrentCell(true) end
  exactHandlers["cellanchor"] = function() RecenterCurrentCellAnchor(false) end
  exactHandlers["cellsize standard"] = function() SetGridSize(GRID_SIZE_STANDARD, "standard building size") end
  exactHandlers["cellsize inn"] = function() SetGridSize(GRID_SIZE_STANDARD, "inn-sized preset") end
  exactHandlers["cellcal"] = function() TA_ReportCellYardsCalibration(nil) end
  exactHandlers["cellyards off"] = function() DisableCellSizeYardsMode() end
  exactHandlers["cellmap on"] = function()
    TA.mapOverlayEnabled = true
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.mapOverlayEnabled = true
    AddLine("system", "World Map cell overlay enabled.")
    UpdateMapCellOverlay()
  end
  exactHandlers["cellmap off"] = function()
    TA.mapOverlayEnabled = false
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.mapOverlayEnabled = false
    UpdateMapCellOverlay()
    AddLine("system", "World Map cell overlay disabled.")
  end
  exactHandlers["markedcells"] = function() ListMarkedCells() end
  exactHandlers["listmarks"] = function() ListMarkedCells() end
  exactHandlers["renamemark"] = function() AddLine("system", "Usage: renamemark <id> <name>") end
  exactHandlers["deletemark"] = function() AddLine("system", "Usage: deletemark <id>") end
  exactHandlers["clearmarks"] = function() ClearMarkedCells() end
  exactHandlers["explore"] = function()
    ReportExplorationMemory(true)
    ReportPathMemory(true)
  end

  addPatternHandler("^markcell%s+(.+)$", function(name) MarkCurrentCell(name) end)
  addPatternHandler("^mark cell%s+(.+)$", function(name) MarkCurrentCell(name) end)
  addPatternHandler("^cellsize%s+(%d+)$", function(size) SetGridSize(tonumber(size)) end)
  addPatternHandler("^cellcal%s+(.+)$", function(args) TA_ReportCellYardsCalibration(args) end)
  addPatternHandler("^cellyards%s+([%d%.]+)$", function(yards) SetCellSizeYards(tonumber(yards)) end)
  addPatternHandler("^showmark%s+(%d+)$", function(markID) ShowMarkedCellOnMap(tonumber(markID)) end)
  addPatternHandler("^renamemark%s+(%d+)%s+(.+)$", function(markID, newName) TA_RenameMarkedCell(tonumber(markID), newName) end)
  addPatternHandler("^deletemark%s+(%d+)$", function(markID) DeleteMarkedCell(tonumber(markID)) end)

  TA.navigationCommandHandlersRegistered = true
end

function TA_HandleNavigationInputCommand(lower, msg)
  if lower == "map" then
    TA_ReportAsciiMap(true, true)
    return true
  elseif lower == "map on" then
    TA.asciiMapEnabled = true
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.asciiMapEnabled = true
    AddLine("system", "ASCII map auto-output enabled.")
    TA_ReportAsciiMap(true, true)
    return true
  elseif lower == "map off" then
    TA.asciiMapEnabled = false
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.asciiMapEnabled = false
    AddLine("system", "ASCII map auto-output disabled.")
    return true
  end

  if lower == "dfmode" or lower == "df" then
    TA_ToggleDFMode()
    return true
  elseif lower == "dfmode on" or lower == "df on" then
    if not TA.dfModeEnabled then
      TA_ToggleDFMode()
    end
    return true
  elseif lower == "dfmode off" or lower == "df off" then
    if TA.dfModeEnabled then
      TA_ToggleDFMode()
    end
    return true
  end

  local dfSizeW, dfSizeH = lower:match("^df%s+size%s+(%d+)%s+(%d+)$")
  if not dfSizeW then
    dfSizeW, dfSizeH = lower:match("^dfmode%s+size%s+(%d+)%s+(%d+)$")
  end
  if dfSizeW and dfSizeH then
    TA_SetDFModeSize(dfSizeW, dfSizeH)
    return true
  end
  if lower == "df size" or lower == "dfmode size" then
    TA_SetDFModeSize(nil, nil)
    return true
  end

  local dfMarkRadius = lower:match("^df%s+markradius%s+(%d+)$")
  if not dfMarkRadius then
    dfMarkRadius = lower:match("^dfmode%s+markradius%s+(%d+)$")
  end
  if dfMarkRadius then
    TA_SetDFModeMarkRadius(dfMarkRadius)
    return true
  end
  if lower == "df markradius" or lower == "dfmode markradius" then
    TA_SetDFModeMarkRadius(nil)
    return true
  end

  local dfGridN = lower:match("^df%s+grid%s+(%d+)$")
  if not dfGridN then
    dfGridN = lower:match("^dfmode%s+grid%s+(%d+)$")
  end
  if dfGridN then
    local n = math.floor(tonumber(dfGridN) or 0)
    if n < 5 then n = 5 end
    if n > 99 then n = 99 end
    if n % 2 == 0 then n = n + 1 end
    TA.dfModeGridSize = n
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeGridSize = n
    AddLine("system", "DF grid size set to " .. n .. "x" .. n)
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end
  if lower == "df grid" or lower == "dfmode grid" then
    AddLine("system", "DF grid size: " .. (TA.dfModeGridSize or 35) .. "x" .. (TA.dfModeGridSize or 35))
    AddLine("system", "Usage: /ta df grid <size> (odd number 5-99, even values rounded up)")
    return true
  end

  local dfCellN = lower:match("^df%s+cell%s+(%d+)$")
  if not dfCellN then
    dfCellN = lower:match("^dfmode%s+cell%s+(%d+)$")
  end
  if dfCellN then
    local n = math.floor(tonumber(dfCellN) or 0)
    if n < 3 then n = 3 end
    if n > 100 then n = 100 end
    TA.dfModeYardsPerCell = n
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeYardsPerCell = n
    AddLine("system", "DF cell size set to " .. n .. " yards per cell")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end
  if lower == "df cell auto" or lower == "dfmode cell auto" then
    TA.dfModeYardsPerCell = nil
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeYardsPerCell = nil
    AddLine("system", "DF cell size set to auto (using " .. TA_GetEffectiveDFYardsPerCell() .. " yards per cell)")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end
  if lower == "df cell" or lower == "dfmode cell" then
    if TA.dfModeYardsPerCell then
      AddLine("system", "DF cell size: fixed at " .. TA.dfModeYardsPerCell .. " yards per cell")
    else
      AddLine("system", "DF cell size: auto (using " .. TA_GetEffectiveDFYardsPerCell() .. " yards per cell)")
    end
    AddLine("system", "Usage: /ta df cell <yards>|auto")
    return true
  end

  local dfRotationMode = lower:match("^df%s+rotation%s+(%w+)$") or lower:match("^dfmode%s+rotation%s+(%w+)$")
  if dfRotationMode then
    if dfRotationMode == "smooth" or dfRotationMode == "octant" then
      TA.dfModeRotationMode = dfRotationMode
      TextAdventurerDB = TextAdventurerDB or {}
      TextAdventurerDB.dfModeRotationMode = dfRotationMode
      AddLine("system", "DF rotation mode set to: " .. dfRotationMode)
      if TA.dfModeEnabled then
        TA.dfModeLastUpdate = 0
        TA_UpdateDFMode()
      end
    else
      AddLine("system", "Unknown DF rotation mode. Use: smooth or octant")
    end
    return true
  end
  if lower == "df rotation" or lower == "dfmode rotation" then
    AddLine("system", "DF rotation mode: " .. (TA.dfModeRotationMode or "smooth"))
    AddLine("system", "Usage: /ta df rotation <smooth|octant>")
    return true
  end

  local dfOrientation = lower:match("^df%s+orientation%s+(%w+)$") or lower:match("^dfmode%s+orientation%s+(%w+)$")
  if dfOrientation then
    if dfOrientation == "fixed" or dfOrientation == "rotating" then
      TA.dfModeOrientation = dfOrientation
      TextAdventurerDB = TextAdventurerDB or {}
      TextAdventurerDB.dfModeOrientation = dfOrientation
      AddLine("system", "DF orientation set to: " .. dfOrientation)
      if TA.dfModeEnabled then
        TA.dfModeLastUpdate = 0
        TA_UpdateDFMode()
      end
    else
      AddLine("system", "Unknown DF orientation. Use: fixed or rotating")
    end
    return true
  end
  if lower == "df orientation" or lower == "dfmode orientation" then
    AddLine("system", "DF orientation: " .. (TA.dfModeOrientation or "fixed"))
    AddLine("system", "Usage: /ta df orientation <fixed|rotating>")
    return true
  end

  if lower == "df fixed" or lower == "dfmode fixed" then
    TA.dfModeOrientation = "fixed"
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeOrientation = "fixed"
    AddLine("system", "DF orientation set to: fixed")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  elseif lower == "df rotating" or lower == "dfmode rotating" then
    TA.dfModeOrientation = "rotating"
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeOrientation = "rotating"
    AddLine("system", "DF orientation set to: rotating")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end

  if lower == "df square on" or lower == "dfmode square on" then
    TA.dfModeRotationMode = "octant"
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeRotationMode = "octant"
    AddLine("system", "DF square mode enabled (rotation snap: octant).")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  elseif lower == "df square off" or lower == "dfmode square off" then
    TA.dfModeRotationMode = "smooth"
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeRotationMode = "smooth"
    AddLine("system", "DF square mode disabled (rotation: smooth).")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end

  local dfModeView = lower:match("^dfmode%s+(%w+)$") or lower:match("^df%s+(%w+)$")
  if dfModeView then
    if dfModeView == "hybrid" or dfModeView == "all" then
      dfModeView = "combined"
    end
    if dfModeView == "threat" or dfModeView == "tactical" or dfModeView == "exploration" or dfModeView == "combined" then
      TA.dfModeViewMode = dfModeView
      if TA.dfModeEnabled then
        AddLine("system", "DF Mode view changed to: " .. dfModeView)
        TA.dfModeLastUpdate = 0
        TA_UpdateDFMode()
      end
    else
      AddLine("system", "Unknown DF Mode view. Use: tactical, threat, exploration, or combined (aliases: hybrid, all)")
    end
    return true
  end

  local dfProfile = lower:match("^df%s+profile%s+(%w+)$") or lower:match("^dfmode%s+profile%s+(%w+)$")
  if dfProfile then
    if dfProfile == "balanced" or dfProfile == "full" then
      TA.dfModeProfile = dfProfile
      TextAdventurerDB = TextAdventurerDB or {}
      TextAdventurerDB.dfModeProfile = dfProfile
      AddLine("system", "DF profile set to: " .. dfProfile)
      if TA.dfModeEnabled then
        TA.dfModeLastUpdate = 0
        TA_UpdateDFMode()
      end
    else
      AddLine("system", "Unknown DF profile. Use: balanced or full")
    end
    return true
  end

  if lower == "df status" or lower == "dfmode status" then
    TA_DFModeStatus()
    return true
  end

  if lower == "df sonar" or lower == "dfmode sonar" or lower == "df sonar status" or lower == "dfmode sonar status" then
    local mapID = nil
    if C_Map and C_Map.GetBestMapForUnit then
      mapID = C_Map.GetBestMapForUnit("player")
    end
    local contacts = TA_PruneDFSonarContacts(mapID)
    local ttl = math.floor(tonumber(TA.dfModeSonarTTL) or 8)
    local pulseRemaining = math.max(0, (tonumber(TA.dfModeSonarPulseUntil) or 0) - GetTime())
    AddLine("system", string.format("DF sonar: %d active contact(s), TTL %ds, pulse remaining %.1fs.", contacts, ttl, pulseRemaining))
    AddLine("system", "Usage: /ta df sonar ping [seconds] | /ta df sonar ttl <seconds> | /ta df sonar clear")
    return true
  end

  local sonarPingSeconds = lower:match("^df%s+sonar%s+ping%s*(%d*)$")
  if sonarPingSeconds == nil then
    sonarPingSeconds = lower:match("^dfmode%s+sonar%s+ping%s*(%d*)$")
  end
  if sonarPingSeconds ~= nil then
    local duration = TA_TriggerDFSonarPing(tonumber(sonarPingSeconds))
    AddLine("system", string.format("DF sonar ping active for %d second(s).", duration))
    return true
  end

  local sonarTTLSeconds = lower:match("^df%s+sonar%s+ttl%s+(%d+)$")
  if not sonarTTLSeconds then
    sonarTTLSeconds = lower:match("^dfmode%s+sonar%s+ttl%s+(%d+)$")
  end
  if sonarTTLSeconds then
    local ttl = math.floor(tonumber(sonarTTLSeconds) or 8)
    if ttl < 1 then ttl = 1 end
    if ttl > 60 then ttl = 60 end
    TA.dfModeSonarTTL = ttl
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeSonarTTL = ttl
    AddLine("system", string.format("DF sonar TTL set to %d second(s).", ttl))
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end

  if lower == "df sonar clear" or lower == "dfmode sonar clear" then
    TA_ClearDFSonar()
    AddLine("system", "DF sonar contacts cleared.")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return true
  end

  if lower == "route" then
    AddLine("system", "Usage: route start <name> | route stop | route list | route show <name> | route clear <name> | route follow <name> | route follow off")
    return true
  elseif lower == "route stop" then
    TA_RouteStop()
    return true
  elseif lower == "route list" then
    TA_RouteList()
    return true
  elseif lower == "route follow off" then
    TA_RouteFollowOff()
    return true
  end

  local routeName = lower:match("^route%s+start%s+(.+)$")
  if routeName then
    TA_RouteStart(routeName)
    return true
  end
  routeName = lower:match("^route%s+show%s+(.+)$")
  if routeName then
    TA_RouteShow(routeName)
    return true
  end
  routeName = lower:match("^route%s+clear%s+(.+)$")
  if routeName then
    TA_RouteClear(routeName)
    return true
  end
  routeName = lower:match("^route%s+follow%s+(.+)$")
  if routeName then
    TA_RouteFollow(routeName)
    return true
  end

  return false
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterNavigationCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
