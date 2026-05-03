-- Modules/MacrosAndBindings.lua
-- Action-bar reporting, macro CRUD + casting, spellbook reporting, and the
-- spellbook/macro/bag -> action-slot binders, plus TA_MoveBagItem, for
-- TextAdventurer.
--
-- Extracted from textadventurer.lua. Owns:
--   * Action-slot label helpers GetActionSlotName, ResolveActionLabel
--     (kept module-local, only used by ReportActionBars).
--   * ReportActionBars (promoted; Commands.lua "actions"/"bars" handlers
--     call it).
--   * ReportMacros (promoted; MacroRecipeCommands.lua "macros" handler).
--   * ShowMacroInfo, CastMacroByIndex, CastMacroByName (promoted; bound
--     by MacroRecipeCommands.lua patterns).
--   * Macro-edit helpers ParseNameAndBodyArgs, ParseRenameArgs (promoted),
--     IsMacroEditBlocked (kept module-local; only used internally).
--   * CreateNewMacro, SetMacroBody, RenameMacro, DeleteMacroByIndex
--     (all promoted; called from MacroRecipeCommands.lua and from the
--     multiline terminal-input block still in textadventurer.lua).
--   * ReportSpellbook (promoted; Commands.lua + SpellbookCommands.lua).
--   * BindSpellbookSpellToActionSlot, BindMacroToActionSlot (promoted;
--     Commands.lua pattern handlers).
--   * TA_BindBagItemToActionSlot, TA_MoveBagItem (already true globals;
--     kept here because they're the bag-side counterparts to the
--     spellbook/macro binders).
--
-- All _G.X = X mirror lines at the bottom of textadventurer.lua for
-- ReportActionBars, ReportMacros, ReportSpellbook, ShowMacroInfo,
-- CastMacroByIndex, CastMacroByName, SetMacroBody, ParseRenameArgs,
-- ParseNameAndBodyArgs, RenameMacro, CreateNewMacro, DeleteMacroByIndex,
-- BindSpellbookSpellToActionSlot, and BindMacroToActionSlot are removed
-- since the functions are now declared global at definition.
--
-- Must load AFTER textadventurer.lua and BEFORE Modules/Commands.lua,
-- Modules/MacroRecipeCommands.lua, and Modules/SpellbookCommands.lua.
-- The .toc slot is between Modules/QuestNarration.lua and
-- Modules/VendorInventory.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2979-3622 ----
local function GetActionSlotName(slot)
  if slot <= 12 then return string.format("Bar1-%d", slot) end
  if slot <= 24 then return string.format("Bar2-%d", slot - 12) end
  if slot <= 36 then return string.format("Bar3-%d", slot - 24) end
  if slot <= 48 then return string.format("Bar4-%d", slot - 36) end
  if slot <= 60 then return string.format("Bar5-%d", slot - 48) end
  if slot <= 72 then return string.format("Bar6-%d", slot - 60) end
  return string.format("Action-%d", slot)
end

local function ResolveActionLabel(actionType, id)
  if actionType == "spell" and GetSpellInfo then
    local name = GetSpellInfo(id)
    return name or ("Spell " .. tostring(id))
  elseif actionType == "item" and GetItemInfo then
    local name = GetItemInfo(id)
    return name or ("Item " .. tostring(id))
  elseif actionType == "macro" and GetMacroInfo then
    local name = GetMacroInfo(id)
    return name or ("Macro " .. tostring(id))
  elseif actionType == "companion" then
    return "Companion " .. tostring(id)
  end
  return string.format("%s %s", tostring(actionType), tostring(id))
end

function ReportActionBars(fromSlot, toSlot)
  fromSlot = fromSlot or 1
  toSlot = toSlot or 120
  local found = 0
  for slot = fromSlot, toSlot do
    local actionType, id = GetActionInfo(slot)
    if actionType and id then
      local start, duration, enable = GetActionCooldown(slot)
      local cdText = "ready"
      if enable == 1 and duration and duration > 1.5 and start and start > 0 then
        cdText = string.format("%.1fs cooldown", math.max(0, (start + duration) - GetTime()))
      end
      AddLine("cast", string.format("%s: %s - %s", GetActionSlotName(slot), ResolveActionLabel(actionType, id), cdText))
      found = found + 1
    end
  end
  if found == 0 then
    AddLine("system", string.format("No bound actions in slots %d-%d.", fromSlot, toSlot))
  end
end

function ReportMacros()
  if not GetNumMacros or not GetMacroInfo then
    AddLine("system", "Macro API unavailable.")
    return
  end
  local numMacros = GetNumMacros() or 0
  if numMacros == 0 then
    AddLine("system", "You have no macros.")
    return
  end
  AddLine("system", string.format("=== Your Macros (%d) ===", numMacros))
  for i = 1, numMacros do
    local name, icon, body = GetMacroInfo(i)
    if name then
      AddLine("quest", string.format("[%d] %s", i, name))
    end
  end
  AddLine("system", "Use '/ta macro <index>' to cast, '/ta macroinfo <index>' to view, '/ta macroset <index> <body>' to edit, '/ta macrorename <index> <name>' to rename, '/ta macrocreate <name> <body>' to create, and '/ta macrodelete <index>' to delete.")
end

function ShowMacroInfo(index)
  if not GetMacroInfo then
    AddLine("system", "Macro API unavailable.")
    return
  end
  local name, icon, body = GetMacroInfo(index)
  if not name then
    AddLine("system", string.format("No macro found at index %d.", index))
    return
  end
  AddLine("quest", string.format("=== Macro %d: %s ===", index, name))
  if body and body ~= "" then
    local lines = {}
    for line in body:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    if #lines > 0 then
      for _, line in ipairs(lines) do
        AddLine("cast", line)
      end
    else
      AddLine("cast", "(empty macro)")
    end
  else
    AddLine("cast", "(empty macro)")
  end
end

function CastMacroByIndex(index)
  if not GetNumMacros or not GetMacroInfo then
    AddLine("system", "Macro API unavailable.")
    return
  end
  local numMacros = GetNumMacros() or 0
  if index < 1 or index > numMacros then
    AddLine("system", string.format("Invalid macro index. You have %d macros.", numMacros))
    return
  end
  local name = GetMacroInfo(index)
  if name then
    AddLine("cast", "Casting macro: " .. name)
    CastMacro(index)
  else
    AddLine("system", "Macro not found.")
  end
end

function CastMacroByName(macroName)
  if not GetNumMacros or not GetMacroInfo then
    AddLine("system", "Macro API unavailable.")
    return
  end
  local numMacros = GetNumMacros() or 0
  for i = 1, numMacros do
    local name = GetMacroInfo(i)
    if name and name:lower() == macroName:lower() then
      AddLine("cast", "Casting macro: " .. name)
      CastMacro(i)
      return
    end
  end
  AddLine("system", "Macro '" .. macroName .. "' not found.")
end

function ParseNameAndBodyArgs(args)
  if not args or args == "" then return nil, nil end
  local quotedName, quotedBody = args:match('^"([^"]+)"%s+(.+)$')
  if quotedName and quotedBody then
    return quotedName, quotedBody
  end
  local name, body = args:match("^(%S+)%s+(.+)$")
  return name, body
end

function ParseRenameArgs(args)
  if not args or args == "" then return nil, nil end
  local idxText, quotedName = args:match('^(%d+)%s+"([^"]+)"$')
  if idxText and quotedName then
    return tonumber(idxText), quotedName
  end
  local idxText2, plainName = args:match("^(%d+)%s+(.+)$")
  if idxText2 and plainName then
    return tonumber(idxText2), plainName
  end
  return nil, nil
end

local function IsMacroEditBlocked()
  return InCombatLockdown and InCombatLockdown()
end

function CreateNewMacro(name, body)
  if not CreateMacro then
    AddLine("system", "Macro creation API unavailable.")
    return
  end
  if IsMacroEditBlocked() then
    AddLine("system", "You cannot create macros in combat.")
    return
  end
  if not name or name == "" then
    AddLine("system", "Usage: macrocreate <name> <body>. Use quotes for spaces in name.")
    return
  end
  local created = CreateMacro(name, "INV_MISC_QUESTIONMARK", body or "", nil)
  if created then
    AddLine("cast", string.format("Created macro [%d] %s.", created, name))
  else
    AddLine("system", "Could not create macro (you may be at macro limit).")
  end
end

function SetMacroBody(index, newBody)
  if not EditMacro or not GetMacroInfo then
    AddLine("system", "Macro editing API unavailable.")
    return
  end
  if IsMacroEditBlocked() then
    AddLine("system", "You cannot edit macros in combat.")
    return
  end
  if not index or index < 1 then
    AddLine("system", "Usage: macroset <index> <new body>")
    return
  end
  local name, icon = GetMacroInfo(index)
  if not name then
    AddLine("system", string.format("No macro found at index %d.", index))
    return
  end
  EditMacro(index, name, icon or "INV_MISC_QUESTIONMARK", newBody or "")
  AddLine("cast", string.format("Updated body of macro [%d] %s.", index, name))
end

function RenameMacro(index, newName)
  if not EditMacro or not GetMacroInfo then
    AddLine("system", "Macro editing API unavailable.")
    return
  end
  if IsMacroEditBlocked() then
    AddLine("system", "You cannot rename macros in combat.")
    return
  end
  if not index or index < 1 or not newName or newName == "" then
    AddLine("system", "Usage: macrorename <index> <new name>")
    return
  end
  local oldName, icon, body = GetMacroInfo(index)
  if not oldName then
    AddLine("system", string.format("No macro found at index %d.", index))
    return
  end
  EditMacro(index, newName, icon or "INV_MISC_QUESTIONMARK", body or "")
  AddLine("cast", string.format("Renamed macro [%d] from '%s' to '%s'.", index, oldName, newName))
end

function DeleteMacroByIndex(index)
  if not DeleteMacro or not GetMacroInfo then
    AddLine("system", "Macro deletion API unavailable.")
    return
  end
  if IsMacroEditBlocked() then
    AddLine("system", "You cannot delete macros in combat.")
    return
  end
  if not index or index < 1 then
    AddLine("system", "Usage: macrodelete <index>")
    return
  end
  local name = GetMacroInfo(index)
  if not name then
    AddLine("system", string.format("No macro found at index %d.", index))
    return
  end
  DeleteMacro(index)
  AddLine("cast", string.format("Deleted macro [%d] %s.", index, name))
end

function ReportSpellbook()
  if not GetNumSpellTabs or not GetSpellTabInfo then
    AddLine("system", "Spellbook API unavailable.")
    return
  end

  local function CooldownTextForSpell(spellID)
    local start, duration, enable = GetSpellCooldown(spellID)
    local cdText = "ready"
    if enable == 1 and duration and duration > 1.5 and start and start > 0 then
      cdText = string.format("%.1fs cooldown", math.max(0, (start + duration) - GetTime()))
    end
    return cdText
  end

  local function CooldownTextForPetAction(slot)
    if not GetPetActionCooldown then return "ready" end
    local start, duration, enable = GetPetActionCooldown(slot)
    local cdText = "ready"
    if enable == 1 and duration and duration > 1.5 and start and start > 0 then
      cdText = string.format("%.1fs cooldown", math.max(0, (start + duration) - GetTime()))
    end
    return cdText
  end

  local numTabs = GetNumSpellTabs() or 0
  local foundAny = false
  for t = 1, numTabs do
    local tabName, _, offset, numSpells = GetSpellTabInfo(t)
    AddLine("system", string.format("== %s ==", tabName or ("Tab " .. t)))
    for i = 1, (numSpells or 0) do
      local index = (offset or 0) + i
      local skillType, spellID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
      if skillType == "SPELL" then
        local spellName = GetSpellBookItemName(index, BOOKTYPE_SPELL)
        if spellName then
          local cdText = CooldownTextForSpell(spellID)
          AddLine("cast", string.format("[%d] %s - %s", index, spellName, cdText))
          foundAny = true
        end
      end
    end
  end

  local petFound = false
  local petSectionShown = false
  local seenPetNames = {}
  if UnitExists and UnitExists("pet") then
    AddLine("system", "== Pet Abilities ==")
    petSectionShown = true
  end

  if petSectionShown and BOOKTYPE_PET and HasPetSpells and GetSpellBookItemInfo and GetSpellBookItemName then
    local numPetSpells = select(1, HasPetSpells()) or 0
    if type(numPetSpells) ~= "number" then numPetSpells = 0 end
    for i = 1, numPetSpells do
      local skillType, spellID = GetSpellBookItemInfo(i, BOOKTYPE_PET)
      if skillType == "SPELL" then
        local spellName = GetSpellBookItemName(i, BOOKTYPE_PET)
        if spellName and spellName ~= "" then
          local cdText = CooldownTextForSpell(spellID)
          AddLine("cast", string.format("[pet %d] %s - %s", i, spellName, cdText))
          seenPetNames[spellName] = true
          petFound = true
        end
      end
    end
  end

  if petSectionShown and GetPetActionInfo then
    for i = 1, 10 do
      local name, _, _, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)
      if name and name ~= "" then
        local displayName = name
        if isToken and _G[name] then displayName = _G[name] end
        if not seenPetNames[displayName] then
          local cdText = CooldownTextForPetAction(i)
          local stateBits = {}
          if isActive then table.insert(stateBits, "active") end
          if autoCastAllowed then
            table.insert(stateBits, autoCastEnabled and "autocast on" or "autocast off")
          end
          local suffix = ""
          if #stateBits > 0 then
            suffix = " [" .. table.concat(stateBits, ", ") .. "]"
          end
          AddLine("cast", string.format("[petbar %d] %s - %s%s", i, displayName, cdText, suffix))
          seenPetNames[displayName] = true
          petFound = true
        end
      end
    end
  end

  if petSectionShown and not petFound then
    AddLine("system", "No pet abilities are currently visible. Summon your pet and open your spellbook once, then try again.")
  end
  if petFound then foundAny = true end

  if not foundAny then AddLine("system", "No spells found in spellbook.") end
end

function BindSpellbookSpellToActionSlot(actionSlot, spellbookIndex)
  local function BindFeedback(message, channel)
    AddLine(channel or "system", message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("[TextAdventurer] " .. message)
    end
  end

  local function ResolveBindActionSlot(slot)
    local page = (GetActionBarPage and GetActionBarPage()) or 1
    if slot >= 1 and slot <= 12 then
      local button = _G["ActionButton" .. tostring(slot)]
      local buttonAction = button and button.action
      if type(buttonAction) == "number" and buttonAction >= 1 and buttonAction <= 120 then
        return buttonAction, page, true
      end
      if page and page > 1 then
        return ((page - 1) * 12) + slot, page, true
      end
      return slot, page, true
    end
    return slot, page, false
  end

  if not actionSlot or not spellbookIndex then
    BindFeedback("Usage: bind <actionSlot> <spellbookIndex>")
    return
  end
  local resolvedSlot, page, isMainBarSlot = ResolveBindActionSlot(actionSlot)
  BindFeedback(string.format("Attempting bind: spellbook %d -> slot %d (resolved action slot %d)", spellbookIndex, actionSlot, resolvedSlot))
  if isMainBarSlot and page and page > 1 then
    BindFeedback(string.format("Main bar slot %d resolved to action slot %d on visible page %d.", actionSlot, resolvedSlot, page))
  end
  if resolvedSlot < 1 or resolvedSlot > 120 then
    BindFeedback("Action slot must be between 1 and 120.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    BindFeedback("You cannot change action bars in combat.")
    return
  end
  if not PickupSpellBookItem or not PlaceAction or not GetActionInfo then
    BindFeedback("Action bar binding API unavailable.")
    return
  end
  local skillType, spellID = GetSpellBookItemInfo(spellbookIndex, BOOKTYPE_SPELL)
  if skillType ~= "SPELL" then
    BindFeedback(string.format("No spell found at spellbook index %d.", spellbookIndex))
    return
  end
  local spellName = GetSpellBookItemName(spellbookIndex, BOOKTYPE_SPELL) or ("Spell " .. tostring(spellID))
  ClearCursor()
  PickupSpellBookItem(spellbookIndex, BOOKTYPE_SPELL)
  local cursorType = GetCursorInfo and GetCursorInfo() or nil
  if cursorType ~= "spell" then
    ClearCursor()
    BindFeedback(string.format("Could not pick up %s from spellbook index %d. It may be passive or unavailable.", spellName, spellbookIndex))
    return
  end
  PlaceAction(resolvedSlot)
  ClearCursor()
  local newActionType, newActionID = GetActionInfo(resolvedSlot)
  local placed = false
  if newActionType == "spell" then
    if spellID and newActionID == spellID then
      placed = true
    elseif GetSpellInfo and newActionID then
      local newName = GetSpellInfo(newActionID)
      if newName and newName == spellName then
        placed = true
      end
    end
  end
  if placed then
    BindFeedback(string.format("Placed %s into action slot %d (resolved %d).", spellName, actionSlot, resolvedSlot), "cast")
  else
    BindFeedback(string.format("Could not place %s into action slot %d (resolved %d, slot currently: %s %s).", spellName, actionSlot, resolvedSlot, tostring(newActionType or "empty"), tostring(newActionID or "")))
  end
end

function BindMacroToActionSlot(actionSlot, macroIndex)
  local function BindFeedback(message, channel)
    AddLine(channel or "system", message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("[TextAdventurer] " .. message)
    end
  end

  local function ResolveBindActionSlot(slot)
    local page = (GetActionBarPage and GetActionBarPage()) or 1
    if slot >= 1 and slot <= 12 then
      local button = _G["ActionButton" .. tostring(slot)]
      local buttonAction = button and button.action
      if type(buttonAction) == "number" and buttonAction >= 1 and buttonAction <= 120 then
        return buttonAction, page, true
      end
      if page and page > 1 then
        return ((page - 1) * 12) + slot, page, true
      end
      return slot, page, true
    end
    return slot, page, false
  end

  if not actionSlot or not macroIndex then
    BindFeedback("Usage: bindmacro <actionSlot> <macroIndex>")
    return
  end
  local resolvedSlot, page, isMainBarSlot = ResolveBindActionSlot(actionSlot)
  BindFeedback(string.format("Attempting bindmacro: macro %d -> slot %d (resolved action slot %d)", macroIndex, actionSlot, resolvedSlot))
  if isMainBarSlot and page and page > 1 then
    BindFeedback(string.format("Main bar slot %d resolved to action slot %d on visible page %d.", actionSlot, resolvedSlot, page))
  end
  if resolvedSlot < 1 or resolvedSlot > 120 then
    BindFeedback("Action slot must be between 1 and 120.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    BindFeedback("You cannot change action bars in combat.")
    return
  end
  if not PickupMacro or not PlaceAction or not GetMacroInfo or not GetActionInfo then
    BindFeedback("Macro binding API unavailable.")
    return
  end
  local macroName = GetMacroInfo(macroIndex)
  if not macroName then
    BindFeedback(string.format("No macro found at index %d.", macroIndex))
    return
  end
  ClearCursor()
  PickupMacro(macroIndex)
  local cursorType, cursorID = GetCursorInfo and GetCursorInfo() or nil, nil
  if GetCursorInfo then
    local _, id = GetCursorInfo()
    cursorID = id
  end
  if cursorType ~= "macro" then
    ClearCursor()
    BindFeedback(string.format("Could not pick up macro '%s' (index %d).", macroName, macroIndex))
    return
  end
  PlaceAction(resolvedSlot)
  ClearCursor()
  local newActionType, newActionID = GetActionInfo(resolvedSlot)
  if newActionType == "macro" and newActionID == macroIndex then
    BindFeedback(string.format("Placed macro '%s' into action slot %d (resolved %d).", macroName, actionSlot, resolvedSlot), "cast")
  else
    BindFeedback(string.format("Could not place macro '%s' into action slot %d (resolved %d, cursor macro id %s, slot currently: %s %s).", macroName, actionSlot, resolvedSlot, tostring(cursorID or "?"), tostring(newActionType or "empty"), tostring(newActionID or "")))
  end
end

function TA_BindBagItemToActionSlot(actionSlot, bag, slot)
  local function BindFeedback(message, channel)
    AddLine(channel or "system", message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("[TextAdventurer] " .. message)
    end
  end

  local function ResolveBindActionSlot(slotNumber)
    local page = (GetActionBarPage and GetActionBarPage()) or 1
    if slotNumber >= 1 and slotNumber <= 12 then
      local button = _G["ActionButton" .. tostring(slotNumber)]
      local buttonAction = button and button.action
      if type(buttonAction) == "number" and buttonAction >= 1 and buttonAction <= 120 then
        return buttonAction, page, true
      end
      if page and page > 1 then
        return ((page - 1) * 12) + slotNumber, page, true
      end
      return slotNumber, page, true
    end
    return slotNumber, page, false
  end

  if not actionSlot or bag == nil or not slot then
    BindFeedback("Usage: binditem <actionSlot> <bag> <slot>")
    return
  end

  local resolvedSlot, page, isMainBarSlot = ResolveBindActionSlot(actionSlot)
  if resolvedSlot < 1 or resolvedSlot > 120 then
    BindFeedback("Action slot must be between 1 and 120.")
    return
  end
  if isMainBarSlot and page and page > 1 then
    BindFeedback(string.format("Main bar slot %d resolved to action slot %d on visible page %d.", actionSlot, resolvedSlot, page))
  end

  if InCombatLockdown and InCombatLockdown() then
    BindFeedback("You cannot change action bars in combat.")
    return
  end
  if not PlaceAction or not GetActionInfo then
    BindFeedback("Action bar binding API unavailable.")
    return
  end
  if not (C_Container and C_Container.GetContainerItemInfo) then
    BindFeedback("Container API unavailable.")
    return
  end

  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    BindFeedback(string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  local itemRef = info.hyperlink or tostring(info.itemID or "item")
  ClearCursor()
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  elseif PickupContainerItem then
    PickupContainerItem(bag, slot)
  else
    BindFeedback("Container pickup API unavailable.")
    return
  end

  local cursorType = GetCursorInfo and GetCursorInfo() or nil
  if cursorType ~= "item" then
    ClearCursor()
    BindFeedback(string.format("Could not pick up %s from %s slot %d.", itemRef, BagLabel(bag), slot))
    return
  end

  PlaceAction(resolvedSlot)
  ClearCursor()

  local newActionType, newActionID = GetActionInfo(resolvedSlot)
  local placed = newActionType == "item"
  if placed and info.itemID and newActionID and tonumber(newActionID) ~= tonumber(info.itemID) then
    placed = false
  end

  if placed then
    BindFeedback(string.format("Placed %s into action slot %d (resolved %d).", itemRef, actionSlot, resolvedSlot), "cast")
  else
    BindFeedback(string.format("Could not place %s into action slot %d (resolved %d, slot currently: %s %s).", itemRef, actionSlot, resolvedSlot, tostring(newActionType or "empty"), tostring(newActionID or "")))
  end
end

function TA_MoveBagItem(srcBag, srcSlot, dstBag, dstSlot)
  local function BagLabel(bag)
    return bag == 0 and "backpack" or ("bag " .. tostring(bag))
  end
  if srcBag == nil or srcSlot == nil or dstBag == nil or dstSlot == nil then
    AddLine("system", "Usage: moveitem <srcBag> <srcSlot> <dstBag> <dstSlot>")
    AddLine("system", "  Bags: 0=backpack, 1-4=bag slots. Example: moveitem 0 3 1 1")
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "Cannot move items during combat.")
    return
  end

  if not (C_Container and C_Container.GetContainerItemInfo and C_Container.PickupContainerItem) then
    AddLine("system", "Container API unavailable.")
    return
  end

  local srcInfo = C_Container.GetContainerItemInfo(srcBag, srcSlot)
  if not srcInfo then
    AddLine("system", string.format("No item in %s slot %d.", BagLabel(srcBag), srcSlot))
    return
  end

  local srcName = srcInfo.hyperlink or tostring(srcInfo.itemID or "item")
  local dstInfo = C_Container.GetContainerItemInfo(dstBag, dstSlot)

  ClearCursor()
  C_Container.PickupContainerItem(srcBag, srcSlot)

  local cursorType = GetCursorInfo and GetCursorInfo() or nil
  if cursorType ~= "item" then
    ClearCursor()
    AddLine("system", string.format("Could not pick up %s from %s slot %d.", srcName, BagLabel(srcBag), srcSlot))
    return
  end

  C_Container.PickupContainerItem(dstBag, dstSlot)
  ClearCursor()

  local newSrcInfo = C_Container.GetContainerItemInfo(srcBag, srcSlot)
  local newDstInfo = C_Container.GetContainerItemInfo(dstBag, dstSlot)

  if dstInfo then
    local dstName = dstInfo.hyperlink or tostring(dstInfo.itemID or "item")
    AddLine("system", string.format("Swapped %s (%s/%d) with %s (%s/%d).",
      srcName, BagLabel(srcBag), srcSlot,
      dstName, BagLabel(dstBag), dstSlot))
  else
    AddLine("system", string.format("Moved %s to %s slot %d.", srcName, BagLabel(dstBag), dstSlot))
  end
end

