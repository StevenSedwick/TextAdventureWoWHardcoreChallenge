if not TA then
  return
end

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
  ["marka"] = function() MarkFacingA() end,
  ["markb"] = function() MarkFacingB() end,
  ["spacing"] = function() ReportSpacingEstimate() end,
  ["behind"] = function() ReportTargetPositioning() end,
  ["backstab"] = function() ReportTargetPositioning() end,
  ["ta input"] = function() TA_FocusTerminalInput() end,
  ["input"] = function() TA_FocusTerminalInput() end,
  ["runlast"] = function() TA_RunLastInputBlock() end,
  ["run last"] = function() TA_RunLastInputBlock() end,
  ["rerun"] = function() TA_RunLastInputBlock() end,
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
  ["selftest"] = function() TA_RunCommandSelfTest("safe") end,
  ["selftest full"] = function() TA_RunCommandSelfTest("full") end,
  ["selftest patterns"] = function() TA_RunPatternSelfTest("safe") end,
  ["selftest patterns full"] = function() TA_RunPatternSelfTest("full") end,
  ["performance"] = function() TA_ReportPerformanceStatus() end,
  ["performance status"] = function() TA_ReportPerformanceStatus() end,
  ["performance on"] = function() TA_EnablePerformanceMode() end,
  ["performance off"] = function() TA_DisablePerformanceMode() end,
  ["terrain"] = function()
    local data = rawget(_G, "TextAdventurerTerrainData")
    if type(data) ~= "table" then
      AddLine("system", "Terrain data not loaded. Expected global: TextAdventurerTerrainData")
      return
    end

    local chunks = (type(data.chunks) == "table") and #data.chunks or 0
    local markers = (type(data.markers) == "table") and #data.markers or 0
    local tiles = (type(data.tilesPresent) == "table") and #data.tilesPresent or 0
    AddLine("system", string.format("Terrain loaded: zone=%s map=%s chunks=%d markers=%d tiles=%d", tostring(data.zoneKey or "?"), tostring(data.mapName or "?"), chunks, markers, tiles))
  end,
  ["terrain status"] = function()
    local data = rawget(_G, "TextAdventurerTerrainData")
    if type(data) ~= "table" then
      AddLine("system", "Terrain data not loaded. Expected global: TextAdventurerTerrainData")
      return
    end

    local chunks = (type(data.chunks) == "table") and #data.chunks or 0
    local markers = (type(data.markers) == "table") and #data.markers or 0
    local tiles = (type(data.tilesPresent) == "table") and #data.tilesPresent or 0
    AddLine("system", string.format("Terrain loaded: zone=%s map=%s chunks=%d markers=%d tiles=%d", tostring(data.zoneKey or "?"), tostring(data.mapName or "?"), chunks, markers, tiles))
  end,
  ["profile enable"] = function() TA:EnableProfiler() end,
  ["profile disable"] = function() TA:DisableProfiler() end,
  ["profile results"] = function() TA:PrintProfiler() end,
  ["loglimit"] = function() TA_SetLineLimit(nil, false) end,
}

TA.PATTERN_INPUT_HANDLERS = {
  { "^help%s+(.+)$", function(topic) TA_ShowHelpTopic(topic) end },
  { "^skills%s+(%a+)$", function(which) TA_ReportSkillLevels(true, which) end },
  { "^skill%s+(%a+)$", function(which) TA_ReportSkillLevels(true, which) end },
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

if TA_RegisterAccessibilityCommandHandlers then
  TA_RegisterAccessibilityCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

if TA_RegisterDFDangerCommandHandlers then
  TA_RegisterDFDangerCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

if TA_RegisterWarlockMLCommandHandlers then
  TA_RegisterWarlockMLCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

if TA_RegisterMacroRecipeCommandHandlers then
  TA_RegisterMacroRecipeCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

if TA_RegisterTalentCommandHandlers then
  TA_RegisterTalentCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

TA_AddPatternInputHandler("^bind%s+(%d+)%s+(%d+)$", function(slot, spellIndex) BindSpellbookSpellToActionSlot(tonumber(slot), tonumber(spellIndex)) end)
TA_AddPatternInputHandler("^bindmacro%s+(%d+)%s+(%d+)$", function(slot, macroIndex) BindMacroToActionSlot(tonumber(slot), tonumber(macroIndex)) end)
TA_AddPatternInputHandler("^actions%s+(%d+)%s+(%d+)$", function(a, b) ReportActionBars(tonumber(a), tonumber(b)) end)
TA_AddPatternInputHandler("^bars%s+(%d+)%s+(%d+)$", function(a, b) ReportActionBars(tonumber(a), tonumber(b)) end)
TA_AddPatternInputHandler("^actions%s+bar(%d+)$", function(n) local b = (tonumber(n) - 1) * 12 + 1; ReportActionBars(b, b + 11) end)
TA_AddPatternInputHandler("^bars%s+bar(%d+)$", function(n) local b = (tonumber(n) - 1) * 12 + 1; ReportActionBars(b, b + 11) end)
TA_AddPatternInputHandler("^loglimit%s+(%d+)$", function(n) TA_SetLineLimit(tonumber(n), false) end)

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

  if TA_HandleSettingsInputCommand and TA_HandleSettingsInputCommand(lower, msg) then
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

