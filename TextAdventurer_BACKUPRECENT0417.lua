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
TA.lastPositionX = nil
TA.lastPositionY = nil
TA.lastPositionSampleTime = 0
TA.lastNoProgressWhileMoving = 0
TA.blockedStreak = 0
TA.lastWallWarningAt = 0
TA.emaDelta = 0
TA.activeCasts = {}
TA.markA = nil
TA.markB = nil
TA.lastCellKey = nil
TA.recentCells = {}
TA.lastPathNarration = nil
TA.moveTicker = nil
TA.awarenessTicker = nil
TA.lineLimit = 1000
TA.lines = {}
TA.lastNearbySignature = nil
TA.textMode = false
TA.bagState = {}
TA.pendingLoot = True
TA.lastLocationSignature = nil
TA.lastStatusBucket = nil
TA.lastTargetHealthBucket = nil
TA.lastExplorationBucket = nil
TA.autoQuests = true
TA.captureChat = true

local GRID_SIZE = 12
local WALL_WARNING_COOLDOWN = 2.5
local SPACING_ASSUMED_RANGE = 25
local MAX_RECENT_CELLS = 12

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
text:SetMaxLines(1000)
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
    r = c[1], g = c[2], b = c[3],
  }
  table.insert(TA.lines, line)
  if #TA.lines > TA.lineLimit then table.remove(TA.lines, 1) end
  panel.text:Clear()
  for i = 1, #TA.lines do
    local entry = TA.lines[i]
    panel.text:AddMessage(entry.text, entry.r, entry.g, entry.b)
  end
  panel.text:ScrollToBottom()
end

local function BagLabel(bag)
  if bag == 0 then return "Backpack" end
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
        table.insert(changes, string.format("Loot placed in %s slot %d: %s x%d", BagLabel(bag), slot, newItem.hyperlink or ("item:" .. tostring(newItem.itemID or "?")), newItem.stackCount or 1))
      elseif oldItem and newItem and oldItem.itemID == newItem.itemID then
        local oldCount = oldItem.stackCount or 0
        local newCount = newItem.stackCount or 0
        if newCount > oldCount then
          table.insert(changes, string.format("Loot added in %s slot %d: %s +%d", BagLabel(bag), slot, newItem.hyperlink or ("item:" .. tostring(newItem.itemID or "?")), newCount - oldCount))
        end
      end
    end
  end
  return changes
end

local function SpellLabel(spellName)
  if spellName and spellName ~= "" then return spellName end
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
  local _, subevent, _, _, sourceName, sourceFlags, _, _, destName, destFlags, _, param1, param2, _, param4 = CombatLogGetCurrentEventInfo()
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

local function DescribeUnit(unit)
  if unit == "player" then return "You" end
  if UnitIsUnit(unit, "target") then return UnitName(unit) or "Your target" end
  return UnitName(unit) or unit
end

local function ReportCastStart(unit, spellID, isChannel)
  if not unit or not UnitExists(unit) then return end
  local name, _, _, startTimeMs, endTimeMs
  if isChannel and UnitChannelInfo then
    name, _, _, startTimeMs, endTimeMs = UnitChannelInfo(unit)
  elseif UnitCastingInfo then
    name, _, _, startTimeMs, endTimeMs = UnitCastingInfo(unit)
  end
  if not name and spellID and GetSpellInfo then name = GetSpellInfo(spellID) end
  if not name then return end
  local who = DescribeUnit(unit)
  local durationText = ""
  if startTimeMs and endTimeMs and endTimeMs > startTimeMs then
    durationText = string.format(" (%.1fs)", (endTimeMs - startTimeMs) / 1000)
  end
  local key = unit .. ":" .. name
  if TA.activeCasts[key] then return end
  TA.activeCasts[key] = true
  if isChannel then
    AddLine("cast", string.format("%s begins channeling %s%s.", who, name, durationText))
  else
    AddLine("cast", string.format("%s begins casting %s%s.", who, name, durationText))
  end
end

local function ReportCastStop(unit, spellID, reason, isChannel)
  if not unit then return end
  local name = nil
  if spellID and GetSpellInfo then name = GetSpellInfo(spellID) end
  if not name then
    local castName = UnitCastingInfo and UnitCastingInfo(unit)
    local channelName = UnitChannelInfo and UnitChannelInfo(unit)
    name = castName or channelName
  end
  if not name then return end
  TA.activeCasts[unit .. ":" .. name] = nil
  local who = DescribeUnit(unit)
  if reason == "interrupt" then
    AddLine("cast", string.format("%s's %s is interrupted.", who, name))
  elseif reason == "failed" then
    AddLine("cast", string.format("%s fails to cast %s.", who, name))
  elseif reason == "stop" then
    if isChannel then
      AddLine("cast", string.format("%s stops channeling %s.", who, name))
    else
      AddLine("cast", string.format("%s stops casting %s.", who, name))
    end
  end
end

local function DescribeTargetHealthBucket(unit)
  if not unit or not UnitExists(unit) then return nil end
  local hp = UnitHealth(unit) or 0
  local hpMax = UnitHealthMax(unit) or 1
  if hpMax <= 0 then return nil end
  local pct = (hp / hpMax) * 100
  if pct >= 90 then
    return "healthy", "The target seems healthy."
  elseif pct >= 65 then
    return "lightly_hurt", "The target is taking some damage."
  elseif pct >= 40 then
    return "hurt", "The target is looking worn down."
  elseif pct >= 20 then
    return "rough", "The target is looking rough."
  elseif pct > 0 then
    return "critical", "The target is barely hanging on."
  else
    return "dead", "The target is down."
  end
end

local function ReportTargetCondition(force)
  if not UnitExists("target") or UnitIsDeadOrGhost("target") then
    TA.lastTargetHealthBucket = nil
    return
  end
  local bucket, textMsg = DescribeTargetHealthBucket("target")
  if not bucket or not textMsg then return end
  if force or bucket ~= TA.lastTargetHealthBucket then
    AddLine("target", textMsg)
    TA.lastTargetHealthBucket = bucket
  end
end

local function CheckTarget()
  if not UnitExists("target") then
    if TA.lastTargetGUID then
      AddLine("target", "You clear your target.")
      TA.lastTargetGUID = nil
      TA.lastTargetName = nil
      TA.lastTargetHealthBucket = nil
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
      TA.lastTargetHealthBucket = nil
    else
      AddLine("target", string.format("You target %s (level %s, %s).", name, level > 0 and level or "??", reaction))
      TA.lastTargetHealthBucket = nil
      ReportTargetCondition(true)
    end
    TA.lastTargetGUID = guid
    TA.lastTargetName = name
  end
end

local function FacingToCardinal(facing)
  if not facing then return nil end
  local deg = math.deg(facing) % 360
  if deg < 22.5 then return "north" end
  if deg < 67.5 then return "northwest" end
  if deg < 112.5 then return "west" end
  if deg < 157.5 then return "southwest" end
  if deg < 202.5 then return "south" end
  if deg < 247.5 then return "southeast" end
  if deg < 292.5 then return "east" end
  if deg < 337.5 then return "northeast" end
  return "north"
end

local function SpeedCategory(speed)
  speed = speed or 0
  if speed <= 0 then return "still" end
  if speed < 7.5 then return "walking" end
  if speed < 13.5 then return "running" end
  return "fast"
end

local function GetFacingDegrees()
  local f = GetPlayerFacing()
  if not f then return nil end
  return math.deg(f) % 360
end

local function AngleDiff(a, b)
  local diff = math.abs(a - b)
  if diff > 180 then diff = 360 - diff end
  return diff
end

local function EstimateSpacing(angleDeg)
  local radians = math.rad(angleDeg / 2)
  return 2 * SPACING_ASSUMED_RANGE * math.sin(radians)
end

local function DescribeSpacing(angle, distance)
  if angle < 15 or distance < 7 then
    return "tightly clustered", "high"
  elseif angle < 30 or distance < 13 then
    return "moderately separated", "medium"
  else
    return "widely separated", "lower"
  end
end

local function MarkFacingA()
  local facing = GetFacingDegrees()
  if not facing then AddLine("system", "Could not read facing."); return end
  TA.markA = {
    facing = facing,
    target = UnitName("target") or "unknown target",
    reaction = UnitCanAttack("player", "target") and "hostile" or "non-hostile",
  }
  AddLine("system", string.format("Marked A at %.1f° toward %s.", facing, TA.markA.target))
end

local function MarkFacingB()
  local facing = GetFacingDegrees()
  if not facing then AddLine("system", "Could not read facing."); return end
  TA.markB = {
    facing = facing,
    target = UnitName("target") or "unknown target",
    reaction = UnitCanAttack("player", "target") and "hostile" or "non-hostile",
  }
  AddLine("system", string.format("Marked B at %.1f° toward %s.", facing, TA.markB.target))
end

local function ReportSpacingEstimate()
  if not TA.markA or not TA.markB then
    AddLine("system", "You must mark both directions first with marka and markb.")
    return
  end
  local angle = AngleDiff(TA.markA.facing, TA.markB.facing)
  local dist = EstimateSpacing(angle)
  local desc, risk = DescribeSpacing(angle, dist)
  AddLine("system", string.format("Angle between marks: %.1f°", angle))
  AddLine("system", string.format("Estimated spacing at %.0f-yard range: %.1f yards", SPACING_ASSUMED_RANGE, dist))
  AddLine("system", string.format("%s and %s appear %s. Pull risk is %s.", TA.markA.target, TA.markB.target, desc, risk))
  AddLine("system", "This is a geometric estimate, not a guaranteed safe-pull measurement.")
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

local function ReportQuestLog()
  if not GetNumQuestLogEntries or not GetQuestLogTitle then
    AddLine("system", "Quest log API unavailable.")
    return
  end

  local total = GetNumQuestLogEntries() or 0
  if total <= 0 then
    AddLine("system", "Your quest log is empty.")
    return
  end

  local shown = 0
  for i = 1, total do
    local title, level, _, isHeader, _, isComplete = GetQuestLogTitle(i)
    if title and not isHeader then
      shown = shown + 1
      local statusText = "in progress"
      if isComplete == 1 then
        statusText = "complete"
      elseif isComplete == -1 then
        statusText = "failed"
      end

      AddLine("quest", string.format("[%d] %s (level %d) - %s", i, title, level or 0, statusText))

      local numObjectives = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
      for obj = 1, numObjectives do
        local desc, _, finished = GetQuestLogLeaderBoard(obj, i)
        if desc then
          local mark = finished and "[x]" or "[ ]"
          AddLine("quest", string.format("  %s %s", mark, desc))
        end
      end
    end
  end

  if shown == 0 then
    AddLine("system", "No quests found.")
  end
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
  if not found then AddLine("place", "No minimap tracking is active.") end
end

local EQUIP_SLOTS = {
  {16,"Main Hand"},{17,"Off Hand"},{18,"Ranged"},{1,"Head"},{2,"Neck"},{3,"Shoulder"},{5,"Chest"},{6,"Waist"},{7,"Legs"},{8,"Feet"},{9,"Wrist"},{10,"Hands"},{11,"Finger 1"},{12,"Finger 2"},{13,"Trinket 1"},{14,"Trinket 2"},{15,"Back"}
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

local function ReportActionBars()
  for slot = 1, 120 do
    local actionType, id = GetActionInfo(slot)
    if actionType and id then
      local start, duration, enable = GetActionCooldown(slot)
      local cdText = "ready"
      if enable == 1 and duration and duration > 1.5 and start and start > 0 then
        cdText = string.format("%.1fs cooldown", math.max(0, (start + duration) - GetTime()))
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
            cdText = string.format("%.1fs cooldown", math.max(0, (start + duration) - GetTime()))
          end
          AddLine("cast", string.format("[%d] %s - %s", index, spellName, cdText))
          foundAny = true
        end
      end
    end
  end
  if not foundAny then AddLine("system", "No spells found in spellbook.") end
end

local function BindSpellbookSpellToActionSlot(actionSlot, spellbookIndex)
  if not actionSlot or not spellbookIndex then
    AddLine("system", "Usage: bind <actionSlot> <spellbookIndex>")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "You cannot change action bars in combat.")
    return
  end
  if not PickupSpellBookItem or not PlaceAction then
    AddLine("system", "Action bar binding API unavailable.")
    return
  end
  local skillType, spellID = GetSpellBookItemInfo(spellbookIndex, BOOKTYPE_SPELL)
  if skillType ~= "SPELL" then
    AddLine("system", string.format("No spell found at spellbook index %d.", spellbookIndex))
    return
  end
  local spellName = GetSpellBookItemName(spellbookIndex, BOOKTYPE_SPELL) or ("Spell " .. tostring(spellID))
  ClearCursor()
  PickupSpellBookItem(spellbookIndex, BOOKTYPE_SPELL)
  PlaceAction(actionSlot)
  ClearCursor()
  AddLine("cast", string.format("Placed %s into action slot %d.", spellName, actionSlot))
end

local function DoTargetCommand(arg)
  if not arg or arg == "" then
    AddLine("system", "Usage: target nearest, target next, target corpse, or target <name>")
    return
  end
  local lower = arg:lower()
  if lower == "nearest" then
    if TargetNearestEnemy then
      TargetNearestEnemy()
      AddLine("target", "You attempt to target the nearest enemy.")
    else
      AddLine("system", "Nearest-enemy targeting unavailable.")
    end
  elseif lower == "next" then
    if TargetNearestEnemy then
      TargetNearestEnemy()
      AddLine("target", "You cycle to the next nearby enemy.")
    else
      AddLine("system", "Target cycling unavailable.")
    end
  elseif lower == "corpse" then
    if TargetNearestEnemy then
      TargetNearestEnemy(true)
      AddLine("target", "You attempt to target the nearest corpse.")
    else
      AddLine("system", "Corpse targeting unavailable.")
    end
  else
    if TargetByName then
      TargetByName(arg, true)
      AddLine("target", "You attempt to target " .. arg .. ".")
    else
      AddLine("system", "Name targeting unavailable.")
    end
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
          if reqName and not hasReq then table.insert(reqParts, reqName) end
        end
        if #reqParts > 0 then reqText = " | Missing: " .. table.concat(reqParts, ", ") end
      end
      AddLine("cast", string.format("[%d] %s%s | %s | Cost: %d | Level: %d%s", i, name, rank and rank ~= "" and (" (" .. rank .. ")") or "", tostring(category), cost or 0, levelReq or 0, reqText))
      shown = shown + 1
    end
  end
  if shown == 0 then AddLine("system", "Trainer window is open, but no skills were found.") end
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
      AddLine("quest", string.format("Attempted to train [%d] %s%s.", i, name, rank and rank ~= "" and (" (" .. rank .. ")") or ""))
      bought = bought + 1
    end
  end
  if bought == 0 then AddLine("system", "No currently available trainer skills to buy.") end
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
  return mapID, cellX, cellY, x, y
end

local function GetExplorationData(mapID)
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}
  if not TextAdventurerDB.exploration[mapID] then
    TextAdventurerDB.exploration[mapID] = { visited = {}, visits = {}, minX = nil, maxX = nil, minY = nil, maxY = nil }
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

local function UpdateRecentPath()
  local mapID, cellX, cellY = GetPlayerMapCell()
  if not mapID then return end
  local key = tostring(mapID) .. ":" .. CellKey(cellX, cellY)
  if key == TA.lastCellKey then return end
  TA.lastCellKey = key
  table.insert(TA.recentCells, key)
  if #TA.recentCells > MAX_RECENT_CELLS then table.remove(TA.recentCells, 1) end
end

local function ReportPathMemory(force)
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
    for i = 1, #messages do AddLine("place", messages[i]) end
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

local function CheckWallHeuristic()
  local now = GetTime()
  local mapID, _, _, x, y = GetPlayerMapCell()
  if not mapID or not x or not y then return end
  local speed = GetUnitSpeed("player") or 0
  if speed < 6 or IsFalling() then
    TA.blockedStreak = 0
    return
  end
  if not TA.lastPositionX or not TA.lastPositionY then
    TA.lastPositionX = x
    TA.lastPositionY = y
    return
  end
  local dx = x - TA.lastPositionX
  local dy = y - TA.lastPositionY
  local distSq = dx * dx + dy * dy
  if distSq < 0.00000015 then
    TA.blockedStreak = (TA.blockedStreak or 0) + 1
  else
    TA.blockedStreak = 0
  end
  if TA.blockedStreak >= 8 and (now - (TA.lastWallWarningAt or 0)) > WALL_WARNING_COOLDOWN then
    AddLine("trace", "Your path seems blocked.")
    TA.lastWallWarningAt = now
    TA.blockedStreak = 0
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
      ReportPathMemory(false)
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
          if reaction >= 5 then table.insert(friendlies, name) else table.insert(neutrals, name) end
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
    signature = table.concat({ table.concat(hostiles, ","), table.concat(neutrals, ","), table.concat(friendlies, ",") }, "|"),
  }
end

local function CheckAwareness()
  local info = GetNearbyUnitsSummary()
  local signature = info.signature
  if signature == "||" then signature = "none" end
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
  CHAT_MSG_SAY={label="Say",kind="chat"}, CHAT_MSG_YELL={label="Yell",kind="chat"}, CHAT_MSG_EMOTE={label="Emote",kind="chat"}, CHAT_MSG_TEXT_EMOTE={label="TextEmote",kind="chat"}, CHAT_MSG_PARTY={label="Party",kind="chat"}, CHAT_MSG_PARTY_LEADER={label="PartyLead",kind="chat"}, CHAT_MSG_RAID={label="Raid",kind="chat"}, CHAT_MSG_RAID_LEADER={label="RaidLead",kind="chat"}, CHAT_MSG_RAID_WARNING={label="Warning",kind="chat"}, CHAT_MSG_GUILD={label="Guild",kind="chat"}, CHAT_MSG_OFFICER={label="Officer",kind="chat"}, CHAT_MSG_WHISPER={label="Whisper",kind="whisper"}, CHAT_MSG_WHISPER_INFORM={label="To",kind="whisper"}, CHAT_MSG_MONSTER_SAY={label="NPC",kind="chat"}, CHAT_MSG_MONSTER_YELL={label="NPC",kind="chat"}, CHAT_MSG_MONSTER_WHISPER={label="NPC",kind="chat"}, CHAT_MSG_CHANNEL={label="Channel",kind="chat"}
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
  if event == "CHAT_MSG_CHANNEL" and channelName and channelName ~= "" then prefix = channelName end
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

local hiddenFrames = { "MinimapCluster", "MiniMapTracking", "MinimapZoneTextButton", "GameTimeFrame", "PlayerFrame", "TargetFrame", "BuffFrame", "DurabilityFrame" }

local function ForceHideFrameByName(name)
  local frame = _G[name]
  if frame then frame:Hide() end
end

local function ApplyTextModeFrames()
  for _, name in ipairs(hiddenFrames) do ForceHideFrameByName(name) end
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
  if panel:IsShown() then panel:Hide() else panel:Show() end
end

local function FocusTerminalInput()
  panel:Show()
  panel.inputBox:Show()
  panel.inputBox:SetFocus()
  AddLine("system", "Terminal input ready.")
end

local function SendFromTerminal(msg)
  local cmd, rest = msg:match("^/(%S+)%s*(.*)$")
  if not cmd then return false end
  cmd = cmd:lower()
  if cmd == "s" or cmd == "say" then
    SendChatMessage(rest, "SAY")
  elseif cmd == "y" or cmd == "yell" then
    SendChatMessage(rest, "YELL")
  elseif cmd == "p" or cmd == "party" then
    SendChatMessage(rest, "PARTY")
  elseif cmd == "g" or cmd == "guild" then
    SendChatMessage(rest, "GUILD")
  elseif cmd == "raid" or cmd == "ra" then
    SendChatMessage(rest, "RAID")
  elseif cmd == "rw" then
    SendChatMessage(rest, "RAID_WARNING")
  elseif cmd == "w" or cmd == "whisper" then
    local target, textBody = rest:match("^(%S+)%s+(.+)$")
    if target and textBody then
      SendChatMessage(textBody, "WHISPER", nil, target)
    else
      AddLine("system", "Whisper format: /w Name message")
    end
  else
    AddLine("system", "Unknown chat prefix. Use /s, /p, /g, /w, /raid, or /rw.")
  end
  return true
end

local function ProcessInputCommand(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$")
  if msg == "" then return end
  local lower = msg:lower()
  if msg:sub(1,1) == "/" then
    SendFromTerminal(msg)
  elseif lower == "health" or lower == "hp" or lower == "rage" or lower == "status" then
    ReportStatus(true)
  elseif lower == "where" or lower == "location" then
    ReportLocation(true)
  elseif lower == "xp" or lower == "level" then
    ReportXP()
  elseif lower == "quests" or lower == "questlog" or lower == "quest log" then
    ReportQuestLog()
  elseif lower == "quests" or lower == "questlog" or lower == "quest log" then
    ReportQuestLog()
  elseif lower == "tracking" then
    ReportTracking()
  elseif lower == "inventory" or lower == "bags" then
    ReportInventory()
  elseif lower == "gear" or lower == "equipment" then
    ReportEquipment()
  elseif lower == "actions" or lower == "bars" then
    ReportActionBars()
  elseif lower == "spells" or lower == "spellbook" then
    ReportSpellbook()
  elseif lower == "trainer" or lower == "train list" then
    ReportTrainerServices()
  elseif lower:match("^train%s+all$") then
    TrainAllAvailableServices()
  elseif lower:match("^train%s+%d+$") then
    TrainServiceByIndex(tonumber(lower:match("^train%s+(%d+)$")))
  elseif lower:match("^bind%s+%d+%s+%d+$") then
    local slot, spellIndex = lower:match("^bind%s+(%d+)%s+(%d+)$")
    BindSpellbookSpellToActionSlot(tonumber(slot), tonumber(spellIndex))
  elseif lower:match("^target%s+.+$") then
    DoTargetCommand(msg:match("^target%s+(.+)$"))
  elseif lower == "marka" then
    MarkFacingA()
  elseif lower == "markb" then
    MarkFacingB()
  elseif lower == "spacing" then
    ReportSpacingEstimate()
  elseif lower == "ta input" or lower == "input" then
    FocusTerminalInput()
  elseif lower == "explore" then
    ReportExplorationMemory(true)
    ReportPathMemory(true)
  elseif lower == "autoquests on" then
    TA.autoQuests = true
    AddLine("quest", "Auto quest handling enabled.")
  elseif lower == "autoquests off" then
    TA.autoQuests = false
    AddLine("quest", "Auto quest handling disabled.")
  elseif lower == "chat on" then
    TA.captureChat = true
    AddLine("chat", "Chat capture enabled.")
  elseif lower == "chat off" then
    TA.captureChat = false
    AddLine("chat", "Chat capture disabled.")
  elseif lower == "clear" then
    wipe(TA.lines)
    panel.text:Clear()
    AddLine("system", "Log cleared.")
  elseif lower == "help" then
    AddLine("system", "Type status, where, xp, quests, tracking, inventory, gear, actions, spells, trainer, train <n>, train all, bind <slot> <spellbookIndex>, target nearest/next/corpse/<name>, marka, markb, spacing, ta input, explore, autoquests on/off, chat on/off, or clear.")
  else
    AddLine("system", "Unknown input. Try: status, where, xp, quests, tracking, inventory, gear, actions, spells, trainer, train 1, train all, bind 1 3, target nearest, marka, markb, spacing, ta input, explore")
  end
end

panel.inputBox:SetScript("OnEnterPressed", function(self)
  local msg = self:GetText()
  if msg and msg ~= "" then AddLine("system", "> " .. msg) end
  self:SetText("")
  ProcessInputCommand(msg)
  self:SetFocus()
end)
panel.inputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

SLASH_TEXTADVENTURER1 = "/ta"
SlashCmdList.TEXTADVENTURER = function(msg)
  local original = (msg or ""):match("^%s*(.-)%s*$")
  local lower = original:lower()
  if lower == "" or lower == "show" then
    panel:Show(); AddLine("system", "Text Adventurer opened.")
  elseif lower == "hide" then
    panel:Hide()
  elseif lower == "toggle" then
    TogglePanel()
  elseif lower == "clear" then
    wipe(TA.lines); panel.text:Clear(); AddLine("system", "Log cleared.")
  elseif lower == "textmode on" then
    EnableTextMode()
  elseif lower == "textmode off" then
    DisableTextMode()
  elseif lower == "autostart on" then
    TextAdventurerDB.autoEnable = true; AddLine("system", "Autostart enabled.")
  elseif lower == "autostart off" then
    TextAdventurerDB.autoEnable = false; AddLine("system", "Autostart disabled.")
  elseif lower == "status" then
    ReportStatus(true)
  elseif lower == "where" or lower == "location" then
    ReportLocation(true)
  elseif lower == "xp" or lower == "level" then
    ReportXP()
  elseif lower == "quests" or lower == "questlog" or lower == "quest log" then
    ReportQuestLog()
  elseif lower == "tracking" then
    ReportTracking()
  elseif lower == "inventory" or lower == "bags" then
    ReportInventory()
  elseif lower == "gear" or lower == "equipment" then
    ReportEquipment()
  elseif lower == "actions" or lower == "bars" then
    ReportActionBars()
  elseif lower == "spells" or lower == "spellbook" then
    ReportSpellbook()
  elseif lower == "trainer" or lower == "train list" then
    ReportTrainerServices()
  elseif lower:match("^train%s+all$") then
    TrainAllAvailableServices()
  elseif lower:match("^train%s+%d+$") then
    TrainServiceByIndex(tonumber(lower:match("^train%s+(%d+)$")))
  elseif lower:match("^bind%s+%d+%s+%d+$") then
    local slot, spellIndex = lower:match("^bind%s+(%d+)%s+(%d+)$")
    BindSpellbookSpellToActionSlot(tonumber(slot), tonumber(spellIndex))
  elseif lower:match("^target%s+.+$") then
    DoTargetCommand(original:match("^target%s+(.+)$"))
  elseif lower == "marka" then
    MarkFacingA()
  elseif lower == "markb" then
    MarkFacingB()
  elseif lower == "spacing" then
    ReportSpacingEstimate()
  elseif lower == "input" or lower == "ta input" then
    FocusTerminalInput()
  elseif lower == "explore" then
    ReportExplorationMemory(true)
    ReportPathMemory(true)
  elseif lower == "autoquests on" then
    TA.autoQuests = true; AddLine("quest", "Auto quest handling enabled.")
  elseif lower == "autoquests off" then
    TA.autoQuests = false; AddLine("quest", "Auto quest handling disabled.")
  elseif lower == "chat on" then
    TA.captureChat = true; AddLine("chat", "Chat capture enabled.")
  elseif lower == "chat off" then
    TA.captureChat = false; AddLine("chat", "Chat capture disabled.")
  elseif lower == "help" then
    AddLine("system", "Commands: /ta show, /ta hide, /ta toggle, /ta clear, /ta textmode on, /ta textmode off, /ta autostart on, /ta autostart off, /ta status, /ta where, /ta xp, /ta quests, /ta tracking, /ta inventory, /ta gear, /ta actions, /ta spells, /ta trainer, /ta train 1, /ta train all, /ta bind 1 3, /ta target nearest, /ta target next, /ta target corpse, /ta target <name>, /ta marka, /ta markb, /ta spacing, /ta input, /ta explore, /ta autoquests on, /ta autoquests off, /ta chat on, /ta chat off")
  else
    AddLine("system", "Unknown command. Type /ta help")
  end
end

TA:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}
    if TextAdventurerDB.autoEnable == nil then TextAdventurerDB.autoEnable = true end
    panel:Show()
    TA.bagState = SnapshotBags()
    AddLine("system", "You enter the world.")
    AddLine("system", "Type /ta textmode on for full black-screen text mode.")
    AddLine("system", "Type /ta status for health and rage.")
    AddLine("system", "Type /ta xp for experience.")
    AddLine("system", "Type /ta quests to list your quest log.")
    AddLine("system", "Type /ta where for your current place.")
    AddLine("system", "Type /ta tracking for active tracking modes.")
    AddLine("system", "Type /ta explore for exploration memory.")
    AddLine("system", "Type /ta spells to list your spellbook.")
    AddLine("system", "Type /ta trainer to list trainable abilities.")
    AddLine("system", "Type /ta bind 1 3 to place a spellbook entry on an action slot.")
    AddLine("system", "Type /ta target nearest, /ta target next, /ta target corpse, or /ta target <name>.")
    AddLine("system", "Type /ta marka, /ta markb, then /ta spacing for a geometric spacing estimate.")
    AddLine("system", "The spacing estimate can be used for hostile or friendly targets you can point at.")
    AddLine("system", "Smoothed movement and backtracking narration are enabled automatically.")
    AddLine("system", "Type /ta input if you ever need to refocus the terminal.")
    AddLine("system", "Player and target spellcasts are narrated automatically.")
    AddLine("quest", "Auto quests are enabled by default. Use /ta autoquests off to disable.")
    AddLine("chat", "Chat capture is enabled by default. Use /ta chat off to disable.")
    AddLine("system", "Enemy awareness is always on when nameplates exist.")
    AddLine("system", "Type /ta help for commands.")
    ReportLocation(true)
    ReportStatus(true)
    UpdateExplorationMemory()
    UpdateRecentPath()
    ReportExplorationMemory(true)
    ReportPathMemory(true)
    if not TA.moveTicker then
      TA.moveTicker = C_Timer.NewTicker(0.20, function()
        CheckMovement()
        CheckFallState()
        CheckWallHeuristic()
      end)
    end
    if not TA.awarenessTicker then
      TA.awarenessTicker = C_Timer.NewTicker(0.50, function()
        CheckAwareness()
        UpdateExplorationMemory()
        UpdateRecentPath()
        ReportExplorationMemory(false)
        ReportPathMemory(false)
      end)
    end
    if TextAdventurerDB.autoEnable then
      EnableTextMode()
      panel.inputBox:SetFocus()
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
  elseif event == "UNIT_SPELLCAST_START" then
    local unit, _, spellID = ...
    if unit == "player" or unit == "target" then ReportCastStart(unit, spellID, false) end
  elseif event == "UNIT_SPELLCAST_STOP" then
    local unit, _, spellID = ...
    if unit == "player" or unit == "target" then ReportCastStop(unit, spellID, "stop", false) end
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
    local unit, _, spellID = ...
    if unit == "player" or unit == "target" then ReportCastStop(unit, spellID, "interrupt", false) end
  elseif event == "UNIT_SPELLCAST_FAILED" then
    local unit, _, spellID = ...
    if unit == "player" or unit == "target" then ReportCastStop(unit, spellID, "failed", false) end
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    local unit, _, spellID = ...
    if unit == "player" or unit == "target" then ReportCastStart(unit, spellID, true) end
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    local unit, _, spellID = ...
    if unit == "player" or unit == "target" then ReportCastStop(unit, spellID, "stop", true) end
  elseif event == "PLAYER_ENTERING_WORLD" then
    TA.bagState = SnapshotBags()
    if TA.textMode then
      ApplyTextModeFrames()
      overlay:Show()
      panel:Show()
      panel.inputBox:Show()
      panel.inputBox:SetFocus()
    end
    ReportLocation(true)
    UpdateExplorationMemory()
    UpdateRecentPath()
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
        for i = 1, #changes do AddLine("loot", changes[i]) end
        TA.pendingLoot = false
      end
    end
    TA.bagState = newState
  elseif event == "GOSSIP_SHOW" then
    TryAutoQuestFromGossip()
  elseif event == "TRAINER_SHOW" then
    AddLine("quest", "Trainer opened. Type trainer, train 1, or train all.")
  elseif event == "LOOT_CLOSED" then
    AddLine("loot", "You finish looting.")
  elseif event == "QUEST_DETAIL" then
    TryAcceptQuest()
  elseif event == "QUEST_PROGRESS" then
    TryCompleteQuest()
  elseif event == "QUEST_COMPLETE" then
    TryGetQuestReward()
  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
    ReportLocation(true)
    UpdateExplorationMemory()
    UpdateRecentPath()
    ReportExplorationMemory(true)
    ReportPathMemory(true)
  elseif event == "UNIT_HEALTH" then
    local unit = ...
    if unit == "player" then
      ReportStatus(false)
    elseif unit == "target" then
      ReportTargetCondition(false)
    end
  elseif event == "UNIT_POWER_UPDATE" then
    local unit = ...
    if unit == "player" then ReportStatus(false) end
  end
end)

TA:RegisterEvent("PLAYER_LOGIN")
TA:RegisterEvent("PLAYER_ENTERING_WORLD")
TA:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
TA:RegisterEvent("PLAYER_TARGET_CHANGED")
TA:RegisterEvent("PLAYER_REGEN_DISABLED")
TA:RegisterEvent("PLAYER_REGEN_ENABLED")
TA:RegisterEvent("UNIT_SPELLCAST_START")
TA:RegisterEvent("UNIT_SPELLCAST_STOP")
TA:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
TA:RegisterEvent("UNIT_SPELLCAST_FAILED")
TA:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
TA:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
TA:RegisterEvent("LOOT_OPENED")
TA:RegisterEvent("CHAT_MSG_LOOT")
TA:RegisterEvent("LOOT_CLOSED")
TA:RegisterEvent("BAG_UPDATE_DELAYED")
TA:RegisterEvent("GOSSIP_SHOW")
TA:RegisterEvent("TRAINER_SHOW")
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
