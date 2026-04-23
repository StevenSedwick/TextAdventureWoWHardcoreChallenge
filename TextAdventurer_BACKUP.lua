-- TextAdventurer.lua
-- Put this file in:
-- World of Warcraft/_classic_/Interface/AddOns/TextAdventurer/
--
-- Make sure your TextAdventurer.toc contains:
-- ## Interface: 11507
-- ## Title: Text Adventurer
-- ## Notes: Text-first WoW exploration addon
-- ## Author: You
-- ## Version: 0.1
-- ## SavedVariablesPerCharacter: TextAdventurerDB
-- TextAdventurer.lua

local addonName = ...

TextAdventurerDB = TextAdventurerDB or {}
TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}

local TA = CreateFrame("Frame", "TextAdventurerFrame")
TA.lastTargetGUID = nil
TA.lastTargetName = nil
TA.lastMoving = false
TA.lastFalling = false
TA.fallStartTime = 0
TA.lastFacingBucket = nil
TA.lastSpeedCategory = nil
TA.moveTicker = nil
TA.awarenessTicker = nil
TA.lineLimit = 900
TA.lines = {}
TA.lastNearbySignature = nil
TA.textMode = false
TA.bagState = {}
TA.pendingLoot = false
TA.lastLocationSignature = nil
TA.lastStatusBucket = nil
TA.lastExplorationBucket = nil
TA.autoQuests = true
TA.captureChat = true

local GRID_SIZE = 12

local COLORS = {
  system   = { 0.85, 0.85, 0.85 },
  trace    = { 0.55, 0.75, 1.00 },
  combat   = { 1.00, 0.35, 0.35 },
  cast     = { 0.95, 0.80, 0.35 },
  target   = { 0.50, 1.00, 0.50 },
  corpse   = { 0.75, 0.75, 0.75 },
  loot     = { 1.00, 0.82, 0.20 },
  nearby   = { 0.70, 0.90, 1.00 },
  friendly = { 0.45, 1.00, 0.45 },
  hostile  = { 1.00, 0.40, 0.40 },
  neutral  = { 1.00, 0.85, 0.45 },
  status   = { 1.00, 0.60, 1.00 },
  place    = { 0.60, 1.00, 0.90 },
  quest    = { 0.95, 0.95, 0.45 },
  chat     = { 0.80, 0.80, 1.00 },
  whisper  = { 1.00, 0.60, 1.00 },
}

local overlay = CreateFrame("Frame", "TextAdventurerOverlay", UIParent)
overlay:SetAllPoints(UIParent)
overlay:SetFrameStrata("FULLSCREEN_DIALOG")
overlay:SetFrameLevel(10000)
overlay:EnableMouse(false)
overlay:Hide()

overlay.tex = overlay:CreateTexture(nil, "BACKGROUND")
overlay.tex:SetAllPoints()
overlay.tex:SetColorTexture(0, 0, 0, 1)

local panel = CreateFrame("Frame", "TextAdventurerPanel", UIParent, "BackdropTemplate")
panel:SetSize(920, 560)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, -10)
panel:SetFrameStrata("TOOLTIP")
panel:SetFrameLevel(11000)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("Text Adventurer")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPRIGHT", -14, -16)
subtitle:SetText("/ta help")

local text = CreateFrame("ScrollingMessageFrame", nil, panel)
text:SetPoint("TOPLEFT", 18, -42)
text:SetPoint("BOTTOMRIGHT", -38, 48)
text:SetFontObject(ChatFontNormal)
text:SetJustifyH("LEFT")
text:SetFading(false)
text:SetMaxLines(900)
text:SetInsertMode("BOTTOM")
text:SetIndentedWordWrap(true)
text:EnableMouseWheel(true)
text:SetScript("OnMouseWheel", function(self, delta)
  if delta > 0 then
    self:ScrollUp()
  else
    self:ScrollDown()
  end
end)
panel.text = text

local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
inputBox:SetSize(840, 24)
inputBox:SetPoint("BOTTOMLEFT", 18, 16)
inputBox:SetAutoFocus(false)
inputBox:SetMaxLetters(200)
inputBox:Hide()
panel.inputBox = inputBox

local function AddLine(kind, msg)
  if not msg or msg == "" then return end

  local c = COLORS[kind] or COLORS.system
  local line = {
    text = date("%H:%M:%S") .. "  " .. msg,
    r = c[1],
    g = c[2],
    b = c[3],
  }

  table.insert(TA.lines, line)
  if #TA.lines > TA.lineLimit then
    table.remove(TA.lines, 1)
  end

  panel.text:Clear()
  for i = 1, #TA.lines do
    local entry = TA.lines[i]
    panel.text:AddMessage(entry.text, entry.r, entry.g, entry.b)
  end
  panel.text:ScrollToBottom()
end

local function BagLabel(bag)
  if bag == 0 then
    return "Backpack"
  end
  return string.format("Bag %d", bag)
end

local function SnapshotBags()
  local snapshot = {}
  for bag = 0, 4 do
    snapshot[bag] = {}
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info then
        snapshot[bag][slot] = {
          itemID = info.itemID,
          stackCount = info.stackCount or 0,
          hyperlink = info.hyperlink,
        }
      else
        snapshot[bag][slot] = nil
      end
    end
  end
  return snapshot
end

local function FindBagChanges(oldState, newState)
  local changes = {}
  for bag = 0, 4 do
    local oldBag = oldState[bag] or {}
    local newBag = newState[bag] or {}
    local maxSlots = math.max(#oldBag, #newBag)

    for slot = 1, maxSlots do
      local oldItem = oldBag[slot]
      local newItem = newBag[slot]

      if not oldItem and newItem then
        table.insert(changes, string.format(
          "Loot placed in %s slot %d: %s x%d",
          BagLabel(bag),
          slot,
          newItem.hyperlink or ("item:" .. tostring(newItem.itemID or "?")),
          newItem.stackCount or 1
        ))
      elseif oldItem and newItem and oldItem.itemID == newItem.itemID then
        local oldCount = oldItem.stackCount or 0
        local newCount = newItem.stackCount or 0
        if newCount > oldCount then
          table.insert(changes, string.format(
            "Loot added in %s slot %d: %s +%d",
            BagLabel(bag),
            slot,
            newItem.hyperlink or ("item:" .. tostring(newItem.itemID or "?")),
            newCount - oldCount
          ))
        end
      end
    end
  end
  return changes
end

local function SpellLabel(spellName)
  if spellName and spellName ~= "" then
    return spellName
  end
  return "an ability"
end

local function IsSourcePlayerOrPet(sourceFlags)
  return CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME)
      or CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MY_PET)
end

local function IsDestPlayerOrPet(destFlags)
  return CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_ME)
      or CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_MY_PET)
end

local function FormatDamageEvent(subevent, sourceName, destName, spellName, amount)
  local actor = sourceName or "Unknown"
  local target = destName or "Unknown"
  local ability = SpellLabel(spellName)

  if subevent == "SWING_DAMAGE" then
    return string.format("%s strikes %s for %d.", actor, target, amount or 0)
  elseif subevent == "RANGE_DAMAGE" then
    return string.format("%s shoots %s with %s for %d.", actor, target, ability, amount or 0)
  else
    return string.format("%s hits %s with %s for %d.", actor, target, ability, amount or 0)
  end
end

local function FormatMissEvent(subevent, sourceName, destName, spellName, missType)
  local actor = sourceName or "Unknown"
  local target = destName or "Unknown"
  local ability = SpellLabel(spellName)
  local why = missType or "MISS"

  if subevent == "SWING_MISSED" then
    return string.format("%s attacks %s, but it %s.", actor, target, string.lower(why))
  else
    return string.format("%s uses %s on %s, but it %s.", actor, ability, target, string.lower(why))
  end
end

local function HandleCombatLog()
  local _, subevent,
    _,
    _, sourceName, sourceFlags,
    _,
    _, destName, destFlags,
    _,
    param1, param2, _, param4 = CombatLogGetCurrentEventInfo()

  if subevent == "SWING_DAMAGE" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      AddLine("combat", FormatDamageEvent(subevent, sourceName, destName, nil, param1))
    end
  elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      AddLine("combat", FormatDamageEvent(subevent, sourceName, destName, param2, param4))
    end
  elseif subevent == "SWING_MISSED" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      AddLine("combat", FormatMissEvent(subevent, sourceName, destName, nil, param1))
    end
  elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      AddLine("combat", FormatMissEvent(subevent, sourceName, destName, param2, param4))
    end
  elseif subevent == "SPELL_CAST_SUCCESS" then
    if IsSourcePlayerOrPet(sourceFlags) then
      AddLine("cast", string.format("%s uses %s.", sourceName or "Unknown", SpellLabel(param2)))
    end
  elseif subevent == "UNIT_DIED" then
    if destName then
      AddLine("corpse", string.format("%s dies and leaves a corpse.", destName))
    end
  end
end

local function CheckTarget()
  if not UnitExists("target") then
    if TA.lastTargetGUID then
      AddLine("target", "You clear your target.")
      TA.lastTargetGUID = nil
      TA.lastTargetName = nil
    end
    return
  end

  local guid = UnitGUID("target")
  local name = UnitName("target") or "Unknown"
  local level = UnitLevel("target")
  local dead = UnitIsDeadOrGhost("target")
  local reaction = UnitCanAttack("player", "target") and "hostile" or "neutral/friendly"

  if guid ~= TA.lastTargetGUID then
    if dead then
      AddLine("corpse", string.format("You target the corpse of %s.", name))
    else
      AddLine("target", string.format("You target %s (level %s, %s).", name, level > 0 and level or "??", reaction))
    end

    TA.lastTargetGUID = guid
    TA.lastTargetName = name
  end
end

local function FacingToCardinal(facing)
  if not facing then return nil end
  local deg = math.deg(facing) % 360

  if deg < 22.5 then
    return "north"
  elseif deg < 67.5 then
    return "northwest"
  elseif deg < 112.5 then
    return "west"
  elseif deg < 157.5 then
    return "southwest"
  elseif deg < 202.5 then
    return "south"
  elseif deg < 247.5 then
    return "southeast"
  elseif deg < 292.5 then
    return "east"
  elseif deg < 337.5 then
    return "northeast"
  else
    return "north"
  end
end

local function SpeedCategory(speed)
  speed = speed or 0
  if speed <= 0 then
    return "still"
  elseif speed < 7.5 then
    return "walking"
  elseif speed < 13.5 then
    return "running"
  else
    return "fast"
  end
end

local function ReportLocation(force)
  local zone = GetZoneText() or "Unknown zone"
  local subzone = GetSubZoneText() or ""
  local facingLabel = FacingToCardinal(GetPlayerFacing()) or "unknown direction"
  local descriptor

  if subzone ~= "" then
    descriptor = string.format("You are in %s, %s, facing %s.", subzone, zone, facingLabel)
  else
    descriptor = string.format("You are in %s, facing %s.", zone, facingLabel)
  end

  if force or descriptor ~= TA.lastLocationSignature then
    AddLine("place", descriptor)
    TA.lastLocationSignature = descriptor
  end
end

local function ReportTrainerServices()
  if not GetNumTrainerServices or not GetTrainerServiceInfo then
    AddLine("system", "Trainer API unavailable.")
    return
  end

  local num = GetNumTrainerServices() or 0
  if num <= 0 then
    AddLine("system", "No trainer services available.")
    return
  end

  local shown = 0

  for i = 1, num do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name then
      local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
      local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0

      local reqText = ""
      if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        local reqCount = GetTrainerServiceNumAbilityReq(i) or 0
        local reqParts = {}
        for r = 1, reqCount do
          local reqName, hasReq = GetTrainerServiceAbilityReq(i, r)
          if reqName and not hasReq then
            table.insert(reqParts, reqName)
          end
        end
        if #reqParts > 0 then
          reqText = " | Missing: " .. table.concat(reqParts, ", ")
        end
      end

      AddLine("cast", string.format(
        "[%d] %s%s | %s | Cost: %d | Level: %d%s",
        i,
        name,
        rank and rank ~= "" and (" (" .. rank .. ")") or "",
        tostring(category),
        cost or 0,
        levelReq or 0,
        reqText
      ))
      shown = shown + 1
    end
  end

  if shown == 0 then
    AddLine("system", "Trainer window is open, but no skills were found.")
  end
end

local function TrainServiceByIndex(index)
  if not index or index < 1 then
    AddLine("system", "Invalid trainer index.")
    return
  end

  if not BuyTrainerService or not GetTrainerServiceInfo then
    AddLine("system", "Trainer purchase API unavailable.")
    return
  end

  local name = GetTrainerServiceInfo(index)
  if not name then
    AddLine("system", string.format("No trainer service found at index %d.", index))
    return
  end

  BuyTrainerService(index)
  AddLine("quest", string.format("Attempted to train [%d] %s.", index, name))
end

local function TrainAllAvailableServices()
  if not GetNumTrainerServices or not GetTrainerServiceInfo or not BuyTrainerService then
    AddLine("system", "Trainer API unavailable.")
    return
  end

  local num = GetNumTrainerServices() or 0
  local bought = 0

  for i = 1, num do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name and category == "available" then
      BuyTrainerService(i)
      AddLine("quest", string.format(
        "Attempted to train [%d] %s%s.",
        i,
        name,
        rank and rank ~= "" and (" (" .. rank .. ")") or ""
      ))
      bought = bought + 1
    end
  end

  if bought == 0 then
    AddLine("system", "No currently available trainer skills to buy.")
  end
end

local function ReportStatus(force)
  local hp = UnitHealth("player") or 0
  local hpMax = UnitHealthMax("player") or 1
  local hpPct = hpMax > 0 and (hp / hpMax * 100) or 0
  local rage = UnitPower("player") or 0
  local rageMax = UnitPowerMax("player") or 0

  local state
  if hpPct >= 85 then
    state = "You are in strong condition"
  elseif hpPct >= 60 then
    state = "You are lightly wounded"
  elseif hpPct >= 35 then
    state = "You are wounded"
  else
    state = "You are badly wounded"
  end

  local bucket = string.format("%d|%d", math.floor(hpPct / 10), rage)
  if force or bucket ~= TA.lastStatusBucket then
    AddLine("status", string.format("%s: health %d/%d (%.0f%%), rage %d/%d.", state, hp, hpMax, hpPct, rage, rageMax))
    TA.lastStatusBucket = bucket
  end
end

local function ReportXP()
  local level = UnitLevel("player") or 0
  local xp = UnitXP("player") or 0
  local xpMax = UnitXPMax("player") or 0
  local remaining = math.max(0, xpMax - xp)
  local pct = xpMax > 0 and (xp / xpMax * 100) or 0
  AddLine("status", string.format("Level %d. XP %d/%d (%.1f%%). %d to next level.", level, xp, xpMax, pct, remaining))
end

local function ReportTracking()
  local found = false
  if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
    local num = C_Minimap.GetNumTrackingTypes() or 0
    for i = 1, num do
      local info = C_Minimap.GetTrackingInfo(i)
      if info and info.active then
        AddLine("place", "Tracking active: " .. (info.name or "Unknown"))
        found = true
      end
    end
  elseif GetNumTrackingTypes and GetTrackingInfo then
    local num = GetNumTrackingTypes() or 0
    for i = 1, num do
      local name, _, active = GetTrackingInfo(i)
      if name and active then
        AddLine("place", "Tracking active: " .. name)
        found = true
      end
    end
  end
  if not found then
    AddLine("place", "No minimap tracking is active.")
  end
end

local EQUIP_SLOTS = {
  { 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" },
  { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 5, "Chest" },
  { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 9, "Wrist" },
  { 10, "Hands" }, { 11, "Finger 1" }, { 12, "Finger 2" },
  { 13, "Trinket 1" }, { 14, "Trinket 2" }, { 15, "Back" },
}

local function ReportEquipment()
  for _, entry in ipairs(EQUIP_SLOTS) do
    local slotId, label = entry[1], entry[2]
    local link = GetInventoryItemLink("player", slotId)
    if link then
      AddLine("target", string.format("%s: %s", label, link))
    else
      AddLine("target", string.format("%s: Empty", label))
    end
  end
end

local function ReportInventory()
  for bag = 0, 4 do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info then
        AddLine("loot", string.format("%s slot %d: %s x%d", BagLabel(bag), slot, info.hyperlink or ("item:" .. tostring(info.itemID or "?")), info.stackCount or 1))
      end
    end
  end
end

local function GetActionSlotName(slot)
  if slot <= 12 then
    return string.format("Bar1-%d", slot)
  elseif slot <= 24 then
    return string.format("Bar2-%d", slot - 12)
  elseif slot <= 36 then
    return string.format("Bar3-%d", slot - 24)
  elseif slot <= 48 then
    return string.format("Bar4-%d", slot - 36)
  elseif slot <= 60 then
    return string.format("Bar5-%d", slot - 48)
  elseif slot <= 72 then
    return string.format("Bar6-%d", slot - 60)
  else
    return string.format("Action-%d", slot)
  end
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

local function ReportActionBars()
  for slot = 1, 120 do
    local actionType, id = GetActionInfo(slot)
    if actionType and id then
      local start, duration, enable = GetActionCooldown(slot)
      local cdText = "ready"
      if enable == 1 and duration and duration > 1.5 and start and start > 0 then
        local remaining = math.max(0, (start + duration) - GetTime())
        cdText = string.format("%.1fs cooldown", remaining)
      end
      AddLine("cast", string.format("%s: %s - %s", GetActionSlotName(slot), ResolveActionLabel(actionType, id), cdText))
    end
  end
end

local function ReportSpellbook()
  if not GetNumSpellTabs or not GetSpellTabInfo then
    AddLine("system", "Spellbook API unavailable.")
    return
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
          local start, duration, enable = GetSpellCooldown(spellID)
          local cdText = "ready"
          if enable == 1 and duration and duration > 1.5 and start and start > 0 then
            local remaining = math.max(0, (start + duration) - GetTime())
            cdText = string.format("%.1fs cooldown", remaining)
          end
          AddLine("cast", string.format("%s - %s", spellName, cdText))
          foundAny = true
        end
      end
    end
  end

  if not foundAny then
    AddLine("system", "No spells found in spellbook.")
  end
end

local function GetPlayerMapCell()
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end

  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end

  local x, y = pos:GetXY()
  if not x or not y then return nil end

  local cellX = math.max(0, math.min(GRID_SIZE - 1, math.floor(x * GRID_SIZE)))
  local cellY = math.max(0, math.min(GRID_SIZE - 1, math.floor(y * GRID_SIZE)))

  return mapID, cellX, cellY
end

local function GetExplorationData(mapID)
  if not TextAdventurerDB.exploration[mapID] then
    TextAdventurerDB.exploration[mapID] = {
      visited = {},
      visits = {},
      minX = nil,
      maxX = nil,
      minY = nil,
      maxY = nil,
    }
  end
  return TextAdventurerDB.exploration[mapID]
end

local function CellKey(x, y)
  return tostring(x) .. "," .. tostring(y)
end

local function UpdateExplorationMemory()
  local mapID, cellX, cellY = GetPlayerMapCell()
  if not mapID then return end

  local data = GetExplorationData(mapID)
  local key = CellKey(cellX, cellY)

  if not data.visited[key] then
    data.visited[key] = true
    data.visits[key] = 1

    if data.minX == nil or cellX < data.minX then data.minX = cellX end
    if data.maxX == nil or cellX > data.maxX then data.maxX = cellX end
    if data.minY == nil or cellY < data.minY then data.minY = cellY end
    if data.maxY == nil or cellY > data.maxY then data.maxY = cellY end

    AddLine("place", "You step into unexplored territory.")
  else
    data.visits[key] = (data.visits[key] or 0) + 1
  end
end

local function ReportExplorationMemory(force)
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
    for i = 1, #messages do
      AddLine("place", messages[i])
    end
    TA.lastExplorationBucket = bucket
  end
end

local function CheckFallState()
  local falling = IsFalling()
  if falling and not TA.lastFalling then
    TA.lastFalling = true
    TA.fallStartTime = GetTime()
    AddLine("trace", "WARNING: sudden drop.")
    AddLine("trace", "You are falling.")
  elseif not falling and TA.lastFalling then
    TA.lastFalling = false
    local duration = GetTime() - TA.fallStartTime
    if duration > 1.2 then
      AddLine("trace", "You fall a long distance and hit the ground hard.")
    elseif duration > 0.5 then
      AddLine("trace", "You drop down to a lower level.")
    else
      AddLine("trace", "You regain stable footing.")
    end
  end
end

local function CheckMovement()
  local speed = GetUnitSpeed("player") or 0
  local movingNow = speed > 0
  local facing = GetPlayerFacing()
  local facingLabel = FacingToCardinal(facing)
  local speedLabel = SpeedCategory(speed)

  if movingNow ~= TA.lastMoving then
    if movingNow then
      AddLine("trace", "TRACE: PLAYER_STARTED_MOVING")
      AddLine("trace", string.format("You begin moving %s.", facingLabel or "forward"))
    else
      AddLine("trace", "TRACE: PLAYER_STOPPED_MOVING")
      AddLine("trace", "You come to a stop.")
      ReportLocation(false)
      ReportExplorationMemory(false)
    end
    TA.lastMoving = movingNow
  end

  if movingNow and facingLabel and facingLabel ~= TA.lastFacingBucket then
    AddLine("trace", string.format("TRACE: PLAYER_FACING %s", facingLabel))
    AddLine("trace", string.format("You turn toward the %s.", facingLabel))
    TA.lastFacingBucket = facingLabel
  elseif not movingNow then
    TA.lastFacingBucket = facingLabel
  end

  if speedLabel ~= TA.lastSpeedCategory then
    if speedLabel == "walking" then
      AddLine("trace", string.format("TRACE: PLAYER_SPEED %.2f", speed))
      AddLine("trace", "You are walking.")
    elseif speedLabel == "running" then
      AddLine("trace", string.format("TRACE: PLAYER_SPEED %.2f", speed))
      AddLine("trace", "You are running.")
    elseif speedLabel == "fast" then
      AddLine("trace", string.format("TRACE: PLAYER_SPEED %.2f", speed))
      AddLine("trace", "You move at high speed.")
    end
    TA.lastSpeedCategory = speedLabel
  end
end

local function BuildNearbyLine(kind, names)
  if #names == 0 then return nil end
  return string.format("%s nearby: %s", kind, table.concat(names, ", "))
end

local function GetNearbyUnitsSummary()
  local seen = {}
  local hostiles, neutrals, friendlies = {}, {}, {}

  local nameplates = C_NamePlate.GetNamePlates()
  for _, frame in ipairs(nameplates) do
    local unit = frame.namePlateUnitToken
    if unit and UnitExists(unit) then
      local name = UnitName(unit)
      if name and not seen[name] then
        seen[name] = true
        if UnitCanAttack("player", unit) then
          table.insert(hostiles, name)
        else
          local reaction = UnitReaction(unit, "player") or 4
          if reaction >= 5 then
            table.insert(friendlies, name)
          else
            table.insert(neutrals, name)
          end
        end
      end
    end
  end

  table.sort(hostiles)
  table.sort(neutrals)
  table.sort(friendlies)

  return {
    hostile = BuildNearbyLine("Hostile", hostiles),
    neutral = BuildNearbyLine("Neutral", neutrals),
    friendly = BuildNearbyLine("Friendly", friendlies),
    signature = table.concat({
      table.concat(hostiles, ","),
      table.concat(neutrals, ","),
      table.concat(friendlies, ",")
    }, "|")
  }
end

local function CheckAwareness()
  local info = GetNearbyUnitsSummary()
  local signature = info.signature

  if signature == "||" then
    signature = "none"
  end

  if signature ~= TA.lastNearbySignature then
    if signature == "none" then
      AddLine("nearby", "You sense no visible creatures nearby.")
    else
      if info.hostile then AddLine("hostile", info.hostile) end
      if info.neutral then AddLine("neutral", info.neutral) end
      if info.friendly then AddLine("friendly", info.friendly) end
    end
    TA.lastNearbySignature = signature
  end
end

local CHAT_EVENT_INFO = {
  CHAT_MSG_SAY = { label = "Say", kind = "chat" },
  CHAT_MSG_YELL = { label = "Yell", kind = "chat" },
  CHAT_MSG_EMOTE = { label = "Emote", kind = "chat" },
  CHAT_MSG_TEXT_EMOTE = { label = "TextEmote", kind = "chat" },
  CHAT_MSG_PARTY = { label = "Party", kind = "chat" },
  CHAT_MSG_PARTY_LEADER = { label = "PartyLead", kind = "chat" },
  CHAT_MSG_RAID = { label = "Raid", kind = "chat" },
  CHAT_MSG_RAID_LEADER = { label = "RaidLead", kind = "chat" },
  CHAT_MSG_RAID_WARNING = { label = "Warning", kind = "chat" },
  CHAT_MSG_GUILD = { label = "Guild", kind = "chat" },
  CHAT_MSG_OFFICER = { label = "Officer", kind = "chat" },
  CHAT_MSG_WHISPER = { label = "Whisper", kind = "whisper" },
  CHAT_MSG_WHISPER_INFORM = { label = "To", kind = "whisper" },
  CHAT_MSG_MONSTER_SAY = { label = "NPC", kind = "chat" },
  CHAT_MSG_MONSTER_YELL = { label = "NPC", kind = "chat" },
  CHAT_MSG_MONSTER_WHISPER = { label = "NPC", kind = "chat" },
  CHAT_MSG_CHANNEL = { label = "Channel", kind = "chat" },
}

local function CleanSenderName(sender)
  if not sender or sender == "" then return "Unknown" end
  return sender:gsub("%-.*$", "")
end

local function HandleChatEvent(event, message, sender, _, _, _, _, _, _, channelName)
  if not TA.captureChat then return end
  local info = CHAT_EVENT_INFO[event]
  if not info or not message or message == "" then return end

  local name = CleanSenderName(sender)
  local prefix = info.label
  if event == "CHAT_MSG_CHANNEL" and channelName and channelName ~= "" then
    prefix = channelName
  end

  AddLine(info.kind, string.format("[%s] %s: %s", prefix, name, message))
end

local function TryAutoQuestFromGossip()
  if not TA.autoQuests or not C_GossipInfo then return end

  if C_GossipInfo.GetAvailableQuests and C_GossipInfo.SelectAvailableQuest then
    local available = C_GossipInfo.GetAvailableQuests()
    if available then
      for _, info in ipairs(available) do
        local optionID = info.questID or info.optionID
        if optionID then
          AddLine("quest", string.format("Auto-accepting quest: %s", info.title or "Unknown quest"))
          C_GossipInfo.SelectAvailableQuest(optionID)
          return
        end
      end
    end
  end

  if C_GossipInfo.GetActiveQuests and C_GossipInfo.SelectActiveQuest then
    local active = C_GossipInfo.GetActiveQuests()
    if active then
      for _, info in ipairs(active) do
        local optionID = info.questID or info.optionID
        if optionID and info.isComplete then
          AddLine("quest", string.format("Auto-turning in quest: %s", info.title or "Unknown quest"))
          C_GossipInfo.SelectActiveQuest(optionID)
          return
        end
      end
    end
  end
end

local function TryAcceptQuest()
  if TA.autoQuests and AcceptQuest then
    AcceptQuest()
    AddLine("quest", "Quest accepted.")
  end
end

local function TryCompleteQuest()
  if TA.autoQuests and IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
    CompleteQuest()
    AddLine("quest", "Quest ready to turn in.")
  end
end

local function TryGetQuestReward()
  if not TA.autoQuests or not GetQuestReward or not GetNumQuestChoices then return end
  local choices = GetNumQuestChoices() or 0
  if choices == 0 then
    GetQuestReward(1)
    AddLine("quest", "Quest turned in.")
  elseif choices == 1 then
    GetQuestReward(1)
    AddLine("quest", "Quest turned in and reward accepted.")
  else
    AddLine("quest", string.format("Quest has %d reward choices. Manual choice needed.", choices))
  end
end

local hiddenFrames = {
  "MinimapCluster",
  "MiniMapTracking",
  "MinimapZoneTextButton",
  "GameTimeFrame",
  "PlayerFrame",
  "TargetFrame",
  "BuffFrame",
  "DurabilityFrame",
}

local function ForceHideFrameByName(name)
  local frame = _G[name]
  if not frame then return end
  frame:Hide()
end

local function ApplyTextModeFrames()
  for _, name in ipairs(hiddenFrames) do
    ForceHideFrameByName(name)
  end
end

local function EnableTextMode()
  TA.textMode = true
  overlay:Show()
  overlay.tex:Show()
  panel:Show()
  panel:SetFrameStrata("TOOLTIP")
  panel:SetFrameLevel(11000)
  panel.inputBox:Show()
  ApplyTextModeFrames()
  AddLine("system", "Text mode enabled.")
end

local function DisableTextMode()
  TA.textMode = false
  overlay:Hide()
  panel.inputBox:Hide()
  AddLine("system", "Text mode disabled. Hidden frames may need /reload to return.")
end

local function TogglePanel()
  if panel:IsShown() then
    panel:Hide()
  else
    panel:Show()
  end
end

local function ProcessInputCommand(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "" then
    return
  elseif msg == "health" or msg == "hp" or msg == "rage" or msg == "status" then
    ReportStatus(true)
  elseif msg == "where" or msg == "location" then
    ReportLocation(true)
  elseif msg == "xp" or msg == "level" then
    ReportXP()
  elseif msg == "tracking" then
    ReportTracking()
  elseif msg == "inventory" or msg == "bags" then
    ReportInventory()
  elseif msg == "gear" or msg == "equipment" then
    ReportEquipment()
  elseif msg == "actions" or msg == "bars" then
    ReportActionBars()
  elseif msg == "spells" or msg == "spellbook" then
    ReportSpellbook()
  elseif msg == "spells" or msg == "spellbook" then
    ReportSpellbook()
  elseif msg == "explore" then
    ReportExplorationMemory(true)
  elseif msg == "autoquests on" then
    TA.autoQuests = true
    AddLine("quest", "Auto quest handling enabled.")
  elseif msg == "autoquests off" then
    TA.autoQuests = false
    AddLine("quest", "Auto quest handling disabled.")
  elseif msg == "trainer" or msg == "train list" then
    ReportTrainerServices()
  elseif msg:match("^train%s+all$") then
    TrainAllAvailableServices()
  elseif msg:match("^train%s+%d+$") then
    local idx = tonumber(msg:match("^train%s+(%d+)$"))
    TrainServiceByIndex(idx)
  elseif msg == "chat on" then
    TA.captureChat = true
    AddLine("chat", "Chat capture enabled.")
  elseif msg == "chat off" then
    TA.captureChat = false
    AddLine("chat", "Chat capture disabled.")
  elseif msg == "clear" then
    wipe(TA.lines)
    panel.text:Clear()
    AddLine("system", "Log cleared.")
  elseif msg == "help" then
    AddLine("system", "Type status, where, xp, tracking, inventory, gear, actions, spells, explore, autoquests on/off, chat on/off, or clear.")
  else
    AddLine("system", "Unknown input. Try: status, where, xp, tracking, inventory, gear, actions, spells, explore")
  end
end

panel.inputBox:SetScript("OnEnterPressed", function(self)
  local msg = self:GetText()
  if msg and msg ~= "" then
    AddLine("system", "> " .. msg)
  end
  self:SetText("")
  ProcessInputCommand(msg)
  self:ClearFocus()
end)
panel.inputBox:SetScript("OnEscapePressed", function(self)
  self:ClearFocus()
end)

SLASH_TEXTADVENTURER1 = "/ta"
SlashCmdList.TEXTADVENTURER = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")

  if msg == "" or msg == "show" then
    panel:Show()
    AddLine("system", "Text Adventurer opened.")
  elseif msg == "hide" then
    panel:Hide()
  elseif msg == "toggle" then
    TogglePanel()
  elseif msg == "clear" then
    wipe(TA.lines)
    panel.text:Clear()
    AddLine("system", "Log cleared.")
  elseif msg == "textmode on" then
    EnableTextMode()
  elseif msg == "textmode off" then
    DisableTextMode()
  elseif msg == "autostart on" then
    TextAdventurerDB.autoEnable = true
    AddLine("system", "Autostart enabled.")
  elseif msg == "autostart off" then
    TextAdventurerDB.autoEnable = false
    AddLine("system", "Autostart disabled.")
  elseif msg == "status" then
    ReportStatus(true)
  elseif msg == "where" or msg == "location" then
    ReportLocation(true)
  elseif msg == "xp" or msg == "level" then
    ReportXP()
  elseif msg == "tracking" then
    ReportTracking()
  elseif msg == "inventory" or msg == "bags" then
    ReportInventory()
  elseif msg == "gear" or msg == "equipment" then
    ReportEquipment()
  elseif msg == "actions" or msg == "bars" then
    ReportActionBars()
  elseif msg == "spells" or msg == "spellbook" then
    ReportSpellbook()
  elseif msg == "explore" then
    ReportExplorationMemory(true)
  elseif msg == "autoquests on" then
    TA.autoQuests = true
    AddLine("quest", "Auto quest handling enabled.")
  elseif msg == "autoquests off" then
    TA.autoQuests = false
    AddLine("quest", "Auto quest handling disabled.")
  elseif msg == "chat on" then
    TA.captureChat = true
    AddLine("chat", "Chat capture enabled.")
  elseif msg == "chat off" then
    TA.captureChat = false
    AddLine("chat", "Chat capture disabled.")
  elseif msg == "input" then
    panel.inputBox:Show()
    panel.inputBox:SetFocus()
    AddLine("system", "Input box ready.")
  elseif msg == "help" then
    AddLine("system", "Commands: /ta show, /ta hide, /ta toggle, /ta clear, /ta textmode on, /ta textmode off, /ta autostart on, /ta autostart off, /ta status, /ta where, /ta xp, /ta tracking, /ta inventory, /ta gear, /ta actions, /ta spells, /ta explore, /ta input, /ta autoquests on, /ta autoquests off, /ta chat on, /ta chat off, /ta trainer, /ta train 1, /ta train all")
  else
    AddLine("system", "Unknown command. Type /ta help")
  end
end

TA:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    if TextAdventurerDB.autoEnable == nil then
      TextAdventurerDB.autoEnable = true
    end

    panel:Show()
    TA.bagState = SnapshotBags()
    AddLine("system", "You enter the world.")
    AddLine("system", "Type /ta textmode on for full black-screen text mode.")
    AddLine("system", "Type /ta status for health and rage.")
    AddLine("system", "Type /ta xp for experience.")
    AddLine("system", "Type /ta where for your current place.")
    AddLine("system", "Type /ta tracking for active tracking modes.")
    AddLine("system", "Type /ta explore for exploration memory.")
    AddLine("system", "Type /ta spells to list your spellbook.")
    AddLine("quest", "Auto quests are enabled by default. Use /ta autoquests off to disable.")
    AddLine("chat", "Chat capture is enabled by default. Use /ta chat off to disable.")
    AddLine("system", "Enemy awareness is always on when nameplates exist.")
    AddLine("system", "Type /ta help for commands.")
    ReportLocation(true)
    ReportStatus(true)
    UpdateExplorationMemory()
    ReportExplorationMemory(true)

    if not TA.moveTicker then
      TA.moveTicker = C_Timer.NewTicker(0.20, function()
        CheckMovement()
        CheckFallState()
      end)
    end
    if not TA.awarenessTicker then
      TA.awarenessTicker = C_Timer.NewTicker(0.50, function()
        CheckAwareness()
        UpdateExplorationMemory()
        ReportExplorationMemory(false)
      end)
    end



    if TextAdventurerDB.autoEnable then
      EnableTextMode()
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog()
  elseif CHAT_EVENT_INFO[event] then
    HandleChatEvent(event, ...)
  elseif event == "PLAYER_TARGET_CHANGED" then
    CheckTarget()
  elseif event == "PLAYER_REGEN_DISABLED" then
    AddLine("combat", "You enter combat.")
    ReportStatus(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    AddLine("combat", "You leave combat.")
    ReportStatus(true)
  elseif event == "PLAYER_ENTERING_WORLD" then
    TA.bagState = SnapshotBags()
    if TA.textMode then
      ApplyTextModeFrames()
      overlay:Show()
      panel:Show()
      panel.inputBox:Show()
    end
    ReportLocation(true)
    UpdateExplorationMemory()
  elseif event == "LOOT_OPENED" then
    AddLine("loot", "You begin looting.")
  elseif event == "CHAT_MSG_LOOT" then
    local lootText = ...
    TA.pendingLoot = true
    AddLine("loot", lootText)
  elseif event == "BAG_UPDATE_DELAYED" then
    local newState = SnapshotBags()
    if TA.pendingLoot then
      local changes = FindBagChanges(TA.bagState, newState)
      if #changes > 0 then
        for i = 1, #changes do
          AddLine("loot", changes[i])
        end
        TA.pendingLoot = false
      end
    end
    TA.bagState = newState
  elseif event == "LOOT_CLOSED" then
    AddLine("loot", "You finish looting.")
  elseif event == "GOSSIP_SHOW" then
    TryAutoQuestFromGossip()
  elseif event == "QUEST_DETAIL" then
    TryAcceptQuest()
  elseif event == "QUEST_PROGRESS" then
    TryCompleteQuest()
  elseif event == "QUEST_COMPLETE" then
    TryGetQuestReward()
  elseif event == "GOSSIP_SHOW" then
    RecordNPCInteraction()
    TryAutoQuestFromGossip()

  elseif event == "QUEST_DETAIL" then
    RecordNPCInteraction()
    TryAcceptQuest()

  elseif event == "QUEST_PROGRESS" then
    RecordNPCInteraction()
    TryCompleteQuest()

  elseif event == "QUEST_COMPLETE" then
    RecordNPCInteraction()
    TryGetQuestReward()

  elseif event == "MERCHANT_SHOW" then
    RecordNPCInteraction()
    AddLine("friendly", "You open a merchant window.")

  elseif event == "TRAINER_SHOW" then
    RecordNPCInteraction()
    AddLine("friendly", "You speak with a trainer.")
  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
    ReportLocation(true)
    UpdateExplorationMemory()
    ReportExplorationMemory(true)
  elseif event == "UNIT_HEALTH" then
    local unit = ...
    if unit == "player" then
      ReportStatus(false)
    end
  elseif event == "UNIT_POWER_UPDATE" then
    local unit = ...
    if unit == "player" then
      ReportStatus(false)
    end
  end
end)

TA:RegisterEvent("PLAYER_LOGIN")
TA:RegisterEvent("PLAYER_ENTERING_WORLD")
TA:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
TA:RegisterEvent("PLAYER_TARGET_CHANGED")
TA:RegisterEvent("PLAYER_REGEN_DISABLED")
TA:RegisterEvent("PLAYER_REGEN_ENABLED")
TA:RegisterEvent("LOOT_OPENED")
TA:RegisterEvent("CHAT_MSG_LOOT")
TA:RegisterEvent("LOOT_CLOSED")
TA:RegisterEvent("BAG_UPDATE_DELAYED")
TA:RegisterEvent("GOSSIP_SHOW")
TA:RegisterEvent("QUEST_DETAIL")
TA:RegisterEvent("QUEST_PROGRESS")
TA:RegisterEvent("QUEST_COMPLETE")
TA:RegisterEvent("ZONE_CHANGED")
TA:RegisterEvent("ZONE_CHANGED_INDOORS")
TA:RegisterEvent("ZONE_CHANGED_NEW_AREA")
TA:RegisterEvent("UNIT_HEALTH")
TA:RegisterEvent("UNIT_POWER_UPDATE")
TA:RegisterEvent("CHAT_MSG_SAY")
TA:RegisterEvent("CHAT_MSG_YELL")
TA:RegisterEvent("CHAT_MSG_EMOTE")
TA:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
TA:RegisterEvent("CHAT_MSG_PARTY")
TA:RegisterEvent("CHAT_MSG_PARTY_LEADER")
TA:RegisterEvent("CHAT_MSG_RAID")
TA:RegisterEvent("CHAT_MSG_RAID_LEADER")
TA:RegisterEvent("CHAT_MSG_RAID_WARNING")
TA:RegisterEvent("CHAT_MSG_GUILD")
TA:RegisterEvent("CHAT_MSG_OFFICER")
TA:RegisterEvent("CHAT_MSG_WHISPER")
TA:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
TA:RegisterEvent("CHAT_MSG_MONSTER_SAY")
TA:RegisterEvent("CHAT_MSG_MONSTER_YELL")
TA:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
TA:RegisterEvent("CHAT_MSG_CHANNEL")
