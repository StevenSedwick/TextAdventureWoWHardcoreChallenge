---@diagnostic disable: undefined-global

TA.EXACT_INPUT_HANDLERS = {
  ["health"] = function() ReportStatus(true) end,
  ["hp"] = function() ReportStatus(true) end,
  ["rage"] = function() ReportStatus(true) end,
  ["status"] = function() ReportStatus(true) end,
  ["stats"] = function() ReportCharacterStats() end,
  ["skills"] = function() TA_ReportSkillLevels(true) end,
  ["skill"] = function() TA_ReportSkillLevels(true) end,
  ["dps"] = function() ReportDPS() end,
  ["dps reset"] = function() ResetDPSStats() end,
  ["sealdps"] = function() TA_ReportSealDpsComparison(nil) end,
  ["seal dps"] = function() TA_ReportSealDpsComparison(nil) end,
  ["sealdps live"] = function() TA_ReportLiveSealDpsComparison() end,
  ["sealdps live hybrid"] = function() TA_ReportLiveSealHybridComparison(nil) end,
  ["sealdps assumptions"] = function() TA_ReportSealLiveAssumptions() end,
  ["warlockdps"] = function() TA_ReportLiveWarlockDps() end,
  ["warlock dps"] = function() TA_ReportLiveWarlockDps() end,
  ["warlockdps live"] = function() TA_ReportLiveWarlockDps() end,
  ["warlockdps assumptions"] = function() TA_ReportWarlockLiveAssumptions() end,
  ["warlockdps mapping"] = function() TA_ReportWarlockSheetMapping() end,
  ["warlockdps reset"] = function() TA_ResetWarlockDpsConfigDefaults() end,
  ["warlockdps mode"] = function() AddLine("system", "Usage: warlockdps mode <shadow|fire>") end,
  ["warlockdps set"] = function() AddLine("system", "Usage: warlockdps set <key> <value> (try: warlockdps assumptions)") end,
  ["warlockprompt"] = function() TA_ReportWarlockActionPrompt(true) end,
  ["warlock prompt"] = function() TA_ReportWarlockActionPrompt(true) end,
  ["warlockprompt on"] = function() TA_SetWarlockPromptEnabled(true) end,
  ["warlock prompt on"] = function() TA_SetWarlockPromptEnabled(true) end,
  ["warlockprompt off"] = function() TA_SetWarlockPromptEnabled(false) end,
  ["warlock prompt off"] = function() TA_SetWarlockPromptEnabled(false) end,
  ["warlockprompt status"] = function() TA_ReportWarlockPromptStatus() end,
  ["warlock prompt status"] = function() TA_ReportWarlockPromptStatus() end,
  ["warlockprompt set"] = function() AddLine("system", "Usage: warlockprompt set <manapct|taphpfloor> <value>") end,
  ["warlock prompt set"] = function() AddLine("system", "Usage: warlockprompt set <manapct|taphpfloor> <value>") end,
  ["ml status"] = function() TA_ReportMLStatus() end,
  ["ml recommend"] = function() TA_RecommendWithML(false) end,
  ["ml recommend explain"] = function() TA_RecommendWithML(true) end,
  ["ml xp"] = function() TA_RecommendXPWithML(false) end,
  ["ml xp explain"] = function() TA_RecommendXPWithML(true) end,
  ["ml xp mode"] = function() TA_ReportMLXPMode() end,
  ["ml xp defaults"] = function() TA_ResetMLXPConfigDefaults() end,
  ["ml xp rates"] = function() TA_ReportMLXPRateStatus() end,
  ["ml xp rates reset"] = function() TA_ResetMLXPRateModel() end,
  ["ml xp set"] = function() AddLine("system", "Usage: ml xp set <key> <value> (use 'ml xp explain' for key list)") end,
  ["ml xp warrior preset"] = function() AddLine("system", "Usage: ml xp warrior preset <arms|fury>") end,
  ["ml xp warrior weapon"] = function() AddLine("system", "Usage: ml xp warrior weapon <auto|slow-2h|fast-2h|one-hand|dual-wield>") end,
  ["ml model sample"] = function() TA_LoadSampleMLModel() end,
  ["ml model clear"] = function() TA_ClearMLModel() end,
  ["ml log on"] = function() TA_SetMLLogging(true) end,
  ["ml log off"] = function() TA_SetMLLogging(false) end,
  ["ml log clear"] = function() TA_ClearMLLogs() end,
  ["ml export"] = function() TA_ExportMLLogs(20) end,
  ["sealdps list"] = function() TA_ReportSealDpsModelRows() end,
  ["sealdps clear"] = function() TA_ClearSealDpsModel() end,
  ["sealdps set"] = function() AddLine("system", "Usage: sealdps set <level> <sorDps> <socDps>") end,
  ["sealdps import"] = function() AddLine("system", "Usage: sealdps import <level:sor:soc,level:sor:soc,...>") end,
  ["weapondps"] = function() ReportWeaponDPS() end,
  ["weapon dps"] = function() ReportWeaponDPS() end,
  ["where"] = function() ReportLocation(true) end,
  ["location"] = function() ReportLocation(true) end,
  ["xp"] = function() ReportXP() end,
  ["level"] = function() ReportXP() end,
  ["buffs"] = function() ReportBuffs() end,
  ["tracking"] = function() ReportTracking() end,
  ["actions"] = function() ReportActionBars() end,
  ["bars"] = function() ReportActionBars() end,
  ["spells"] = function() ReportSpellbook() end,
  ["spellbook"] = function() ReportSpellbook() end,
  ["macros"] = function() ReportMacros() end,
  ["trainer"] = function() ReportTrainerServices() end,
  ["train list"] = function() ReportTrainerServices() end,
  ["recipes"] = function() TA_ReportProfessionRecipes() end,
  ["recipe"] = function() TA_ReportProfessionRecipes() end,
  ["recipeinfo"] = function() AddLine("system", "Usage: recipeinfo <index>") end,
  ["marka"] = function() MarkFacingA() end,
  ["markb"] = function() MarkFacingB() end,
  ["spacing"] = function() ReportSpacingEstimate() end,
  ["behind"] = function() ReportTargetPositioning() end,
  ["backstab"] = function() ReportTargetPositioning() end,
  ["markcell"] = function() MarkCurrentCell() end,
  ["mark cell"] = function() MarkCurrentCell() end,
  ["cell"] = function() ReportCurrentCell(true) end,
  ["cellinfo"] = function() ReportCurrentCell(true) end,
  ["cellanchor"] = function() RecenterCurrentCellAnchor(false) end,
  ["cellsize standard"] = function() SetGridSize(GRID_SIZE_STANDARD, "standard building size") end,
  ["cellsize inn"] = function() SetGridSize(GRID_SIZE_STANDARD, "inn-sized preset") end,
  ["cellcal"] = function() TA_ReportCellYardsCalibration(nil) end,
  ["cellyards off"] = function() DisableCellSizeYardsMode() end,
  ["cellmap on"] = function()
    TA.mapOverlayEnabled = true
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.mapOverlayEnabled = true
    AddLine("system", "World Map cell overlay enabled.")
    UpdateMapCellOverlay()
  end,
  ["cellmap off"] = function()
    TA.mapOverlayEnabled = false
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.mapOverlayEnabled = false
    UpdateMapCellOverlay()
    AddLine("system", "World Map cell overlay disabled.")
  end,
  ["markedcells"] = function() ListMarkedCells() end,
  ["listmarks"] = function() ListMarkedCells() end,
  ["renamemark"] = function() AddLine("system", "Usage: renamemark <id> <name>") end,
  ["deletemark"] = function() AddLine("system", "Usage: deletemark <id>") end,
  ["clearmarks"] = function() ClearMarkedCells() end,
  ["ta input"] = function() TA_FocusTerminalInput() end,
  ["input"] = function() TA_FocusTerminalInput() end,
  ["explore"] = function()
    ReportExplorationMemory(true)
    ReportPathMemory(true)
  end,
  ["autoquests on"] = function()
    TA.autoQuests = true
    AddLine("quest", "Auto quest handling enabled.")
  end,
  ["autoquests off"] = function()
    TA.autoQuests = false
    AddLine("quest", "Auto quest handling disabled.")
  end,
  ["chat on"] = function()
    TA.captureChat = true
    AddLine("chat", "Chat capture enabled.")
  end,
  ["chat off"] = function()
    TA.captureChat = false
    AddLine("chat", "Chat capture disabled.")
  end,
  ["autostart on"] = function()
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.autoEnable = true
    TextAdventurerDB.firstRunSafetyAcknowledged = true
    AddLine("system", "Autostart enabled.")
  end,
  ["autostart off"] = function()
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.autoEnable = false
    AddLine("system", "Autostart disabled.")
  end,
  ["prompts"] = function() ReportStaticPopups() end,
  ["debug"] = function() DebugVisiblePopups() end,
  ["debugpopups"] = function() DebugVisiblePopups() end,
  ["range"] = function() ReportRange() end,
  ["fps"] = function() TA_ReportFPS() end,
  ["framerate"] = function() TA_ReportFPS() end,
  ["clear"] = function()
    TA_ClearTerminalLog()
  end,
  ["show"] = function() TA_ShowPanelCommand() end,
  ["hide"] = function() TA_HidePanelCommand() end,
  ["toggle"] = function() TA_TogglePanelCommand() end,
  ["textmode on"] = function() TA_EnableTextModeCommand() end,
  ["textmode off"] = function() TA_DisableTextModeCommand() end,
  ["help"] = function() TA_ShowHelpOverview() end,
  ["performance"] = function() TA_ReportPerformanceStatus() end,
  ["performance status"] = function() TA_ReportPerformanceStatus() end,
  ["performance on"] = function() TA_EnablePerformanceMode() end,
  ["performance off"] = function() TA_DisablePerformanceMode() end,
}

TA.PATTERN_INPUT_HANDLERS = {
  { "^help%s+(.+)$", function(topic) TA_ShowHelpTopic(topic) end },
  { "^skills%s+(%a+)$", function(which) TA_ReportSkillLevels(true, which) end },
  { "^skill%s+(%a+)$", function(which) TA_ReportSkillLevels(true, which) end },
  { "^sealdps%s+live%s+target%s+(%d+)$", function(level) TA_SetSealLiveNumber("targetLevel", level, 1, 63, "targetLevel") end },
  { "^sealdps%s+live%s+cd%s+([%d%.]+)$", function(seconds) TA_SetSealLiveNumber("judgementCD", seconds, 6, 10, "judgementCD") end },
  { "^sealdps%s+live%s+socppm%s+([%d%.]+)$", function(ppm) TA_SetSealLiveNumber("socPPM", ppm, 4, 12, "socPPM") end },
  { "^sealdps%s+live%s+window%s+([%d%.]+)$", function(seconds) TA_SetSealLiveHybridWindow(seconds) end },
  { "^sealdps%s+live%s+resealgcd%s+([%d%.]+)$", function(seconds) TA_SetSealLiveResealGCD(seconds) end },
  { "^sealdps%s+live%s+hybrid%s+([%d%.]+)$", function(seconds) TA_ReportLiveSealHybridComparison(seconds) end },
  { "^sealdps%s+live%s+behind%s+(%a+)$", function(flag) TA_SetSealLiveBehind(flag) end },
  { "^warlockdps%s+mode%s+([%a%-]+)$", function(mode) TA_SetWarlockMode(mode) end },
  { "^warlockdps%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarlockDpsConfigValue(k, v) end },
  { "^warlockdps%s+reset$", function() TA_ResetWarlockDpsConfigDefaults() end },
  { "^warlockdps%s+mapping$", function() TA_ReportWarlockSheetMapping() end },
  { "^warlockprompt%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarlockPromptValue(k, v) end },
  { "^warlock%s+prompt%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarlockPromptValue(k, v) end },
  { "^ml%s+export%s+(%d+)$", function(n) TA_ExportMLLogs(n) end },
  { "^ml%s+log%s+max%s+(%d+)$", function(n) TA_SetMLMaxLogs(n) end },
  { "^ml%s+xp%s+set%s+(%a+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetMLXPConfigValue(k, v) end },
  { "^ml%s+xp%s+mode%s+([%a%-]+)$", function(mode) TA_SetMLXPMode(mode) end },
  { "^ml%s+xp%s+warrior%s+preset%s+([%a%-]+)$", function(name) TA_ApplyWarriorPreset(name) end },
  { "^ml%s+xp%s+warrior%s+weapon%s+([%a%-]+)$", function(name) TA_ApplyWarriorWeaponProfile(name) end },
  { "^sealdps%s+(%d+)$", function(level) TA_ReportSealDpsComparison(tonumber(level)) end },
  { "^sealdps%s+set%s+(%d+)%s+([%-]?[%d%.]+)%s+([%-]?[%d%.]+)$", function(level, sor, soc) TA_SetSealDpsModelRow(level, sor, soc) end },
  { "^sealdps%s+import%s+(.+)$", function(payload) TA_ImportSealDpsModel(payload) end },
  { "^macroinfo%s+(%d+)$", function(idx) ShowMacroInfo(tonumber(idx)) end },
  { "^macro%s+(%d+)$", function(idx) CastMacroByIndex(tonumber(idx)) end },
  { "^macroset%s+(%d+)%s+(.+)$", function(idx, body) SetMacroBody(tonumber(idx), body) end },
  { "^macrorename%s+(.+)$", function(rest)
      local idx, newName = ParseRenameArgs(rest)
      RenameMacro(idx, newName)
    end },
  { "^macrocreate%s+(.+)$", function(rest)
      local name, body = ParseNameAndBodyArgs(rest)
      CreateNewMacro(name, body)
    end },
  { "^macrodelete%s+(%d+)$", function(idx) DeleteMacroByIndex(tonumber(idx)) end },
  { "^macro%s+(.+)$", function(name) CastMacroByName(name) end },
  { "^train%s+all$", function() TrainAllAvailableServices() end },
  { "^train%s+(%d+)$", function(idx) TrainServiceByIndex(tonumber(idx)) end },
  { "^recipeinfo%s+(%d+)$", function(idx) TA_ReportRecipeDetails(tonumber(idx)) end },
  { "^recipe%s+(%d+)$", function(idx) TA_ReportRecipeDetails(tonumber(idx)) end },
}

function TA_AddPatternInputHandler(pattern, handler)
  table.insert(TA.PATTERN_INPUT_HANDLERS, { pattern, handler })
end

if TA_RegisterQuestCommandHandlers then
  TA_RegisterQuestCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

if TA_RegisterEconomyCommandHandlers then
  TA_RegisterEconomyCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

TA_AddPatternInputHandler("^bind%s+(%d+)%s+(%d+)$", function(slot, spellIndex) BindSpellbookSpellToActionSlot(tonumber(slot), tonumber(spellIndex)) end)
TA_AddPatternInputHandler("^bindmacro%s+(%d+)%s+(%d+)$", function(slot, macroIndex) BindMacroToActionSlot(tonumber(slot), tonumber(macroIndex)) end)
TA_AddPatternInputHandler("^target%s+(.+)$", function(arg) DoTargetCommand(arg) end)
TA_AddPatternInputHandler("^markcell%s+(.+)$", function(name) MarkCurrentCell(name) end)
TA_AddPatternInputHandler("^mark cell%s+(.+)$", function(name) MarkCurrentCell(name) end)
TA_AddPatternInputHandler("^cellsize%s+(%d+)$", function(size) SetGridSize(tonumber(size)) end)
TA_AddPatternInputHandler("^cellcal%s+(.+)$", function(args) TA_ReportCellYardsCalibration(args) end)
TA_AddPatternInputHandler("^cellyards%s+([%d%.]+)$", function(yards) SetCellSizeYards(tonumber(yards)) end)
TA_AddPatternInputHandler("^showmark%s+(%d+)$", function(markID) ShowMarkedCellOnMap(tonumber(markID)) end)
TA_AddPatternInputHandler("^renamemark%s+(%d+)%s+(.+)$", function(markID, newName) TA_RenameMarkedCell(tonumber(markID), newName) end)
TA_AddPatternInputHandler("^deletemark%s+(%d+)$", function(markID) DeleteMarkedCell(tonumber(markID)) end)

function TA_RunCVarList(filter)
  if not ConsoleExec then
    AddLine("system", "Console command API unavailable.")
    return
  end

  local suffix = ""
  local f = (filter or ""):match("^%s*(.-)%s*$")
  if f ~= "" then
    suffix = " " .. f
  end

  TA.pendingCVarList = true
  AddLine("system", string.format("Running cvarlist%s...", suffix))
  ConsoleExec("cvarlist" .. suffix)
  if C_Timer and C_Timer.After then
    C_Timer.After(3.0, function()
      TA.pendingCVarList = false
    end)
  end
end

function TA_ProcessInputCommand(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$")
  if msg == "" then return end
  if msg:sub(1, 1) == "/" then
    TA_SendFromTerminal(msg)
    return
  end

  local lower = msg:lower()
  if lower == "autostart on" then
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.autoEnable = true
    TextAdventurerDB.firstRunSafetyAcknowledged = true
    AddLine("system", "Autostart enabled.")
    return
  elseif lower == "autostart off" then
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.autoEnable = false
    AddLine("system", "Autostart disabled.")
    return
  elseif lower == "reload" or lower == "reloadui" then
    ReloadUI()
    return
  end
  if lower == "renamecell" then
    lower = "renamemark"
  elseif lower:find("^renamecell%s+") then
    lower = "renamemark " .. (lower:match("^renamecell%s+(.+)$") or "")
  end
  if lower == "equip" then
    AddLine("system", "Usage: equip <item name> or equip <bag> <slot>")
    return
  end

  if TA_HandleEconomyInputCommand and TA_HandleEconomyInputCommand(lower, msg) then
    return
  end

  if lower == "who" then
    TA_ReportWhoList()
    return
  end
  local whoQuery = msg:match("^%s*[Ww][Hh][Oo]%s+(.+)$")
  if whoQuery then
    TA_RunWhoQuery(whoQuery)
    return
  end

  local bindItemActionSlot, bindItemBag, bindItemSlot = lower:match("^binditem%s+(%d+)%s+(-?%d+)%s+(%d+)$")
  if bindItemActionSlot and bindItemBag and bindItemSlot then
    TA_BindBagItemToActionSlot(tonumber(bindItemActionSlot), tonumber(bindItemBag), tonumber(bindItemSlot))
    return
  elseif lower == "binditem" then
    AddLine("system", "Usage: binditem <actionSlot> <bag> <slot>")
    return
  end

  if lower == "map" then
    TA_ReportAsciiMap(true, true)
    return
  elseif lower == "map on" then
    TA.asciiMapEnabled = true
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.asciiMapEnabled = true
    AddLine("system", "ASCII map auto-output enabled.")
    TA_ReportAsciiMap(true, true)
    return
  elseif lower == "map off" then
    TA.asciiMapEnabled = false
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.asciiMapEnabled = false
    AddLine("system", "ASCII map auto-output disabled.")
    return
  end

  if lower == "dfmode" or lower == "df" then
    TA_ToggleDFMode()
    return
  elseif lower == "dfmode on" or lower == "df on" then
    if not TA.dfModeEnabled then
      TA_ToggleDFMode()
    end
    return
  elseif lower == "dfmode off" or lower == "df off" then
    if TA.dfModeEnabled then
      TA_ToggleDFMode()
    end
    return
  end

  local dfSizeW, dfSizeH = lower:match("^df%s+size%s+(%d+)%s+(%d+)$")
  if not dfSizeW then
    dfSizeW, dfSizeH = lower:match("^dfmode%s+size%s+(%d+)%s+(%d+)$")
  end
  if dfSizeW and dfSizeH then
    TA_SetDFModeSize(dfSizeW, dfSizeH)
    return
  end
  if lower == "df size" or lower == "dfmode size" then
    TA_SetDFModeSize(nil, nil)
    return
  end

  local dfMarkRadius = lower:match("^df%s+markradius%s+(%d+)$")
  if not dfMarkRadius then
    dfMarkRadius = lower:match("^dfmode%s+markradius%s+(%d+)$")
  end
  if dfMarkRadius then
    TA_SetDFModeMarkRadius(dfMarkRadius)
    return
  end
  if lower == "df markradius" or lower == "dfmode markradius" then
    TA_SetDFModeMarkRadius(nil)
    return
  end

  local dfGridN = lower:match("^df%s+grid%s+(%d+)$")
  if not dfGridN then
    dfGridN = lower:match("^dfmode%s+grid%s+(%d+)$")
  end
  if dfGridN then
    local n = math.floor(tonumber(dfGridN) or 0)
    if n < 5 then n = 5 end
    if n > 99 then n = 99 end
    -- Force odd so there is always a true center cell.
    if n % 2 == 0 then n = n + 1 end
    TA.dfModeGridSize = n
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeGridSize = n
    AddLine("system", "DF grid size set to " .. n .. "x" .. n)
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return
  end
  if lower == "df grid" or lower == "dfmode grid" then
    AddLine("system", "DF grid size: " .. (TA.dfModeGridSize or 35) .. "x" .. (TA.dfModeGridSize or 35))
    AddLine("system", "Usage: /ta df grid <size> (odd number 5-99, even values rounded up)")
    return
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
    return
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
    return
  end
  if lower == "df cell" or lower == "dfmode cell" then
    if TA.dfModeYardsPerCell then
      AddLine("system", "DF cell size: fixed at " .. TA.dfModeYardsPerCell .. " yards per cell")
    else
      AddLine("system", "DF cell size: auto (using " .. TA_GetEffectiveDFYardsPerCell() .. " yards per cell)")
    end
    AddLine("system", "Usage: /ta df cell <yards>|auto")
    return
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
    return
  end
  if lower == "df rotation" or lower == "dfmode rotation" then
    AddLine("system", "DF rotation mode: " .. (TA.dfModeRotationMode or "smooth"))
    AddLine("system", "Usage: /ta df rotation <smooth|octant>")
    return
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
    return
  end
  if lower == "df orientation" or lower == "dfmode orientation" then
    AddLine("system", "DF orientation: " .. (TA.dfModeOrientation or "fixed"))
    AddLine("system", "Usage: /ta df orientation <fixed|rotating>")
    return
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
    return
  elseif lower == "df rotating" or lower == "dfmode rotating" then
    TA.dfModeOrientation = "rotating"
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeOrientation = "rotating"
    AddLine("system", "DF orientation set to: rotating")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return
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
    return
  elseif lower == "df square off" or lower == "dfmode square off" then
    TA.dfModeRotationMode = "smooth"
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.dfModeRotationMode = "smooth"
    AddLine("system", "DF square mode disabled (rotation: smooth).")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return
  end

  -- DF Mode view switching
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
    return
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
    return
  end

  if lower == "df status" or lower == "dfmode status" then
    TA_DFModeStatus()
    return
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
    return
  end

  local sonarPingSeconds = lower:match("^df%s+sonar%s+ping%s*(%d*)$")
  if sonarPingSeconds == nil then
    sonarPingSeconds = lower:match("^dfmode%s+sonar%s+ping%s*(%d*)$")
  end
  if sonarPingSeconds ~= nil then
    local duration = TA_TriggerDFSonarPing(tonumber(sonarPingSeconds))
    AddLine("system", string.format("DF sonar ping active for %d second(s).", duration))
    return
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
    return
  end

  if lower == "df sonar clear" or lower == "dfmode sonar clear" then
    TA_ClearDFSonar()
    AddLine("system", "DF sonar contacts cleared.")
    if TA.dfModeEnabled then
      TA.dfModeLastUpdate = 0
      TA_UpdateDFMode()
    end
    return
  end

  if lower == "route" then
    AddLine("system", "Usage: route start <name> | route stop | route list | route show <name> | route clear <name> | route follow <name> | route follow off")
    return
  elseif lower == "route stop" then
    TA_RouteStop()
    return
  elseif lower == "route list" then
    TA_RouteList()
    return
  elseif lower == "route follow off" then
    TA_RouteFollowOff()
    return
  end

  local routeName = lower:match("^route%s+start%s+(.+)$")
  if routeName then
    TA_RouteStart(routeName)
    return
  end
  routeName = lower:match("^route%s+show%s+(.+)$")
  if routeName then
    TA_RouteShow(routeName)
    return
  end
  routeName = lower:match("^route%s+clear%s+(.+)$")
  if routeName then
    TA_RouteClear(routeName)
    return
  end
  routeName = lower:match("^route%s+follow%s+(.+)$")
  if routeName then
    TA_RouteFollow(routeName)
    return
  end

  if lower == "settings" then
    TA_ReportGameSettings()
    return
  elseif lower == "set" then
    AddLine("system", "Usage: set <name> <value>")
    AddLine("system", "Shortcuts: autoloot, sound, sfx, music, ambience, master, graphics, spellqueue, maxfps, maxfpsbk")
    AddLine("system", "Any other name is treated as a direct CVar name.")
    return
  elseif lower == "cvar" then
    AddLine("system", "Usage: cvar <name> [value]")
    return
  elseif lower == "cvarlist" then
    TA_RunCVarList(nil)
    return
  end

  local cvarFilter = msg:match("^%s*[Cc][Vv][Aa][Rr][Ll][Ii][Ss][Tt]%s+(.+)$")
  if cvarFilter then
    TA_RunCVarList(cvarFilter)
    return
  end

  local setName, setValue = msg:match("^%s*[Ss][Ee][Tt]%s+(%S+)%s+(.+)$")
  if setName and setValue then
    TA_HandleSettingCommand(setName, setValue)
    return
  end

  local cvarName, cvarValue = msg:match("^%s*[Cc][Vv][Aa][Rr]%s+(%S+)%s+(.+)$")
  if cvarName and cvarValue then
    TA_SetNamedCVar(cvarName, cvarValue)
    return
  end
  cvarName = msg:match("^%s*[Cc][Vv][Aa][Rr]%s+(%S+)%s*$")
  if cvarName then
    TA_ReportNamedCVar(cvarName)
    return
  end

  local equipArg = lower:match("^equip%s+(.+)$")
  if equipArg then
    local bag, slot = equipArg:match("^%s*(-?%d+)%s+(%d+)%s*$")
    if bag and slot then
      TA_EquipBagItem(tonumber(bag), tonumber(slot))
    else
      TA_EquipItemByQuery(equipArg)
    end
    return
  end
  local exactHandler = TA.EXACT_INPUT_HANDLERS[lower]
  if exactHandler then
    exactHandler()
    return
  end

  for i = 1, #TA.PATTERN_INPUT_HANDLERS do
    local entry = TA.PATTERN_INPUT_HANDLERS[i]
    local captures = { lower:match(entry[1]) }
    if #captures > 0 then
      entry[2](unpack(captures))
      return
    end
  end

  AddLine("system", "Unknown input. Type 'help' for a list of commands.")
end

