-- TextAdventurer.lua
---@diagnostic disable: undefined-global, undefined-field, deprecated
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

-- WoW API compatibility aliases for Lua diagnostics and mixed client API surfaces.
local GetSpellInfo = GetSpellInfo
local GetSpellTabInfo = GetSpellTabInfo
local UnitFacing = UnitFacing
local UnitBuff = UnitBuff
local GetNumQuestLogEntries = GetNumQuestLogEntries
local GetQuestLogTitle = GetQuestLogTitle
local GetQuestLogSelection = GetQuestLogSelection
local SelectQuestLogEntry = SelectQuestLogEntry
local GetNumSpellTabs = GetNumSpellTabs
local GetSpellBookItemInfo = GetSpellBookItemInfo
local GetSpellBookItemName = GetSpellBookItemName
local PickupSpellBookItem = PickupSpellBookItem
local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"
local BOOKTYPE_PET = BOOKTYPE_PET or "pet"

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
TA.markedCells = {}
TA.markedCellCount = 0
TA.lastMarkedCellNotification = nil
TA.nextMarkID = 1
TA.lastCellKey = nil
TA.recentCells = {}
TA.lastPathNarration = nil
TA.moveTicker = nil
TA.awarenessNearbyTicker = nil
TA.awarenessMemoryTicker = nil
TA.lineLimit = 1000
TA.lines = {}
TA.lastNearbySignature = nil
TA.textMode = false
TA.bagState = {}
TA.pendingLoot = false
TA.lastLocationSignature = nil
TA.lastStatusBucket = nil
TA.lastTargetHealthBucket = nil
TA.lastHealthWarningState = nil
TA.lastExplorationBucket = nil
TA.autoQuests = true
TA.captureChat = true
TA.lastBuffSnapshot = {}
TA.swingReadyAt = 0
TA.lastSwingState = nil
TA.inputHistory = {}
TA.inputHistoryMax = 50
TA.inputHistoryPos = 0
TA.inputDraft = ""
TA.lastSubzone = nil
TA.vendorOpen = false
TA.questObjectiveSnapshot = {}
TA.dpsSessionStart = 0
TA.dpsTotalDamage = 0
TA.dpsCombatStart = 0
TA.dpsCombatDamage = 0
TA.lastCombatDamage = 0
TA.lastCombatDuration = 0
TA.pendingItemTextRead = nil
TA.lastItemTextSignature = nil
TA.gridSize = nil
TA.cellSizeMode = "yards"
TA.cellSizeYards = 30
TA.cellAnchors = {}
TA.lastCellVizSignature = nil
TA.activeMapMarkID = nil
TA.mapOverlayEnabled = true
TA.asciiMapEnabled = false
TA.lastAsciiMapSignature = nil
TA.routeRecordingName = nil
TA.routeFollowName = nil
TA.routeFollowIndex = nil
TA.routeLastGuidedCell = nil
TA.pendingWhoQuery = nil
TA.pendingCVarList = false
TA.dfModeEnabled = false
TA.lastNearbyUnits = {}
TA.dfModeGridSize = 35
TA.dfModeLastUpdate = 0
TA.dfModeViewMode = "threat"  -- tactical, threat, exploration, combined
TA.dfModeProfile = "full"  -- balanced, full
TA.dfModeOrientation = "fixed"  -- fixed (north-up), rotating (heading-up)
TA.dfModeRotationMode = "smooth"  -- smooth, octant (45-degree snaps for squarer geometry)
TA.dfModeMarkRadius = 3  -- cells around mark center to draw edge ring
TA.dfModeRecentCells = {}  -- Track recently visited cells for breadcrumb trail
TA.dfModeLastFacing = nil
TA.dfModeEnemyPatrols = {}  -- Track enemy positions over time
TA.dfModeShowLevelFilter = nil  -- nil = show all, number = threshold
TA.dfModeLastNearestMarkID = nil
TA.dfModeLastNearestMarkDist = nil
TA.dfModeSonarContacts = {}
TA.dfModeSonarPulseUntil = 0
TA.dfModeSonarTTL = 8

local GRID_SIZE_LEGACY_DEFAULT = 12
local GRID_SIZE_STANDARD = 80
local GRID_SIZE_DEFAULT = GRID_SIZE_STANDARD
local GRID_SIZE_MIN = 8
local GRID_SIZE_MAX = 240
local CELL_YARDS_STANDARD = 30
local CELL_YARDS_MIN = 5
local CELL_YARDS_MAX = 500
CELL_YARDS_CANDIDATES = { 12, 15, 18, 20, 24, 30, 36, 40, 45, 50, 60 }
local WALL_WARNING_COOLDOWN = 2.5
local SPACING_ASSUMED_RANGE = 25
local MAX_RECENT_CELLS = 12

local COLORS = {
  system   = { 0.85, 0.85, 0.85 },
  trace    = { 0.55, 0.75, 1.00 },
  combat   = { 1.00, 0.35, 0.35 },
  playerCombat = { 1.00, 1.00, 0.50 },
  enemyCombat = { 1.00, 0.40, 0.40 },
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

local ResetSwingTimer
local CheckSwingTimer
local GetPlayerMapCell
local RecordOutgoingDamage
local ReportCurrentCell
local UpdateMapCellOverlay

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

local warningFrame = CreateFrame("Frame", "TextAdventurerWarningFrame", panel, "BackdropTemplate")
warningFrame:SetSize(860, 50)
warningFrame:SetPoint("TOP", panel, "TOP", 0, -40)
warningFrame:SetFrameStrata("HIGH")
warningFrame:SetFrameLevel(11001)
warningFrame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
warningFrame:SetBackdropColor(0.25, 0, 0, 0.85)
warningFrame:Hide()

warningFrame.text = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
warningFrame.text:SetPoint("CENTER", warningFrame, "CENTER", 0, 0)
warningFrame.text:SetJustifyH("CENTER")
warningFrame.text:SetTextColor(1, 0.4, 0.4)

local function ShowWarningMessage(msg)
  if not msg or msg == "" then return end
  warningFrame.text:SetText(msg)
  warningFrame:Show()
  C_Timer.After(3, function()
    if warningFrame and warningFrame:IsShown() then
      warningFrame:Hide()
    end
  end)
end

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("Text Adventurer")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPRIGHT", -14, -16)
subtitle:SetText("/ta help")

local text = CreateFrame("ScrollingMessageFrame", nil, panel)
text:SetSize(864, 472)
text:SetPoint("TOPLEFT", 18, -42)
text:SetFontObject(GameFontHighlightHuge)
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

-- Subtle bottom flash on new lines (no buffering, no event delay).
text.newLineFlash = text:CreateTexture(nil, "OVERLAY")
text.newLineFlash:SetPoint("BOTTOMLEFT", text, "BOTTOMLEFT", 0, 0)
text.newLineFlash:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 0, 0)
text.newLineFlash:SetHeight(18)
text.newLineFlash:SetColorTexture(0.82, 0.90, 1.0, 0)

text.flashAnim = text.newLineFlash:CreateAnimationGroup()
local flashIn = text.flashAnim:CreateAnimation("Alpha")
flashIn:SetOrder(1)
flashIn:SetDuration(0.02)
flashIn:SetFromAlpha(0.0)
flashIn:SetToAlpha(0.20)
local flashOut = text.flashAnim:CreateAnimation("Alpha")
flashOut:SetOrder(2)
flashOut:SetDuration(0.14)
flashOut:SetFromAlpha(0.20)
flashOut:SetToAlpha(0.0)

panel.text = text

local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
inputBox:SetSize(840, 24)
inputBox:SetPoint("BOTTOMLEFT", 18, 16)
inputBox:SetAutoFocus(false)
inputBox:SetMaxLetters(200)
inputBox:Hide()
panel.inputBox = inputBox

local DF_MODE_DEFAULT_WIDTH = 300
local DF_MODE_DEFAULT_HEIGHT = 600

local dfModeFrame = CreateFrame("Frame", "TextAdventurerDFModeFrame", UIParent, "BackdropTemplate")
dfModeFrame:SetSize(DF_MODE_DEFAULT_WIDTH, DF_MODE_DEFAULT_HEIGHT)
dfModeFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
dfModeFrame:SetFrameStrata("TOOLTIP")
dfModeFrame:SetFrameLevel(11000)
dfModeFrame:SetClampedToScreen(true)
if dfModeFrame.SetResizable then
  dfModeFrame:SetResizable(true)
end
if dfModeFrame.SetMinResize then
  dfModeFrame:SetMinResize(100, 200)
end
if dfModeFrame.SetMaxResize then
  dfModeFrame:SetMaxResize(1200, 1000)
end
dfModeFrame:SetMovable(true)
dfModeFrame:EnableMouse(true)
dfModeFrame:RegisterForDrag("LeftButton")
dfModeFrame:SetScript("OnDragStart", dfModeFrame.StartMoving)
dfModeFrame:SetScript("OnDragStop", dfModeFrame.StopMovingOrSizing)
dfModeFrame:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
    self:StartMoving()
  end
end)
dfModeFrame:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" then
    self:StopMovingOrSizing()
  end
end)
dfModeFrame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
dfModeFrame:SetBackdropColor(0.05, 0.08, 0.10, 0.96)
dfModeFrame:Hide()

local dfTitle = dfModeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
dfTitle:SetPoint("TOPLEFT", 14, -12)
dfTitle:SetText("Tactical Map (DF Mode)")

dfModeFrame.resizeHandle = CreateFrame("Button", nil, dfModeFrame)
dfModeFrame.resizeHandle:SetPoint("BOTTOMRIGHT", -6, 6)
dfModeFrame.resizeHandle:SetSize(16, 16)
dfModeFrame.resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
dfModeFrame.resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
dfModeFrame.resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
dfModeFrame.resizeHandle:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" and self:GetParent().StartSizing then
    self:GetParent():StartSizing("BOTTOMRIGHT")
  end
end)
dfModeFrame.resizeHandle:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" then
    self:GetParent():StopMovingOrSizing()
  end
end)

-- Fixed FontString rows for flicker-free in-place map updates (Dwarf Fortress style)
local dfMapContainer = CreateFrame("Frame", nil, dfModeFrame)
dfMapContainer:SetPoint("TOPLEFT", 18, -42)
dfMapContainer:SetPoint("BOTTOMRIGHT", -18, 18)

local DF_MAX_ROWS = 50
local DF_LINE_HEIGHT = 15
dfModeFrame.mapLines = {}
for i = 1, DF_MAX_ROWS do
  local fs = dfMapContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 0, -(i - 1) * DF_LINE_HEIGHT)
  fs:SetJustifyH("LEFT")
  fs:SetTextColor(0.6, 1.0, 0.9)
  fs:SetText("")
  dfModeFrame.mapLines[i] = fs
end

if ChatFrame1 then
  ChatFrame1:Show()
  ChatFrame1:SetFrameStrata("LOW")
  ChatFrame1:SetFrameLevel(1)
end

local function AddLine(kind, msg)
  if not msg or msg == "" then return end
  local c = COLORS[kind] or COLORS.system
  local line = {
    text = date("%H:%M:%S") .. "  " .. msg,
    r = c[1], g = c[2], b = c[3],
  }
  table.insert(TA.lines, line)
  if #TA.lines > TA.lineLimit then table.remove(TA.lines, 1) end
  panel.text:AddMessage(line.text, line.r, line.g, line.b)
  if panel.text.flashAnim and panel.text.newLineFlash then
    if panel.text.flashAnim:IsPlaying() then
      panel.text.flashAnim:Stop()
    end
    panel.text.newLineFlash:SetAlpha(0)
    panel.text.flashAnim:Play()
  end
  panel.text:ScrollToBottom()
end

local function TA_BroadcastDangerWarningToChat()
  local chat = DEFAULT_CHAT_FRAME
  if chat and chat.AddMessage then
    chat:AddMessage("|cffff4040[Text Adventurer WARNING]|r This addon is extremely dangerous for Hardcore play and WILL eventually get your character killed.")
    chat:AddMessage("|cffff4040[Text Adventurer WARNING]|r First-run safety is ON: autostart is disabled. Use /ta autostart on only after you understand the risks.")
  end
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

local function FormatMoney(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local cop = copper % 100
  if gold > 0 then
    return string.format("%dg %ds %dc", gold, silver, cop)
  elseif silver > 0 then
    return string.format("%ds %dc", silver, cop)
  else
    return string.format("%dc", cop)
  end
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
        local sellText = ""
        if newItem.itemID and GetItemInfo then
          local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(newItem.itemID)
          if sellPrice and sellPrice > 0 then
            sellText = string.format(" [sells for %s]", FormatMoney(sellPrice * (newItem.stackCount or 1)))
          end
        end
        table.insert(changes, string.format("Loot placed in %s slot %d: %s x%d%s", BagLabel(bag), slot, newItem.hyperlink or ("item:" .. tostring(newItem.itemID or "?")), newItem.stackCount or 1, sellText))
      elseif oldItem and newItem and oldItem.itemID == newItem.itemID then
        local oldCount = oldItem.stackCount or 0
        local newCount = newItem.stackCount or 0
        if newCount > oldCount then
          local delta = newCount - oldCount
          local sellText = ""
          if newItem.itemID and GetItemInfo then
            local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(newItem.itemID)
            if sellPrice and sellPrice > 0 then
              sellText = string.format(" [sells for %s]", FormatMoney(sellPrice * delta))
            end
          end
          table.insert(changes, string.format("Loot added in %s slot %d: %s +%d%s", BagLabel(bag), slot, newItem.hyperlink or ("item:" .. tostring(newItem.itemID or "?")), delta, sellText))
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
      local color = IsSourcePlayerOrPet(sourceFlags) and "playerCombat" or "enemyCombat"
      AddLine(color, FormatDamageEvent(subevent, sourceName, destName, nil, param1))
    end
    if IsSourcePlayerOrPet(sourceFlags) then
      RecordOutgoingDamage(param1)
    end
    if IsSourcePlayerOrPet(sourceFlags) then
      ResetSwingTimer()
    end
  elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      local color = IsSourcePlayerOrPet(sourceFlags) and "playerCombat" or "enemyCombat"
      AddLine(color, FormatDamageEvent(subevent, sourceName, destName, param2, param4))
    end
    if IsSourcePlayerOrPet(sourceFlags) then
      RecordOutgoingDamage(param4)
    end
  elseif subevent == "SWING_MISSED" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      local color = IsSourcePlayerOrPet(sourceFlags) and "playerCombat" or "enemyCombat"
      AddLine(color, FormatMissEvent(subevent, sourceName, destName, nil, param1))
    end
    if IsSourcePlayerOrPet(sourceFlags) then
      ResetSwingTimer()
    end
  elseif subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
    if IsSourcePlayerOrPet(sourceFlags) or IsDestPlayerOrPet(destFlags) then
      local color = IsSourcePlayerOrPet(sourceFlags) and "playerCombat" or "enemyCombat"
      AddLine(color, FormatMissEvent(subevent, sourceName, destName, param2, param4))
    end
  elseif subevent == "SPELL_CAST_SUCCESS" then
    if IsSourcePlayerOrPet(sourceFlags) then
      AddLine("cast", string.format("%s uses %s.", sourceName or "Unknown", SpellLabel(param2)))
    end
  elseif subevent == "SPELL_CAST_FAILED" then
    if IsSourcePlayerOrPet(sourceFlags) then
      local spellName = param2
      local reason = param4
      local message = reason
      if reason == "You are moving" or reason:lower():find("moving") then
        local inRange = UnitExists("target") and IsSpellInRange(spellName, "target") == 1
        if inRange then
          message = "You have to stand still."
        else
          message = "Out of range."
        end
      end
      AddLine("cast", string.format("Failed to cast %s: %s", SpellLabel(spellName), message))
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
  elseif reason == "failed" and unit ~= "player" then
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

local function GetTargetFacingDegrees()
  if not UnitExists("target") or UnitIsDeadOrGhost("target") then return nil end
  if not UnitFacing then return nil end
  local f = UnitFacing("target")
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

local function ReportTargetPositioning()
  if not UnitExists("target") then
    AddLine("system", "No target selected.")
    return
  end
  if UnitIsDeadOrGhost("target") then
    AddLine("system", "Target is dead.")
    return
  end

  local playerFacing = GetFacingDegrees()
  if not playerFacing then
    AddLine("system", "Could not read your facing.")
    return
  end

  local targetFacing = GetTargetFacingDegrees()
  local targetFacingPlayer = nil
  local playerFacingTarget = nil
  if UnitIsFacing then
    targetFacingPlayer = UnitIsFacing("target", "player")
    playerFacingTarget = UnitIsFacing("player", "target")
  end

  if not targetFacing and targetFacingPlayer == nil then
    if UnitIsFacing then
      AddLine("system", "Could not determine target facing from this client.")
    else
      AddLine("system", "Target-facing information is not available in this client, so backstab cannot be determined.")
    end
    return
  end

  if targetFacing then
    local relative = AngleDiff(playerFacing, targetFacing)
    local facingText
    if relative < 30 then
      facingText = "Target is facing you."
    elseif relative < 150 then
      facingText = "Target is facing sideways to you."
    else
      facingText = "Target is facing away from you."
    end
    AddLine("system", string.format("%s facing: %.0f°, you facing: %.0f°, relative heading: %.0f°.", UnitName("target") or "Target", targetFacing, playerFacing, relative))
    AddLine("system", facingText)
    if relative > 150 then
      AddLine("system", "Rear attack likely possible if you are in melee range.")
    else
      AddLine("system", "You are not behind the target.")
    end
  else
    -- Use facing checks when exact target facing angle is unavailable.
    local facingText
    if targetFacingPlayer and playerFacingTarget then
      facingText = "You and the target are facing each other. You are not behind them."
    elseif targetFacingPlayer and not playerFacingTarget then
      facingText = "The target is facing you, but you are not facing them directly."
    elseif not targetFacingPlayer and playerFacingTarget then
      facingText = "The target is not facing you and you are facing them. You are likely behind them."
    else
      facingText = "Neither of you is directly facing the other. You may be to the side or behind the target."
    end
    AddLine("system", string.format("You facing target: %s, target facing you: %s.", tostring(playerFacingTarget), tostring(targetFacingPlayer)))
    AddLine("system", facingText)
    if not targetFacingPlayer and playerFacingTarget then
      AddLine("system", "Rear attack likely possible if you are in melee range.")
    else
      AddLine("system", "You are not clearly behind the target.")
    end
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

local function GetGridSize()
  local size = tonumber(TA.gridSize) or GRID_SIZE_DEFAULT
  size = math.floor(size)
  if size < GRID_SIZE_MIN then size = GRID_SIZE_MIN end
  if size > GRID_SIZE_MAX then size = GRID_SIZE_MAX end
  return size
end

local function ClampGridSize(n)
  n = math.floor(tonumber(n) or GRID_SIZE_DEFAULT)
  if n < GRID_SIZE_MIN then n = GRID_SIZE_MIN end
  if n > GRID_SIZE_MAX then n = GRID_SIZE_MAX end
  return n
end

local function NormalizePeriodicOffset(offset, step)
  if not step or step <= 0 then return 0 end
  offset = tonumber(offset) or 0
  offset = offset % step
  return offset
end

local function IsAnchorCompatible(anchor, gridX, gridY)
  if type(anchor) ~= "table" then return false end
  if tonumber(anchor.gridX) ~= tonumber(gridX) or tonumber(anchor.gridY) ~= tonumber(gridY) then
    return false
  end
  local anchorMode = anchor.mode == "yards" and "yards" or "grid"
  local currentMode = TA.cellSizeMode == "yards" and "yards" or "grid"
  if anchorMode ~= currentMode then
    return false
  end
  if anchorMode == "yards" then
    local anchorYards = math.floor((tonumber(anchor.targetYards) or 0) + 0.5)
    local currentYards = math.floor((tonumber(TA.cellSizeYards) or 0) + 0.5)
    return anchorYards > 0 and anchorYards == currentYards
  end
  return true
end

local function GetCellGridForMap(mapID)
  local mode = TA.cellSizeMode == "yards" and "yards" or "grid"
  local targetYards = tonumber(TA.cellSizeYards)
  if mode == "yards" then
    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if targetYards and targetYards > 0 and mapInfo and mapInfo.width and mapInfo.height and mapInfo.width > 0 and mapInfo.height > 0 then
      local gridX = ClampGridSize(math.floor((mapInfo.width / targetYards) + 0.5))
      local gridY = ClampGridSize(math.floor((mapInfo.height / targetYards) + 0.5))
      return gridX, gridY, "yards", targetYards
    end
  end

  local gridSize = GetGridSize()
  return gridSize, gridSize, mode, targetYards
end

local function GetMapAnchor(mapID, gridX, gridY)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local anchors = TA.cellAnchors or {}
  local anchor = anchors[mapID]
  if not IsAnchorCompatible(anchor, gridX, gridY) then
    return 0, 0
  end
  return NormalizePeriodicOffset(anchor.offsetX, stepX), NormalizePeriodicOffset(anchor.offsetY, stepY)
end

local function ComputeCellForPosition(x, y, gridX, gridY, offsetX, offsetY)
  local shiftedX = (x - (offsetX or 0)) % 1
  local shiftedY = (y - (offsetY or 0)) % 1
  local scaledX = shiftedX * gridX
  local scaledY = shiftedY * gridY
  local cellX = math.floor(scaledX)
  local cellY = math.floor(scaledY)
  if cellX < 0 then cellX = 0 end
  if cellY < 0 then cellY = 0 end
  if cellX >= gridX then cellX = gridX - 1 end
  if cellY >= gridY then cellY = gridY - 1 end
  local inCellX = math.max(0, math.min(1, scaledX - cellX))
  local inCellY = math.max(0, math.min(1, scaledY - cellY))
  return cellX, cellY, inCellX, inCellY
end

local function GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local minX = ((offsetX or 0) + (cellX * stepX)) % 1
  local maxX = minX + stepX
  local minY = ((offsetY or 0) + (cellY * stepY)) % 1
  local maxY = minY + stepY
  return minX, maxX, minY, maxY, stepX, stepY
end

local function RecenterCurrentCellAnchor(silent)
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then
    if not silent then AddLine("system", "Could not center grid: map is unavailable.") end
    return false
  end
  local x, y
  if C_Map and C_Map.GetPlayerMapPosition then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      x, y = pos:GetXY()
    end
  elseif GetPlayerMapPosition then
    x, y = GetPlayerMapPosition("player")
  end
  if not x or not y then
    if not silent then AddLine("system", "Could not center grid: player position unavailable.") end
    return false
  end

  local gridX, gridY, mode, targetYards = GetCellGridForMap(mapID)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local offsetX = NormalizePeriodicOffset(x - (0.5 * stepX), stepX)
  local offsetY = NormalizePeriodicOffset(y - (0.5 * stepY), stepY)

  TA.cellAnchors = TA.cellAnchors or {}
  TA.cellAnchors[mapID] = {
    offsetX = offsetX,
    offsetY = offsetY,
    gridX = gridX,
    gridY = gridY,
    mode = mode,
    targetYards = targetYards,
  }
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.cellAnchors = TA.cellAnchors
  TA.lastCellVizSignature = nil
  UpdateMapCellOverlay()

  if not silent then
    AddLine("system", "Cell grid anchor moved so your position is centered in the current cell.")
  end
  return true
end

ReportCurrentCell = function(force)
  local mapID, cellX, cellY, x, y, _, _, _, gridX, gridY, offsetX, offsetY, inCellX, inCellY = GetPlayerMapCell()
  if not mapID then
    if force then AddLine("system", "Could not determine current cell.") end
    return
  end
  local minX, maxX, minY, maxY = GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local sizeText = "size unknown"
  if mapInfo and mapInfo.width and mapInfo.height and mapInfo.width > 0 and mapInfo.height > 0 then
    sizeText = string.format("~%.1f x %.1f yards", mapInfo.width / gridX, mapInfo.height / gridY)
  end
  local signature = string.format("%d:%d,%d:%d:%d:%s:%.6f:%.6f", mapID, cellX, cellY, gridX, gridY, TA.cellSizeMode or "grid", offsetX or 0, offsetY or 0)
  local modeText
  if TA.cellSizeMode == "yards" and tonumber(TA.cellSizeYards) then
    modeText = string.format("fixed %.0f-yard mode (%dx%d grid)", tonumber(TA.cellSizeYards), gridX, gridY)
  else
    modeText = string.format("%dx%d grid", gridX, gridY)
  end
  if force or signature ~= TA.lastCellVizSignature then
    AddLine("place", string.format("Cell %d,%d on map %d using %s (%s).", cellX, cellY, mapID, modeText, sizeText))
    AddLine("place", string.format("Bounds X %.4f-%.4f, Y %.4f-%.4f. Position in cell: %.0f%% east, %.0f%% south.", minX, maxX, minY, maxY, inCellX * 100, inCellY * 100))
    if TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID then
      AddLine("place", string.format("YOU ARE IN MARKED CELL [%d]: %s", TA.markedCells[TA.lastMarkedCellNotification].id or -1, TA.markedCells[TA.lastMarkedCellNotification].name or "Unnamed"))
    else
      AddLine("place", "You are not in a marked cell.")
    end
    TA.lastCellVizSignature = signature
  end
end

local function SetGridSize(newSize, label)
  local n = tonumber(newSize)
  if not n then
    AddLine("system", "Usage: cellsize <number|standard|inn>")
    return
  end
  n = math.floor(n)
  if n < GRID_SIZE_MIN or n > GRID_SIZE_MAX then
    AddLine("system", string.format("Cell size must be between %d and %d.", GRID_SIZE_MIN, GRID_SIZE_MAX))
    return
  end
  TA.gridSize = n
  TA.cellSizeMode = "grid"
  TA.cellSizeYards = nil
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.gridSize = n
  TextAdventurerDB.cellSizeMode = "grid"
  TextAdventurerDB.cellSizeYards = nil
  RecenterCurrentCellAnchor(true)
  TA.lastCellVizSignature = nil
  if label and label ~= "" then
    AddLine("system", string.format("Cell grid set to %s (%dx%d).", label, n, n))
  else
    AddLine("system", string.format("Cell grid set to %dx%d.", n, n))
  end
end

local function SetCellSizeYards(newYards)
  local yards = tonumber(newYards)
  if not yards then
    AddLine("system", "Usage: cellyards <yards>|off")
    return
  end
  yards = math.floor(yards + 0.5)
  if yards < CELL_YARDS_MIN or yards > CELL_YARDS_MAX then
    AddLine("system", string.format("Cell yards must be between %d and %d.", CELL_YARDS_MIN, CELL_YARDS_MAX))
    return
  end

  TA.cellSizeMode = "yards"
  TA.cellSizeYards = yards
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.cellSizeMode = "yards"
  TextAdventurerDB.cellSizeYards = yards
  RecenterCurrentCellAnchor(true)
  TA.lastCellVizSignature = nil
  AddLine("system", string.format("Cell sizing set to fixed %d-yard mode.", yards))
end

local function DisableCellSizeYardsMode()
  TA.cellSizeMode = "grid"
  TA.cellSizeYards = nil
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.cellSizeMode = "grid"
  TextAdventurerDB.cellSizeYards = nil
  RecenterCurrentCellAnchor(true)
  TA.lastCellVizSignature = nil
  AddLine("system", "Fixed-yard cell mode disabled; using grid mode.")
end

function TA_ParseCellYardsCandidates(arg)
  if not arg or arg == "" then
    return nil
  end

  local values = {}
  local seen = {}
  for token in string.gmatch(arg, "[%d%.]+") do
    local yards = math.floor((tonumber(token) or 0) + 0.5)
    if yards >= CELL_YARDS_MIN and yards <= CELL_YARDS_MAX and not seen[yards] then
      seen[yards] = true
      table.insert(values, yards)
    end
  end

  if #values == 0 then
    return nil
  end

  table.sort(values)
  return values
end

function TA_ReportCellYardsCalibration(arg)
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then
    AddLine("system", "Could not calibrate cell size: map is unavailable.")
    return
  end

  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  if not mapInfo or not mapInfo.width or not mapInfo.height or mapInfo.width <= 0 or mapInfo.height <= 0 then
    AddLine("system", "Could not calibrate cell size: map dimensions are unavailable.")
    return
  end

  local candidates = TA_ParseCellYardsCandidates(arg) or CELL_YARDS_CANDIDATES
  local rows = {}
  for _, targetYards in ipairs(candidates) do
    local gridX = ClampGridSize(math.floor((mapInfo.width / targetYards) + 0.5))
    local gridY = ClampGridSize(math.floor((mapInfo.height / targetYards) + 0.5))
    local actualX = mapInfo.width / gridX
    local actualY = mapInfo.height / gridY
    local drift = math.abs(actualX - targetYards) + math.abs(actualY - targetYards)
    local skew = math.abs(actualX - actualY)
    -- Prefer candidates that stay close to target yards and keep X/Y cell dimensions similar.
    local score = drift + (skew * 0.35)

    table.insert(rows, {
      target = targetYards,
      gridX = gridX,
      gridY = gridY,
      actualX = actualX,
      actualY = actualY,
      drift = drift,
      skew = skew,
      score = score,
    })
  end

  if #rows == 0 then
    AddLine("system", "No valid cell-yard candidates to test.")
    return
  end

  table.sort(rows, function(a, b)
    if a.score == b.score then
      return a.target < b.target
    end
    return a.score < b.score
  end)

  local mapName = mapInfo.name or ("map " .. tostring(mapID))
  AddLine("system", string.format("Cell calibration on %s (%d):", mapName, mapID))
  local showCount = math.min(#rows, 6)
  for i = 1, showCount do
    local row = rows[i]
    AddLine("system", string.format("  %d yd -> %dx%d grid, actual %.1f x %.1f yd (drift %.1f, skew %.1f)", row.target, row.gridX, row.gridY, row.actualX, row.actualY, row.drift, row.skew))
  end

  local best = rows[1]
  AddLine("system", string.format("Recommended here: /ta cellyards %d", best.target))
  AddLine("system", "Use /ta cellcal <n1 n2 n3 ...> to test your own yard list.")
end

local function GetWorldMapOverlayParent()
  if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return nil end
  return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
end

local function EnsureMapCellOverlay()
  if TA.mapCellOverlay then return TA.mapCellOverlay end
  local parent = GetWorldMapOverlayParent()
  if not parent then return nil end

  local container = CreateFrame("Frame", nil, parent)
  container:SetAllPoints(parent)
  container:SetFrameStrata("HIGH")
  container:SetFrameLevel(parent:GetFrameLevel() + 20)
  container:EnableMouse(false)
  container:Hide()

  local function CreateOutline(r, g, b)
    local frame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    frame:SetBackdrop({
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 12,
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, 0.08)
    frame:SetBackdropBorderColor(r, g, b, 0.95)
    frame:Hide()

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    frame.label:SetTextColor(r, g, b)
    return frame
  end

  container.current = CreateOutline(0.1, 1.0, 0.2)
  container.marked = CreateOutline(1.0, 0.82, 0.2)

  TA.mapCellOverlay = container
  return container
end

local function SetOverlayRect(frame, parent, minX, maxX, minY, maxY, label)
  if not frame or not parent then return end
  minX = math.max(0, math.min(1, minX))
  maxX = math.max(0, math.min(1, maxX))
  minY = math.max(0, math.min(1, minY))
  maxY = math.max(0, math.min(1, maxY))
  if maxX <= minX or maxY <= minY then
    frame:Hide()
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", minX * parent:GetWidth(), -minY * parent:GetHeight())
  frame:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", maxX * parent:GetWidth(), -maxY * parent:GetHeight())
  frame.label:SetText(label or "")
  frame:Show()
end

local function GetMarkedCellByID(markID)
  if not markID then return nil end
  return TA.markedCells and TA.markedCells[markID] or nil
end

UpdateMapCellOverlay = function()
  local overlayParent = GetWorldMapOverlayParent()
  local overlay = EnsureMapCellOverlay()
  if not overlay or not overlayParent or not TA.mapOverlayEnabled then
    if overlay then overlay:Hide() end
    return
  end
  if not WorldMapFrame:IsShown() then
    overlay:Hide()
    return
  end

  local currentMapID, cellX, cellY, _, _, _, _, _, gridX, gridY, offsetX, offsetY = GetPlayerMapCell()
  local displayedMapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or currentMapID
  local showedAnything = false

  overlay.current:Hide()
  overlay.marked:Hide()

  if currentMapID and displayedMapID and currentMapID == displayedMapID then
    local minX, maxX, minY, maxY = GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
    SetOverlayRect(overlay.current, overlayParent, minX, maxX, minY, maxY, "Current cell")
    showedAnything = true
  end

  local mark = GetMarkedCellByID(TA.activeMapMarkID)
  if mark and displayedMapID and mark.mapID == displayedMapID and mark.cellX ~= nil and mark.cellY ~= nil then
    local markGridX = ClampGridSize(tonumber(mark.gridX) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
    local markGridY = ClampGridSize(tonumber(mark.gridY) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
    local markOffsetX = NormalizePeriodicOffset(mark.anchorOffsetX, 1 / markGridX)
    local markOffsetY = NormalizePeriodicOffset(mark.anchorOffsetY, 1 / markGridY)
    local minX, maxX, minY, maxY = GetCellBounds(mark.cellX, mark.cellY, markGridX, markGridY, markOffsetX, markOffsetY)
    SetOverlayRect(overlay.marked, overlayParent, minX, maxX, minY, maxY, mark.name or "Marked cell")
    showedAnything = true
  end

  if showedAnything then
    overlay:Show()
  else
    overlay:Hide()
  end
end

GetPlayerMapCell = function()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local gridX, gridY = GetCellGridForMap(mapID)
  local offsetX, offsetY = GetMapAnchor(mapID, gridX, gridY)
  local x, y
  if C_Map and C_Map.GetPlayerMapPosition then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      x, y = pos:GetXY()
    end
  elseif GetPlayerMapPosition then
    x, y = GetPlayerMapPosition("player")
  end
  if not x or not y then return nil end
  local cellX, cellY, inCellX, inCellY = ComputeCellForPosition(x, y, gridX, gridY, offsetX, offsetY)
  
  -- Get continent coordinates for global positioning
  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local continentID = mapInfo and mapInfo.continentID or nil
  local continentX, continentY = 0, 0
  if continentID and C_Map and C_Map.GetWorldPosFromMapPos then
    local worldPos = C_Map.GetWorldPosFromMapPos(mapID, {x = x, y = y})
    if worldPos and type(worldPos) == "table" and worldPos.x and worldPos.y then
      continentX, continentY = worldPos.x, worldPos.y
    end
  end
  
  return mapID, cellX, cellY, x, y, continentX, continentY, continentID, gridX, gridY, offsetX, offsetY, inCellX, inCellY
end

local function CellKey(x, y)
  return tostring(x) .. "," .. tostring(y)
end

local function MarkCurrentCell(name)
  local mapID, cellX, cellY, x, y, continentX, continentY, continentID, gridX, gridY, offsetX, offsetY = GetPlayerMapCell()
  if not mapID then 
    AddLine("system", "Could not determine current location - mapID is nil.")
    return 
  end
  local zoneName = GetZoneText() or "Unknown Zone"
  
  local markID = TA.nextMarkID
  local markName = name or ("cell " .. tostring(markID))
  TA.markedCells[markID] = {
    id = markID,
    name = markName,
    zoneName = zoneName,
    mapID = mapID,
    gridSize = gridX,
    gridX = gridX,
    gridY = gridY,
    anchorOffsetX = offsetX,
    anchorOffsetY = offsetY,
    cellMode = TA.cellSizeMode or "grid",
    targetYards = tonumber(TA.cellSizeYards),
    continentID = continentID,
    cellX = cellX,
    cellY = cellY,
    x = x,
    y = y,
    continentX = continentX,
    continentY = continentY,
    timestamp = time()
  }
  TA.nextMarkID = TA.nextMarkID + 1
  TA.activeMapMarkID = markID
  TA.lastMarkedCellNotification = markID
  AddLine("system", string.format("Marked %s", markName))
  UpdateMapCellOverlay()
end

local function ListMarkedCells()
  if not next(TA.markedCells) then
    AddLine("system", "No cells marked.")
    return
  end
  AddLine("system", "Marked cells:")
  for markID, mark in pairs(TA.markedCells) do
    local active = (TA.activeMapMarkID == markID) and " [shown on map]" or ""
    AddLine("system", string.format("  [%d] %s in %s%s", mark.id, mark.name, mark.zoneName, active))
  end
end

local function ShowMarkedCellOnMap(markID)
  local mark = GetMarkedCellByID(markID)
  if not mark then
    AddLine("system", string.format("No marked cell found with ID %d.", tonumber(markID) or -1))
    return
  end
  TA.activeMapMarkID = mark.id
  AddLine("system", string.format("World Map will highlight marked cell [%d] %s.", mark.id, mark.name or "Unnamed"))
  UpdateMapCellOverlay()
end

function TA_RenameMarkedCell(markID, newName)
  local mark = GetMarkedCellByID(markID)
  if not mark then
    AddLine("system", string.format("No marked cell found with ID %d.", markID))
    return
  end
  local oldName = mark.name
  mark.name = newName
  TextAdventurerDB.markedCells = TA.markedCells
  AddLine("system", string.format("Renamed marked cell [%d] from '%s' to '%s'.", markID, oldName, newName))
end

local function ClearMarkedCells()
  wipe(TA.markedCells)
  TA.activeMapMarkID = nil
  UpdateMapCellOverlay()
  AddLine("system", "All marked cells cleared.")
end

local LANDMARK_FLAVOR = {
  -- Dungeons / instances
  ["Deadmines"]             = "The smell of sea-salt and rust fills the air. You have entered the Deadmines.",
  ["Wailing Caverns"]       = "Twisted green light filters through the stone. You descend into the Wailing Caverns.",
  ["Shadowfang Keep"]       = "The gates of Shadowfang Keep loom before you, cold and silent.",
  ["Blackfathom Deeps"]     = "The sound of lapping water echoes in the darkness of Blackfathom Deeps.",
  ["The Stockade"]          = "Iron bars and the stench of the imprisoned surround you in the Stockade.",
  ["Gnomeregan"]            = "A low mechanical hum pervades the air. You enter the ruins of Gnomeregan.",
  ["Razorfen Kraul"]        = "Thorned tunnels close around you. You are within Razorfen Kraul.",
  ["Scarlet Monastery"]     = "The halls reek of zealotry and old blood. You have entered the Scarlet Monastery.",
  ["Razorfen Downs"]        = "The stench of undeath is overwhelming here in Razorfen Downs.",
  ["Uldaman"]               = "Ancient stone presses in from all sides. You are inside Uldaman.",
  ["Zul'Farrak"]            = "Searing heat and the cry of trolls greet you in Zul'Farrak.",
  ["Maraudon"]              = "Bioluminescent fungi cast strange light across Maraudon.",
  ["Sunken Temple"]         = "Forgotten whispers echo beneath the water. You enter the Sunken Temple.",
  ["Blackrock Depths"]      = "Molten heat radiates from the stone walls of Blackrock Depths.",
  ["Lower Blackrock Spire"] = "The roar of wyverns and the clang of iron surround you in Blackrock Spire.",
  ["Upper Blackrock Spire"] = "You press deeper into the heights of Blackrock Spire.",
  ["Dire Maul"]             = "Crumbling arches of a lost elven city rise around you in Dire Maul.",
  ["Stratholme"]            = "The burning ruins of Stratholme stretch before you, hauntingly still.",
  ["Scholomance"]           = "Necromantic cold seeps into your bones as you enter Scholomance.",
  ["Blackwing Lair"]        = "The air shimmers with draconic power. You have entered Blackwing Lair.",
  ["Molten Core"]           = "The floor shudders beneath your feet. You descend into the Molten Core.",
  ["Onyxia's Lair"]         = "The reek of dragonfire and old bone fills Onyxia's Lair.",
  ["Zul'Gurub"]             = "Drums echo through the jungle ruins of Zul'Gurub.",
  ["Ruins of Ahn'Qiraj"]    = "The sand shifts and writhes. You are within the Ruins of Ahn'Qiraj.",
  ["Temple of Ahn'Qiraj"]   = "An alien silence presses down upon the Temple of Ahn'Qiraj.",
  ["Naxxramas"]             = "The floating necropolis of Naxxramas turns slowly overhead.",
  -- Notable outdoor subzones
  ["Sentinel Hill"]         = "The watchtower of Sentinel Hill rises before you, a fragile beacon of order.",
  ["Goldshire"]             = "The smell of roasting meat and spilled ale drifts from the Lion's Pride Inn.",
  ["Darkshire"]             = "Darkshire lies wrapped in its perpetual twilight, the townsfolk watchful and grim.",
  ["Lakeshire"]             = "The creak of the old bridge announces your arrival in Lakeshire.",
  ["Ironforge"]             = "The Great Forge thunders below you. You have entered Ironforge.",
  ["Stormwind City"]        = "The gates of Stormwind stand tall, banners snapping in the wind.",
  ["Orgrimmar"]             = "The war-drums of Orgrimmar greet you as you pass through the canyon gates.",
  ["Thunder Bluff"]         = "The winds of the high mesa sweep through Thunder Bluff.",
  ["Undercity"]             = "The stench of formaldehyde and damp stone fills the passages of the Undercity.",
  ["Darnassus"]             = "Ancient trees arch overhead as you walk the moonlit paths of Darnassus.",
  ["Booty Bay"]             = "The raucous clamor of Booty Bay's docks rises around you.",
  ["Gadgetzan"]             = "Heat shimmers off the sand-blasted walls of Gadgetzan.",
  ["Everlook"]              = "The biting cold of Winterspring cuts through you as you enter Everlook.",
  ["Cenarion Hold"]         = "The forward camp of Cenarion Hold is a thin green line against the sands.",
}

local function CheckLandmarkEntry()
  local subzone = GetSubZoneText() or ""
  local zone    = GetZoneText() or ""
  if subzone == "" then subzone = zone end
  if subzone == TA.lastSubzone then return end
  TA.lastSubzone = subzone
  local flavor = LANDMARK_FLAVOR[subzone] or LANDMARK_FLAVOR[zone]
  if flavor then
    AddLine("place", flavor)
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
  
  if hpPct < 35 then
    local warningText
    if hpPct < 20 then
      warningText = "LOW HEALTH! HEAL NOW!"
    else
      warningText = "WOUNDED! WATCH YOUR HEALTH!"
    end
    if TA.lastHealthWarningState ~= warningText then
      ShowWarningMessage(warningText)
      TA.lastHealthWarningState = warningText
    end
  else
    TA.lastHealthWarningState = nil
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
  if not GetNumTrackingTypes or not GetTrackingInfo then
    AddLine("system", "Tracking API unavailable.")
    return
  end
  local total = GetNumTrackingTypes() or 0
  if total <= 0 then
    AddLine("system", "No tracking types available.")
    return
  end
  local active = {}
  for i = 1, total do
    local name, _, activeFlag = GetTrackingInfo(i)
    if name and activeFlag then
      table.insert(active, name)
    end
  end
  if #active == 0 then
    AddLine("status", "No minimap tracking is active.")
  else
    AddLine("status", "Active tracking: " .. table.concat(active, ", ") .. ".")
  end
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

local function QuestCompletionLabel(isComplete)
  if isComplete == 1 then return "complete" end
  if isComplete == -1 then return "failed" end
  return "in progress"
end

local function FindQuestIndexByName(name)
  if not name or name == "" then return nil end
  local wanted = string.lower(name)
  local total = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
  for i = 1, total do
    local title, _, _, isHeader = GetQuestLogTitle(i)
    if title and not isHeader and string.lower(title) == wanted then
      return i
    end
  end
  for i = 1, total do
    local title, _, _, isHeader = GetQuestLogTitle(i)
    if title and not isHeader and string.find(string.lower(title), wanted, 1, true) then
      return i
    end
  end
  return nil
end

local function GetFallbackQuestIndex()
  local selected = GetQuestLogSelection and GetQuestLogSelection() or 0
  if selected and selected > 0 then return selected end
  local total = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
  for i = 1, total do
    local _, _, _, isHeader = GetQuestLogTitle(i)
    if not isHeader then return i end
  end
  return nil
end

local function ReportQuestInfoByIndex(index)
  if not index or index < 1 or not SelectQuestLogEntry then
    AddLine("system", "Usage: questinfo <index or name>")
    return
  end
  local title, level, _, isHeader, _, isComplete = GetQuestLogTitle(index)
  if not title or isHeader then
    AddLine("system", string.format("No quest found at index %d.", index))
    return
  end

  local previousSelection = GetQuestLogSelection and GetQuestLogSelection() or 0
  SelectQuestLogEntry(index)

  AddLine("quest", string.format("Quest [%d]: %s (level %d) - %s", index, title, level or 0, QuestCompletionLabel(isComplete)))
  if GetQuestLogQuestText then
    local description, objectivesText = GetQuestLogQuestText()
    if description and description ~= "" then
      AddLine("quest", "Description:")
      for line in description:gmatch("[^\n]+") do
        AddLine("quest", "  " .. line)
      end
    end
    if objectivesText and objectivesText ~= "" then
      AddLine("quest", "Objectives:")
      for line in objectivesText:gmatch("[^\n]+") do
        AddLine("quest", "  " .. line)
      end
    end
  end

  local numObjectives = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(index) or 0
  for obj = 1, numObjectives do
    local desc, objType, finished = GetQuestLogLeaderBoard(obj, index)
    if desc then
      local mark = finished and "[x]" or "[ ]"
      AddLine("quest", string.format("  %s %s", mark, desc))
    end
  end

  if previousSelection and previousSelection > 0 and previousSelection ~= index then
    SelectQuestLogEntry(previousSelection)
  end
end

local function ReportQuestInfo(arg)
  if not GetNumQuestLogEntries or not GetQuestLogTitle then
    AddLine("system", "Quest log API unavailable.")
    return
  end
  local total = GetNumQuestLogEntries() or 0
  if total <= 0 then
    AddLine("system", "Your quest log is empty.")
    return
  end

  local index = nil
  if arg and arg ~= "" then
    local numeric = tonumber(arg)
    if numeric then
      index = numeric
    else
      index = FindQuestIndexByName(arg)
      if not index then
        AddLine("system", string.format("No quest matched '%s'.", arg))
        return
      end
    end
  else
    index = GetFallbackQuestIndex()
  end
  if not index then
    AddLine("system", "No quest selected. Use questinfo <index or name>.")
    return
  end
  ReportQuestInfoByIndex(index)
end

local function BuildQuestObjectiveSnapshot()
  local snapshot = {}
  local total = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
  for i = 1, total do
    local title, _, _, isHeader = GetQuestLogTitle(i)
    if title and not isHeader then
      local numObjectives = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
      for obj = 1, numObjectives do
        local desc, _, finished = GetQuestLogLeaderBoard(obj, i)
        if desc then
          local key = string.format("%s#%d", title, obj)
          snapshot[key] = {
            questTitle = title,
            desc = desc,
            finished = finished and true or false,
          }
        end
      end
    end
  end
  return snapshot
end

local function ReportQuestObjectiveChanges()
  local oldSnapshot = TA.questObjectiveSnapshot or {}
  local newSnapshot = BuildQuestObjectiveSnapshot()
  for key, now in pairs(newSnapshot) do
    local before = oldSnapshot[key]
    if not before then
      AddLine("quest", string.format("New objective tracked for %s: %s", now.questTitle, now.desc))
    elseif before.desc ~= now.desc then
      AddLine("quest", string.format("Objective update for %s: %s", now.questTitle, now.desc))
    elseif before.finished ~= now.finished then
      if now.finished then
        AddLine("quest", string.format("Objective complete for %s: %s", now.questTitle, now.desc))
      else
        AddLine("quest", string.format("Objective reset for %s: %s", now.questTitle, now.desc))
      end
    end
  end
  TA.questObjectiveSnapshot = newSnapshot
end

local function FormatSecondsRemaining(expirationTime)
  if not expirationTime or expirationTime == 0 then
    return "no timer"
  end
  local remain = math.max(0, expirationTime - GetTime())
  return string.format("%.0fs", remain)
end

local function SnapshotBuffs()
  local snapshot = {}
  for i = 1, 40 do
    local name, icon, count, debuffType, duration, expirationTime, source, isStealable,
      nameplateShowPersonal, spellId = UnitBuff("player", i)
    if not name then break end
    snapshot[name] = {
      count = count or 0,
      expirationTime = expirationTime or 0,
      spellId = spellId,
    }
  end
  return snapshot
end

local function ReportBuffs()
  local found = 0
  for i = 1, 40 do
    local name, icon, count, debuffType, duration, expirationTime = UnitBuff("player", i)
    if not name then break end
    local timerText = FormatSecondsRemaining(expirationTime)
    local stackText = (count and count > 1) and (" x" .. count) or ""
    AddLine("status", string.format("Buff: %s%s - %s", name, stackText, timerText))
    found = found + 1
  end
  if found == 0 then
    AddLine("status", "You have no active buffs.")
  end
end

local function ReportBuffChanges()
  local newSnapshot = SnapshotBuffs()
  for name, info in pairs(newSnapshot) do
    if not TA.lastBuffSnapshot[name] then
      AddLine("status", string.format("You gain %s (%s).", name, FormatSecondsRemaining(info.expirationTime)))
    end
  end
  for name, info in pairs(TA.lastBuffSnapshot) do
    if not newSnapshot[name] then
      AddLine("status", string.format("%s fades.", name))
    end
  end
  TA.lastBuffSnapshot = newSnapshot
end

ResetSwingTimer = function()
  local mainSpeed = UnitAttackSpeed("player")
  if not mainSpeed or mainSpeed <= 0 then return end
  TA.swingReadyAt = GetTime() + mainSpeed
  TA.lastSwingState = "waiting"
  AddLine("playerCombat", "You ready your next strike.")
end


local function CheckSwingTimer()
  if not TA.swingReadyAt or TA.swingReadyAt == 0 then return end
  local remain = TA.swingReadyAt - GetTime()
  if remain <= 0 and TA.lastSwingState ~= "ready" then
    AddLine("playerCombat", "Your next strike is ready.")
    TA.lastSwingState = "ready"
  elseif remain > 0 and remain <= 0.3 and TA.lastSwingState ~= "soon" then
    AddLine("playerCombat", "Your strike is about to land again.")
    TA.lastSwingState = "soon"
  end
end

local function ReportMoney()
  local copper = GetMoney() or 0
  AddLine("status", "You have " .. FormatMoney(copper) .. ".")
end

RecordOutgoingDamage = function(amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return end
  local now = GetTime()
  if not TA.dpsSessionStart or TA.dpsSessionStart <= 0 then
    TA.dpsSessionStart = now
  end
  TA.dpsTotalDamage = (TA.dpsTotalDamage or 0) + amount
  if TA.dpsCombatStart and TA.dpsCombatStart > 0 then
    TA.dpsCombatDamage = (TA.dpsCombatDamage or 0) + amount
  end
end

local function ResetDPSStats()
  TA.dpsSessionStart = GetTime()
  TA.dpsTotalDamage = 0
  TA.dpsCombatStart = 0
  TA.dpsCombatDamage = 0
  TA.lastCombatDamage = 0
  TA.lastCombatDuration = 0
  AddLine("playerCombat", "DPS stats reset.")
end

local function ReportWeaponDPS()
  if not UnitDamage or not UnitAttackSpeed then
    AddLine("playerCombat", "Weapon DPS is unavailable on this client.")
    return
  end

  local minMain, maxMain, minOff, maxOff = UnitDamage("player")
  local mainSpeed, offSpeed = UnitAttackSpeed("player")
  if not minMain or not maxMain or not mainSpeed or mainSpeed <= 0 then
    AddLine("playerCombat", "Weapon DPS unavailable right now.")
    return
  end

  local mainAvg = (minMain + maxMain) / 2
  local mainDPS = mainAvg / mainSpeed
  local totalWeaponDPS = mainDPS
  AddLine("playerCombat", string.format("Main-hand weapon DPS: %.1f (%.0f-%.0f damage, %.2fs speed)", mainDPS, minMain, maxMain, mainSpeed))

  if minOff and maxOff and offSpeed and offSpeed > 0 and maxOff > 0 then
    local offAvg = (minOff + maxOff) / 2
    local offDPS = offAvg / offSpeed
    totalWeaponDPS = totalWeaponDPS + offDPS
    AddLine("playerCombat", string.format("Off-hand weapon DPS: %.1f (%.0f-%.0f damage, %.2fs speed)", offDPS, minOff, maxOff, offSpeed))
  end

  AddLine("playerCombat", string.format("Total weapon DPS (auto-attacks): %.1f", totalWeaponDPS))
end

local function ReportDPS()
  local now = GetTime()
  local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
  local sessionStart = TA.dpsSessionStart or 0
  local totalDamage = TA.dpsTotalDamage or 0
  local sessionDuration = sessionStart > 0 and math.max(0, now - sessionStart) or 0
  local sessionDPS = sessionDuration > 0 and (totalDamage / sessionDuration) or 0

  if inCombat and TA.dpsCombatStart and TA.dpsCombatStart > 0 then
    local combatDuration = math.max(0.001, now - TA.dpsCombatStart)
    local combatDamage = TA.dpsCombatDamage or 0
    local combatDPS = combatDamage / combatDuration
    AddLine("playerCombat", string.format("Current fight DPS: %.1f (%d damage over %.1fs)", combatDPS, math.floor(combatDamage + 0.5), combatDuration))
  elseif (TA.lastCombatDuration or 0) > 0 then
    local lastDPS = (TA.lastCombatDamage or 0) / TA.lastCombatDuration
    AddLine("playerCombat", string.format("Last fight DPS: %.1f (%d damage over %.1fs)", lastDPS, math.floor((TA.lastCombatDamage or 0) + 0.5), TA.lastCombatDuration))
  else
    AddLine("playerCombat", "No completed combat sample yet.")
  end

  AddLine("playerCombat", string.format("Session DPS: %.1f (%d damage over %.1fs)", sessionDPS, math.floor(totalDamage + 0.5), sessionDuration))
  ReportWeaponDPS()
end

local function ReportCharacterStats()
  local level = UnitLevel("player") or 0
  local className = select(2, UnitClass("player")) or "Unknown"
  local hp = UnitHealth("player") or 0
  local hpMax = UnitHealthMax("player") or 0
  local manaType = UnitPowerType("player") or 0
  local resource = UnitPower("player", manaType) or 0
  local resourceMax = UnitPowerMax("player", manaType) or 0
  local resourceLabel = _G["MANA"] or "Resource"
  if manaType == 1 then resourceLabel = _G["RAGE"] or "Rage"
  elseif manaType == 2 then resourceLabel = _G["FOCUS"] or "Focus"
  elseif manaType == 3 then resourceLabel = _G["ENERGY"] or "Energy"
  elseif manaType == 6 then resourceLabel = _G["RUNIC_POWER"] or "Runic Power"
  end

  local str = select(1, UnitStat("player", 1)) or 0
  local agi = select(1, UnitStat("player", 2)) or 0
  local sta = select(1, UnitStat("player", 3)) or 0
  local int = select(1, UnitStat("player", 4)) or 0
  local spi = select(1, UnitStat("player", 5)) or 0
  local armor = select(2, UnitArmor("player")) or 0
  local baseAP, posAP, negAP = UnitAttackPower("player")
  local totalAP = (baseAP or 0) + (posAP or 0) + (negAP or 0)
  local meleeCrit = GetCritChance and (GetCritChance() or 0) or 0
  local dodge = GetDodgeChance and (GetDodgeChance() or 0) or 0
  local parry = GetParryChance and (GetParryChance() or 0) or 0
  local block = GetBlockChance and (GetBlockChance() or 0) or 0
  local meleeHit = GetHitModifier and (GetHitModifier() or 0) or 0

  AddLine("status", string.format("Level %d %s | Health %d/%d | %s %d/%d", level, className, hp, hpMax, resourceLabel, resource, resourceMax))
  AddLine("status", string.format("Stats: STR %d | AGI %d | STA %d | INT %d | SPI %d", str, agi, sta, int, spi))
  AddLine("status", string.format("Armor: %d | Attack Power: %d", armor, totalAP))
  AddLine("status", string.format("Combat: Crit %.2f%% | Hit %.2f%% | Dodge %.2f%% | Parry %.2f%% | Block %.2f%%", meleeCrit, meleeHit, dodge, parry, block))
end

local EQUIP_SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist",
  [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger 1",
  [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
  [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged"
}

local function ReportEquipmentChange(slotId)
  local label = EQUIP_SLOT_NAMES[slotId] or ("Slot " .. tostring(slotId))
  local link = GetInventoryItemLink("player", slotId)
  if link then
    AddLine("loot", string.format("You equip %s in %s.", link, label))
  else
    AddLine("loot", string.format("%s is now empty.", label))
  end
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

local function ReportMacros()
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

local function ShowMacroInfo(index)
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

local function CastMacroByIndex(index)
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

local function CastMacroByName(macroName)
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

local function ParseNameAndBodyArgs(args)
  if not args or args == "" then return nil, nil end
  local quotedName, quotedBody = args:match('^"([^"]+)"%s+(.+)$')
  if quotedName and quotedBody then
    return quotedName, quotedBody
  end
  local name, body = args:match("^(%S+)%s+(.+)$")
  return name, body
end

local function ParseRenameArgs(args)
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

local function CreateNewMacro(name, body)
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

local function SetMacroBody(index, newBody)
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

local function RenameMacro(index, newName)
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

local function DeleteMacroByIndex(index)
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

local function ReportSpellbook()
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

local function BindSpellbookSpellToActionSlot(actionSlot, spellbookIndex)
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

local function BindMacroToActionSlot(actionSlot, macroIndex)
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

local function ReportVendorItems()
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  local num = GetMerchantNumItems() or 0
  if num <= 0 then
    AddLine("loot", "The merchant has nothing for sale right now.")
    return
  end
  for i = 1, num do
    local name, texture, price, quantity, numAvail, isUsable, extendedCost = GetMerchantItemInfo(i)
    if name then
      local priceText = price and price > 0 and FormatMoney(price) or "free"
      local stockText = (numAvail and numAvail >= 0) and string.format(", %d in stock", numAvail) or ""
      local qtyText   = (quantity and quantity > 1) and string.format(" (x%d)", quantity) or ""
      AddLine("loot", string.format("[%d] %s%s - %s%s", i, name, qtyText, priceText, stockText))
    end
  end
end

function TA_ReportVendorBuybackItems()
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not GetNumBuybackItems or not GetBuybackItemInfo then
    AddLine("system", "Buyback API unavailable.")
    return
  end

  local num = GetNumBuybackItems() or 0
  if num <= 0 then
    AddLine("loot", "Buyback list is empty.")
    return
  end

  AddLine("loot", string.format("Buyback items (%d):", num))
  for i = 1, num do
    local name, _, price, quantity = GetBuybackItemInfo(i)
    if name then
      local qtyText = (quantity and quantity > 1) and string.format(" (x%d)", quantity) or ""
      local priceText = (price and price > 0) and FormatMoney(price) or "free"
      AddLine("loot", string.format("[%d] %s%s - %s", i, name, qtyText, priceText))
    end
  end
end

function TA_BuybackVendorItem(index)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not GetNumBuybackItems or not GetBuybackItemInfo or not BuybackItem then
    AddLine("system", "Buyback API unavailable.")
    return
  end

  local num = GetNumBuybackItems() or 0
  if not index or index < 1 or index > num then
    AddLine("system", string.format("Invalid buyback index. Buyback list has %d item(s).", num))
    return
  end

  local name, _, price = GetBuybackItemInfo(index)
  if not name then
    AddLine("system", "Could not read that buyback item.")
    return
  end

  local money = GetMoney and (GetMoney() or 0) or 0
  local cost = tonumber(price) or 0
  if cost > money then
    AddLine("system", string.format("You cannot afford to buy back %s (cost %s, have %s).", name, FormatMoney(cost), FormatMoney(money)))
    return
  end

  BuybackItem(index)
  AddLine("loot", string.format("Attempted buyback: [%d] %s for %s.", index, name, FormatMoney(cost)))
end

function TA_ReportWhoList()
  local getNumWho = GetNumWhoResults or (C_FriendList and C_FriendList.GetNumWhoResults)
  local getWhoInfo = GetWhoInfo or (C_FriendList and C_FriendList.GetWhoInfo)
  if not getNumWho or not getWhoInfo then
    AddLine("system", "Who API unavailable.")
    return
  end

  local count = getNumWho() or 0
  if count <= 0 then
    AddLine("social", "No /who results to display.")
    return
  end

  local queryLabel = TA.pendingWhoQuery and (" for '" .. TA.pendingWhoQuery .. "'") or ""
  AddLine("social", string.format("/who results%s (%d):", queryLabel, count))
  local maxShown = math.min(count, 50)
  for i = 1, maxShown do
    local result1, result2, result3, result4, result5, result6 = getWhoInfo(i)
    local name, guild, level, race, className, zone
    
    -- Handle table-based API (new C_FriendList) vs multi-value return (legacy GetWhoInfo)
    if type(result1) == "table" then
      name = result1.fullName
      guild = result1.fullGuildName
      level = result1.level
      race = result1.raceStr
      className = result1.classStr
      zone = result1.area
    else
      name = result1
      guild = result2
      level = result3
      race = result4
      className = result5
      zone = result6
    end
    
    if name then
      local guildText = (guild and guild ~= "") and (" <" .. guild .. ">") or ""
      local levelText = level and tostring(level) or "?"
      local classText = className or "Unknown"
      local zoneText = zone or "Unknown zone"
      AddLine("social", string.format("[%d] %s%s - %s %s in %s", i, name, guildText, levelText, classText, zoneText))
    end
  end
  if count > maxShown then
    AddLine("social", string.format("(Showing first %d of %d results)", maxShown, count))
  end
end

function TA_RunWhoQuery(query)
  local q = (query or ""):match("^%s*(.-)%s*$")
  local sendWho = SendWho or (C_FriendList and C_FriendList.SendWho)
  if not sendWho then
    AddLine("system", "Who API unavailable.")
    return
  end
  if q == "" then
    TA_ReportWhoList()
    return
  end

  TA.pendingWhoQuery = q
  sendWho(q)
  AddLine("social", string.format("Querying /who: %s", q))
end

function TA_RepairVendorGear(useGuild)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not CanMerchantRepair or not RepairAllItems or not GetRepairAllCost then
    AddLine("system", "Repair API unavailable.")
    return
  end
  if not CanMerchantRepair() then
    AddLine("system", "This merchant cannot repair gear.")
    return
  end

  local cost, canRepairNow = GetRepairAllCost()
  cost = tonumber(cost) or 0
  if cost <= 0 then
    AddLine("loot", "Your gear does not need repairs.")
    return
  end
  if not canRepairNow then
    AddLine("system", string.format("You cannot afford repairs (%s needed).", FormatMoney(cost)))
    return
  end

  local usedGuild = false
  if useGuild and CanGuildBankRepair and CanGuildBankRepair() then
    RepairAllItems(true)
    usedGuild = true
  else
    RepairAllItems()
  end

  if usedGuild then
    AddLine("loot", string.format("Attempted repairs using guild funds (up to %s).", FormatMoney(cost)))
  else
    if useGuild then
      AddLine("system", "Guild bank repair unavailable; using personal funds.")
    end
    AddLine("loot", string.format("Attempted repairs for %s.", FormatMoney(cost)))
  end
end

function TA_ReportRepairStatus()
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not CanMerchantRepair or not GetRepairAllCost then
    AddLine("system", "Repair API unavailable.")
    return
  end
  if not CanMerchantRepair() then
    AddLine("system", "This merchant cannot repair gear.")
    return
  end

  local cost, canRepairNow = GetRepairAllCost()
  cost = tonumber(cost) or 0
  if cost <= 0 then
    AddLine("loot", "Your gear does not need repairs.")
    return
  end

  local money = GetMoney and (GetMoney() or 0) or 0
  AddLine("loot", string.format("Repair cost: %s | You have: %s", FormatMoney(cost), FormatMoney(money)))
  if canRepairNow then
    AddLine("status", "You can afford repairs.")
  else
    AddLine("system", string.format("You cannot afford repairs yet (need %s more).", FormatMoney(cost - money)))
  end
  if CanGuildBankRepair and CanGuildBankRepair() then
    AddLine("status", "Guild bank repair is available here (use: repair guild).")
  end
end

function TA_SellJunk()
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Container.UseContainerItem) then
    AddLine("system", "Container API unavailable.")
    return
  end

  local soldStacks = 0
  local soldUnits = 0
  local totalValue = 0
  local maxBag = tonumber(NUM_BAG_SLOTS) or 4

  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        local quality = info.quality
        local itemRef = info.hyperlink or info.itemID
        local stackCount = tonumber(info.stackCount) or 1
        local _, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemRef)
        if quality == nil then
          quality = itemQuality
        end
        if quality == 0 then
          local value = (tonumber(sellPrice) or 0) * stackCount
          C_Container.UseContainerItem(bag, slot)
          soldStacks = soldStacks + 1
          soldUnits = soldUnits + stackCount
          totalValue = totalValue + value
        end
      end
    end
  end

  if soldStacks == 0 then
    AddLine("loot", "No junk-quality items found to sell.")
  else
    AddLine("loot", string.format("Sold junk: %d stack(s), %d item(s), estimated value %s.", soldStacks, soldUnits, FormatMoney(totalValue)))
  end
end

function TA_RestockVendorItem(itemQuery, desiredCount)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not itemQuery or itemQuery == "" or not desiredCount then
    AddLine("system", "Usage: restock <item name> <count>")
    return
  end
  if not GetMerchantNumItems or not GetMerchantItemInfo or not BuyMerchantItem then
    AddLine("system", "Merchant API unavailable.")
    return
  end

  desiredCount = math.max(1, math.floor(tonumber(desiredCount) or 0))
  local queryLower = itemQuery:lower()
  local num = GetMerchantNumItems() or 0
  if num <= 0 then
    AddLine("system", "Merchant has no items to restock.")
    return
  end

  local merchantIndex = nil
  local merchantName = nil
  local partialIndex = nil
  local partialName = nil
  for i = 1, num do
    local name = GetMerchantItemInfo(i)
    if name then
      local lowerName = name:lower()
      if lowerName == queryLower then
        merchantIndex = i
        merchantName = name
        break
      end
      if not partialIndex and lowerName:find(queryLower, 1, true) then
        partialIndex = i
        partialName = name
      end
    end
  end
  if not merchantIndex and partialIndex then
    merchantIndex = partialIndex
    merchantName = partialName
  end
  if not merchantIndex or not merchantName then
    AddLine("system", string.format("No vendor item matched '%s'.", itemQuery))
    return
  end

  local haveCount = 0
  if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
    local maxBag = tonumber(NUM_BAG_SLOTS) or 4
    local merchantNameLower = merchantName:lower()
    for bag = 0, maxBag do
      local numSlots = C_Container.GetContainerNumSlots(bag) or 0
      for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
          local bagItemName = info.itemName
          if not bagItemName then
            bagItemName = GetItemInfo(info.hyperlink or info.itemID)
          end
          if bagItemName and bagItemName:lower() == merchantNameLower then
            haveCount = haveCount + (tonumber(info.stackCount) or 1)
          end
        end
      end
    end
  end

  local needed = desiredCount - haveCount
  if needed <= 0 then
    AddLine("loot", string.format("Already stocked: %s x%d (target %d).", merchantName, haveCount, desiredCount))
    return
  end

  local _, _, price, stackSize, numAvail = GetMerchantItemInfo(merchantIndex)
  local unitsPerBuy = math.max(1, tonumber(stackSize) or 1)
  if numAvail and numAvail >= 0 and numAvail <= 0 then
    AddLine("system", string.format("%s is out of stock.", merchantName))
    return
  end

  local plannedUnits = needed
  if numAvail and numAvail >= 0 and plannedUnits > numAvail then
    plannedUnits = numAvail
  end
  local purchases = math.max(1, math.ceil(plannedUnits / unitsPerBuy))

  local unitCost = tonumber(price) or 0
  if unitCost > 0 then
    local money = GetMoney() or 0
    local totalCost = unitCost * purchases
    if money < totalCost then
      purchases = math.floor(money / unitCost)
      if purchases < 1 then
        AddLine("system", string.format("Not enough money to restock %s.", merchantName))
        return
      end
      totalCost = unitCost * purchases
      AddLine("system", string.format("Partial restock due to funds: buying %d purchase(s) for %s.", purchases, FormatMoney(totalCost)))
    end
  end

  BuyMerchantItem(merchantIndex, purchases)
  local approxUnits = purchases * unitsPerBuy
  AddLine("loot", string.format("Restock: bought %d purchase(s) of %s (about %d item(s)).", purchases, merchantName, approxUnits))
end

function TA_ReportVendorItemDetails(index)
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  local num = GetMerchantNumItems() or 0
  if index < 1 or index > num then
    AddLine("system", string.format("Invalid item index. Merchant has %d items.", num))
    return
  end

  local name, _, price, quantity, numAvail = GetMerchantItemInfo(index)
  if not name then
    AddLine("system", "Could not read that merchant item.")
    return
  end

  local priceText = price and price > 0 and FormatMoney(price) or "free"
  local stockText = (numAvail and numAvail >= 0) and string.format("%d in stock", numAvail) or "unlimited stock"
  local stackText = (quantity and quantity > 1) and string.format("sells in stacks of %d", quantity) or "single item"
  AddLine("loot", string.format("[%d] %s - %s (%s, %s)", index, name, priceText, stackText, stockText))

  local link = GetMerchantItemLink and GetMerchantItemLink(index)
  if link and GetItemInfo then
    local _, _, quality, itemLevel, reqLevel, className, subClassName, _, equipLoc, _, sellPrice = GetItemInfo(link)
    if quality ~= nil then
      AddLine("loot", string.format("Quality: %d", quality))
    end
    if itemLevel and itemLevel > 0 then
      AddLine("loot", string.format("Item level: %d", itemLevel))
    end
    if reqLevel and reqLevel > 0 then
      AddLine("loot", string.format("Requires level: %d", reqLevel))
    end
    if className or subClassName then
      AddLine("loot", string.format("Type: %s%s", className or "unknown", subClassName and (" - " .. subClassName) or ""))
    end
    if equipLoc and equipLoc ~= "" then
      AddLine("loot", string.format("Equip slot: %s", equipLoc))
    end
    if sellPrice and sellPrice > 0 then
      AddLine("loot", string.format("Vendor sell value: %s", FormatMoney(sellPrice)))
    end
  end

  if not CreateFrame or not UIParent then
    return
  end
  if not TA.vendorInspectTooltip then
    TA.vendorInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerVendorInspectTooltip", UIParent, "GameTooltipTemplate")
  end
  local tip = TA.vendorInspectTooltip
  if not tip or not tip.SetMerchantItem or not tip.NumLines or not tip.GetName then
    return
  end

  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetMerchantItem(index)

  local tipName = tip:GetName()
  local shown = 0
  local maxLines = 14
  for i = 2, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local leftText = left and left:GetText() or ""
    local rightText = right and right:GetText() or ""
    if leftText ~= "" or rightText ~= "" then
      local lineText = leftText
      if rightText ~= "" then
        if lineText ~= "" then
          lineText = lineText .. "  " .. rightText
        else
          lineText = rightText
        end
      end
      AddLine("loot", lineText)
      shown = shown + 1
      if shown >= maxLines then
        AddLine("loot", "(Additional item details truncated.)")
        break
      end
    end
  end
  tip:Hide()
end

local function BuyVendorItem(index, quantity)
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  local num = GetMerchantNumItems() or 0
  if index < 1 or index > num then
    AddLine("system", string.format("Invalid item index. Merchant has %d items.", num))
    return
  end
  local name, _, price, stackSize = GetMerchantItemInfo(index)
  if not name then
    AddLine("system", "Could not read that merchant item.")
    return
  end
  quantity = quantity or 1
  local copper = GetMoney() or 0
  local totalCost = price * quantity
  if copper < totalCost then
    AddLine("system", string.format("You cannot afford %dx %s. Need %s, have %s.", quantity, name, FormatMoney(totalCost), FormatMoney(copper)))
    return
  end
  BuyMerchantItem(index, quantity)
  AddLine("loot", string.format("You purchase %dx %s for %s.", quantity, name, FormatMoney(totalCost)))
end

function TA_CheckVendorPurchase(index, quantity)
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end

  local num = GetMerchantNumItems() or 0
  if index < 1 or index > num then
    AddLine("system", string.format("Invalid item index. Merchant has %d items.", num))
    return
  end

  local name, _, price, stackSize, numAvail = GetMerchantItemInfo(index)
  if not name then
    AddLine("system", "Could not read that merchant item.")
    return
  end

  quantity = quantity or 1
  quantity = math.max(1, math.floor(quantity))
  local totalCost = (price or 0) * quantity
  local copper = GetMoney() or 0
  local remaining = copper - totalCost

  local stockText = (numAvail and numAvail >= 0) and tostring(numAvail) or "unlimited"
  local perPurchaseText = (stackSize and stackSize > 1) and string.format("%d per buy", stackSize) or "1 per buy"
  AddLine("loot", string.format("Buy check [%d] %s x%d (%s, stock %s):", index, name, quantity, perPurchaseText, stockText))
  AddLine("loot", string.format("Cost: %s | You have: %s", FormatMoney(totalCost), FormatMoney(copper)))

  if remaining >= 0 then
    AddLine("status", string.format("Affordable. You would have %s left.", FormatMoney(remaining)))
  else
    AddLine("system", string.format("Not affordable. You need %s more.", FormatMoney(-remaining)))
  end
end

local function SellCurrentTarget()
  -- Sells the item currently moused-over or last opened via merchant; WoW Classic
  -- exposes this via merchant sell slot — we instead sell by item link from bags.
  AddLine("system", "To sell an item, use /ta sell <bag> <slot>. Example: /ta sell 0 3")
end

function TA_EquipBagItem(bag, slot)
  local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  if not (C_Container and C_Container.UseContainerItem) then
    AddLine("system", "Container use API unavailable on this client.")
    return
  end

  C_Container.UseContainerItem(bag, slot)
  AddLine("loot", string.format("Attempting to equip %s from %s slot %d.", info.hyperlink or info.itemID or "item", BagLabel(bag), slot))
end

function TA_EquipItemByQuery(query)
  local itemName = (query or ""):match("^%s*(.-)%s*$")
  if itemName == "" then
    AddLine("system", "Usage: equip <item name> or equip <bag> <slot>")
    return
  end

  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Container.UseContainerItem) then
    AddLine("system", "Container API unavailable on this client.")
    return
  end

  local queryLower = itemName:lower()
  local exactBag, exactSlot = nil, nil
  local partialBag, partialSlot = nil, nil
  local maxBag = tonumber(NUM_BAG_SLOTS) or 4

  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        local bagItemName = info.itemName
        if not bagItemName and GetItemInfo then
          bagItemName = GetItemInfo(info.hyperlink or info.itemID)
        end

        if bagItemName then
          local bagItemLower = bagItemName:lower()
          if bagItemLower == queryLower then
            exactBag, exactSlot = bag, slot
            break
          end
          if not partialBag and bagItemLower:find(queryLower, 1, true) then
            partialBag, partialSlot = bag, slot
          end
        end
      end
    end
    if exactBag then break end
  end

  if exactBag then
    TA_EquipBagItem(exactBag, exactSlot)
    return
  end
  if partialBag then
    TA_EquipBagItem(partialBag, partialSlot)
    return
  end

  AddLine("system", string.format("No bag item matched '%s'.", itemName))
end

local function SellBagItem(bag, slot)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end
  C_Container.UseContainerItem(bag, slot)
  AddLine("loot", string.format("You sell %s from %s slot %d.", info.hyperlink or info.itemID or "item", BagLabel(bag), slot))
end

local function DestroyBagItem(bag, slot)
  local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  local quality = info.quality
  if quality == nil and GetItemInfo then
    local _, _, itemQuality = GetItemInfo(info.hyperlink or info.itemID)
    quality = itemQuality
  end
  if quality == nil then
    AddLine("system", "Could not determine item quality yet. Try again in a moment.")
    return
  end
  if quality > 1 then
    AddLine("system", string.format("Refusing to destroy %s. Only gray or white items can be destroyed.", info.hyperlink or info.itemID or "item"))
    return
  end

  if not DeleteCursorItem then
    AddLine("system", "Item destruction API unavailable.")
    return
  end

  ClearCursor()
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  elseif PickupContainerItem then
    PickupContainerItem(bag, slot)
  else
    AddLine("system", "Container pickup API unavailable.")
    return
  end

  local cursorType = GetCursorInfo()
  if cursorType ~= "item" then
    ClearCursor()
    AddLine("system", "Could not pick up that item to destroy it.")
    return
  end

  DeleteCursorItem()
  ClearCursor()
  AddLine("loot", string.format("Destroyed %s from %s slot %d.", info.hyperlink or info.itemID or "item", BagLabel(bag), slot))
end

function TA_ReportOpenItemText(force)
  if not ItemTextGetItem or not ItemTextGetText then
    AddLine("system", "Item text API unavailable.")
    return
  end

  local title = ItemTextGetItem() or "Unreadable item"
  local text = ItemTextGetText()
  if not text or text == "" then
    AddLine("system", string.format("%s has no readable text.", title))
    return
  end

  local signature = title .. "\n" .. text
  if not force and signature == TA.lastItemTextSignature then
    return
  end
  TA.lastItemTextSignature = signature

  AddLine("quest", string.format("Reading: %s", title))
  local shown = 0
  for line in text:gmatch("[^\r\n]+") do
    local cleaned = line:gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned ~= "" then
      AddLine("quest", cleaned)
      shown = shown + 1
      if shown >= 60 then
        AddLine("quest", "(Text truncated at 60 lines.)")
        break
      end
    end
  end
  if shown == 0 then
    AddLine("quest", "(No readable text.)")
  end
end

function TA_ReadBagItemText(bag, slot)
  if bag == nil or slot == nil then
    AddLine("system", "Usage: readitem <bag> <slot>")
    return
  end

  local info
  if C_Container and C_Container.GetContainerItemInfo then
    info = C_Container.GetContainerItemInfo(bag, slot)
  end
  if not info then
    AddLine("system", string.format("No item found in bag %d slot %d.", bag, slot))
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "You cannot use readable items while in combat lockdown.")
    return
  end

  if C_Container and C_Container.UseContainerItem then
    TA.pendingItemTextRead = { bag = bag, slot = slot, item = info.hyperlink or tostring(info.itemID or "item") }
    TA.lastItemTextSignature = nil
    C_Container.UseContainerItem(bag, slot)
    AddLine("system", string.format("Attempting to read item from bag %d slot %d.", bag, slot))
  elseif UseContainerItem then
    TA.pendingItemTextRead = { bag = bag, slot = slot, item = info.hyperlink or tostring(info.itemID or "item") }
    TA.lastItemTextSignature = nil
    UseContainerItem(bag, slot)
    AddLine("system", string.format("Attempting to read item from bag %d slot %d.", bag, slot))
  else
    AddLine("system", "Item use API unavailable.")
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

local function ReportRange()
  if not UnitExists("target") then
    AddLine("system", "You have no target.")
    return
  end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then
    AddLine("system", "Map position unavailable.")
    return
  end
  local px, py, tx, ty
  if C_Map and C_Map.GetPlayerMapPosition then
    local playerPos = C_Map.GetPlayerMapPosition(mapID, "player")
    local targetPos = C_Map.GetPlayerMapPosition(mapID, "target")
    if playerPos and targetPos then
      px, py = playerPos:GetXY()
      tx, ty = targetPos:GetXY()
    end
  elseif GetPlayerMapPosition then
    px, py = GetPlayerMapPosition("player")
    tx, ty = GetPlayerMapPosition("target")
  end
  if not px or not py or not tx or not ty then
    AddLine("system", "Could not read positions for range calculation.")
    return
  end
  if px == 0 and py == 0 and tx == 0 and ty == 0 then
    AddLine("system", "Position data incomplete.")
    return
  end
  -- Map coordinates are 0-1 fractions of the map tile.
  -- Multiply by the map's reported dimensions to get yards.
  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local mapWidth  = mapInfo and mapInfo.width  or 0
  local mapHeight = mapInfo and mapInfo.height or 0
  local yardDist
  if mapWidth > 0 and mapHeight > 0 then
    local dx = (tx - px) * mapWidth
    local dy = (ty - py) * mapHeight
    yardDist = math.sqrt(dx * dx + dy * dy)
  else
    -- Fallback: use raw coordinate distance with a rough scale
    local dx = tx - px
    local dy = ty - py
    yardDist = math.sqrt(dx * dx + dy * dy) * 100
  end
  if not yardDist then
    AddLine("system", "Could not determine range right now.")
    return
  end
  local name = UnitName("target") or "target"
  local rangeDesc
  if yardDist < 5 then
    rangeDesc = "right next to you"
  elseif yardDist < 10 then
    rangeDesc = "very close"
  elseif yardDist < 20 then
    rangeDesc = "within melee reach"
  elseif yardDist < 35 then
    rangeDesc = "at short range"
  elseif yardDist < 60 then
    rangeDesc = "at medium range"
  else
    rangeDesc = "far away"
  end
  AddLine("target", string.format("%s is approximately %.0f yards away (%s).", name, yardDist, rangeDesc))
end

local function GetExplorationData(mapID)
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}
  if not TextAdventurerDB.exploration[mapID] then
    TextAdventurerDB.exploration[mapID] = { visited = {}, visits = {}, minX = nil, maxX = nil, minY = nil, maxY = nil }
  end
  return TextAdventurerDB.exploration[mapID]
end

local function UpdateExplorationMemory()
  local mapID, cellX, cellY, x, y, continentX, continentY, continentID = GetPlayerMapCell()
  if not mapID then return end
  continentX = continentX or 0
  continentY = continentY or 0
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
  
  -- Check whether we're in a marked cell using mapID + cell coordinates.
  local foundMark = nil
  for _, mark in pairs(TA.markedCells) do
    if mark.mapID == mapID and mark.cellX ~= nil and mark.cellY ~= nil then
      local markGridX = ClampGridSize(tonumber(mark.gridX) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
      local markGridY = ClampGridSize(tonumber(mark.gridY) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
      local markOffsetX = NormalizePeriodicOffset(mark.anchorOffsetX, 1 / markGridX)
      local markOffsetY = NormalizePeriodicOffset(mark.anchorOffsetY, 1 / markGridY)
      local currentCellX, currentCellY = ComputeCellForPosition(x, y, markGridX, markGridY, markOffsetX, markOffsetY)
      if currentCellX == mark.cellX and currentCellY == mark.cellY then
        foundMark = mark
        break
      end
    end
  end
  
  local previousMarkID = TA.lastMarkedCellNotification
  if foundMark then
    if previousMarkID ~= foundMark.id then
      local previousMark = GetMarkedCellByID(previousMarkID)
      if previousMark then
        AddLine("place", string.format("You leave marked cell: %s", previousMark.name or "Unnamed"))
      end
      AddLine("place", string.format("You are in marked cell: %s", foundMark.name))
      TA.lastMarkedCellNotification = foundMark.id
    end
  else
    if previousMarkID then
      local previousMark = GetMarkedCellByID(previousMarkID)
      if previousMark then
        AddLine("place", string.format("You leave marked cell: %s", previousMark.name or "Unnamed"))
      else
        AddLine("place", "You leave a marked cell.")
      end
    end
    TA.lastMarkedCellNotification = nil
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
  TA_RouteOnCellChanged(mapID, cellX, cellY)
end

function TA_RouteDirection(dx, dy)
  if dx == 0 and dy == 0 then return "here" end
  local horiz = ""
  local vert = ""
  if dy > 0 then vert = "north" elseif dy < 0 then vert = "south" end
  if dx > 0 then horiz = "east" elseif dx < 0 then horiz = "west" end
  if vert ~= "" and horiz ~= "" then
    return vert .. "-" .. horiz
  end
  return vert ~= "" and vert or horiz
end

function TA_RouteGetTable()
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.routes = TextAdventurerDB.routes or {}
  return TextAdventurerDB.routes
end

function TA_RouteStart(name)
  local routeName = (name or ""):match("^%s*(.-)%s*$")
  if routeName == "" then
    AddLine("system", "Usage: route start <name>")
    return
  end
  local mapID, cellX, cellY = GetPlayerMapCell()
  if not mapID then
    AddLine("system", "Could not determine current cell for route recording.")
    return
  end
  local routeKey = routeName:lower()
  local routes = TA_RouteGetTable()
  routes[routeKey] = {
    name = routeName,
    mapID = mapID,
    cells = { CellKey(cellX, cellY) },
    createdAt = time(),
  }
  TA.routeRecordingName = routeKey
  TA.routeFollowName = nil
  TA.routeFollowIndex = nil
  TA.routeLastGuidedCell = nil
  AddLine("place", string.format("Route recording started: %s", routeName))
end

function TA_RouteStop()
  if not TA.routeRecordingName then
    AddLine("system", "No active route recording.")
    return
  end
  local routes = TA_RouteGetTable()
  local route = routes[TA.routeRecordingName]
  local name = (route and route.name) or TA.routeRecordingName
  local steps = route and route.cells and #route.cells or 0
  TA.routeRecordingName = nil
  AddLine("place", string.format("Route recording stopped: %s (%d cell(s)).", name, steps))
end

function TA_RouteList()
  local routes = TA_RouteGetTable()
  local count = 0
  for _ in pairs(routes) do count = count + 1 end
  if count == 0 then
    AddLine("system", "No saved routes yet.")
    return
  end
  AddLine("place", string.format("Saved routes (%d):", count))
  for key, route in pairs(routes) do
    local tag = ""
    if TA.routeRecordingName == key then tag = " [recording]" end
    if TA.routeFollowName == key then tag = tag .. " [following]" end
    AddLine("place", string.format("  %s - %d cells%s", route.name or key, route.cells and #route.cells or 0, tag))
  end
end

function TA_RouteShow(name)
  local routeKey = (name or ""):match("^%s*(.-)%s*$"):lower()
  if routeKey == "" then
    AddLine("system", "Usage: route show <name>")
    return
  end
  local routes = TA_RouteGetTable()
  local route = routes[routeKey]
  if not route then
    AddLine("system", string.format("No route named '%s'.", name or ""))
    return
  end
  local total = route.cells and #route.cells or 0
  AddLine("place", string.format("Route %s: %d cell(s).", route.name or routeKey, total))
  if total <= 1 then
    AddLine("place", "  Route has only a start point.")
    return
  end
  local shown = 0
  local maxShown = 10
  for i = 1, total - 1 do
    local x1, y1 = route.cells[i]:match("^(-?%d+),(-?%d+)$")
    local x2, y2 = route.cells[i + 1]:match("^(-?%d+),(-?%d+)$")
    if x1 and y1 and x2 and y2 then
      local dir = TA_RouteDirection(tonumber(x2) - tonumber(x1), tonumber(y2) - tonumber(y1))
      AddLine("place", string.format("  %d -> %d: %s", i, i + 1, dir))
      shown = shown + 1
      if shown >= maxShown then
        AddLine("place", string.format("  ... (%d more segment(s))", (total - 1) - shown))
        break
      end
    end
  end
end

function TA_RouteClear(name)
  local routeKey = (name or ""):match("^%s*(.-)%s*$"):lower()
  if routeKey == "" then
    AddLine("system", "Usage: route clear <name>")
    return
  end
  local routes = TA_RouteGetTable()
  if not routes[routeKey] then
    AddLine("system", string.format("No route named '%s'.", name or ""))
    return
  end
  local routeName = routes[routeKey].name or routeKey
  routes[routeKey] = nil
  if TA.routeRecordingName == routeKey then
    TA.routeRecordingName = nil
  end
  if TA.routeFollowName == routeKey then
    TA.routeFollowName = nil
    TA.routeFollowIndex = nil
    TA.routeLastGuidedCell = nil
  end
  AddLine("place", string.format("Route cleared: %s", routeName))
end

function TA_RouteFollow(name)
  local routeKey = (name or ""):match("^%s*(.-)%s*$"):lower()
  if routeKey == "" then
    AddLine("system", "Usage: route follow <name>")
    return
  end
  local routes = TA_RouteGetTable()
  local route = routes[routeKey]
  if not route then
    AddLine("system", string.format("No route named '%s'.", name or ""))
    return
  end
  TA.routeFollowName = routeKey
  TA.routeFollowIndex = 1
  TA.routeLastGuidedCell = nil
  AddLine("place", string.format("Now following route: %s", route.name or routeKey))
end

function TA_RouteFollowOff()
  if not TA.routeFollowName then
    AddLine("system", "No route is currently being followed.")
    return
  end
  local routeKey = TA.routeFollowName
  local route = TA_RouteGetTable()[routeKey]
  TA.routeFollowName = nil
  TA.routeFollowIndex = nil
  TA.routeLastGuidedCell = nil
  AddLine("place", string.format("Stopped following route: %s", (route and route.name) or routeKey))
end

function TA_RouteOnCellChanged(mapID, cellX, cellY)
  local routes = TA_RouteGetTable()
  local currentCell = CellKey(cellX, cellY)

  if TA.routeRecordingName then
    local route = routes[TA.routeRecordingName]
    if route and route.mapID == mapID and route.cells then
      local last = route.cells[#route.cells]
      if last ~= currentCell then
        table.insert(route.cells, currentCell)
      end
    end
  end

  if not TA.routeFollowName then
    return
  end

  local route = routes[TA.routeFollowName]
  if not route or not route.cells or #route.cells == 0 then
    TA.routeFollowName = nil
    TA.routeFollowIndex = nil
    TA.routeLastGuidedCell = nil
    return
  end
  if route.mapID and route.mapID ~= mapID then
    if TA.routeLastGuidedCell ~= "map-mismatch" then
      AddLine("system", "Route follow paused: you are on a different map.")
      TA.routeLastGuidedCell = "map-mismatch"
    end
    return
  end

  if TA.routeLastGuidedCell == currentCell then
    return
  end
  TA.routeLastGuidedCell = currentCell

  local total = #route.cells
  local idx = nil
  for i = 1, total do
    if route.cells[i] == currentCell then
      idx = i
      break
    end
  end

  if idx then
    TA.routeFollowIndex = idx
    if idx >= total then
      AddLine("place", string.format("Route %s complete.", route.name or TA.routeFollowName))
      TA.routeFollowName = nil
      TA.routeFollowIndex = nil
      return
    end
    local nx, ny = route.cells[idx + 1]:match("^(-?%d+),(-?%d+)$")
    if nx and ny then
      local dir = TA_RouteDirection(tonumber(nx) - cellX, tonumber(ny) - cellY)
      AddLine("place", string.format("Route %s [%d/%d]: go %s.", route.name or TA.routeFollowName, idx, total, dir))
    end
    return
  end

  local bestI, bestDist = nil, nil
  for i = 1, total do
    local rx, ry = route.cells[i]:match("^(-?%d+),(-?%d+)$")
    if rx and ry then
      local dist = math.abs(tonumber(rx) - cellX) + math.abs(tonumber(ry) - cellY)
      if not bestDist or dist < bestDist then
        bestDist = dist
        bestI = i
      end
    end
  end
  if bestI and bestDist ~= nil then
    AddLine("place", string.format("Off route '%s'. Nearest step: %d (about %d cell(s) away).", route.name or TA.routeFollowName, bestI, bestDist))
  end
end

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

local function GetNearbyUnitsWithPositions()
  local units = { hostile = {}, neutral = {}, friendly = {} }
  local nameplates = C_NamePlate.GetNamePlates()
  if not nameplates then return units end
  local playerX, playerY = UnitPosition("player")
  
  for _, frame in ipairs(nameplates) do
    local unit = frame.namePlateUnitToken
    if unit and UnitExists(unit) then
      local name = UnitName(unit)
      if name then
        local reaction = UnitReaction(unit, "player") or 4
        local canAttack = UnitCanAttack("player", unit)
        local unitType = "neutral"
        
        if canAttack then
          unitType = "hostile"
        elseif reaction >= 5 then
          unitType = "friendly"
        end
        
        -- Get distance estimate from UnitDistance or calculate from coordinates
        local distance = 0
        local unitX, unitY = UnitPosition(unit)
        if CheckInteractDistance then
          -- Try to get approximate distance
          for i = 1, 4 do
            if CheckInteractDistance(unit, i) then
              distance = i * 5
              break
            end
          end
        end
        
        -- Fallback to trying position calculation
        if distance == 0 then
          if unitX and unitY and playerX and playerY then
            local dx = unitX - playerX
            local dy = unitY - playerY
            distance = math.sqrt(dx*dx + dy*dy)
          else
            distance = 50  -- assume far if we can't get position
          end
        end
        
        table.insert(units[unitType], {
          name = name,
          distance = distance,
          level = UnitLevel(unit),
          class = UnitClass(unit),
          health = UnitHealth(unit),
          maxHealth = UnitHealthMax(unit),
          unit = unit,
          guid = UnitGUID(unit),
          worldX = unitX,
          worldY = unitY,
          hasExactPos = unitX and unitY and playerX and playerY,
        })
      end
    end
  end
  
  return units
end

local function TA_ClearDFSonar()
  TA.dfModeSonarContacts = {}
end

local function TA_RecordDFSonarContacts(units, mapID)
  if not units or not mapID then return end
  local now = GetTime()
  local ttl = tonumber(TA.dfModeSonarTTL) or 8
  local contactTable = TA.dfModeSonarContacts or {}
  local function ingest(kind, list)
    for _, u in ipairs(list or {}) do
      if u and u.hasExactPos and u.worldX and u.worldY then
        local key = u.guid or (kind .. ":" .. (u.name or "unknown"))
        local existing = contactTable[key] or {}
        existing.name = u.name or existing.name or "Unknown"
        existing.kind = kind
        existing.mapID = mapID
        existing.worldX = u.worldX
        existing.worldY = u.worldY
        existing.seenAt = now
        existing.expiresAt = now + ttl
        contactTable[key] = existing
      end
    end
  end
  ingest("hostile", units.hostile)
  ingest("neutral", units.neutral)
  ingest("friendly", units.friendly)
  TA.dfModeSonarContacts = contactTable
end

local function TA_PruneDFSonarContacts(mapID)
  local now = GetTime()
  local count = 0
  for key, c in pairs(TA.dfModeSonarContacts or {}) do
    if type(c) ~= "table" or c.expiresAt == nil or c.expiresAt <= now or (mapID and c.mapID and c.mapID ~= mapID) then
      TA.dfModeSonarContacts[key] = nil
    else
      count = count + 1
    end
  end
  return count
end

local function TA_TriggerDFSonarPing(seconds)
  local duration = tonumber(seconds) or 4
  if duration < 1 then duration = 1 end
  if duration > 20 then duration = 20 end
  TA.dfModeSonarPulseUntil = GetTime() + duration
  if TA.dfModeEnabled then
    TA.dfModeLastUpdate = 0
    TA_UpdateDFMode()
  end
  return duration
end

local function GetEntitySymbol(unit)
  if unit.class then
    local classLower = unit.class:sub(1, 1):lower()
    return classLower
  end
  return "?"
end

local function BuildDFModeDisplay()
  local mapID, _, _, x, y, continentX, continentY, continentID = GetPlayerMapCell()
  if not mapID then
    return "ERROR: Could not determine map position."
  end

  local gridSize = TA.dfModeGridSize or 21
  local radius = math.floor(gridSize / 2)
  -- innerRadius is large enough that after any rotation, all display cells map to valid world cells.
  -- A rotated square needs sqrt(2) * radius coverage; we use 1.45 for a small safety margin.
  local innerRadius = math.ceil(radius * 1.45)
  -- Each DF grid cell represents this many in-game yards. Must be a whole number
  -- so mark and unit positions map cleanly: N yards = exactly N/yardsPerCell cells.
  local yardsPerCell = 6
  local viewMode = TA.dfModeViewMode or "threat"
  local profile = TA.dfModeProfile or "full"
  local orientation = TA.dfModeOrientation or "fixed"
  local rotationMode = TA.dfModeRotationMode or "smooth"
  local balanced = (profile ~= "full")

  -- Get facing direction
  local facing = GetPlayerFacing() or 0
  local playerWorldX, playerWorldY = UnitPosition("player")
  local now = GetTime()
  local facingDegrees = math.floor(math.deg(facing))
  TA.dfModeNavHint = nil

  -- Build the world grid at innerRadius so rotation never hits an out-of-bounds edge.
  local grid = {}
  local threatHeat = {}
  for y = -innerRadius, innerRadius do
    grid[y] = {}
    threatHeat[y] = {}
    for x = -innerRadius, innerRadius do
      grid[y][x] = "."
      threatHeat[y][x] = 0
    end
  end

  -- Place player at center; use @ when standing inside a marked cell.
  grid[0][0] = (TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID) and "@" or "P"

  -- Get nearby units
  local units = GetNearbyUnitsWithPositions()
  if (tonumber(TA.dfModeSonarPulseUntil) or 0) > now then
    TA_RecordDFSonarContacts(units, mapID)
  end
  TA_PruneDFSonarContacts(mapID)

  -- Get target
  local targetName = UnitName("target")
  local targetUnit = targetName and "target" or nil
  local targetDistance = nil

  local function OctantAngle(angle)
    local step = math.pi / 4
    return math.floor((angle / step) + 0.5) * step
  end

  local function DistanceBucket(d)
    if d <= 8 then return 2 end
    if d <= 18 then return 4 end
    if d <= 30 then return 6 end
    return math.min(radius, 8)
  end

  local function PlaceUnitByDistance(unit, symbol, unitType)
    if not unit or not unit.distance then return end

    local dist = math.floor(unit.distance / yardsPerCell)
    if dist <= 0 then dist = 1 end
    if dist <= 0 then dist = 1 end
    if dist > innerRadius then dist = innerRadius end

    local x, y
    if unit.hasExactPos and unit.worldX and unit.worldY and playerWorldX and playerWorldY then
      local dx = unit.worldX - playerWorldX
      local dy = unit.worldY - playerWorldY
      x = dx >= 0 and math.floor((dx / yardsPerCell) + 0.5) or math.ceil((dx / yardsPerCell) - 0.5)
      y = dy >= 0 and math.floor((dy / yardsPerCell) + 0.5) or math.ceil((dy / yardsPerCell) - 0.5)
      if x > innerRadius then x = innerRadius end
      if x < -innerRadius then x = -innerRadius end
      if y > innerRadius then y = innerRadius end
      if y < -innerRadius then y = -innerRadius end
    else
      local nameHash = 0
      for i = 1, #(unit.name or "") do
        nameHash = nameHash + string.byte(unit.name, i)
      end
      local angle = math.rad(nameHash % 360)

      if balanced then
        -- Coarsen to broad sectors and distance buckets to keep awareness, not precision.
        dist = DistanceBucket(unit.distance)
        angle = OctantAngle(angle)
        if unitType ~= "hostile" then
          symbol = "?"
        end
      end

      x = math.floor(math.cos(angle) * dist)
      y = math.floor(math.sin(angle) * dist)
    end

    if balanced then
      if unitType ~= "hostile" then
        symbol = "?"
      end
    end

    if math.abs(x) <= innerRadius and math.abs(y) <= innerRadius and grid[y] then
      if grid[y][x] == "." then
        grid[y][x] = symbol
      elseif grid[y][x] ~= "P" and grid[y][x] ~= symbol then
        grid[y][x] = "*"
      end
      if unitType == "hostile" then
        threatHeat[y][x] = (threatHeat[y][x] or 0) + 1
      end
    end
  end

  -- Place units
  for _, unit in ipairs(units.hostile or {}) do
    PlaceUnitByDistance(unit, "E", "hostile")
  end
  for _, unit in ipairs(units.neutral or {}) do
    PlaceUnitByDistance(unit, "N", "neutral")
  end
  for _, unit in ipairs(units.friendly or {}) do
    PlaceUnitByDistance(unit, "F", "friendly")
  end

  -- Place target with near-visual emphasis in balanced mode.
  if targetUnit then
    local tx, ty
    local playerX, playerY = UnitPosition("player")
    local targetX, targetY = UnitPosition("target")

    if playerX and playerY and targetX and targetY then
      local dx = targetX - playerX
      local dy = targetY - playerY
      targetDistance = math.sqrt(dx * dx + dy * dy)

      if balanced then
        local angle = OctantAngle(math.atan2(dy, dx))
        local ring = targetDistance <= 14 and 2 or (targetDistance <= 30 and 4 or nil)
        if ring then
          tx = math.floor(math.cos(angle) * ring)
          ty = math.floor(math.sin(angle) * ring)
        end
      else
        tx = math.floor(dx / yardsPerCell + 0.5)
        ty = math.floor(dy / yardsPerCell + 0.5)
      end
    else
      local nameHash = 0
      for i = 1, #(targetName or "") do
        nameHash = nameHash + string.byte(targetName, i)
      end
      local angle = math.rad(nameHash % 360)
      tx = math.floor(math.cos(angle) * 2)
      ty = math.floor(math.sin(angle) * 2)

      if CheckInteractDistance then
        if CheckInteractDistance("target", 1) then targetDistance = 10
        elseif CheckInteractDistance("target", 2) then targetDistance = 11
        elseif CheckInteractDistance("target", 3) then targetDistance = 28
        elseif CheckInteractDistance("target", 4) then targetDistance = 30
        end
      end
    end

    if tx and ty then
      if tx > innerRadius then tx = innerRadius end
      if tx < -innerRadius then tx = -innerRadius end
      if ty > innerRadius then ty = innerRadius end
      if ty < -innerRadius then ty = -innerRadius end

      if tx == 0 and ty == 0 then
        tx = math.floor(math.cos(facing) + 0.5)
        ty = math.floor(math.sin(facing) + 0.5)
        if tx == 0 and ty == 0 then tx = 1 end
      end

      if math.abs(tx) <= innerRadius and math.abs(ty) <= innerRadius and grid[ty] and grid[ty][tx] ~= "P" then
        local targetGlyph = "T"
        if balanced and targetDistance and targetDistance > 14 then
          targetGlyph = "t"
        end
        grid[ty][tx] = targetGlyph
      end
    end
  end

  -- Place marked cells last so marks stay visible over other map symbols.
  local markRadius = math.floor(tonumber(TA.dfModeMarkRadius) or 1)
  local maxMarkRadius = math.floor((TA.dfModeGridSize or 35) / 2)
  if markRadius < 0 then markRadius = 0 end
  if markRadius > maxMarkRadius then markRadius = maxMarkRadius end
  -- Scale: 1 DF grid cell = yardsPerCell yards (integer), same as unit placement.
  local defaultCellYards = tonumber(TA.cellSizeYards) or CELL_YARDS_STANDARD
  local nearestMarkDist = nil
  local nearestMarkID = nil
  local nearestMarkName = nil
  local nearestMarkMX = nil
  local nearestMarkMY = nil
  for _, mark in pairs(TA.markedCells or {}) do
    if mark.mapID == mapID and mark.cellX and mark.cellY then
      local dx_yards, dy_yards
      local markGridX = ClampGridSize(tonumber(mark.gridX) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
      local markGridY = ClampGridSize(tonumber(mark.gridY) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
      local markOffsetX = NormalizePeriodicOffset(mark.anchorOffsetX, 1 / markGridX)
      local markOffsetY = NormalizePeriodicOffset(mark.anchorOffsetY, 1 / markGridY)
      local playerCellX, playerCellY, playerInCellX, playerInCellY = ComputeCellForPosition(x, y, markGridX, markGridY, markOffsetX, markOffsetY)

      -- Keep mark math in one coordinate system (map-cell space) to avoid drift when rotating view.
      local markCenterX = mark.cellX + 0.5
      local markCenterY = mark.cellY + 0.5
      local playerPosX = playerCellX + playerInCellX
      local playerPosY = playerCellY + playerInCellY
      local markCellYards = tonumber(mark.targetYards) or defaultCellYards
      dx_yards = (markCenterX - playerPosX) * markCellYards
      -- Map-space Y grows southward; DF-space Y grows northward.
      dy_yards = (playerPosY - markCenterY) * markCellYards

      local markDist = math.sqrt((dx_yards * dx_yards) + (dy_yards * dy_yards))
      local mx = dx_yards >= 0 and math.floor((dx_yards / yardsPerCell) + 0.5) or math.ceil((dx_yards / yardsPerCell) - 0.5)
      local my = dy_yards >= 0 and math.floor((dy_yards / yardsPerCell) + 0.5) or math.ceil((dy_yards / yardsPerCell) - 0.5)

      if nearestMarkDist == nil or markDist < nearestMarkDist then
        nearestMarkDist = markDist
        nearestMarkID = mark.id or -1
        nearestMarkName = mark.name or "Unnamed"
        nearestMarkMX = mx
        nearestMarkMY = my
      end

      if math.abs(mx) <= innerRadius and math.abs(my) <= innerRadius then
        -- Draw a perimeter so marked-cell influence is visible beyond center glyph.
        if markRadius > 0 then
          for oy = -markRadius, markRadius do
            for ox = -markRadius, markRadius do
              if math.max(math.abs(ox), math.abs(oy)) == markRadius then
                local ex = mx + ox
                local ey = my + oy
                if math.abs(ex) <= innerRadius and math.abs(ey) <= innerRadius and grid[ey] and grid[ey][ex] then
                  -- Only draw edge on empty cells so entities are never overwritten.
                  if grid[ey][ex] == "." then
                    grid[ey][ex] = "o"
                  end
                end
              end
            end
          end
        end

        if grid[my] and grid[my][mx] then
          local current = grid[my][mx]
          if current ~= "P" and current ~= "@" and current ~= "T" and current ~= "t" then
            grid[my][mx] = "M"
          end
        end
      end
    end
  end

  -- Sonar echo overlay: recent exact-contact memory to improve map definition between direct sightings.
  for _, c in pairs(TA.dfModeSonarContacts or {}) do
    if c and c.mapID == mapID and c.worldX and c.worldY and playerWorldX and playerWorldY and c.expiresAt and c.expiresAt > now then
      local dx_yards = c.worldX - playerWorldX
      local dy_yards = c.worldY - playerWorldY
      local sx = dx_yards >= 0 and math.floor((dx_yards / yardsPerCell) + 0.5) or math.ceil((dx_yards / yardsPerCell) - 0.5)
      local sy = dy_yards >= 0 and math.floor((dy_yards / yardsPerCell) + 0.5) or math.ceil((dy_yards / yardsPerCell) - 0.5)
      if math.abs(sx) <= innerRadius and math.abs(sy) <= innerRadius and grid[sy] and grid[sy][sx] and grid[sy][sx] == "." then
        local ttl = math.max(1, (tonumber(TA.dfModeSonarTTL) or 8))
        local age = now - (c.seenAt or now)
        local glyph = "'"
        if c.kind == "hostile" then
          if age <= ttl * 0.33 then glyph = "h"
          elseif age <= ttl * 0.66 then glyph = ":"
          else glyph = "." end
          threatHeat[sy][sx] = (threatHeat[sy][sx] or 0) + 1
        elseif c.kind == "friendly" then
          glyph = age <= ttl * 0.5 and "f" or ","
        else
          glyph = age <= ttl * 0.5 and "n" or ","
        end
        grid[sy][sx] = glyph
      end
    end
  end

  -- Build output: grid rows only, no header or footer
  local lines = {}
  local navRotationAngle = facing - (math.pi / 2)
  if rotationMode == "octant" then
    local step = math.pi / 4
    navRotationAngle = math.floor((navRotationAngle / step) + 0.5) * step
  end
  local navSinA = math.sin(navRotationAngle)
  local navCosA = math.cos(navRotationAngle)

  local displayRotationAngle = 0
  if orientation == "rotating" then
    displayRotationAngle = navRotationAngle
  end
  local displaySinA = math.sin(displayRotationAngle)
  local displayCosA = math.cos(displayRotationAngle)

  local function RoundNearest(n)
    if n >= 0 then
      return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
  end

  if nearestMarkDist and nearestMarkMX and nearestMarkMY then
    local sx = RoundNearest((nearestMarkMX * navCosA) + (nearestMarkMY * navSinA))
    local sy = RoundNearest((-nearestMarkMX * navSinA) + (nearestMarkMY * navCosA))
    local vertical = ""
    local horizontal = ""
    if sy > 0 then
      vertical = "ahead"
    elseif sy < 0 then
      vertical = "behind"
    end
    if sx > 0 then
      horizontal = "right"
    elseif sx < 0 then
      horizontal = "left"
    end
    local relDir
    if vertical ~= "" and horizontal ~= "" then
      relDir = vertical .. "-" .. horizontal
    elseif vertical ~= "" then
      relDir = vertical
    elseif horizontal ~= "" then
      relDir = horizontal
    else
      relDir = "on top of you"
    end
    local approachIndicator = ""
    local prevDist = (TA.dfModeLastNearestMarkID == nearestMarkID) and TA.dfModeLastNearestMarkDist or nil
    if prevDist then
      local delta = nearestMarkDist - prevDist
      if delta < -1 then
        approachIndicator = " >>>"
      elseif delta > 1 then
        approachIndicator = " <<<"
      else
        approachIndicator = " ---"
      end
    end
    TA.dfModeLastNearestMarkID = nearestMarkID
    TA.dfModeLastNearestMarkDist = nearestMarkDist
    TA.dfModeNavHint = string.format("Mark [%d] %s: %dyd %s%s", nearestMarkID, nearestMarkName, math.floor(nearestMarkDist + 0.5), relDir, approachIndicator)
  end

  for y = radius, -radius, -1 do
    local row = {}
    for x = -radius, radius do
      -- Rotate viewport with heading: screen coords -> world coords.
      local wx = RoundNearest((x * displayCosA) - (y * displaySinA))
      local wy = RoundNearest((x * displaySinA) + (y * displayCosA))

      local cell = "."
      if math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and grid[wy] and grid[wy][wx] then
        cell = grid[wy][wx]
      end
      local dist = math.sqrt(x * x + y * y)

      local showThreat = (viewMode == "threat" or viewMode == "combined")
      local showExploration = (viewMode == "exploration" or viewMode == "combined")
      local showRange = (viewMode == "tactical" or viewMode == "combined")

      local threatVal = 0
      if math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and threatHeat[wy] and threatHeat[wy][wx] then
        threatVal = threatHeat[wy][wx] or 0
      end
      if showThreat and threatVal > 0 then
        if threatVal >= 3 then cell = "!" .. cell
        elseif threatVal >= 2 then cell = "~" .. cell
        end
      end

      if showExploration and math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and TA.dfModeRecentCells[wy] and TA.dfModeRecentCells[wy][wx] then
        cell = "+" .. cell
      end

      if showRange then
        if (math.abs(dist - 2) < 0.5 or math.abs(dist - 4) < 0.5 or math.abs(dist - 6) < 0.5) and cell == "." then
          cell = "-"
        end
      end

      table.insert(row, cell)
    end
    table.insert(lines, table.concat(row, " "))
  end

  return table.concat(lines, "\n")
end

function TA_SetDFModeSize(width, height, silent)
  local minW, minH = 100, 200
  local maxW, maxH = 1200, 1000

  if not width or not height then
    local currentW, currentH = dfModeFrame:GetSize()
    AddLine("system", "DF window size: " .. math.floor(currentW) .. "x" .. math.floor(currentH))
    AddLine("system", "Usage: /ta df size <width> <height> (range " .. minW .. "-" .. maxW .. " x " .. minH .. "-" .. maxH .. ")")
    return
  end

  local w = math.floor(tonumber(width) or 0)
  local h = math.floor(tonumber(height) or 0)
  if w <= 0 or h <= 0 then
    AddLine("system", "Invalid DF size. Usage: /ta df size <width> <height>")
    return
  end

  if w < minW then w = minW end
  if h < minH then h = minH end
  if w > maxW then w = maxW end
  if h > maxH then h = maxH end

  dfModeFrame:SetSize(w, h)
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfModeWidth = w
  TextAdventurerDB.dfModeHeight = h

  if not silent then
    AddLine("system", "DF window size set to " .. w .. "x" .. h)
  end
  if TA.dfModeEnabled then
    TA.dfModeLastUpdate = 0
    TA_UpdateDFMode()
  end
end

function TA_SetDFModeMarkRadius(radius, silent)
  local minR = 0
  local maxR = math.floor((TA.dfModeGridSize or 35) / 2)

  if radius == nil then
    local current = tonumber(TA.dfModeMarkRadius) or 1
    AddLine("system", "DF mark radius: " .. math.floor(current) .. " cell(s)")
    AddLine("system", "Usage: /ta df markradius <0-" .. maxR .. ">")
    return
  end

  local r = math.floor(tonumber(radius) or -1)
  if r < minR or r > maxR then
    AddLine("system", "Invalid DF mark radius. Use a value from " .. minR .. " to " .. maxR)
    return
  end

  TA.dfModeMarkRadius = r
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfModeMarkRadius = r

  if not silent then
    AddLine("system", "DF mark radius set to " .. r .. " cell(s)")
  end
  if TA.dfModeEnabled then
    TA.dfModeLastUpdate = 0
    TA_UpdateDFMode()
  end
end

function TA_DFModeStatus()
  if not TA.dfModeEnabled then
    AddLine("system", "DF Mode is not active. Use /ta dfmode to enable it.")
    return
  end

  local profile = TA.dfModeProfile or "full"
  local balanced = (profile ~= "full")
  local viewMode = TA.dfModeViewMode or "threat"

  local facing = GetPlayerFacing() or 0
  local facingDegrees = math.floor(math.deg(facing))
  local dirStr = "?"
  if facingDegrees >= 315 or facingDegrees < 45 then dirStr = "N"
  elseif facingDegrees >= 45 and facingDegrees < 135 then dirStr = "E"
  elseif facingDegrees >= 135 and facingDegrees < 225 then dirStr = "S"
  elseif facingDegrees >= 225 and facingDegrees < 315 then dirStr = "W"
  end

  local mapID, cellX, cellY = GetPlayerMapCell()
  local zoneName = GetZoneText() or "Unknown"
  local units = GetNearbyUnitsWithPositions()

  local totalHostile = #(units.hostile or {})
  local totalNeutral = #(units.neutral or {})
  local totalFriendly = #(units.friendly or {})

  AddLine("system", "=== DF MODE STATUS ===")
  AddLine("system", "View: " .. viewMode:upper() .. "  |  Profile: " .. profile:upper())
  AddLine("system", "Zone: " .. zoneName .. (mapID and ("  |  Cell: [" .. cellX .. "," .. cellY .. "]") or ""))
  AddLine("system", "Facing: " .. dirStr .. " (" .. facingDegrees .. " deg)")
  AddLine("system", "Legend: P=You  @=You in marked cell  E=Enemy  M=Mark center  o=mark edge/radius")
  AddLine("system", "        T=near target  t=mid target  ?=non-hostile blob")
  AddLine("system", "        +=Trail  -=Range ring  *=Contested")
  AddLine("system", "Mark radius: " .. (tonumber(TA.dfModeMarkRadius) or 1) .. " cell(s)")
  AddLine("system", "Orientation: " .. ((TA.dfModeOrientation or "fixed"):upper()))
  AddLine("system", "Rotation mode: " .. ((TA.dfModeRotationMode or "smooth"):upper()))
  if TA.dfModeNavHint and TA.dfModeNavHint ~= "" then
    AddLine("system", "Navigation hint: " .. TA.dfModeNavHint)
  end
  if TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID then
    AddLine("system", "Marked cell occupancy: IN [" .. (TA.markedCells[TA.lastMarkedCellNotification].id or -1) .. "] " .. (TA.markedCells[TA.lastMarkedCellNotification].name or "Unnamed"))
  else
    AddLine("system", "Marked cell occupancy: not in a marked cell")
  end
  AddLine("system", "        ~=2 threats on cell  !=3+ threats on cell")

  if totalHostile > 0 then
    if balanced then
      local near, mid, far = 0, 0, 0
      for _, u in ipairs(units.hostile or {}) do
        local d = u.distance or 999
        if d <= 10 then near = near + 1
        elseif d <= 25 then mid = mid + 1
        else far = far + 1
        end
      end
      AddLine("system", "[THREAT] Hostiles: " .. totalHostile .. "  (Near: " .. near .. "  Mid: " .. mid .. "  Far: " .. far .. ")")
    else
      AddLine("system", "[!!! THREAT !!!] " .. totalHostile .. " hostile unit(s)!")
      for i = 1, math.min(6, totalHostile) do
        local unit = units.hostile[i]
        if unit then
          local health = "?"
          if unit.maxHealth and unit.maxHealth > 0 then
            health = math.floor((unit.health or 0) / unit.maxHealth * 100) .. "%"
          end
          local dist = math.floor(unit.distance or 0) .. "yd"
          local level = unit.level or "?"
          AddLine("system", "  [" .. i .. "] " .. (unit.name or "?") .. " Lvl" .. level .. " HP:" .. health .. " (" .. dist .. ")")
        end
      end
      if totalHostile > 6 then
        AddLine("system", "  ... and " .. (totalHostile - 6) .. " more hostile!")
      end
    end
  end

  local targetName = UnitName("target")
  if targetName then
    local playerX, playerY = UnitPosition("player")
    local targetX, targetY = UnitPosition("target")
    if playerX and targetX then
      local dx = targetX - playerX
      local dy = targetY - playerY
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= 14 then AddLine("system", "Target: " .. targetName .. " (near, " .. math.floor(d) .. "yd)")
      elseif d <= 30 then AddLine("system", "Target: " .. targetName .. " (mid-range, " .. math.floor(d) .. "yd)")
      else AddLine("system", "Target: " .. targetName .. " (far, " .. math.floor(d) .. "yd)")
      end
    else
      AddLine("system", "Target: " .. targetName .. " (detected)")
    end
  end

  if totalNeutral > 0 then AddLine("system", "Neutral: " .. totalNeutral .. " nearby") end
  if totalFriendly > 0 then AddLine("system", "Friendly: " .. totalFriendly .. " nearby") end
  if totalHostile == 0 and totalNeutral == 0 and totalFriendly == 0 then
    AddLine("system", "All clear - no units detected nearby")
  end
end

function TA_UpdateDFMode()
  if not TA.dfModeEnabled or not dfModeFrame:IsShown() then
    return
  end
  
  local now = GetTime()
  if now - TA.dfModeLastUpdate < 0.05 then
    return  -- Update at most every 0.05 seconds
  end
  TA.dfModeLastUpdate = now
  
  local display = BuildDFModeDisplay()
  local mapLines = dfModeFrame.mapLines
  local i = 1
  if display then
    for line in display:gmatch("[^\n]+") do
      if mapLines[i] then
        mapLines[i]:SetText(line)
        i = i + 1
      end
    end
  else
    if mapLines[1] then mapLines[1]:SetText("Error generating tactical map.") end
    i = 2
  end
  -- Blank out any rows below the current map
  for j = i, #mapLines do
    mapLines[j]:SetText("")
  end
  if TA.dfModeNavHint and TA.dfModeNavHint ~= "" then
    dfTitle:SetText("Tactical Map (DF Mode) - " .. TA.dfModeNavHint)
  else
    dfTitle:SetText("Tactical Map (DF Mode)")
  end
end

function TA_ToggleDFMode()
  TA.dfModeEnabled = not TA.dfModeEnabled
  if TA.dfModeEnabled then
    dfModeFrame:Show()
    TA.dfModeLastUpdate = 0  -- Reset timer to force immediate update
    TA_UpdateDFMode()
    AddLine("system", "DF Mode tactical map enabled.")
  else
    dfModeFrame:Hide()
    AddLine("system", "DF Mode tactical map disabled.")
  end
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfModeEnabled = TA.dfModeEnabled
  TextAdventurerDB.dfModeProfile = TA.dfModeProfile
  local currentW, currentH = dfModeFrame:GetSize()
  TextAdventurerDB.dfModeWidth = math.floor(currentW)
  TextAdventurerDB.dfModeHeight = math.floor(currentH)
end

function TA_ReportAsciiMap(force, ignoreToggle)
  if not ignoreToggle and not TA.asciiMapEnabled then
    return
  end


  local mapID, cellX, cellY, _, _, _, _, _, gridX, gridY, offsetX, offsetY = GetPlayerMapCell()
  if not mapID then
    if force then AddLine("system", "Could not determine current cell for map.") end
    return
  end

  local signature = tostring(mapID) .. ":" .. tostring(cellX) .. "," .. tostring(cellY)
  if not force and signature == TA.lastAsciiMapSignature then
    return
  end
  TA.lastAsciiMapSignature = signature

  local data = GetExplorationData(mapID)
  local recentLookup = {}
  for i = 1, #TA.recentCells do
    local key = TA.recentCells[i]
    local keyMap, keyCell = key:match("^(%d+):(.+)$")
    if tonumber(keyMap) == mapID and keyCell then
      recentLookup[keyCell] = true
    end
  end

  local markLookup = {}
  for _, mark in pairs(TA.markedCells) do
    if mark.mapID == mapID and mark.x and mark.y then
      local mCellX, mCellY = ComputeCellForPosition(mark.x, mark.y, gridX, gridY, offsetX, offsetY)
      markLookup[CellKey(mCellX, mCellY)] = true
    elseif mark.mapID == mapID and mark.cellX ~= nil and mark.cellY ~= nil then
      markLookup[CellKey(mark.cellX, mark.cellY)] = true
    end
  end

  local radius = 3
  local span = (radius * 2) + 1
  AddLine("place", string.format("ASCII map (%dx%d), centered on [%d,%d]:", span, span, cellX, cellY))

  for y = cellY + radius, cellY - radius, -1 do
    local row = {}
    for x = cellX - radius, cellX + radius do
      local glyph = "."
      if x == cellX and y == cellY then
        glyph = "P"
      else
        local key = CellKey(x, y)
        if markLookup[key] then
          glyph = "M"
        elseif recentLookup[key] then
          glyph = "+"
        elseif data.visited and data.visited[key] then
          glyph = "#"
        end
      end
      table.insert(row, glyph)
    end
    AddLine("place", "  " .. table.concat(row, " "))
  end
  AddLine("place", "Legend: P=you M=mark +=recent #=visited .=unknown")
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

-- Returns an 8-direction compass string (N/NE/E/SE/S/SW/W/NW) from a world-space dx/dy offset.
-- Uses the same coordinate convention as UnitPosition: dx = deltaX (south+), dy = deltaY (east+).
function TA_CompassDir(dx, dy)
  local deg = math.deg(math.atan2(dy, dx)) % 360
  local dirs = { "E", "SE", "S", "SW", "W", "NW", "N", "NE" }
  return dirs[math.floor((deg + 22.5) / 45) % 8 + 1]
end

local DF_YARDS_PER_CELL = 6

local function BuildNearbyLine(kind, units)
  if #units == 0 then return nil end
  local parts = {}
  for _, u in ipairs(units) do
    local label = u.isTarget and ("[T]" .. u.name) or u.name
    if u.dist then
      local cells = math.max(1, math.floor(u.dist / DF_YARDS_PER_CELL + 0.5))
      local cellWord = cells == 1 and "cell" or "cells"
      local approxMark = u.distApprox and "~" or ""
      if u.dir then
        parts[#parts + 1] = label .. " (" .. approxMark .. cells .. " " .. cellWord .. " " .. u.dir .. ")"
      else
        parts[#parts + 1] = label .. " (" .. approxMark .. cells .. " " .. cellWord .. " away)"
      end
    else
      parts[#parts + 1] = label
    end
  end
  return string.format("%s nearby: %s", kind, table.concat(parts, ", "))
end

local function GetNearbyUnitsSummary()
  local seen = {}
  local hostiles, neutrals, friendlies = {}, {}, {}
  local nameplates = C_NamePlate.GetNamePlates()
  local playerX, playerY = UnitPosition("player")
  for _, frame in ipairs(nameplates) do
    local unit = frame.namePlateUnitToken
    if unit and UnitExists(unit) then
      local name = UnitName(unit)
      if name and not seen[name] then
        seen[name] = true
        local dist, dir, distApprox = nil, nil, false
        if playerX and playerY then
          local ux, uy = UnitPosition(unit)
          if ux and uy then
            local dx, dy = ux - playerX, uy - playerY
            dist = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
            dir = TA_CompassDir(dx, dy)
          end
        end
        -- Fallback: CheckInteractDistance gives bracketed range when UnitPosition is unavailable
        if not dist and CheckInteractDistance then
          if CheckInteractDistance(unit, 1) then dist = 3      -- ~0 cells (right next to you)
          elseif CheckInteractDistance(unit, 2) then dist = 9  -- ~1-2 cells
          elseif CheckInteractDistance(unit, 3) then dist = 24 -- ~4 cells
          else dist = 48 end                                    -- ~8 cells
          distApprox = true
        end
        local entry = { name = name, dist = dist, dir = dir, distApprox = distApprox, isTarget = UnitIsUnit(unit, "target") }
        if UnitCanAttack("player", unit) then
          table.insert(hostiles, entry)
        else
          local reaction = UnitReaction(unit, "player") or 4
          if reaction >= 5 then table.insert(friendlies, entry) else table.insert(neutrals, entry) end
        end
      end
    end
  end
  local function sortByName(a, b) return a.name < b.name end
  table.sort(hostiles, sortByName)
  table.sort(neutrals, sortByName)
  table.sort(friendlies, sortByName)
  local function nameList(t) local n = {} for _, u in ipairs(t) do n[#n + 1] = u.name end return n end
  return {
    hostile = BuildNearbyLine("Hostile", hostiles),
    neutral = BuildNearbyLine("Neutral", neutrals),
    friendly = BuildNearbyLine("Friendly", friendlies),
    signature = table.concat({ table.concat(nameList(hostiles), ","), table.concat(nameList(neutrals), ","), table.concat(nameList(friendlies), ",") }, "|"),
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
  CHAT_MSG_SAY={label="Say",kind="chat"}, CHAT_MSG_YELL={label="Yell",kind="chat"}, CHAT_MSG_EMOTE={label="Emote",kind="chat"}, CHAT_MSG_TEXT_EMOTE={label="TextEmote",kind="chat"}, CHAT_MSG_PARTY={label="Party",kind="chat"}, CHAT_MSG_PARTY_LEADER={label="PartyLead",kind="chat"}, CHAT_MSG_RAID={label="Raid",kind="chat"}, CHAT_MSG_RAID_LEADER={label="RaidLead",kind="chat"}, CHAT_MSG_RAID_WARNING={label="Warning",kind="chat"}, CHAT_MSG_GUILD={label="Guild",kind="chat"}, CHAT_MSG_OFFICER={label="Officer",kind="chat"}, CHAT_MSG_WHISPER={label="Whisper",kind="whisper"}, CHAT_MSG_WHISPER_INFORM={label="To",kind="whisper"}, CHAT_MSG_MONSTER_SAY={label="NPC",kind="chat"}, CHAT_MSG_MONSTER_YELL={label="NPC",kind="chat"}, CHAT_MSG_MONSTER_WHISPER={label="NPC",kind="chat"}, CHAT_MSG_CHANNEL={label="Channel",kind="chat"}, CHAT_MSG_SYSTEM={label="System",kind="system"}
}

local function CleanSenderName(sender)
  if not sender or sender == "" then return "Unknown" end
  return sender:gsub("%-.*$", "")
end

local function HandleChatEvent(event, message, sender, _, _, _, _, _, _, channelName)
  if event == "CHAT_MSG_SYSTEM" then
    if TA.captureChat or TA.pendingCVarList then
      if message and message ~= "" then
        AddLine("system", message)
      end
    end
    return
  end
  if not TA.captureChat then return end
  local info = CHAT_EVENT_INFO[event]
  if not info or not message or message == "" then return end
  local name = CleanSenderName(sender)
  local prefix = info.label
  if event == "CHAT_MSG_CHANNEL" and channelName and channelName ~= "" then prefix = channelName end
  AddLine(info.kind, string.format("[%s] %s: %s", prefix, name, message))
end

local function TryAutoQuestFromGossip()
  if not TA.autoQuests then return end
  if C_GossipInfo then
    if C_GossipInfo.GetAvailableQuests and C_GossipInfo.SelectAvailableQuest then
      local available = C_GossipInfo.GetAvailableQuests()
      if available then
        for _, info in ipairs(available) do
          local optionID = info.questID or rawget(info, "optionID")
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
          local optionID = info.questID or rawget(info, "optionID")
          if optionID and info.isComplete then
            AddLine("quest", string.format("Auto-turning in quest: %s", info.title or "Unknown quest"))
            C_GossipInfo.SelectActiveQuest(optionID)
            return
          end
        end
      end
    end
  end

  if GetNumAvailableQuests and GetAvailableTitle and SelectAvailableQuest then
    local availableCount = tonumber(GetNumAvailableQuests()) or 0
    for i = 1, availableCount do
      local title = GetAvailableTitle(i)
      if title and title ~= "" then
        AddLine("quest", string.format("Auto-accepting quest: %s", title))
        if not pcall(SelectAvailableQuest, i) then
          pcall(SelectAvailableQuest)
        end
        return
      end
    end
  end

  if GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
    local activeCount = tonumber(GetNumActiveQuests()) or 0
    for i = 1, activeCount do
      local title, isComplete = GetActiveTitle(i)
      if title and title ~= "" and isComplete then
        AddLine("quest", string.format("Auto-turning in quest: %s", title))
        if not pcall(SelectActiveQuest, i) then
          pcall(SelectActiveQuest)
        end
        return
      end
    end
  end
end

local function BuildGossipOptionPool()
  local pool = {}
  if C_GossipInfo then
    if C_GossipInfo.GetAvailableQuests then
      local available = C_GossipInfo.GetAvailableQuests() or {}
      for _, info in ipairs(available) do
        local optionID = info.questID or rawget(info, "optionID")
        if optionID then
          table.insert(pool, {
            kind = "availableQuest",
            id = optionID,
            title = info.title or "Available quest",
          })
        end
      end
    end

    if C_GossipInfo.GetActiveQuests then
      local active = C_GossipInfo.GetActiveQuests() or {}
      for _, info in ipairs(active) do
        local optionID = info.questID or rawget(info, "optionID")
        if optionID then
          table.insert(pool, {
            kind = "activeQuest",
            id = optionID,
            title = info.title or "Active quest",
            isComplete = info.isComplete and true or false,
          })
        end
      end
    end

    if C_GossipInfo.GetOptions then
      local options = C_GossipInfo.GetOptions() or {}
      for _, info in ipairs(options) do
        local optionID = info.gossipOptionID or info.optionID
        if optionID then
          table.insert(pool, {
            kind = "gossipOption",
            id = optionID,
            title = info.name or info.title or "Dialogue option",
          })
        end
      end
    end
  end

  if #pool == 0 and GetNumAvailableQuests and GetAvailableTitle then
    local availableCount = tonumber(GetNumAvailableQuests()) or 0
    for i = 1, availableCount do
      local title = GetAvailableTitle(i)
      if title and title ~= "" then
        table.insert(pool, {
          kind = "availableQuestLegacy",
          id = i,
          title = title,
        })
      end
    end
  end

  if #pool == 0 and GetNumActiveQuests and GetActiveTitle then
    local activeCount = tonumber(GetNumActiveQuests()) or 0
    for i = 1, activeCount do
      local title, isComplete = GetActiveTitle(i)
      if title and title ~= "" then
        table.insert(pool, {
          kind = "activeQuestLegacy",
          id = i,
          title = title,
          isComplete = isComplete and true or false,
        })
      end
    end
  end

  return pool
end

local function ReportGossipOptions()
  local options = BuildGossipOptionPool()
  if #options == 0 then
    AddLine("quest", "No selectable dialogue options are available right now.")
    return
  end
  AddLine("quest", "Dialogue options:")
  for i = 1, #options do
    local opt = options[i]
    local prefix = "Talk"
    if opt.kind == "availableQuest" or opt.kind == "availableQuestLegacy" then
      prefix = "Quest available"
    elseif opt.kind == "activeQuest" or opt.kind == "activeQuestLegacy" then
      prefix = opt.isComplete and "Quest turn-in" or "Quest in progress"
    end
    AddLine("quest", string.format("  [%d] %s: %s", i, prefix, opt.title))
  end
  AddLine("quest", "Use 'choose <number>' to select one.")
end

local function ChooseGossipOption(index)
  if not index or index < 1 then
    AddLine("system", "Usage: choose <number>")
    return
  end
  local options = BuildGossipOptionPool()
  local opt = options[index]
  if not opt then
    AddLine("system", string.format("Invalid dialogue option %d.", index))
    return
  end

  if opt.kind == "availableQuest" and C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
    C_GossipInfo.SelectAvailableQuest(opt.id)
    AddLine("quest", string.format("Selected quest offer: %s", opt.title))
  elseif opt.kind == "availableQuestLegacy" and SelectAvailableQuest then
    if not pcall(SelectAvailableQuest, opt.id) then
      pcall(SelectAvailableQuest)
    end
    AddLine("quest", string.format("Selected quest offer: %s", opt.title))
  elseif opt.kind == "activeQuest" and C_GossipInfo and C_GossipInfo.SelectActiveQuest then
    C_GossipInfo.SelectActiveQuest(opt.id)
    AddLine("quest", string.format("Selected active quest: %s", opt.title))
  elseif opt.kind == "activeQuestLegacy" and SelectActiveQuest then
    if not pcall(SelectActiveQuest, opt.id) then
      pcall(SelectActiveQuest)
    end
    AddLine("quest", string.format("Selected active quest: %s", opt.title))
  elseif opt.kind == "gossipOption" and C_GossipInfo and C_GossipInfo.SelectOption then
    C_GossipInfo.SelectOption(opt.id)
    AddLine("quest", string.format("Selected dialogue option: %s", opt.title))
  else
    AddLine("system", "That dialogue choice is unavailable in this client state.")
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

local function CompleteQuestFromTerminal()
  if GetNumQuestChoices and GetQuestReward then
    local numChoices = GetNumQuestChoices() or 0
    if numChoices > 0 then
      GetQuestRewardChoice(TA.selectedRewardIndex or 1)
      return
    end
  end
  if not IsQuestCompletable or not IsQuestCompletable() then
    AddLine("quest", "No quest is ready to complete.")
    return
  end
  if not CompleteQuest then
    AddLine("system", "Quest completion API unavailable.")
    return
  end
  CompleteQuest()
  AddLine("quest", "Quest completed and dialogue progressed.")
end

local function ListQuestRewards()
  if not GetNumQuestChoices or not GetQuestItemInfo then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  local numChoices = GetNumQuestChoices() or 0
  if numChoices == 0 then
    AddLine("quest", "No reward choices available (quest may auto-complete).")
    return
  end
  AddLine("quest", string.format("Quest has %d reward choice(s):", numChoices))
  for i = 1, numChoices do
    local itemName, itemTexture, itemQuality, itemLevel = GetQuestItemInfo("choice", i)
    if itemName then
      local qualityColor = itemQuality or 1
      local qualityName = ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" })[qualityColor + 1] or "Unknown"
      AddLine("quest", string.format("  [%d] %s (Quality: %s, Level: %d)", i, itemName, qualityName, itemLevel or 0))
    else
      AddLine("quest", string.format("  [%d] (reward item %d)", i, i))
    end
  end
  AddLine("quest", "Use 'select <number>' to pick, then 'complete' to turn in.")
end

local function SelectQuestReward(index)
  if not GetNumQuestChoices then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  local numChoices = GetNumQuestChoices() or 0
  if numChoices == 0 then
    AddLine("quest", "No reward choices available.")
    return
  end
  if not index or index < 1 or index > numChoices then
    AddLine("system", string.format("Invalid choice %d. Quest has %d options. Use 'rewards' to list them.", index, numChoices))
    return
  end
  
  -- In WoW Classic, you select a reward by clicking on it in the quest reward frame
  -- We can simulate this by clicking the reward button
  local QuestFrame = _G["QuestFrame"]
  if QuestFrame and QuestFrame:IsVisible() then
    local RewardItemChoice = _G["QuestRewardItem_" .. index]
    if RewardItemChoice and RewardItemChoice:IsVisible() then
      RewardItemChoice:Click()
      TA.selectedRewardIndex = index
      AddLine("quest", string.format("Selected reward choice %d.", index))
      return
    end
  end
  
  -- Fallback: just report which one will be selected
  AddLine("quest", string.format("Selected reward choice %d. Type 'complete' to turn in.", index))
  TA.selectedRewardIndex = index
end

local function GetQuestRewardChoice(index)
  if not GetQuestReward then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  if not index or index < 1 then
    index = TA.selectedRewardIndex or 1
  end
  local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
  if numChoices == 0 then
    GetQuestReward(1)
    AddLine("quest", "Quest turned in with no reward choice.")
  elseif index > numChoices then
    AddLine("system", string.format("Invalid reward choice %d. Quest has %d options.", index, numChoices))
  else
    GetQuestReward(index)
    AddLine("quest", string.format("Quest turned in. Reward choice %d selected.", index))
    TA.selectedRewardIndex = nil
  end
end

local function ReportQuestRewardInfo(index)
  if not GetNumQuestChoices or not GetQuestItemInfo then
    AddLine("system", "Quest reward API unavailable.")
    return
  end

  local numChoices = GetNumQuestChoices() or 0
  if numChoices == 0 then
    AddLine("quest", "No reward choices available (quest may auto-complete).")
    return
  end

  index = tonumber(index)
  if not index then
    AddLine("system", "Usage: rewardinfo <index>")
    return
  end
  if index < 1 or index > numChoices then
    AddLine("system", string.format("Invalid choice %d. Quest has %d options. Use 'rewards' to list them.", index, numChoices))
    return
  end

  local itemName, _, itemQuality, itemLevel = GetQuestItemInfo("choice", index)
  local link = GetQuestItemLink and GetQuestItemLink("choice", index)
  local title = itemName or (link and link:match("%[(.-)%]")) or ("Reward " .. tostring(index))
  local qualityName = ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" })[(itemQuality or 1) + 1] or "Unknown"

  AddLine("quest", string.format("Reward [%d]: %s", index, title))
  AddLine("quest", string.format("Quality: %s | Item level: %d", qualityName, itemLevel or 0))

  if not CreateFrame or not UIParent then
    AddLine("system", "Tooltip inspection API unavailable.")
    return
  end
  if not TA.questRewardInspectTooltip then
    TA.questRewardInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerQuestRewardInspectTooltip", UIParent, "GameTooltipTemplate")
  end

  local tip = TA.questRewardInspectTooltip
  if not tip or not tip.SetQuestItem or not tip.NumLines or not tip.GetName then
    AddLine("system", "Tooltip inspection API unavailable.")
    return
  end

  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetQuestItem("choice", index)

  local tipName = tip:GetName()
  local shown = 0
  local maxLines = 16
  for i = 2, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local leftText = left and left:GetText() or ""
    local rightText = right and right:GetText() or ""
    if leftText ~= "" or rightText ~= "" then
      local lineText = leftText
      if rightText ~= "" then
        if lineText ~= "" then
          lineText = lineText .. "  " .. rightText
        else
          lineText = rightText
        end
      end
      AddLine("quest", lineText)
      shown = shown + 1
      if shown >= maxLines then
        AddLine("quest", "(Additional reward details truncated.)")
        break
      end
    end
  end

  if shown == 0 then
    AddLine("quest", "No additional tooltip details available yet.")
  end

  tip:Hide()
end

local function BuildStaticPopupList()
  local popups = {}
  
  -- In Classic Era, dialogs are registered as StaticPopup1, StaticPopup2, etc.
  -- We need to check them by reference and identify by text content
  for i = 1, 10 do
    local frameName = "StaticPopup" .. i
    local dialog = _G[frameName]
    if dialog and dialog:IsVisible() then
      local text = ""
      if dialog.Text then
        local ok, txt = pcall(function() return dialog.Text:GetText() end)
        text = ok and txt or ""
      end
      
      local kind, title, defaultAction
      
      if text:find("home", 1, true) or text:find("Home", 1, true) then
        kind = "hearthstone"
        title = "Confirm hearthstone location"
        defaultAction = "accept"
      elseif text:find("invite", 1, true) or text:find("Invite", 1, true) then
        kind = "groupInvite"
        title = "Group invite received"
        defaultAction = "accept"
      elseif text:find("duel", 1, true) or text:find("Duel", 1, true) then
        kind = "duelRequest"
        title = "Duel request"
        defaultAction = "decline"
      elseif text:find("delete", 1, true) or text:find("Delete", 1, true) then
        kind = "deleteItem"
        title = "Confirm item deletion"
        defaultAction = "decline"
      end
      
      if kind then
        local btn1Name = frameName .. "Button1"
        local btn2Name = frameName .. "Button2"
        table.insert(popups, {
          kind = kind,
          title = title,
          defaultAction = defaultAction,
          frame = dialog,
          button1 = _G[btn1Name],
          button2 = _G[btn2Name],
        })
      end
    end
  end
  
  return popups
end

local function ReportStaticPopups()
  local popups = BuildStaticPopupList()
  if #popups == 0 then
    AddLine("system", "No active prompts or dialogs.")
    return
  end
  AddLine("system", "Active prompts:")
  for i = 1, #popups do
    local p = popups[i]
    AddLine("system", string.format("  [%d] %s (%s)", i, p.title, p.kind))
  end
  AddLine("system", "Use 'accept <number>' or 'decline <number>' to respond.")
end

local function DebugVisiblePopups()
  AddLine("system", "=== Scanning StaticPopup1-10 ===")
  
  for i = 1, 10 do
    local frameName = "StaticPopup" .. i
    local dialog = _G[frameName]
    if dialog then
      local isVis = dialog:IsVisible()
      AddLine("system", string.format("%s: visible=%s", frameName, tostring(isVis)))
      
      if isVis then
        -- Show text
        if dialog.Text then
          local ok, txt = pcall(function() return dialog.Text:GetText() end)
          if ok then
            AddLine("system", string.format("  Text: %s", txt))
          end
        end
        
        -- Check for buttons by global name
        local btn1Name = frameName .. "Button1"
        local btn2Name = frameName .. "Button2"
        local btn1 = _G[btn1Name]
        local btn2 = _G[btn2Name]
        
        if btn1 then
          local ok, label = pcall(function() return btn1:GetText() end)
          label = ok and label or "error"
          AddLine("system", string.format("  %s: %s", btn1Name, label))
        end
        if btn2 then
          local ok, label = pcall(function() return btn2:GetText() end)
          label = ok and label or "error"
          AddLine("system", string.format("  %s: %s", btn2Name, label))
        end
      end
    end
  end
  
  AddLine("system", "=== End popup scan ===")
end

local function RespondToPopup(index, action)
  if not index or index < 1 then
    AddLine("system", string.format("Usage: %s <number>", action))
    return
  end
  local popups = BuildStaticPopupList()
  local p = popups[index]
  if not p then
    AddLine("system", string.format("No prompt at index %d.", index))
    return
  end
  
  if action == "accept" then
    if p.button1 then
      p.button1:Click()
      if p.kind == "hearthstone" then
        AddLine("quest", "Hearthstone location confirmed.")
      elseif p.kind == "groupInvite" then
        AddLine("quest", "Group invite accepted.")
      elseif p.kind == "duelRequest" then
        AddLine("quest", "Duel accepted.")
      elseif p.kind == "deleteItem" then
        AddLine("loot", "Item deletion confirmed.")
      end
    else
      AddLine("system", string.format("%s button not accessible.", p.title))
    end
  elseif action == "decline" then
    if p.button2 then
      p.button2:Click()
      if p.kind == "hearthstone" then
        AddLine("quest", "Hearthstone location declined.")
      elseif p.kind == "groupInvite" then
        AddLine("quest", "Group invite declined.")
      elseif p.kind == "duelRequest" then
        AddLine("quest", "Duel declined.")
      elseif p.kind == "deleteItem" then
        AddLine("loot", "Item deletion declined.")
      end
    else
      AddLine("system", string.format("%s decline button not accessible.", p.title))
    end
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
  if panel:IsShown() then 
    panel:Hide()
    if ChatFrame1 then ChatFrame1:Show() end
  else 
    panel:Show()
  end
end

function TA_FocusTerminalInput()
  panel:Show()
  panel.inputBox:Show()
  panel.inputBox:SetFocus()
  AddLine("system", "Terminal input ready.")
end

function TA_SendFromTerminal(msg)
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

function TA_ShowHelpOverview()
  AddLine("system", "Text Adventurer help topics:")
  AddLine("system", "  combat - damage, stats, range, spacing")
  AddLine("system", "  navigation - cells, marks, map overlay")
  AddLine("system", "  quests - quest, gossip, trainer flows")
  AddLine("system", "  automation - auto behaviors and text mode")
  AddLine("system", "  economy - bags, gear, vendor, buying/selling")
  AddLine("system", "  social - chat and targeting shortcuts")
  AddLine("system", "  advanced - macros, bindings, diagnostics")
  AddLine("system", "Type: help <topic>. Example: help navigation")
end

function TA_ShowHelpTopic(topicArg)
  local raw = (topicArg or ""):match("^%s*(.-)%s*$"):lower()
  if raw == "" or raw == "all" or raw == "commands" or raw == "topics" then
    TA_ShowHelpOverview()
    return
  end

  local key = raw
  if raw == "dps" or raw == "battle" then key = "combat" end
  if raw == "nav" or raw == "cells" or raw == "map" then key = "navigation" end
  if raw == "quest" or raw == "npc" then key = "quests" end
  if raw == "auto" then key = "automation" end
  if raw == "inventory" or raw == "vendor" then key = "economy" end
  if raw == "chat" then key = "social" end
  if raw == "macros" then key = "advanced" end

  if key == "combat" then
    AddLine("system", "Help: Combat & Stats")
    AddLine("system", "  status - health and current resource summary.")
    AddLine("system", "  stats - full character stat breakdown.")
    AddLine("system", "  dps - fight DPS, session DPS, and weapon DPS.")
    AddLine("system", "  dps reset - clear recorded DPS history.")
    AddLine("system", "  weapondps - main-hand and off-hand auto-attack DPS.")
    AddLine("system", "  range - approximate distance to your target.")
    AddLine("system", "  behind/backstab - positional check for rear attacks.")
    AddLine("system", "  marka, markb, spacing - geometric pull spacing estimate.")
    return
  end

  if key == "navigation" then
    AddLine("system", "Help: Navigation & Cells")
    AddLine("system", "  where - current zone/subzone and facing.")
    AddLine("system", "  markcell [name] - mark your current location cell.")
    AddLine("system", "  markedcells/listmarks - list saved cell marks.")
    AddLine("system", "  renamemark/renamecell <id> <name> - rename a marked cell.")
    AddLine("system", "  showmark <id> - highlight one mark on world map overlay.")
    AddLine("system", "  clearmarks - delete all saved marks.")
    AddLine("system", "  cell - current cell bounds and position-in-cell.")
    AddLine("system", "  cellsize <n|standard|inn> - grid-based cell sizing.")
    AddLine("system", "  cellyards <yards|off> - fixed-distance sizing across maps.")
    AddLine("system", "  cellcal [yards list] - test and recommend yard sizes for this map.")
    AddLine("system", "  cellanchor - recenter current grid on where you stand.")
    AddLine("system", "  cellmap on/off - world map cell overlay toggle.")
    AddLine("system", "  map - print an ASCII local map.")
    AddLine("system", "  map on/off - auto-print ASCII map on cell changes.")
    AddLine("system", "  dfmode/df [on/off] - toggle Dwarf Fortress tactical map window.")
    AddLine("system", "  df tactical/threat/exploration/combined - switch DF mode view.")
    AddLine("system", "  df hybrid or df all - alias for combined view.")
    AddLine("system", "  df profile balanced|full - balanced is fuzzier, full is precise.")
    AddLine("system", "  df orientation fixed|rotating - fixed keeps map north-up (default), rotating follows heading.")
    AddLine("system", "  df rotation smooth|octant - smooth turns freely; octant keeps geometry squarer.")
    AddLine("system", "  df square on/off - alias for octant/smooth rotation.")
    AddLine("system", "  df size <width> <height> - set DF window size by command.")
    AddLine("system", "  df grid <n> - set DF grid cell count (odd number 5-99).")
    AddLine("system", "  df markradius <0-max> - set how far mark edges extend from M.")
    AddLine("system", "  df status - print zone, facing, legend, and threat summary to chat.")
    AddLine("system", "  df sonar - show sonar settings and active contact count.")
    AddLine("system", "  df sonar ping [seconds] - temporarily amplify exact-contact sonar echoes (1-20s).")
    AddLine("system", "  df sonar ttl <seconds> - keep sonar echoes longer after contact (1-60s).")
    AddLine("system", "  df sonar clear - clear remembered sonar echoes immediately.")
    AddLine("system", "  route start <name>, route stop - record your movement path.")
    AddLine("system", "  route list/show/clear <name> - manage saved routes.")
    AddLine("system", "  route follow <name>, route follow off - text navigation prompts.")
    AddLine("system", "  explore - exploration memory and recent path output.")
    return
  end

  if key == "quests" then
    AddLine("system", "Help: Quests & NPC")
    AddLine("system", "  quests - quest log summary.")
    AddLine("system", "  questinfo <index or name> - detailed quest info.")
    AddLine("system", "  gossip, choose <n> - navigate gossip without mouse.")
    AddLine("system", "  complete/turnin - complete active quest interaction.")
    AddLine("system", "  rewards, select <n>, reward <n> - choose turn-in rewards.")
    AddLine("system", "  rewardinfo <n> - inspect stats/details for one reward.")
    AddLine("system", "  prompts, accept <n>, decline <n> - handle popup dialogs.")
    AddLine("system", "  trainer, train <n>, train all - trainer service commands.")
    return
  end

  if key == "automation" then
    AddLine("system", "Help: Automation")
    AddLine("system", "  autoquests on/off - automatic quest handling.")
    AddLine("system", "  chat on/off - narration of chat traffic.")
    AddLine("system", "  autostart on/off - auto-enable on login.")
    AddLine("system", "  settings - view common game settings.")
    AddLine("system", "  set <name> <value> - shortcuts + direct CVar set.")
    AddLine("system", "  cvar <name> - read any CVar value.")
    AddLine("system", "  cvar <name> <value> - set any CVar value.")
    AddLine("system", "  cvarlist [filter] - print console CVar list to terminal.")
    AddLine("system", "  textmode on/off - immersive black-screen text mode.")
    return
  end

  if key == "economy" then
    AddLine("system", "Help: Inventory & Economy")
    AddLine("system", "  inventory/bags - bag contents and free space.")
    AddLine("system", "  gear/equipment - equipped items summary.")
    AddLine("system", "  equip <item name> - equip an item by name.")
    AddLine("system", "  equip <bag> <slot> - equip a specific bag item.")
    AddLine("system", "  money/gold/coins - show your current currency.")
    AddLine("system", "  readitem - read an open readable item, or readitem <bag> <slot>.")
    AddLine("system", "  vendor/shop - vendor inventory overview.")
    AddLine("system", "  vendorinfo <n> - inspect vendor item details before buying.")
    AddLine("system", "  buycheck <n> [qty] - check affordability before buying.")
    AddLine("system", "  buy <n> [qty] - purchase vendor items.")
    AddLine("system", "  buyback - list sold items available for buyback.")
    AddLine("system", "  buyback <index> - buy back a sold item by index.")
    AddLine("system", "  sell <bag> <slot> - sell an item from bag slot.")
    AddLine("system", "  destroy <bag> <slot> - destroy an item from bag slot.")
    AddLine("system", "  selljunk - sell all gray-quality bag items to vendor.")
    AddLine("system", "  restock <item name> <count> - buy items from vendor up to target count.")
    AddLine("system", "  repair - repair equipped gear at current vendor.")
    AddLine("system", "  repair guild - repair using guild funds if available.")
    AddLine("system", "  repairstatus - show repair cost and affordability.")
    return
  end

  if key == "social" then
    AddLine("system", "Help: Chat & Social")
    AddLine("system", "  Use slash chat in text input: /s, /p, /g, /w, /raid, /rw.")
    AddLine("system", "  who <query> - run /who and print results in the text log.")
    AddLine("system", "  who - show the current /who result list.")
    AddLine("system", "  target nearest/next/corpse/<name> - targeting shortcuts.")
    AddLine("system", "  input (or just /ta) - focus terminal input quickly.")
    AddLine("system", "  clear - clear the addon text log.")
    return
  end

  if key == "advanced" then
    AddLine("system", "Help: Advanced & Diagnostics")
    AddLine("system", "  actions/bars - action bar slot report.")
    AddLine("system", "  spells/spellbook - spellbook summary.")
    AddLine("system", "  macros - list all macros.")
    AddLine("system", "  macro <index|name> - run a macro by index or name.")
    AddLine("system", "  macroinfo <index> - inspect macro body and details.")
    AddLine("system", "  macroset <index> <body> - update macro body.")
    AddLine("system", "  macrorename <index> <name> - rename a macro.")
    AddLine("system", "  macrocreate <name> <body> - create new macro.")
    AddLine("system", "  macrodelete <index> - delete a macro.")
    AddLine("system", "  bind <slot> <spellbook idx> - put spellbook spell on action bar.")
    AddLine("system", "  bindmacro <slot> <macro idx> - put macro on action bar.")
    AddLine("system", "  binditem <slot> <bag> <slot> - put bag item on action bar.")
    AddLine("system", "  debug/debugpopups - show popup dialog diagnostics.")
    AddLine("system", "  settings - view current game cvars/settings.")
    AddLine("system", "  set <name> <value> - quick-set game settings by name.")
    AddLine("system", "  cvar <name> - read a specific cvar value.")
    AddLine("system", "  cvar <name> <value> - set a specific cvar value.")
    AddLine("system", "  cvarlist [filter] - print full console cvar list to terminal.")
    AddLine("system", "  textmode on/off - toggle immersive black-screen text mode.")
    AddLine("system", "  autostart on/off - auto-load addon on login.")
    AddLine("system", "  input - focus text input quickly (same as /ta input).")
    AddLine("system", "  hide/show/toggle - hide/show the text panel.")
    AddLine("system", "  clear - clear the addon text log.")
    return
  end

  AddLine("system", string.format("Unknown help topic '%s'.", topicArg or ""))
  TA_ShowHelpOverview()
end

TA.EXACT_INPUT_HANDLERS = {
  ["health"] = function() ReportStatus(true) end,
  ["hp"] = function() ReportStatus(true) end,
  ["rage"] = function() ReportStatus(true) end,
  ["status"] = function() ReportStatus(true) end,
  ["stats"] = function() ReportCharacterStats() end,
  ["money"] = function() ReportMoney() end,
  ["gold"] = function() ReportMoney() end,
  ["coins"] = function() ReportMoney() end,
  ["dps"] = function() ReportDPS() end,
  ["dps reset"] = function() ResetDPSStats() end,
  ["weapondps"] = function() ReportWeaponDPS() end,
  ["weapon dps"] = function() ReportWeaponDPS() end,
  ["where"] = function() ReportLocation(true) end,
  ["location"] = function() ReportLocation(true) end,
  ["xp"] = function() ReportXP() end,
  ["level"] = function() ReportXP() end,
  ["buffs"] = function() ReportBuffs() end,
  ["quests"] = function() ReportQuestLog() end,
  ["questlog"] = function() ReportQuestLog() end,
  ["quest log"] = function() ReportQuestLog() end,
  ["questinfo"] = function() ReportQuestInfo(nil) end,
  ["tracking"] = function() ReportTracking() end,
  ["inventory"] = function() ReportInventory() end,
  ["bags"] = function() ReportInventory() end,
  ["gear"] = function() ReportEquipment() end,
  ["equipment"] = function() ReportEquipment() end,
  ["actions"] = function() ReportActionBars() end,
  ["bars"] = function() ReportActionBars() end,
  ["spells"] = function() ReportSpellbook() end,
  ["spellbook"] = function() ReportSpellbook() end,
  ["macros"] = function() ReportMacros() end,
  ["trainer"] = function() ReportTrainerServices() end,
  ["train list"] = function() ReportTrainerServices() end,
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
  ["gossip"] = function() ReportGossipOptions() end,
  ["complete"] = function() CompleteQuestFromTerminal() end,
  ["turnin"] = function() CompleteQuestFromTerminal() end,
  ["rewards"] = function() ListQuestRewards() end,
  ["rewardinfo"] = function() AddLine("system", "Usage: rewardinfo <index>") end,
  ["prompts"] = function() ReportStaticPopups() end,
  ["debug"] = function() DebugVisiblePopups() end,
  ["debugpopups"] = function() DebugVisiblePopups() end,
  ["vendor"] = function() ReportVendorItems() end,
  ["shop"] = function() ReportVendorItems() end,
  ["vendorinfo"] = function() AddLine("system", "Usage: vendorinfo <index>") end,
  ["shopinfo"] = function() AddLine("system", "Usage: shopinfo <index>") end,
  ["iteminfo"] = function() AddLine("system", "Usage: iteminfo <index> (while vendor is open)") end,
  ["buycheck"] = function() AddLine("system", "Usage: buycheck <index> [qty]") end,
  ["readitem"] = function()
    if ItemTextFrame and ItemTextFrame:IsShown() then
      TA_ReportOpenItemText(true)
    else
      AddLine("system", "Usage: readitem <bag> <slot> (or open a readable item first, then use readitem).")
    end
  end,
  ["range"] = function() ReportRange() end,
  ["clear"] = function()
    wipe(TA.lines)
    panel.text:Clear()
    AddLine("system", "Log cleared.")
  end,
  ["help"] = function() TA_ShowHelpOverview() end,
}

TA.PATTERN_INPUT_HANDLERS = {
  { "^help%s+(.+)$", function(topic) TA_ShowHelpTopic(topic) end },
  { "^questinfo%s+(.+)$", function(arg) ReportQuestInfo(arg) end },
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
  { "^bind%s+(%d+)%s+(%d+)$", function(slot, spellIndex) BindSpellbookSpellToActionSlot(tonumber(slot), tonumber(spellIndex)) end },
  { "^bindmacro%s+(%d+)%s+(%d+)$", function(slot, macroIndex) BindMacroToActionSlot(tonumber(slot), tonumber(macroIndex)) end },
  { "^target%s+(.+)$", function(arg) DoTargetCommand(arg) end },
  { "^markcell%s+(.+)$", function(name) MarkCurrentCell(name) end },
  { "^mark cell%s+(.+)$", function(name) MarkCurrentCell(name) end },
  { "^cellsize%s+(%d+)$", function(size) SetGridSize(tonumber(size)) end },
  { "^cellcal%s+(.+)$", function(args) TA_ReportCellYardsCalibration(args) end },
  { "^cellyards%s+([%d%.]+)$", function(yards) SetCellSizeYards(tonumber(yards)) end },
  { "^showmark%s+(%d+)$", function(markID) ShowMarkedCellOnMap(tonumber(markID)) end },
  { "^renamemark%s+(%d+)%s+(.+)$", function(markID, newName) TA_RenameMarkedCell(tonumber(markID), newName) end },
  { "^choose%s+(%d+)$", function(idx) ChooseGossipOption(tonumber(idx)) end },
  { "^select%s+(%d+)$", function(idx) SelectQuestReward(tonumber(idx)) end },
  { "^rewardinfo%s+(%d+)$", function(idx) ReportQuestRewardInfo(tonumber(idx)) end },
  { "^reward%s+(%d+)$", function(idx)
      idx = tonumber(idx)
      SelectQuestReward(idx)
      GetQuestRewardChoice(idx)
    end },
  { "^accept%s+(%d+)$", function(idx) RespondToPopup(tonumber(idx), "accept") end },
  { "^decline%s+(%d+)$", function(idx) RespondToPopup(tonumber(idx), "decline") end },
  { "^buy%s+(%d+)$", function(idx) BuyVendorItem(tonumber(idx), 1) end },
  { "^buy%s+(%d+)%s+(%d+)$", function(idx, qty) BuyVendorItem(tonumber(idx), tonumber(qty)) end },
  { "^buycheck%s+(%d+)$", function(idx) TA_CheckVendorPurchase(tonumber(idx), 1) end },
  { "^buycheck%s+(%d+)%s+(%d+)$", function(idx, qty) TA_CheckVendorPurchase(tonumber(idx), tonumber(qty)) end },
  { "^sell%s+(%d+)%s+(%d+)$", function(bag, slot) SellBagItem(tonumber(bag), tonumber(slot)) end },
  { "^destroy%s+(%d+)%s+(%d+)$", function(bag, slot) DestroyBagItem(tonumber(bag), tonumber(slot)) end },
  { "^vendorinfo%s+(%d+)$", function(idx) TA_ReportVendorItemDetails(tonumber(idx)) end },
  { "^shopinfo%s+(%d+)$", function(idx) TA_ReportVendorItemDetails(tonumber(idx)) end },
  { "^iteminfo%s+(%d+)$", function(idx) TA_ReportVendorItemDetails(tonumber(idx)) end },
  { "^readitem%s+(-?%d+)%s+(%d+)$", function(bag, slot) TA_ReadBagItemText(tonumber(bag), tonumber(slot)) end },
}

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
  if lower == "renamecell" then
    lower = "renamemark"
  elseif lower:find("^renamecell%s+") then
    lower = "renamemark " .. (lower:match("^renamecell%s+(.+)$") or "")
  end
  if lower == "equip" then
    AddLine("system", "Usage: equip <item name> or equip <bag> <slot>")
    return
  end

  if lower == "repair" then
    TA_RepairVendorGear(false)
    return
  elseif lower == "repair guild" then
    TA_RepairVendorGear(true)
    return
  elseif lower == "repairstatus" then
    TA_ReportRepairStatus()
    return
  elseif lower == "selljunk" then
    TA_SellJunk()
    return
  elseif lower == "restock" then
    AddLine("system", "Usage: restock <item name> <count>")
    return
  end

  local restockItemName, restockCount = lower:match("^restock%s+(.+)%s+(%d+)$")
  if restockItemName and restockCount then
    TA_RestockVendorItem(restockItemName, tonumber(restockCount))
    return
  end

  if lower == "buyback" then
    TA_ReportVendorBuybackItems()
    return
  end
  local buybackIndex = lower:match("^buyback%s+(%d+)$")
  if buybackIndex then
    TA_BuybackVendorItem(tonumber(buybackIndex))
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

panel.inputBox:EnableKeyboard(true)
panel.inputBox:SetScript("OnEnterPressed", function(self)
  local msg = self:GetText()
  if msg and msg ~= "" then
    AddLine("system", "> " .. msg)
    table.insert(TA.inputHistory, msg)
    if #TA.inputHistory > TA.inputHistoryMax then table.remove(TA.inputHistory, 1) end
    TA.inputHistoryPos = 0
    TA.inputDraft = ""
  end
  self:SetText("")
  TA_ProcessInputCommand(msg)
  self:SetFocus()
end)
panel.inputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
panel.inputBox:SetScript("OnKeyDown", function(self, key)
  if key == "UP" then
    if TA.inputHistoryPos == 0 then
      TA.inputDraft = self:GetText()
    end
    local newPos = math.min(TA.inputHistoryPos + 1, #TA.inputHistory)
    if newPos ~= TA.inputHistoryPos and #TA.inputHistory > 0 then
      TA.inputHistoryPos = newPos
      self:SetText(TA.inputHistory[#TA.inputHistory - newPos + 1])
      self:SetCursorPosition(#self:GetText())
    end
  elseif key == "DOWN" then
    if TA.inputHistoryPos > 0 then
      TA.inputHistoryPos = TA.inputHistoryPos - 1
      if TA.inputHistoryPos == 0 then
        self:SetText(TA.inputDraft or "")
      else
        self:SetText(TA.inputHistory[#TA.inputHistory - TA.inputHistoryPos + 1])
      end
      self:SetCursorPosition(#self:GetText())
    end
  end
end)

SLASH_TEXTADVENTURER1 = "/ta"
rawset(SlashCmdList, "TEXTADVENTURER", function(msg)
  local original = (msg or ""):match("^%s*(.-)%s*$")
  local lower = original:lower()
  if lower == "" then
    TA_FocusTerminalInput()
  elseif lower == "show" then
    panel:Show()
    AddLine("system", "Text Adventurer opened.")
  elseif lower == "input" or lower == "i" or lower == "t" then
    TA_FocusTerminalInput()
  elseif lower == "hide" then
    panel:Hide()
    if ChatFrame1 then ChatFrame1:Show() end
  elseif lower == "toggle" then
    TogglePanel()
  elseif lower == "textmode on" then
    EnableTextMode()
  elseif lower == "textmode off" then
    DisableTextMode()
  elseif lower == "autostart on" then
    TextAdventurerDB.autoEnable = true
    AddLine("system", "Autostart enabled.")
  elseif lower == "autostart off" then
    TextAdventurerDB.autoEnable = false
    AddLine("system", "Autostart disabled.")
  else
    TA_ProcessInputCommand(original)
  end
end)

TA:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}
    TextAdventurerDB.routes = type(TextAdventurerDB.routes) == "table" and TextAdventurerDB.routes or {}
    TextAdventurerDB.markedCells = TextAdventurerDB.markedCells or {}
    TextAdventurerDB.cellAnchors = type(TextAdventurerDB.cellAnchors) == "table" and TextAdventurerDB.cellAnchors or {}
    local savedGridSize = tonumber(TextAdventurerDB.gridSize)
    if not savedGridSize
      or savedGridSize == GRID_SIZE_LEGACY_DEFAULT
      or savedGridSize == 42
      or savedGridSize == 51
      or savedGridSize == 64
      or savedGridSize == 72
      or savedGridSize == 80 then
      TextAdventurerDB.gridSize = GRID_SIZE_DEFAULT
    else
      TextAdventurerDB.gridSize = math.floor(savedGridSize)
    end
    TA.gridSize = TextAdventurerDB.gridSize
    local savedCellMode = TextAdventurerDB.cellSizeMode
    local savedCellYards = tonumber(TextAdventurerDB.cellSizeYards)
    if savedCellMode == "grid" then
      TA.cellSizeMode = "grid"
      TA.cellSizeYards = nil
      TextAdventurerDB.cellSizeMode = "grid"
      TextAdventurerDB.cellSizeYards = nil
    elseif savedCellMode == "yards" and savedCellYards and savedCellYards >= CELL_YARDS_MIN and savedCellYards <= CELL_YARDS_MAX then
      TA.cellSizeMode = "yards"
      TA.cellSizeYards = math.floor(savedCellYards + 0.5)
      TextAdventurerDB.cellSizeMode = "yards"
      TextAdventurerDB.cellSizeYards = TA.cellSizeYards
    else
      TA.cellSizeMode = "yards"
      TA.cellSizeYards = CELL_YARDS_STANDARD
      TextAdventurerDB.cellSizeMode = "yards"
      TextAdventurerDB.cellSizeYards = CELL_YARDS_STANDARD
    end
    TA.cellAnchors = TextAdventurerDB.cellAnchors
    if TextAdventurerDB.mapOverlayEnabled == nil then
      TextAdventurerDB.mapOverlayEnabled = true
    end
    TA.mapOverlayEnabled = TextAdventurerDB.mapOverlayEnabled and true or false
    if TextAdventurerDB.asciiMapEnabled == nil then
      TextAdventurerDB.asciiMapEnabled = false
    end
    TA.asciiMapEnabled = TextAdventurerDB.asciiMapEnabled and true or false
    if TextAdventurerDB.dfModeEnabled == nil then
      TextAdventurerDB.dfModeEnabled = false
    end
    TA.dfModeEnabled = TextAdventurerDB.dfModeEnabled and true or false
    if TextAdventurerDB.dfModeProfile ~= "full" and TextAdventurerDB.dfModeProfile ~= "balanced" then
      TextAdventurerDB.dfModeProfile = "full"
    end
    TA.dfModeProfile = TextAdventurerDB.dfModeProfile
    if TextAdventurerDB.dfModeOrientation ~= "fixed" and TextAdventurerDB.dfModeOrientation ~= "rotating" then
      TextAdventurerDB.dfModeOrientation = "fixed"
    end
    TA.dfModeOrientation = TextAdventurerDB.dfModeOrientation
    if TextAdventurerDB.dfModeRotationMode ~= "smooth" and TextAdventurerDB.dfModeRotationMode ~= "octant" then
      TextAdventurerDB.dfModeRotationMode = "smooth"
    end
    TA.dfModeRotationMode = TextAdventurerDB.dfModeRotationMode
    if type(TextAdventurerDB.dfModeGridSize) == "number" then
      local savedGrid = math.floor(TextAdventurerDB.dfModeGridSize)
      if savedGrid < 5 then savedGrid = 5 end
      if savedGrid > 99 then savedGrid = 99 end
      if savedGrid % 2 == 0 then savedGrid = savedGrid + 1 end
      TA.dfModeGridSize = savedGrid
    end
    local isFirstRunSafeMode = (TextAdventurerDB.firstRunSafetyAcknowledged ~= true)
    if isFirstRunSafeMode then
      TextAdventurerDB.dfModeWidth = DF_MODE_DEFAULT_WIDTH
      TextAdventurerDB.dfModeHeight = DF_MODE_DEFAULT_HEIGHT
    end
    local maxMarkRadius = math.floor((TA.dfModeGridSize or 35) / 2)
    if type(TextAdventurerDB.dfModeMarkRadius) ~= "number" or TextAdventurerDB.dfModeMarkRadius > 5 then
      -- Reset oversized values (e.g. old default of 17) to default perimeter of 3.
      TextAdventurerDB.dfModeMarkRadius = 3
    end
    TA_SetDFModeMarkRadius(TextAdventurerDB.dfModeMarkRadius, true)
    if type(TextAdventurerDB.dfModeWidth) ~= "number" or type(TextAdventurerDB.dfModeHeight) ~= "number" then
      TextAdventurerDB.dfModeWidth = DF_MODE_DEFAULT_WIDTH
      TextAdventurerDB.dfModeHeight = DF_MODE_DEFAULT_HEIGHT
    end
    TA_SetDFModeSize(TextAdventurerDB.dfModeWidth, TextAdventurerDB.dfModeHeight, true)
    if TA.dfModeEnabled then
      dfModeFrame:Show()
      TA_UpdateDFMode()
    end
    TA.markedCells = TextAdventurerDB.markedCells
    -- Calculate the next mark ID from existing marks
    TA.nextMarkID = 1
    for _, mark in pairs(TA.markedCells) do
      if mark.id and mark.id >= TA.nextMarkID then
        TA.nextMarkID = mark.id + 1
        TA.activeMapMarkID = mark.id
      end
    end
    if isFirstRunSafeMode then
      TextAdventurerDB.autoEnable = false
      TextAdventurerDB.firstRunSafetyAcknowledged = true
    elseif TextAdventurerDB.autoEnable == nil then
      TextAdventurerDB.autoEnable = false
    end
    if ChatFrame1 then
      ChatFrame1:Show()
      ChatFrame1:SetFrameLevel(5000)
    end
    if TextAdventurerDB.autoEnable then
      panel:Show()
    else
      panel:Hide()
    end
    TA.bagState = SnapshotBags()
    TA.lastBuffSnapshot = SnapshotBuffs()
    TA.questObjectiveSnapshot = BuildQuestObjectiveSnapshot()
    TA.dpsSessionStart = GetTime()
    TA.dpsTotalDamage = TA.dpsTotalDamage or 0
    TA.dpsCombatStart = 0
    TA.dpsCombatDamage = 0
    TA.lastCombatDamage = TA.lastCombatDamage or 0
    TA.lastCombatDuration = TA.lastCombatDuration or 0
    ResetSwingTimer()
    AddLine("system", "You enter the world.")
    AddLine("system", "WARNING: This addon is extremely dangerous and WILL eventually get your character killed.")
    AddLine("system", "WARNING: First-run safety mode starts with autostart OFF. Use /ta autostart on only after reviewing /ta help.")
    AddLine("system", "Type /ta textmode on for full black-screen text mode.")
    AddLine("system", "Type /ta status for health and rage.")
    AddLine("system", "Type /ta xp for experience.")
    AddLine("system", "Type /ta quests to list your quest log.")
    AddLine("system", "Type /ta questinfo <index or name> to read full quest details.")
    AddLine("system", "Type /ta buffs to list your current buffs and timers.")
    AddLine("system", "Type /ta where for your current place.")
    AddLine("system", "Type /ta tracking for active tracking modes.")
    AddLine("system", "Type /ta explore for exploration memory.")
    AddLine("system", "Type /ta spells to list your spellbook.")
    AddLine("quest", "At NPC dialogue, use /ta gossip then /ta choose <number> to navigate options without clicking.")
    AddLine("system", "Type /ta trainer to list trainable abilities.")
    AddLine("system", "Type /ta bind 1 3 to place a spellbook entry on an action slot.")
    AddLine("system", "Type /ta target nearest, /ta target next, /ta target corpse, or /ta target <name>.")
    AddLine("system", "Type /ta marka, /ta markb, then /ta spacing for a geometric spacing estimate.")
    AddLine("system", "The spacing estimate can be used for hostile or friendly targets you can point at.")
    AddLine("system", "Type /ta markcell or just 'markcell' in text mode to mark your current grid cell for navigation.")
    AddLine("system", "Type /ta markedcells to list marked cells.")
    AddLine("system", "Type /ta markcell 'My Location' to give it a custom name.")
    AddLine("system", "Type /ta cell to view current cell bounds and size.")
    AddLine("system", string.format("Fixed-distance cell mode is default at %d yards.", CELL_YARDS_STANDARD))
    AddLine("system", string.format("Standard marked-cell size is now %dx%d for building-sized places like inns.", GRID_SIZE_STANDARD, GRID_SIZE_STANDARD))
    AddLine("system", "Type /ta cellsize inn to use the standard inn-sized preset.")
    AddLine("system", "Type /ta cellsize 120 or /ta cellsize 48 to fine-tune it (range 8-240).")
    AddLine("system", "Type /ta cellyards 40 for fixed-distance cells across maps, or /ta cellyards off to return to grid mode.")
    AddLine("system", "Type /ta cellanchor to recenter the current grid on where you stand.")
    AddLine("system", "ASCII map is off by default. Type /ta map on to auto-show it, or /ta map for one snapshot.")
    AddLine("system", "Route recorder: /ta route start <name>, then /ta route stop. Use /ta route follow <name> for guidance.")
    AddLine("system", "In text mode, you can also type commands directly in the input box without /ta.")
    AddLine("system", "Smoothed movement and backtracking narration are enabled automatically.")
    AddLine("system", "Type /ta input if you ever need to refocus the terminal.")
    AddLine("system", "Player and target spellcasts are narrated automatically.")
    AddLine("quest", "Auto quests are enabled by default. Use /ta autoquests off to disable.")
    AddLine("chat", "Chat capture is enabled by default. Use /ta chat off to disable.")
    AddLine("system", "Enemy awareness is always on when nameplates exist.")
    AddLine("system", "Type /ta help for commands.")
    TA_BroadcastDangerWarningToChat()
    ReportLocation(true)
    CheckLandmarkEntry()
    ReportStatus(true)
    UpdateMapCellOverlay()
    UpdateExplorationMemory()
    UpdateRecentPath()
    ReportExplorationMemory(true)
    ReportPathMemory(true)
    if not TA.moveTicker then
      TA.moveTicker = C_Timer.NewTicker(0.05, function()
        CheckMovement()
        CheckFallState()
        CheckWallHeuristic()
        CheckSwingTimer()
      end)
    end
    if not TA.awarenessNearbyTicker then
      TA.awarenessNearbyTicker = C_Timer.NewTicker(0.1, function()
        CheckAwareness()
      end)
    end
    if not TA.awarenessMemoryTicker then
      TA.awarenessMemoryTicker = C_Timer.NewTicker(0.1, function()
        UpdateExplorationMemory()
        UpdateRecentPath()
        ReportExplorationMemory(false)
        ReportPathMemory(false)
        TA_ReportAsciiMap(false, false)
        UpdateMapCellOverlay()
        -- Track recent cells for DF mode
        local mapID, cellX, cellY = GetPlayerMapCell()
        if mapID and cellX and cellY then
          TA.dfModeRecentCells[0] = TA.dfModeRecentCells[0] or {}
          TA.dfModeRecentCells[0][0] = true
          -- Add adjacent cells as well
          for dy = -1, 1 do
            if not TA.dfModeRecentCells[dy] then TA.dfModeRecentCells[dy] = {} end
            for dx = -1, 1 do
              TA.dfModeRecentCells[dy][dx] = true
            end
          end
        end
      end)
    end
    if not TA.dfModeTicker then
      TA.dfModeTicker = C_Timer.NewTicker(0.05, function()
        TA_UpdateDFMode()
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
    TA.dpsCombatStart = GetTime()
    TA.dpsCombatDamage = 0
    AddLine("playerCombat", "You enter combat.")
    ShowWarningMessage("UNDER ATTACK!")
    ReportStatus(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if TA.dpsCombatStart and TA.dpsCombatStart > 0 then
      local dur = math.max(0.001, GetTime() - TA.dpsCombatStart)
      TA.lastCombatDuration = dur
      TA.lastCombatDamage = TA.dpsCombatDamage or 0
      TA.dpsCombatStart = 0
      TA.dpsCombatDamage = 0
      AddLine("playerCombat", string.format("Fight summary: %.1f DPS (%d damage over %.1fs)", (TA.lastCombatDamage or 0) / dur, math.floor((TA.lastCombatDamage or 0) + 0.5), dur))
    end
    AddLine("playerCombat", "You leave combat.")
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
  elseif event == "MERCHANT_SHOW" then
    TA.vendorOpen = true
    AddLine("loot", "A merchant opens their wares. Type 'vendor' to browse, 'buy <n>', 'buyback [n]', 'sell <bag> <slot>', 'selljunk', or 'repair'/'repairstatus'.")
    ReportVendorItems()
  elseif event == "WHO_LIST_UPDATE" then
    TA_ReportWhoList()
  elseif event == "MERCHANT_CLOSED" then
    TA.vendorOpen = false
    AddLine("loot", "The merchant closes their wares.")
  elseif event == "GOSSIP_SHOW" then
    TryAutoQuestFromGossip()
    ReportGossipOptions()
  elseif event == "QUEST_GREETING" then
    TryAutoQuestFromGossip()
    ReportGossipOptions()


  elseif event == "TRAINER_SHOW" then
    AddLine("quest", "Trainer opened. Type trainer, train 1, or train all.")
  elseif event == "LOOT_CLOSED" then
    AddLine("loot", "You finish looting.")
  elseif event == "ITEM_TEXT_BEGIN" or event == "ITEM_TEXT_READY" then
    TA_ReportOpenItemText(false)
  elseif event == "ITEM_TEXT_CLOSED" then
    TA.pendingItemTextRead = nil
    TA.lastItemTextSignature = nil
  elseif event == "QUEST_DETAIL" then
    TryAcceptQuest()
  elseif event == "QUEST_PROGRESS" then
    TryCompleteQuest()
  elseif event == "QUEST_COMPLETE" then
    TryGetQuestReward()
  elseif event == "QUEST_LOG_UPDATE" then
    ReportQuestObjectiveChanges()
  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
    ReportLocation(true)
    CheckLandmarkEntry()
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
  elseif event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" then
      ReportBuffChanges()
    end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    local slotId = ...
    ReportEquipmentChange(slotId)
  elseif event == "UNIT_ATTACK_SPEED" then
    local unit = ...
    if unit == "player" then
      ResetSwingTimer()
    end
  elseif event == "UNIT_POWER_UPDATE" then
    local unit = ...
    if unit == "player" then ReportStatus(false) end
  end
end)

TA:RegisterEvent("PLAYER_MONEY")
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
TA:RegisterEvent("ITEM_TEXT_BEGIN")
TA:RegisterEvent("ITEM_TEXT_READY")
TA:RegisterEvent("ITEM_TEXT_CLOSED")
TA:RegisterEvent("BAG_UPDATE_DELAYED")
TA:RegisterEvent("GOSSIP_SHOW")
TA:RegisterEvent("QUEST_GREETING")
TA:RegisterEvent("TRAINER_SHOW")
TA:RegisterEvent("QUEST_DETAIL")
TA:RegisterEvent("QUEST_PROGRESS")
TA:RegisterEvent("QUEST_COMPLETE")
TA:RegisterEvent("QUEST_LOG_UPDATE")
TA:RegisterEvent("ZONE_CHANGED")
TA:RegisterEvent("ZONE_CHANGED_INDOORS")
TA:RegisterEvent("ZONE_CHANGED_NEW_AREA")
TA:RegisterEvent("UNIT_HEALTH")
TA:RegisterEvent("UNIT_AURA")
TA:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
TA:RegisterEvent("UNIT_ATTACK_SPEED")
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
TA:RegisterEvent("CHAT_MSG_SYSTEM")
TA:RegisterEvent("MERCHANT_SHOW")
TA:RegisterEvent("MERCHANT_CLOSED")
TA:RegisterEvent("WHO_LIST_UPDATE")

TA.chatKeepAlive = C_Timer.NewTicker(2, function()
  if ChatFrame1 then
    if not ChatFrame1:IsShown() then
      ChatFrame1:Show()
    end
    if ChatFrame1:GetFrameStrata() ~= "LOW" then
      ChatFrame1:SetFrameStrata("LOW")
    end
  end
end)