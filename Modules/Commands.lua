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
  ["ta input"] = function() TA_FocusTerminalInput() end,
  ["input"] = function() TA_FocusTerminalInput() end,
  ["autoquests on"] = function()
    TA.autoQuests = true
    AddLine("quest", "Auto quest handling enabled.")
  end,
  ["autoquests off"] = function()
    TA.autoQuests = false
    AddLine("quest", "Auto quest handling disabled.")
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

if TA_RegisterSocialCommandHandlers then
  TA_RegisterSocialCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

if TA_RegisterNavigationCommandHandlers then
  TA_RegisterNavigationCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

TA_AddPatternInputHandler("^bind%s+(%d+)%s+(%d+)$", function(slot, spellIndex) BindSpellbookSpellToActionSlot(tonumber(slot), tonumber(spellIndex)) end)
TA_AddPatternInputHandler("^bindmacro%s+(%d+)%s+(%d+)$", function(slot, macroIndex) BindMacroToActionSlot(tonumber(slot), tonumber(macroIndex)) end)

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

  if TA_HandleSocialInputCommand and TA_HandleSocialInputCommand(lower, msg) then
    return
  end

  if TA_HandleNavigationInputCommand and TA_HandleNavigationInputCommand(lower, msg) then
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

