-- TextAdventurer.lua
---@diagnostic disable: deprecated
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
BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"
BOOKTYPE_PET = BOOKTYPE_PET or "pet"

local function TA_IsSpellKnownCompat(spellID)
  if not IsSpellKnown or not spellID then
    return false
  end

  local ok, known = pcall(IsSpellKnown, spellID)
  if ok then
    return not not known
  end

  ok, known = pcall(IsSpellKnown, spellID, false)
  if ok then
    return not not known
  end

  return false
end

TextAdventurerDB = TextAdventurerDB or {}
TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}

TA = CreateFrame("Frame", "TextAdventurerFrame")
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
TA.warlockPromptTicker = nil
TA.warriorPromptTicker = nil
TA.lineLimit = 400
TA.lines = {}
TA.lastNearbySignature = nil
TA.awarenessDirty = true
TA.awarenessLastRunAt = 0
TA.awarenessEventMinInterval = 0.20
TA.awarenessFallbackInterval = 0.75
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
TA.lastInputBlock = nil
TA.isReplayingLastBlock = false
TA.lastSubzone = nil
TA.vendorOpen = false
TA.questObjectiveSnapshot = {}
TA.skillSnapshot = {}
TA.dpsSessionStart = 0
TA.dpsTotalDamage = 0
TA.dpsCombatStart = 0
TA.dpsCombatDamage = 0
TA.lastCombatDamage = 0
TA.lastCombatDuration = 0
TA.mlFightSnapshot = nil
TA.mlXPTrackerLastXP = nil
TA.mlXPTrackerLastXPMax = nil
TA.mlXPTrackerLastLevel = nil
TA.mlXPTrackerLastAt = 0
TA.mlXPTrackerAbsolute = 0
TA.mlXPSourceHints = {}
TA.lastCombatEndedAt = 0
TA.pendingItemTextRead = nil
TA.lastItemTextSignature = nil
TA.lastXPStatusBucket = nil
TA.lastMoneyCopper = nil
TA.sellJunkState = nil
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
TA.dfModeEnabled = true
TA.lastNearbyUnits = {}
TA.nearbyUnitsCacheAt = 0
TA.nearbyUnitsCacheInterval = 0.20
TA.dfModeGridSize = 35
TA.dfModeInnerRadius = nil
TA.dfModeInnerRadiusGridSize = nil
TA.dfModeLastUpdate = 0
TA.dfModeViewMode = "threat"  -- tactical, threat, exploration, combined
TA.dfModeProfile = "full"  -- balanced, full
TA.dfModeOrientation = "fixed"  -- fixed (north-up), rotating (heading-up)
TA.dfModeRotationMode = "smooth"  -- smooth, octant (45-degree snaps for squarer geometry)
TA.dfModeLookaheadSeconds = 0.15  -- short player-only projection to make DF cell transitions feel snappier
TA.dfModeHysteresisEnterPct = 0.42  -- enter next DF cell early, then require backing out farther before snapping back
TA.dfModeAnchorCellX = nil
TA.dfModeAnchorCellY = nil
TA.dfModeMarkRadius = 5  -- cells around mark center to draw edge ring (0 = center cell only)
TA.dfModeRecentCells = {}  -- Track recently visited cells for breadcrumb trail
TA.dfModeLastFacing = nil
TA.dfModeEnemyPatrols = {}  -- Track enemy positions over time
TA.dfModeShowLevelFilter = nil  -- nil = show all, number = threshold
TA.dfModeLastNearestMarkID = nil
TA.dfModeLastNearestMarkDist = nil
TA.dfModeLastKnownUnits = {}
TA.dfModeCorpseContacts = {}
TA.dfModeCorpseTTL = 45
TA.dfModeTerrainContext = nil
TA.dfModeTerrainStandingLabel = nil
TA.dfModeTerrainStandingShort = nil
TA.dfModeHueEnabled = true
TA.dfModeCalibrationEnabled = false
TA.dfModeLegendEnabled = true
TA.performanceModeEnabled = false
TA.performancePendingApply = false
TA.performanceHiddenFrames = {}
TA.performanceFrameHooks = {}
TA.tickerIntervals = { move = 0.2, nearby = 0.25, memory = 0.5, df = 0.15 }
TA.tickerIntervals.warlockPrompt = 0.75
local AWARENESS_SUBEVENTS = {
  SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true,
  SPELL_PERIODIC_DAMAGE = true, SPELL_BUILDING_DAMAGE = true,
  ENVIRONMENTAL_DAMAGE = true, DAMAGE_SHIELD = true, DAMAGE_SPLIT = true,
  SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true,
  SWING_MISSED = true, SPELL_MISSED = true,
  UNIT_DIED = true, UNIT_DESTROYED = true,
  PARTY_KILL = true,
}
TA.tickerIntervals.warriorPrompt = 0.75

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
  swingDance = { 0.20, 1.00, 1.00 },
}

-- Performance profiling system
TA.profiler = {
  data = {},
  enabled = false,
}

function TA:ProfileStart(label)
  if not self.profiler.enabled then return end
  if not self.profiler.data[label] then
    self.profiler.data[label] = { count = 0, totalMs = 0, maxMs = 0, minMs = 999999 }
  end
  self.profiler.data[label].__startTime = debugprofilestop()
end

function TA:ProfileEnd(label)
  if not self.profiler.enabled then return end
  local entry = self.profiler.data[label]
  if not entry or not entry.__startTime then return end
  local elapsed = debugprofilestop() - entry.__startTime
  entry.count = entry.count + 1
  entry.totalMs = entry.totalMs + elapsed
  entry.maxMs = math.max(entry.maxMs, elapsed)
  entry.minMs = math.min(entry.minMs, elapsed)
  entry.__startTime = nil
end

function TA:PrintProfiler()
  if not self.profiler.enabled then AddLine("system", "Profiler disabled") return end
  AddLine("system", "=== TextAdventurer Performance Profile ===")
  for label, data in pairs(self.profiler.data) do
    if data.count > 0 then
      local avg = data.totalMs / data.count
      AddLine("system", string.format("%s: %.2fms avg (%.2f min, %.2f max) - %d calls", 
        label, avg, data.minMs, data.maxMs, data.count))
    end
  end
end

function TA:EnableProfiler()
  self.profiler.enabled = true
  self.profiler.data = {}
  AddLine("system", "TextAdventurer profiler enabled")
end

function TA:DisableProfiler()
  self.profiler.enabled = false
  AddLine("system", "TextAdventurer profiler disabled")
end

local overlay = CreateFrame("Frame", "TextAdventurerOverlay", UIParent)
overlay:SetAllPoints(UIParent)
overlay:SetFrameStrata("FULLSCREEN_DIALOG")
overlay:SetFrameLevel(10000)
overlay:EnableMouse(false)
overlay:Hide()
overlay.__taCommandPreviewInit = nil
if overlay.commandPreviewBox then
  overlay.commandPreviewBox:Hide()
  overlay.commandPreviewBox = nil
end

overlay.tex = overlay:CreateTexture(nil, "BACKGROUND")
overlay.tex:SetAllPoints()
overlay.tex:SetColorTexture(0, 0, 0, 1)

function TA_InitCommandPreviewBox()
  if not overlay or overlay.__taCommandPreviewInit then return end
  local box = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
  box:SetSize(560, 34)
  box:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 24, 24)
  box:SetFrameStrata("FULLSCREEN_DIALOG")
  box:SetFrameLevel(12000)
  box:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(1, 1, 1, 1)
  box:SetBackdropBorderColor(0, 0, 0, 1)
  box:Hide()

  box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  box.text:SetPoint("LEFT", box, "LEFT", 8, 0)
  box.text:SetPoint("RIGHT", box, "RIGHT", -8, 0)
  box.text:SetJustifyH("LEFT")
  box.text:SetTextColor(0.05, 0.05, 0.05, 1)
  box.text:SetText("")

  overlay.commandPreviewBox = box
  overlay.__taCommandPreviewInit = true
end

function TA_FindActiveChatEditBox()
  local total = NUM_CHAT_WINDOWS or 10
  for i = 1, total do
    local chatFrame = _G["ChatFrame" .. i]
    local editBox = (chatFrame and chatFrame.editBox) or _G["ChatFrame" .. i .. "EditBox"]
    if editBox and editBox:IsShown() then
      return editBox
    end
  end
  return nil
end

function TA_UpdateCommandPreviewBox()
  if not TA or not TA.textMode or not overlay or not overlay:IsShown() then
    if overlay and overlay.commandPreviewBox then overlay.commandPreviewBox:Hide() end
    return
  end

  if not overlay.__taCommandPreviewInit then
    TA_InitCommandPreviewBox()
  end
  local editBox = TA_FindActiveChatEditBox()
  if not editBox then
    if overlay.commandPreviewBox then overlay.commandPreviewBox:Hide() end
    return
  end

  local txt = editBox:GetText() or ""
  if txt == "" then txt = "/" end
  if overlay.commandPreviewBox and overlay.commandPreviewBox.text then
    overlay.commandPreviewBox.text:SetText(txt)
    overlay.commandPreviewBox:Show()
  end
  if overlay.tex then overlay.tex:Show() end
  -- Defensive re-lift: Blizzard's chat code (ChatEdit_ActivateChat,
  -- ChatEdit_OnEditFocusGained) resets the edit box strata back to "DIALOG"
  -- after our hooks fire, which sinks it under the TOOLTIP-strata blackout.
  -- Re-apply every tick while text mode is on so the typed text is always
  -- visible.
  if editBox:GetFrameStrata() ~= "TOOLTIP" then
    editBox:SetFrameStrata("TOOLTIP")
    editBox:SetFrameLevel(12050)
    editBox:SetAlpha(1)
  end
end

overlay:SetScript("OnUpdate", function(self, elapsed)
  if not TA or not TA.textMode then return end
  TA:ProfileStart("overlay.OnUpdate")
  self.__taCommandPreviewElapsed = (self.__taCommandPreviewElapsed or 0) + (elapsed or 0)
  if self.__taCommandPreviewElapsed < 0.05 then TA:ProfileEnd("overlay.OnUpdate") return end
  self.__taCommandPreviewElapsed = 0
  TA_UpdateCommandPreviewBox()
  TA:ProfileEnd("overlay.OnUpdate")
end)
overlay.__taOnUpdateScript = nil

local ResetSwingTimer
local CheckSwingTimer
local GetPlayerMapCell
local RecordOutgoingDamage
local ReportCurrentCell
local UpdateMapCellOverlay
local TA_RecordDFCorpseFromGUID
local SyncTextModeOverlay
TA.chatEditBoxLayerState = TA.chatEditBoxLayerState or {}

function TA_SyncProtectedCommandEditBoxes(enabled)
  local total = NUM_CHAT_WINDOWS or 10
  for i = 1, total do
    -- Modern chat refactor exposes ChatFrameN.editBox; fall back to the
    -- legacy global if the field isn't present.
    local chatFrame = _G["ChatFrame" .. i]
    local editBox = (chatFrame and chatFrame.editBox) or _G["ChatFrame" .. i .. "EditBox"]
    if editBox then
      if enabled then
        if not TA.chatEditBoxLayerState[editBox] then
          TA.chatEditBoxLayerState[editBox] = {
            strata = editBox:GetFrameStrata(),
            level = editBox:GetFrameLevel(),
            alpha = editBox:GetAlpha(),
          }
        end
        if not editBox.__taLayerHooked then
          local function reapply(self)
            if TA and TA.textMode then
              self:SetFrameStrata("TOOLTIP")
              self:SetFrameLevel(12050)
              self:SetAlpha(1)
            end
          end
          -- Blizzard's ChatEdit_ActivateChat resets strata back to "DIALOG"
          -- after our show hook fires, sinking the edit box below the
          -- TOOLTIP-strata blackout overlay. Re-apply on every focus event so
          -- the edit box stays visible whenever the user is actually typing.
          editBox:HookScript("OnShow", reapply)
          editBox:HookScript("OnEditFocusGained", reapply)
          editBox:HookScript("OnTextChanged", reapply)
          editBox.__taLayerHooked = true
        end
        -- Keep slash-command typing visible above blackout while preserving
        -- world blindness.
        editBox:SetFrameStrata("TOOLTIP")
        editBox:SetFrameLevel(12050)
        editBox:SetAlpha(1)
      else
        local state = TA.chatEditBoxLayerState[editBox]
        if state then
          if state.strata then editBox:SetFrameStrata(state.strata) end
          if state.level then editBox:SetFrameLevel(state.level) end
          if state.alpha then editBox:SetAlpha(state.alpha) end
        end
      end
    end
  end
end

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
text:SetMaxLines(TA.lineLimit or 400)
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

TA.INPUTBOX_LAYOUT = TA.INPUTBOX_LAYOUT or {
  baseHeight = 24,
  lineHeight = 14,
  minLines = 1,
  maxLines = 6,
  x = 18,
  baseY = 16,
  insetLeft = 8,
  insetRight = 8,
  insetTop = 6,
  insetBottom = 6,
}

local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
inputBox:SetSize(840, TA.INPUTBOX_LAYOUT.baseHeight)
inputBox:SetPoint("BOTTOMLEFT", TA.INPUTBOX_LAYOUT.x, TA.INPUTBOX_LAYOUT.baseY)
inputBox:SetAutoFocus(false)
inputBox:SetMaxLetters(200)
inputBox:SetMultiLine(true)
inputBox:SetFontObject(ChatFontNormal)
inputBox:SetTextColor(1, 1, 1, 1)
inputBox:SetJustifyH("LEFT")
inputBox:SetJustifyV("TOP")
inputBox:SetTextInsets(TA.INPUTBOX_LAYOUT.insetLeft, TA.INPUTBOX_LAYOUT.insetRight, TA.INPUTBOX_LAYOUT.insetTop, TA.INPUTBOX_LAYOUT.insetBottom)
if inputBox.SetBlinkSpeed then
  inputBox:SetBlinkSpeed(0.5)
end
inputBox.customCaret = inputBox:CreateTexture(nil, "OVERLAY")
inputBox.customCaret:SetColorTexture(0.90, 1.00, 0.85, 0.90)
inputBox.customCaret:SetSize(2, 14)
inputBox.customCaret:Hide()
inputBox.customCaretFlash = inputBox.customCaret:CreateAnimationGroup()
inputBox.customCaretFlash:SetLooping("REPEAT")
inputBox.customCaretFlashA = inputBox.customCaretFlash:CreateAnimation("Alpha")
inputBox.customCaretFlashA:SetOrder(1)
inputBox.customCaretFlashA:SetDuration(0.50)
inputBox.customCaretFlashA:SetFromAlpha(0.95)
inputBox.customCaretFlashA:SetToAlpha(0.05)
inputBox.customCaretFlashB = inputBox.customCaretFlash:CreateAnimation("Alpha")
inputBox.customCaretFlashB:SetOrder(2)
inputBox.customCaretFlashB:SetDuration(0.50)
inputBox.customCaretFlashB:SetFromAlpha(0.05)
inputBox.customCaretFlashB:SetToAlpha(0.95)
inputBox:Hide()
panel.inputBox = inputBox

function TA_UpdateInputBoxLayout(editBox)
  local textValue = editBox:GetText() or ""
  local lineCount = 1
  for _ in textValue:gmatch("\n") do
    lineCount = lineCount + 1
  end
  lineCount = math.max(TA.INPUTBOX_LAYOUT.minLines, math.min(TA.INPUTBOX_LAYOUT.maxLines, lineCount))

  local height = TA.INPUTBOX_LAYOUT.baseHeight + ((lineCount - 1) * TA.INPUTBOX_LAYOUT.lineHeight)
  editBox:SetHeight(height)
  -- Keep top edge stable and grow downward so multiline input doesn't cover log text.
  editBox:ClearAllPoints()
  editBox:SetPoint("BOTTOMLEFT", TA.INPUTBOX_LAYOUT.x, TA.INPUTBOX_LAYOUT.baseY - (height - TA.INPUTBOX_LAYOUT.baseHeight))
end

TA_UpdateInputBoxLayout(inputBox)

local DF_MODE_DEFAULT_WIDTH = 400
local DF_MODE_DEFAULT_HEIGHT = 600
local DF_MODE_MIN_USABLE_WIDTH = 300

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
  dfModeFrame:SetMinResize(300, 200)
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

local dfTitle = dfModeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dfTitle:SetPoint("TOPLEFT", 8, -8)
dfTitle:SetText("threat")

dfModeFrame.resizeHandle = CreateFrame("Button", nil, dfModeFrame)
dfModeFrame.resizeHandle:SetPoint("BOTTOMRIGHT", -6, 6)
dfModeFrame.resizeHandle:SetSize(16, 16)
dfModeFrame.resizeHandle:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
dfModeFrame.resizeHandle:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
dfModeFrame.resizeHandle:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
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

local TA_API_VERSION = "1.0.0"
local TAExternalCallbacks = {}

local function TA_EmitExternal(eventName, payload)
  local listeners = TAExternalCallbacks[eventName]
  if not listeners then return end
  for i = #listeners, 1, -1 do
    local cb = listeners[i]
    if type(cb) == "function" then
      local ok = pcall(cb, payload)
      if not ok then
        table.remove(listeners, i)
      end
    else
      table.remove(listeners, i)
    end
  end
end

local function TA_GetIntegrationStateSnapshot()
  local panelShown = panel and panel.IsShown and panel:IsShown() or false
  return {
    version = TA_API_VERSION,
    addonLoaded = true,
    panelVisible = panelShown and true or false,
    textModeEnabled = TA.textMode and true or false,
    dfModeEnabled = TA.dfModeEnabled and true or false,
    dfModeView = TA.dfModeViewMode or "threat",
    performanceModeEnabled = TA.performanceModeEnabled and true or false,
  }
end

local function TA_PublishPublicAPI()
  local api = _G.TextAdventurerAPI
  if type(api) ~= "table" then
    api = {}
    _G.TextAdventurerAPI = api
  end

  api.apiVersion = TA_API_VERSION

  function api.GetVersion()
    return TA_API_VERSION
  end

  function api.GetState()
    return TA_GetIntegrationStateSnapshot()
  end

  function api.ExecuteCommand(commandText)
    if type(TA_ProcessInputCommand) ~= "function" then
      return false, "TA_ProcessInputCommand unavailable"
    end
    local ok, err = pcall(TA_ProcessInputCommand, tostring(commandText or ""))
    if not ok then
      return false, tostring(err)
    end
    TA_EmitExternal("COMMAND_EXECUTED", { command = tostring(commandText or "") })
    return true
  end

  function api.SendSlash(slashText)
    if type(TA_SendFromTerminal) ~= "function" then
      return false, "TA_SendFromTerminal unavailable"
    end
    local ok, result = pcall(TA_SendFromTerminal, tostring(slashText or ""))
    if not ok then
      return false, tostring(result)
    end
    TA_EmitExternal("SLASH_SENT", { slash = tostring(slashText or ""), handled = result and true or false })
    return true, result and true or false
  end

  function api.RegisterCallback(eventName, callbackFn)
    if type(eventName) ~= "string" or eventName == "" then
      return false, "eventName must be non-empty string"
    end
    if type(callbackFn) ~= "function" then
      return false, "callbackFn must be function"
    end
    local bucket = TAExternalCallbacks[eventName]
    if not bucket then
      bucket = {}
      TAExternalCallbacks[eventName] = bucket
    end
    bucket[#bucket + 1] = callbackFn
    return true
  end

  function api.UnregisterCallback(eventName, callbackFn)
    local bucket = TAExternalCallbacks[eventName]
    if not bucket or type(callbackFn) ~= "function" then
      return false
    end
    for i = #bucket, 1, -1 do
      if bucket[i] == callbackFn then
        table.remove(bucket, i)
        return true
      end
    end
    return false
  end
end

TA_PublishPublicAPI()

-- ============================================================
-- External streaming (TA_Stream)
-- Wrapped in `do ... end` so its locals don't count against the file-chunk's
-- 200-local cap. Cross-block reads (AddLine, PLAYER_TARGET_CHANGED) use
-- TA._streamEnabled instead of a file-scope local.
-- ============================================================
TA._streamEnabled = false
do
  local STREAM_SENTINEL = "##TA##"
  local streamFrame = nil
  local streamSeq = 0

  local function ta_json_escape(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return s
  end
  local function ta_json_encode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
      if v ~= v or v == math.huge or v == -math.huge then return "null" end
      return string.format("%.6g", v)
    end
    if t == "string" then return '"' .. ta_json_escape(v) .. '"' end
    if t == "table" then
      local n = #v
      local isArray = n > 0
      if isArray then
        for k in pairs(v) do
          if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
            isArray = false; break
          end
        end
      end
      local parts = {}
      if isArray then
        for i = 1, n do parts[#parts+1] = ta_json_encode(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
      else
        for k, val in pairs(v) do
          parts[#parts+1] = '"' .. ta_json_escape(k) .. '":' .. ta_json_encode(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
      end
    end
    return "null"
  end

  local function TA_StreamEnsureFrame()
    if streamFrame then return streamFrame end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
      local name = GetChatWindowInfo and select(1, GetChatWindowInfo(i))
      if name == "TAStream" then
        streamFrame = _G["ChatFrame" .. i]
        break
      end
    end
    if not streamFrame and FCF_OpenNewWindow then
      streamFrame = FCF_OpenNewWindow("TAStream")
      if streamFrame then
        streamFrame:UnregisterAllEvents()
        if FCF_SetWindowAlpha then FCF_SetWindowAlpha(streamFrame, 0) end
        streamFrame:SetAlpha(0)
        streamFrame:Hide()
        local tab = _G[streamFrame:GetName() .. "Tab"]
        if tab then tab:Hide(); tab:SetAlpha(0) end
      end
    end
    return streamFrame
  end

  local function TA_StreamWrite(eventName, payload)
    if not TA._streamEnabled then return end
    local f = TA_StreamEnsureFrame()
    if not f then return end
    streamSeq = streamSeq + 1
    f:AddMessage(STREAM_SENTINEL .. ta_json_encode({
      seq = streamSeq, t = GetTime(), ev = eventName, p = payload,
    }))
  end

  local STREAM_EVENTS = { "LINE", "TARGET", "READY", "COMBAT_ENTER", "COMBAT_LEAVE", "DEATH", "COMMAND_EXECUTED", "SLASH_SENT" }
  local function TA_StreamAttachListeners()
    for _, ev in ipairs(STREAM_EVENTS) do
      local bucket = TAExternalCallbacks[ev]
      if not bucket then bucket = {}; TAExternalCallbacks[ev] = bucket end
      local marker = "_taStream_" .. ev
      if not bucket[marker] then
        local evName = ev
        local fn = function(payload) TA_StreamWrite(evName, payload) end
        bucket[#bucket + 1] = fn
        bucket[marker] = true
      end
    end
  end

  function TA_StreamEnable(on)
    if on == nil then on = not TA._streamEnabled end
    if on then
      TA_StreamEnsureFrame()
      TA_StreamAttachListeners()
      if ConsoleExec then ConsoleExec("LoggingChat 1") end
      TA._streamEnabled = true
      AddLine("system", "Stream ON. Tail Logs/WoWChatLog.txt for lines beginning with '" .. STREAM_SENTINEL .. "'.")
      TA_StreamWrite("STREAM_START", { version = TA_API_VERSION, time = time() })
    else
      TA_StreamWrite("STREAM_STOP", { time = time() })
      TA._streamEnabled = false
      if ConsoleExec then ConsoleExec("LoggingChat 0") end
      AddLine("system", "Stream OFF. LoggingChat disabled.")
    end
  end

  function TA_StreamStatus()
    return TA._streamEnabled, streamSeq
  end

  SLASH_TASTREAM1 = "/tastream"
  SlashCmdList["TASTREAM"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "off" or msg == "0" or msg == "false" then
      TA_StreamEnable(false)
    elseif msg == "on" or msg == "1" or msg == "true" or msg == "" then
      TA_StreamEnable(true)
    elseif msg == "test" then
      if not TA._streamEnabled then TA_StreamEnable(true) end
      TA_EmitExternal("LINE", { kind = "system", text = "stream test ping" })
      AddLine("system", "Sent test ping to stream.")
    elseif msg == "status" then
      local on, n = TA_StreamStatus()
      AddLine("system", string.format("Stream: %s, seq=%d", on and "ON" or "OFF", n or 0))
    else
      AddLine("system", "Usage: /tastream [on|off|test|status]")
    end
  end
end

function TA_SetLineLimit(limit, silent)
  local minLimit = 100
  local maxLimit = 2000

  if limit == nil then
    AddLine("system", string.format("Text log line limit: %d", TA.lineLimit or 400))
    AddLine("system", string.format("Usage: loglimit <n> (range %d-%d)", minLimit, maxLimit))
    return
  end

  local n = math.floor(tonumber(limit) or 0)
  if n < minLimit then n = minLimit end
  if n > maxLimit then n = maxLimit end

  TA.lineLimit = n
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.lineLimit = n

  while #TA.lines > TA.lineLimit do
    table.remove(TA.lines, 1)
  end

  if panel and panel.text then
    if panel.text.SetMaxLines then
      panel.text:SetMaxLines(TA.lineLimit)
    end
    panel.text:Clear()
    for i = 1, #TA.lines do
      local line = TA.lines[i]
      if line and line.text then
        panel.text:AddMessage(line.text, line.r or 1, line.g or 1, line.b or 1)
      end
    end
    panel.text:ScrollToBottom()
  end

  if not silent then
    AddLine("system", string.format("Text log line limit set to %d.", TA.lineLimit))
  end
end

-- Suppress "Screenshot captured as..." chat spam.
if TA.hideScreenshotMessage == nil then TA.hideScreenshotMessage = true end
TA._screenshotFilterInstalled = false

local function TA_ScreenshotChatFilter(_, _, msg)
  if not TA.hideScreenshotMessage then return false end
  if type(msg) ~= "string" then return false end
  -- SCREENSHOT_SUCCESS = "Screenshot captured as %s"; SCREENSHOT_FAILURE = "Screenshot failed."
  if msg:find("Screenshot captured as", 1, true)
    or msg:find("Screenshot failed", 1, true) then
    return true
  end
  if SCREENSHOT_SUCCESS then
    local pat = "^" .. SCREENSHOT_SUCCESS:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$"
    if msg:match(pat) then return true end
  end
  if SCREENSHOT_FAILURE and msg == SCREENSHOT_FAILURE then return true end
  return false
end

function TA_InstallScreenshotFilter()
  if not TA._screenshotChatFilterInstalled and ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", TA_ScreenshotChatFilter)
    TA._screenshotChatFilterInstalled = true
  end
  -- Suppress the on-screen yellow "Screenshot captured as..." UIErrorsFrame popup.
  if UIErrorsFrame and UIErrorsFrame.AddMessage and not TA._uiErrorsOriginalAddMessage then
    TA._uiErrorsOriginalAddMessage = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(self, msg, ...)
      if TA.debugScreenshotFilter and type(msg) == "string" then
        print("[TA-SS] UIErrors:", msg)
      end
      if TA.hideScreenshotMessage and type(msg) == "string"
        and (msg:lower():find("screenshot", 1, true)) then
        return
      end
      return TA._uiErrorsOriginalAddMessage(self, msg, ...)
    end
  end
  if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage and not TA._uiErrorsOriginalAddExternal then
    TA._uiErrorsOriginalAddExternal = UIErrorsFrame.AddExternalErrorMessage
    UIErrorsFrame.AddExternalErrorMessage = function(self, msg, ...)
      if TA.debugScreenshotFilter and type(msg) == "string" then
        print("[TA-SS] UIErrors-Ext:", msg)
      end
      if TA.hideScreenshotMessage and type(msg) == "string"
        and (msg:lower():find("screenshot", 1, true)) then
        return
      end
      return TA._uiErrorsOriginalAddExternal(self, msg, ...)
    end
  end
  -- Some screenshot text may be raised via RaidNotice / RaidWarning frames; cover those too.
  for _, frameName in ipairs({ "RaidNotice_AddMessage" }) do
    local orig = _G[frameName]
    if type(orig) == "function" and not TA["_orig_" .. frameName] then
      TA["_orig_" .. frameName] = orig
      _G[frameName] = function(noticeFrame, textString, ...)
        if TA.hideScreenshotMessage and type(textString) == "string"
          and (textString:find("Screenshot captured as", 1, true)
            or textString:find("Screenshot failed", 1, true)) then
          return
        end
        return TA["_orig_" .. frameName](noticeFrame, textString, ...)
      end
    end
  end
  -- Override the FrameXML screenshot event handler if it's a global function (Classic).
  if type(Screenshot_OnEvent) == "function" and not TA._origScreenshotOnEvent then
    TA._origScreenshotOnEvent = Screenshot_OnEvent
    Screenshot_OnEvent = function(self, event, ...)
      if TA.hideScreenshotMessage
        and (event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED") then
        return
      end
      return TA._origScreenshotOnEvent(self, event, ...)
    end
  end
  -- Last-resort: unregister the screenshot events from any frame that listens for them.
  -- The popup may be drawn directly by an engine-side handler bound to these events.
  if EnumerateFrames then
    local f = EnumerateFrames()
    while f do
      if f.IsEventRegistered and f.UnregisterEvent then
        local ok1 = pcall(function() return f:IsEventRegistered("SCREENSHOT_SUCCEEDED") end)
        if ok1 then
          if f:IsEventRegistered("SCREENSHOT_SUCCEEDED") then
            f:UnregisterEvent("SCREENSHOT_SUCCEEDED")
            if TA.debugScreenshotFilter then
              print("[TA-SS] unregistered SCREENSHOT_SUCCEEDED from", f:GetName() or tostring(f))
            end
          end
          if f:IsEventRegistered("SCREENSHOT_FAILED") then
            f:UnregisterEvent("SCREENSHOT_FAILED")
            if TA.debugScreenshotFilter then
              print("[TA-SS] unregistered SCREENSHOT_FAILED from", f:GetName() or tostring(f))
            end
          end
        end
      end
      f = EnumerateFrames(f)
    end
  end
  TA._screenshotFilterInstalled = true
end

-- Try installing right now in case UIErrorsFrame already exists at file-load time.
if pcall(TA_InstallScreenshotFilter) then end

function TA_SetHideScreenshotMessage(enabled, silent)
  if enabled == nil then
    AddLine("system", string.format("Screenshot message: %s",
      TA.hideScreenshotMessage and "HIDDEN" or "shown"))
    AddLine("system", "Usage: hidescreenshot on|off")
    return
  end
  TA.hideScreenshotMessage = enabled and true or false
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.hideScreenshotMessage = TA.hideScreenshotMessage
  TA_InstallScreenshotFilter()
  if not silent then
    AddLine("system", string.format("Screenshot 'captured' message %s.",
      TA.hideScreenshotMessage and "hidden" or "shown"))
  end
end

function AddLine(kind, msg)
  if not msg or msg == "" then return end
  local c = COLORS[kind] or COLORS.system
  local now = time()
  if now ~= TA._tsCacheT then
    TA._tsCache = date("%H:%M:%S")
    TA._tsCacheT = now
  end
  local line = {
    text = TA._tsCache .. "  " .. msg,
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
  if TA._streamEnabled then
    TA_EmitExternal("LINE", { kind = kind, text = msg, ts = TA._tsCacheT })
  end
end

function TA_BroadcastDangerWarningToChat()
  local chat = DEFAULT_CHAT_FRAME
  if chat and chat.AddMessage then
    chat:AddMessage("|cffff4040[Text Adventurer WARNING]|r This addon is extremely dangerous for Hardcore play and WILL eventually get your character killed.")
    if not (TextAdventurerDB and TextAdventurerDB.autoEnable) then
      chat:AddMessage("|cffff4040[Text Adventurer WARNING]|r Autostart is OFF. Use /ta autostart on to enable auto-open on login.")
    else
      chat:AddMessage("|cff00ff00[Text Adventurer]|r Autostart is ON. Panel will auto-open on login.")
    end
  end
end

function BagLabel(bag)
  if bag == 0 then return "Backpack" end
  return string.format("Bag %d", bag)
end

function SnapshotBags()
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

function FormatMoney(copper)
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

function FindBagChanges(oldState, newState)
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

function ReportLootWindowPreview()
  if not GetNumLootItems or not GetLootSlotInfo then
    AddLine("loot", "Loot preview API unavailable on this client.")
    return
  end

  local numItems = GetNumLootItems() or 0
  if numItems <= 0 then
    AddLine("loot", "No loot found on this target.")
    return
  end

  AddLine("loot", string.format("Loot preview (%d slot(s)):", numItems))
  for slot = 1, numItems do
    local _, itemName, quantity, quality, _, isQuestItem, _, isCoin = GetLootSlotInfo(slot)
    local qty = tonumber(quantity) or 1
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local label = link or itemName or "Unknown"
    if isCoin then
      AddLine("loot", string.format("  [%d] %s", slot, label))
    else
      local questTag = isQuestItem and " [quest]" or ""
      local qualityTag = quality and quality > -1 and string.format(" [q%d]", quality) or ""
      AddLine("loot", string.format("  [%d] %s x%d%s%s", slot, label, qty, qualityTag, questTag))
    end
  end
end

function TA_BuildSkillSnapshot()
  local snapshot = {}
  if not GetNumSkillLines or not GetSkillLineInfo then
    return snapshot
  end

  local count = GetNumSkillLines() or 0
  for i = 1, count do
    local skillName, isHeader, _, skillRank, _, skillModifier, skillMaxRank = GetSkillLineInfo(i)
    if skillName and skillName ~= "" and not isHeader and tonumber(skillMaxRank or 0) > 0 then
      snapshot[skillName] = {
        rank = tonumber(skillRank) or 0,
        max = tonumber(skillMaxRank) or 0,
        modifier = tonumber(skillModifier) or 0,
      }
    end
  end
  return snapshot
end

function TA_GetSkillCategory(name)
  if not name then return "other" end
  local lower = string.lower(name)
  local WEAPON_SKILLS = {
    axes = true, swords = true, maces = true, daggers = true, staves = true,
    polearms = true, bows = true, guns = true, crossbows = true, fist = true,
    thrown = true, unarmed = true,
  }
  WEAPON_SKILLS["two-handed swords"] = true
  WEAPON_SKILLS["two-handed maces"] = true
  WEAPON_SKILLS["two-handed axes"] = true
  local PROF_SKILLS = {
    alchemy = true, blacksmithing = true, enchanting = true, engineering = true,
    herbalism = true, mining = true, skinning = true, tailoring = true,
    leatherworking = true, cooking = true, fishing = true, firstaid = true,
  }
  PROF_SKILLS["first aid"] = true
  local SECONDARY_SKILLS = {
    cooking = true, fishing = true, firstaid = true,
  }
  SECONDARY_SKILLS["first aid"] = true

  if WEAPON_SKILLS[lower] or lower:find("two%-handed") then return "weapon" end
  if lower == "defense" or lower == "defence" then return "defense" end
  if SECONDARY_SKILLS[lower] then return "secondary" end
  if PROF_SKILLS[lower] then return "profession" end
  return "other"
end

function TA_ReportSkillLevels(force, filter)
  filter = (filter or "all"):lower()
  local current = TA_BuildSkillSnapshot()
  if not next(current) then
    if force then
      AddLine("system", "Skill API unavailable or no skill lines found.")
    end
    TA.skillSnapshot = current
    return
  end

  if force then
    local names = {}
    for name in pairs(current) do
      local cat = TA_GetSkillCategory(name)
      if filter == "all"
        or (filter == "weapon" and cat == "weapon")
        or (filter == "weapons" and cat == "weapon")
        or (filter == "profession" and cat == "profession")
        or (filter == "professions" and cat == "profession")
        or (filter == "secondary" and cat == "secondary")
        or (filter == "defense" and cat == "defense") then
        table.insert(names, name)
      end
    end
    table.sort(names)
    AddLine("status", string.format("Skills tracked (%s): %d", filter, #names))
    for i = 1, #names do
      local name = names[i]
      local row = current[name]
      local modText = (row.modifier and row.modifier ~= 0) and string.format(" (%+d)", row.modifier) or ""
      AddLine("status", string.format("  %s: %d/%d%s [%s]", name, row.rank or 0, row.max or 0, modText, TA_GetSkillCategory(name)))
    end
    TA.skillSnapshot = current
    return
  end

  local previous = TA.skillSnapshot or {}
  for name, now in pairs(current) do
    local before = previous[name]
    if not before then
      AddLine("status", string.format("Skill learned: %s (%d/%d)", name, now.rank or 0, now.max or 0))
    elseif (now.rank or 0) ~= (before.rank or 0) or (now.max or 0) ~= (before.max or 0) or (now.modifier or 0) ~= (before.modifier or 0) then
      AddLine("status", string.format("Skill update: %s %d/%d -> %d/%d", name, before.rank or 0, before.max or 0, now.rank or 0, now.max or 0))
    end
  end
  TA.skillSnapshot = current
end

function SpellLabel(spellName)
  if spellName and spellName ~= "" then return spellName end
  return "an ability"
end

function IsSourcePlayerOrPet(sourceFlags)
  return CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME)
      or CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MY_PET)
end

function IsDestPlayerOrPet(destFlags)
  return CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_ME)
      or CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_MY_PET)
end

function FormatDamageEvent(subevent, sourceName, destName, spellName, amount)
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

function FormatMissEvent(subevent, sourceName, destName, spellName, missType)
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


function HandleCombatLog()
  local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, param1, param2, _, param4 = CombatLogGetCurrentEventInfo()
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
    local mapID = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or nil
    TA_RecordDFCorpseFromGUID(destGUID, destName, mapID)
  end

  return subevent
end

function DescribeUnit(unit)
  if unit == "player" then return "You" end
  if UnitIsUnit(unit, "target") then return UnitName(unit) or "Your target" end
  return UnitName(unit) or unit
end

function ReportCastStart(unit, spellID, isChannel)
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

function ReportCastStop(unit, spellID, reason, isChannel)
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

function DescribeTargetHealthBucket(unit)
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

function ReportTargetCondition(force)
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

function TA_CardinalFromEastNorth(east, north)
  if not east or not north then return nil end
  local eps = 0.01
  local hasEast = math.abs(east) > eps
  local hasNorth = math.abs(north) > eps
  if not hasEast and not hasNorth then
    return "here"
  end
  if hasNorth and hasEast then
    if north > 0 then
      return east > 0 and "northeast" or "northwest"
    end
    return east > 0 and "southeast" or "southwest"
  end
  if hasNorth then
    return north > 0 and "north" or "south"
  end
  return east > 0 and "east" or "west"
end

function TA_GetUnitCellsAway(unit)
  if not unit or not UnitExists(unit) then
    return nil, false
  end

  local yardsPerCell = TA_GetEffectiveDFYardsPerCell and TA_GetEffectiveDFYardsPerCell() or 3
  if yardsPerCell <= 0 then yardsPerCell = 3 end

  local px, py = UnitPosition("player")
  local ux, uy = UnitPosition(unit)
  if px and py and ux and uy then
    local dx = ux - px
    local dy = uy - py
    local east = dx
    local north = dy
    local distYards = math.sqrt((east * east) + (north * north))
    local cells = math.max(1, math.floor((distYards / yardsPerCell) + 0.5))
    local direction = TA_CardinalFromEastNorth(east, north)
    return cells, false, direction
  end

  if CheckInteractDistance then
    local approxYards = nil
    if TA_TryInteractDistance and TA_TryInteractDistance(unit, 1) then approxYards = 3
    elseif TA_TryInteractDistance and TA_TryInteractDistance(unit, 2) then approxYards = 9
    elseif TA_TryInteractDistance and TA_TryInteractDistance(unit, 3) then approxYards = 24
    elseif TA_TryInteractDistance and TA_TryInteractDistance(unit, 4) then approxYards = 30
    end
    if approxYards then
      local cells = math.max(1, math.floor((approxYards / yardsPerCell) + 0.5))
      return cells, true, nil
    end
  end

  return nil, false, nil
end

function CheckTarget()
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
      local cellsAway, isApprox, direction = TA_GetUnitCellsAway("target")
      if cellsAway then
        local approxPrefix = isApprox and "~" or ""
        local cellWord = cellsAway == 1 and "cell" or "cells"
        local where = direction and direction ~= "here" and (" " .. direction) or ""
        AddLine("target", string.format("You target %s (level %s, %s, %s%d %s%s away).", name, level > 0 and level or "??", reaction, approxPrefix, cellsAway, cellWord, where))
      else
        AddLine("target", string.format("You target %s (level %s, %s).", name, level > 0 and level or "??", reaction))
      end
      TA.lastTargetHealthBucket = nil
      ReportTargetCondition(true)
    end
    TA.lastTargetGUID = guid
    TA.lastTargetName = name
  end
end

function FacingToCardinal(facing)
  if not facing then return nil end
  local deg = math.deg(facing) % 360
  -- WoW Classic facing uses 0°=north, 90°=west, 180°=south, 270°=east.
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

function SpeedCategory(speed)
  speed = speed or 0
  if speed <= 0 then return "still" end
  if speed < 7.5 then return "walking" end
  if speed < 13.5 then return "running" end
  return "fast"
end

function GetFacingDegrees()
  local f = GetPlayerFacing()
  if not f then return nil end
  return math.deg(f) % 360
end

function GetTargetFacingDegrees()
  if not UnitExists("target") or UnitIsDeadOrGhost("target") then return nil end
  if not UnitFacing then return nil end
  local f = UnitFacing("target")
  if not f then return nil end
  return math.deg(f) % 360
end

function AngleDiff(a, b)
  local diff = math.abs(a - b)
  if diff > 180 then diff = 360 - diff end
  return diff
end

function EstimateSpacing(angleDeg)
  local radians = math.rad(angleDeg / 2)
  return 2 * SPACING_ASSUMED_RANGE * math.sin(radians)
end

function DescribeSpacing(angle, distance)
  if angle < 15 or distance < 7 then
    return "tightly clustered", "high"
  elseif angle < 30 or distance < 13 then
    return "moderately separated", "medium"
  else
    return "widely separated", "lower"
  end
end

function ReportTargetPositioning()
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
    AddLine("system", string.format("%s facing: %.0fÂ°, you facing: %.0fÂ°, relative heading: %.0fÂ°.", UnitName("target") or "Target", targetFacing, playerFacing, relative))
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

function MarkFacingA()
  local facing = GetFacingDegrees()
  if not facing then AddLine("system", "Could not read facing."); return end
  TA.markA = {
    facing = facing,
    target = UnitName("target") or "unknown target",
    reaction = UnitCanAttack("player", "target") and "hostile" or "non-hostile",
  }
  AddLine("system", string.format("Marked A at %.1fÂ° toward %s.", facing, TA.markA.target))
end

function MarkFacingB()
  local facing = GetFacingDegrees()
  if not facing then AddLine("system", "Could not read facing."); return end
  TA.markB = {
    facing = facing,
    target = UnitName("target") or "unknown target",
    reaction = UnitCanAttack("player", "target") and "hostile" or "non-hostile",
  }
  AddLine("system", string.format("Marked B at %.1fÂ° toward %s.", facing, TA.markB.target))
end

function ReportSpacingEstimate()
  if not TA.markA or not TA.markB then
    AddLine("system", "You must mark both directions first with marka and markb.")
    return
  end
  local angle = AngleDiff(TA.markA.facing, TA.markB.facing)
  local dist = EstimateSpacing(angle)
  local desc, risk = DescribeSpacing(angle, dist)
  AddLine("system", string.format("Angle between marks: %.1fÂ°", angle))
  AddLine("system", string.format("Estimated spacing at %.0f-yard range: %.1f yards", SPACING_ASSUMED_RANGE, dist))
  AddLine("system", string.format("%s and %s appear %s. Pull risk is %s.", TA.markA.target, TA.markB.target, desc, risk))
  AddLine("system", "This is a geometric estimate, not a guaranteed safe-pull measurement.")
end

function GetGridSize()
  local size = tonumber(TA.gridSize) or GRID_SIZE_DEFAULT
  size = math.floor(size)
  if size < GRID_SIZE_MIN then size = GRID_SIZE_MIN end
  if size > GRID_SIZE_MAX then size = GRID_SIZE_MAX end
  return size
end

function ClampGridSize(n)
  n = math.floor(tonumber(n) or GRID_SIZE_DEFAULT)
  if n < GRID_SIZE_MIN then n = GRID_SIZE_MIN end
  if n > GRID_SIZE_MAX then n = GRID_SIZE_MAX end
  return n
end

function NormalizePeriodicOffset(offset, step)
  if not step or step <= 0 then return 0 end
  offset = tonumber(offset) or 0
  offset = offset % step
  return offset
end

function IsAnchorCompatible(anchor, gridX, gridY)
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

function GetMapWorldDimensions(mapID)
  -- Returns (widthYards, heightYards) for a zone map, measured via corner
  -- samples through C_Map.GetWorldPosFromMapPos. This is a fallback for
  -- Classic Era where C_Map.GetMapInfo does not populate width/height.
  -- Cached per mapID since these never change at runtime.
  if not mapID then return nil, nil end
  TA._mapYardsCache = TA._mapYardsCache or {}
  local cached = TA._mapYardsCache[mapID]
  if cached then return cached.width, cached.height end

  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  if mapInfo and tonumber(mapInfo.width) and tonumber(mapInfo.height) and mapInfo.width > 0 and mapInfo.height > 0 then
    TA._mapYardsCache[mapID] = { width = mapInfo.width, height = mapInfo.height }
    return mapInfo.width, mapInfo.height
  end

  if C_Map and C_Map.GetWorldPosFromMapPos then
    local makeVec = CreateVector2D or function(vx, vy) return { x = vx, y = vy } end
    -- C_Map.GetWorldPosFromMapPos returns (continentID, worldPos) -- the
    -- vector is the SECOND return value.
    local ok1, _c1, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.0, 0.5))
    local ok2, _c2, p2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(1.0, 0.5))
    local ok3, _c3, p3 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.5, 0.0))
    local ok4, _c4, p4 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.5, 1.0))
    if ok1 and ok2 and ok3 and ok4
        and type(p1) == "table" and type(p2) == "table"
        and type(p3) == "table" and type(p4) == "table" then
      local function vx(p) return tonumber(p.x) or tonumber(p[1]) or 0 end
      local function vy(p) return tonumber(p.y) or tonumber(p[2]) or 0 end
      local widthYards = math.sqrt((vx(p2) - vx(p1))^2 + (vy(p2) - vy(p1))^2)
      local heightYards = math.sqrt((vx(p4) - vx(p3))^2 + (vy(p4) - vy(p3))^2)
      if widthYards > 0 and heightYards > 0 then
        TA._mapYardsCache[mapID] = { width = widthYards, height = heightYards }
        return widthYards, heightYards
      end
    end
  end
  return nil, nil
end

function GetCellGridForMap(mapID)
  local mode = TA.cellSizeMode == "yards" and "yards" or "grid"
  local targetYards = tonumber(TA.cellSizeYards)
  if mode == "yards" and targetYards and targetYards > 0 then
    local mapWidthYards, mapHeightYards = GetMapWorldDimensions(mapID)
    if mapWidthYards and mapHeightYards then
      local gridX = ClampGridSize(math.floor((mapWidthYards / targetYards) + 0.5))
      local gridY = ClampGridSize(math.floor((mapHeightYards / targetYards) + 0.5))
      return gridX, gridY, "yards", targetYards
    end
  end

  local gridSize = GetGridSize()
  return gridSize, gridSize, mode, targetYards
end

function GetMapAnchor(mapID, gridX, gridY)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local anchors = TA.cellAnchors or {}
  local anchor = anchors[mapID]
  if not IsAnchorCompatible(anchor, gridX, gridY) then
    return 0, 0
  end
  return NormalizePeriodicOffset(anchor.offsetX, stepX), NormalizePeriodicOffset(anchor.offsetY, stepY)
end

function ComputeCellForPosition(x, y, gridX, gridY, offsetX, offsetY)
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

function GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local minX = ((offsetX or 0) + (cellX * stepX)) % 1
  local maxX = minX + stepX
  local minY = ((offsetY or 0) + (cellY * stepY)) % 1
  local maxY = minY + stepY
  return minX, maxX, minY, maxY, stepX, stepY
end

function RecenterCurrentCellAnchor(silent)
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

function SetGridSize(newSize, label)
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

function SetCellSizeYards(newYards)
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

function DisableCellSizeYardsMode()
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

function GetWorldMapOverlayParent()
  if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return nil end
  return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
end

function EnsureMapCellOverlay()
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

function SetOverlayRect(frame, parent, minX, maxX, minY, maxY, label)
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

function GetMarkedCellByID(markID)
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

function CellKey(x, y)
  return tostring(x) .. "," .. tostring(y)
end

function MarkCurrentCell(name)
  -- Always recenter the grid anchor on the player before marking so the cell
  -- center lands on top of the player, matching the delete-and-remark behavior.
  RecenterCurrentCellAnchor(true)
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

function ListMarkedCells()
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

function ShowMarkedCellOnMap(markID)
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

function ClearMarkedCells()
  wipe(TA.markedCells)
  TA.activeMapMarkID = nil
  UpdateMapCellOverlay()
  AddLine("system", "All marked cells cleared.")
end

function DeleteMarkedCell(markID)
  local mark = GetMarkedCellByID(markID)
  if not mark then
    AddLine("system", string.format("No marked cell found with ID %d.", markID))
    return
  end
  local name = mark.name or "Unnamed"
  TA.markedCells[markID] = nil
  if TA.activeMapMarkID == markID then
    TA.activeMapMarkID = nil
  end
  if TA.lastMarkedCellNotification == markID then
    TA.lastMarkedCellNotification = nil
  end
  TextAdventurerDB.markedCells = TA.markedCells
  UpdateMapCellOverlay()
  AddLine("system", string.format("Deleted marked cell [%d] '%s'.", markID, name))
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

local TA_QUEST_ROUTE_DEFAULT_WEIGHTS = {
  xp = 0.32,
  proximity = 0.30,
  levelFit = 0.16,
  progress = 0.12,
  guide = 0.10,
}

local function TA_ClampQuestRouteWeight(v)
  local n = tonumber(v) or 0
  if n < 0 then return 0 end
  if n > 1 then return 1 end
  return n
end

local function TA_NormalizeQuestRouteWeights(weights)
  local sum = 0
  for k, _ in pairs(TA_QUEST_ROUTE_DEFAULT_WEIGHTS) do
    local w = TA_ClampQuestRouteWeight(weights[k])
    weights[k] = w
    sum = sum + w
  end
  if sum <= 0 then
    for k, w in pairs(TA_QUEST_ROUTE_DEFAULT_WEIGHTS) do
      weights[k] = w
    end
    return
  end
  for k, _ in pairs(TA_QUEST_ROUTE_DEFAULT_WEIGHTS) do
    weights[k] = (weights[k] or 0) / sum
  end
end

local function TA_GetQuestRouterStore()
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.questRouter = type(TextAdventurerDB.questRouter) == "table" and TextAdventurerDB.questRouter or {}
  local s = TextAdventurerDB.questRouter
  s.weights = type(s.weights) == "table" and s.weights or {}
  for k, w in pairs(TA_QUEST_ROUTE_DEFAULT_WEIGHTS) do
    if type(s.weights[k]) ~= "number" then
      s.weights[k] = w
    end
  end
  TA_NormalizeQuestRouteWeights(s.weights)
  if type(s.learningRate) ~= "number" then s.learningRate = 0.08 end
  if type(s.topN) ~= "number" then s.topN = 3 end
  if type(s.yardsPerPercent) ~= "number" then s.yardsPerPercent = 45 end
  if s.enabled == nil then s.enabled = true end
  if type(s.samples) ~= "number" then s.samples = 0 end
  if type(s.correctSuggestions) ~= "number" then s.correctSuggestions = 0 end
  return s
end

local function TA_GetQuestieModule(name)
  local loader = _G.QuestieLoader
  if not loader or type(loader.ImportModule) ~= "function" then
    return nil
  end
  local ok, mod = pcall(function()
    return loader:ImportModule(name)
  end)
  if ok and mod then
    return mod
  end
  return nil
end

local function TA_GetQuestRouteContext()
  local now = GetTime()
  if TA.questRouteContext and (now - (TA.questRouteContext.at or 0)) < 5 then
    return TA.questRouteContext
  end
  local ctx = {
    at = now,
    db = TA_GetQuestieModule("QuestieDB"),
    xp = TA_GetQuestieModule("QuestXP"),
    player = TA_GetQuestieModule("QuestiePlayer"),
  }
  TA.questRouteContext = ctx
  return ctx
end

local function TA_GetQuestObjectiveProgressRatio(index)
  local total = GetNumQuestLeaderBoards and tonumber(GetNumQuestLeaderBoards(index)) or 0
  if total <= 0 then
    return 0
  end
  local finishedCount = 0
  local sumCurrent = 0
  local sumNeed = 0
  for i = 1, total do
    local desc, _, finished = GetQuestLogLeaderBoard(i, index)
    if finished then
      finishedCount = finishedCount + 1
    end
    if type(desc) == "string" then
      local a, b = desc:match("(%d+)%s*/%s*(%d+)")
      a = tonumber(a)
      b = tonumber(b)
      if a and b and b > 0 then
        sumCurrent = sumCurrent + math.min(a, b)
        sumNeed = sumNeed + b
      end
    end
  end
  local byDone = finishedCount / total
  local byCount = (sumNeed > 0) and (sumCurrent / sumNeed) or 0
  local v = math.max(byDone, byCount)
  if v < 0 then v = 0 end
  if v > 1 then v = 1 end
  return v
end

local function TA_GetGuideSignal(questTitle)
  local signal = 0
  local lowerTitle = string.lower(tostring(questTitle or ""))
  local gl = _G.GuidelimeDataChar
  if type(gl) == "table" then
    local g = string.lower(tostring(gl.currentGuide or ""))
    if g ~= "" and lowerTitle ~= "" and string.find(g, lowerTitle, 1, true) then
      signal = signal + 0.75
    elseif g ~= "" then
      signal = signal + 0.25
    end
  end
  local wowpro = _G.WoWPro
  if type(wowpro) == "table" then
    signal = signal + 0.15
  end
  if _G.TomTom then
    signal = signal + 0.10
  end
  if signal > 1 then signal = 1 end
  return signal
end

local function TA_GetQuestStartFromQuestie(db, questID, currentMapID)
  if not db or type(db.GetQuest) ~= "function" then
    return nil
  end
  local okQuest, quest = pcall(function()
    return db.GetQuest(questID)
  end)
  if not okQuest then
    return nil
  end
  if type(quest) ~= "table" then
    return nil
  end

  local npcList = nil
  if quest.Starts and type(quest.Starts.NPC) == "table" then
    npcList = quest.Starts.NPC
  elseif quest.startedBy and type(quest.startedBy[1]) == "table" then
    npcList = quest.startedBy[1]
  end
  if type(npcList) ~= "table" then
    return nil
  end

  local fallback = nil
  for _, npcID in ipairs(npcList) do
    local npc = nil
    if db.GetNPC then
      local okNpc, value = pcall(function()
        return db:GetNPC(npcID)
      end)
      if okNpc then
        npc = value
      end
    end
    if type(npc) == "table" and type(npc.spawns) == "table" then
      for zoneID, points in pairs(npc.spawns) do
        if type(points) == "table" and points[1] then
          local p = points[1]
          local x = tonumber(p[1])
          local y = tonumber(p[2])
          local z = tonumber(zoneID)
          if x and y and z then
            local row = { mapID = z, xPct = x, yPct = y, npcID = npcID }
            if z == tonumber(currentMapID) then
              return row
            end
            if not fallback then fallback = row end
          end
        end
      end
    end
  end
  return fallback
end

local function TA_MapPercentToCells(targetXPct, targetYPct, yardsPerCell, yardsPerPercent)
  local mapID, _, _, x, y = GetPlayerMapCell()
  if not mapID then return nil end

  local px = tonumber(x)
  local py = tonumber(y)
  if not px or not py then return nil end
  if px > 1.5 then px = px / 100 end
  if py > 1.5 then py = py / 100 end

  local tx = tonumber(targetXPct)
  local ty = tonumber(targetYPct)
  if not tx or not ty then return nil end
  tx = tx / 100
  ty = ty / 100

  local dxPct = (tx - px) * 100
  local dyPct = (ty - py) * 100
  local eastYards = dxPct * yardsPerPercent
  local northYards = -dyPct * yardsPerPercent
  local dxCells = eastYards / math.max(1, yardsPerCell)
  local dyCells = northYards / math.max(1, yardsPerCell)
  local distCells = math.sqrt((dxCells * dxCells) + (dyCells * dyCells))

  return {
    mapID = mapID,
    dxCells = dxCells,
    dyCells = dyCells,
    distCells = distCells,
  }
end

local function TA_IsQuestHeaderFlag(v)
  return v == true or v == 1 or v == "1"
end

local function TA_IsQuestCompleteFlag(v)
  return v == true or v == 1 or v == "1"
end

local function TA_CollectQuestRouteEntries(expandCollapsedHeaders)
  local total = GetNumQuestLogEntries and tonumber((GetNumQuestLogEntries())) or 0
  if total <= 0 then
    return {}, 0, 0, 0, false
  end

  local expandedHeaderIndices = {}
  if expandCollapsedHeaders and ExpandQuestHeader and CollapseQuestHeader and GetQuestLogTitle then
    for i = total, 1, -1 do
      local _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
      if TA_IsQuestHeaderFlag(isHeader) and TA_IsQuestHeaderFlag(isCollapsed) then
        ExpandQuestHeader(i)
        table.insert(expandedHeaderIndices, i)
      end
    end
    total = GetNumQuestLogEntries and tonumber((GetNumQuestLogEntries())) or total
  end

  local entries = {}
  local headerCount = 0
  local completedCount = 0
  for i = 1, total do
    local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
    local isHeaderQuest = TA_IsQuestHeaderFlag(isHeader)
    local isCompletedQuest = TA_IsQuestCompleteFlag(isComplete)
    if title and not isHeaderQuest and not isCompletedQuest then
      table.insert(entries, {
        index = i,
        title = title,
        level = level,
        questID = questID,
      })
    elseif title and isHeaderQuest then
      headerCount = headerCount + 1
    elseif title and isCompletedQuest then
      completedCount = completedCount + 1
    end
  end

  if #expandedHeaderIndices > 0 and CollapseQuestHeader then
    table.sort(expandedHeaderIndices, function(a, b) return a > b end)
    for _, idx in ipairs(expandedHeaderIndices) do
      CollapseQuestHeader(idx)
    end
  end

  return entries, total, headerCount, completedCount, (#expandedHeaderIndices > 0)
end

local function TA_BuildQuestRouteCandidates(topN)
  local initialTotal = GetNumQuestLogEntries and tonumber((GetNumQuestLogEntries())) or 0
  local store = TA_GetQuestRouterStore()
  local weights = store.weights
  local ctx = TA_GetQuestRouteContext()
  local currentMapID = select(1, GetPlayerMapCell())
  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  local playerLevel = UnitLevel("player") or 1
  local gridSize = tonumber(TA.dfModeGridSize) or 21
  local radius = math.max(3, math.floor(gridSize / 2))

  local rows = {}
  local total, headerCount, completedCount = initialTotal, 0, 0
  local usedExpandedHeaderScan = false
  local usedSnapshotFallback = false
  local usedQuestieFallback = false
  local activeEntries = nil

  activeEntries, total, headerCount, completedCount = TA_CollectQuestRouteEntries(false)
  if #activeEntries == 0 and total > 0 then
    activeEntries, total, headerCount, completedCount, usedExpandedHeaderScan = TA_CollectQuestRouteEntries(true)
  end

  for _, entry in ipairs(activeEntries) do
      local qid = tonumber(entry.questID)
      local rewardXP = 0
      if qid and ctx.xp and type(ctx.xp.GetQuestLogRewardXP) == "function" then
        local ok, v = pcall(function() return ctx.xp:GetQuestLogRewardXP(qid, true) end)
        if ok and tonumber(v) then rewardXP = tonumber(v) end
      end

      local xpFactor = math.min(1, math.max(0, rewardXP / 4500))
      local lvl = tonumber(entry.level) or playerLevel
      local levelFit = 1 - math.min(1, math.abs(lvl - playerLevel) / 8)
      local progress = TA_GetQuestObjectiveProgressRatio(entry.index)
      local guide = TA_GetGuideSignal(entry.title)

      local proximity = 0.20
      local dxCells, dyCells = nil, nil
      local routeMapID, routeXPct, routeYPct = nil, nil, nil
      if qid and ctx.db then
        local start = TA_GetQuestStartFromQuestie(ctx.db, qid, currentMapID)
        if start then
          routeMapID = start.mapID
          routeXPct = start.xPct
          routeYPct = start.yPct
          if routeMapID == tonumber(currentMapID) then
            local pos = TA_MapPercentToCells(start.xPct, start.yPct, yardsPerCell, store.yardsPerPercent)
            if pos then
              dxCells = pos.dxCells
              dyCells = pos.dyCells
              local d = tonumber(pos.distCells) or (radius * 2)
              proximity = 1 - math.min(1, d / (radius * 1.5))
            end
          end
        end
      end

      if proximity < 0 then proximity = 0 end
      if proximity > 1 then proximity = 1 end

      local factors = {
        xp = xpFactor,
        proximity = proximity,
        levelFit = levelFit,
        progress = progress,
        guide = guide,
      }

      local score = 0
      for k, w in pairs(weights) do
        score = score + ((factors[k] or 0) * (w or 0))
      end

      table.insert(rows, {
        index = entry.index,
        questID = qid,
        title = entry.title,
        level = lvl,
        score = score,
        factors = factors,
        rewardXP = rewardXP,
        mapID = routeMapID,
        xPct = routeXPct,
        yPct = routeYPct,
        dxCells = dxCells,
        dyCells = dyCells,
      })
  end

  -- Fallback: when Blizzard quest-log iteration yields no visible quests (often due to collapsed headers
  -- or client API differences), pull active quest IDs from Questie's live questlog cache.
  if #rows == 0 and ctx.player and type(ctx.player.currentQuestlog) == "table" and ctx.db then
    for questID, _ in pairs(ctx.player.currentQuestlog) do
      local qid = tonumber(questID)
      if qid and qid > 0 then
        local quest = nil
        if type(ctx.db.GetQuest) == "function" then
          local okQuest, value = pcall(function()
            return ctx.db.GetQuest(qid)
          end)
          if okQuest then
            quest = value
          end
        end
        if type(quest) == "table" then
          local title = quest.name or ("Quest " .. tostring(qid))
          local lvl = tonumber(quest.level) or tonumber(quest.questLevel) or tonumber(quest.requiredLevel) or playerLevel
          local rewardXP = 0
          if ctx.xp and type(ctx.xp.GetQuestLogRewardXP) == "function" then
            local ok, v = pcall(function() return ctx.xp:GetQuestLogRewardXP(qid, true) end)
            if ok and tonumber(v) then rewardXP = tonumber(v) end
          end

          local xpFactor = math.min(1, math.max(0, rewardXP / 4500))
          local levelFit = 1 - math.min(1, math.abs((tonumber(lvl) or playerLevel) - playerLevel) / 8)
          local progress = 0
          local guide = TA_GetGuideSignal(title)

          local proximity = 0.20
          local dxCells, dyCells = nil, nil
          local routeMapID, routeXPct, routeYPct = nil, nil, nil
          local start = TA_GetQuestStartFromQuestie(ctx.db, qid, currentMapID)
          if start then
            routeMapID = start.mapID
            routeXPct = start.xPct
            routeYPct = start.yPct
            if routeMapID == tonumber(currentMapID) then
              local pos = TA_MapPercentToCells(start.xPct, start.yPct, yardsPerCell, store.yardsPerPercent)
              if pos then
                dxCells = pos.dxCells
                dyCells = pos.dyCells
                local d = tonumber(pos.distCells) or (radius * 2)
                proximity = 1 - math.min(1, d / (radius * 1.5))
              end
            end
          end

          if proximity < 0 then proximity = 0 end
          if proximity > 1 then proximity = 1 end

          local factors = {
            xp = xpFactor,
            proximity = proximity,
            levelFit = levelFit,
            progress = progress,
            guide = guide,
          }

          local score = 0
          for k, w in pairs(weights) do
            score = score + ((factors[k] or 0) * (w or 0))
          end

          table.insert(rows, {
            index = nil,
            questID = qid,
            title = title,
            level = lvl,
            score = score,
            factors = factors,
            rewardXP = rewardXP,
            mapID = routeMapID,
            xPct = routeXPct,
            yPct = routeYPct,
            dxCells = dxCells,
            dyCells = dyCells,
          })
          usedQuestieFallback = true
        end
      end
    end
  end

  if #rows == 0 and type(TA.questObjectiveSnapshot) == "table" then
    local byQuest = {}
    for _, item in pairs(TA.questObjectiveSnapshot) do
      local qTitle = tostring(item and item.questTitle or "")
      if qTitle ~= "" then
        local row = byQuest[qTitle]
        if not row then
          row = {
            title = qTitle,
            done = 0,
            total = 0,
          }
          byQuest[qTitle] = row
        end
        row.total = row.total + 1
        if item.finished then
          row.done = row.done + 1
        end
      end
    end

    for title, meta in pairs(byQuest) do
      if meta.total > 0 and meta.done < meta.total then
        local progress = meta.done / meta.total
        local factors = {
          xp = 0.25,
          proximity = 0.20,
          levelFit = 0.50,
          progress = progress,
          guide = TA_GetGuideSignal(title),
        }
        local score = 0
        for k, w in pairs(weights) do
          score = score + ((factors[k] or 0) * (w or 0))
        end
        table.insert(rows, {
          index = nil,
          questID = nil,
          title = title,
          level = playerLevel,
          score = score,
          factors = factors,
          rewardXP = 0,
          mapID = nil,
          xPct = nil,
          yPct = nil,
          dxCells = nil,
          dyCells = nil,
        })
        usedSnapshotFallback = true
      end
    end
  end

  TA.questRouteLastScan = {
    total = total,
    headers = headerCount,
    completed = completedCount,
    candidates = #rows,
    usedExpandedHeaderScan = usedExpandedHeaderScan and true or false,
    usedQuestieFallback = usedQuestieFallback and true or false,
    usedSnapshotFallback = usedSnapshotFallback and true or false,
  }

  table.sort(rows, function(a, b)
    if a.score == b.score then
      return (a.level or 0) < (b.level or 0)
    end
    return a.score > b.score
  end)

  TA.questRouteCandidates = rows
  TA.questRouteLastAt = GetTime()

  local best = rows[1]
  if best then
    TA.questRouteOverlay = {
      mapID = best.mapID,
      dxCells = best.dxCells,
      dyCells = best.dyCells,
      title = best.title,
      questID = best.questID,
      xPct = best.xPct,
      yPct = best.yPct,
      score = best.score,
      updatedAt = GetTime(),
    }
    TA.questRouteLastSuggestedQuestID = best.questID
    TA.questRouteLastSuggestedFactors = best.factors
  else
    TA.questRouteOverlay = nil
    TA.questRouteLastSuggestedQuestID = nil
    TA.questRouteLastSuggestedFactors = nil
  end

  local n = math.max(1, math.min(10, tonumber(topN) or store.topN or 3))
  local top = {}
  for i = 1, math.min(n, #rows) do
    top[#top + 1] = rows[i]
  end
  return top
end

local function TA_ReportQuestRouteSuggestions(explain, topN)
  local store = TA_GetQuestRouterStore()
  if store.enabled == false then
    AddLine("system", "Quest routing is disabled. Use: questroute on")
    return
  end

  local top = TA_BuildQuestRouteCandidates(topN)
  if #top == 0 then
    local scan = TA.questRouteLastScan or {}
    AddLine("quest", string.format("No in-progress quests available to route. (entries=%d headers=%d completed=%d candidates=%d)", tonumber(scan.total) or 0, tonumber(scan.headers) or 0, tonumber(scan.completed) or 0, tonumber(scan.candidates) or 0))
    if scan.usedExpandedHeaderScan then
      AddLine("quest", "Quest-route scan auto-expanded collapsed quest headers.")
    end
    if scan.usedQuestieFallback then
      AddLine("quest", "Questie fallback was used; try /ta quests to confirm visible quest-log entries.")
    end
    return
  end

  AddLine("quest", string.format("Quest route suggestions (top %d):", #top))
  for i = 1, #top do
    local row = top[i]
    AddLine("quest", string.format("%d. %s [id:%s lvl:%d] score %.3f xp %d", i, row.title or "?", tostring(row.questID or "?"), tonumber(row.level) or 0, tonumber(row.score) or 0, tonumber(row.rewardXP) or 0))
    if explain then
      local f = row.factors or {}
      AddLine("quest", string.format("    factors: xp %.2f prox %.2f level %.2f progress %.2f guide %.2f", tonumber(f.xp) or 0, tonumber(f.proximity) or 0, tonumber(f.levelFit) or 0, tonumber(f.progress) or 0, tonumber(f.guide) or 0))
    end
  end

  local best = top[1]
  if best and best.mapID and best.xPct and best.yPct then
    AddLine("quest", string.format("DF marker: Q -> %s (map %d at %.1f, %.1f).", best.title or "quest", best.mapID, best.xPct, best.yPct))
  end
end

local function TA_ReportQuestRouteWeights()
  local s = TA_GetQuestRouterStore()
  local w = s.weights or {}
  AddLine("system", string.format("Quest route weights: xp=%.3f proximity=%.3f levelFit=%.3f progress=%.3f guide=%.3f", tonumber(w.xp) or 0, tonumber(w.proximity) or 0, tonumber(w.levelFit) or 0, tonumber(w.progress) or 0, tonumber(w.guide) or 0))
  AddLine("system", string.format("learningRate=%.3f samples=%d correct=%d", tonumber(s.learningRate) or 0, tonumber(s.samples) or 0, tonumber(s.correctSuggestions) or 0))
end

local function TA_ReportQuestRouteDebug()
  local scan = TA.questRouteLastScan or {}
  local s = TA_GetQuestRouterStore()
  local ctx = TA_GetQuestRouteContext()
  local snapshotCount = 0
  for _, v in pairs(TA.questObjectiveSnapshot or {}) do
    if v then snapshotCount = snapshotCount + 1 end
  end
  AddLine("system", string.format("QuestRoute debug: enabled=%s entries=%d headers=%d completed=%d candidates=%d", tostring(s.enabled ~= false), tonumber(scan.total) or 0, tonumber(scan.headers) or 0, tonumber(scan.completed) or 0, tonumber(scan.candidates) or 0))
  AddLine("system", string.format("  usedExpandedHeaderScan=%s usedQuestieFallback=%s usedSnapshotFallback=%s", tostring(scan.usedExpandedHeaderScan == true), tostring(scan.usedQuestieFallback == true), tostring(scan.usedSnapshotFallback == true)))
  AddLine("system", string.format("  data sources: QuestieDB=%s QuestXP=%s QuestiePlayer=%s objectiveSnapshot=%d", tostring(ctx.db ~= nil), tostring(ctx.xp ~= nil), tostring(ctx.player ~= nil), snapshotCount))
end

local function TA_SetQuestRouteWeight(key, value)
  local k = string.lower(tostring(key or ""))
  if TA_QUEST_ROUTE_DEFAULT_WEIGHTS[k] == nil then
    AddLine("system", "Unknown weight key. Use: xp, proximity, levelFit, progress, guide")
    return
  end
  local v = tonumber(value)
  if not v then
    AddLine("system", "Usage: questroute weight <xp|proximity|levelFit|progress|guide> <value>")
    return
  end
  local s = TA_GetQuestRouterStore()
  s.weights[k] = TA_ClampQuestRouteWeight(v)
  TA_NormalizeQuestRouteWeights(s.weights)
  TA_ReportQuestRouteWeights()
end

local function TA_SetQuestRouteToggle(enabled)
  local s = TA_GetQuestRouterStore()
  s.enabled = enabled and true or false
  if s.enabled then
    AddLine("system", "Quest routing enabled.")
  else
    AddLine("system", "Quest routing disabled.")
    TA.questRouteOverlay = nil
  end
end

local function TA_QuestRouteLearnFromTurnIn(questID, xpReward)
  local qid = tonumber(questID)
  if not qid then return end

  local s = TA_GetQuestRouterStore()
  local lastQ = tonumber(TA.questRouteLastSuggestedQuestID)
  local factors = TA.questRouteLastSuggestedFactors
  if not lastQ or type(factors) ~= "table" then return end

  local reward = (qid == lastQ) and 1 or -0.20
  local xp = tonumber(xpReward) or 0
  if qid == lastQ and xp > 0 then
    reward = reward + math.min(0.40, xp / 6000)
  end

  for k, baseline in pairs(TA_QUEST_ROUTE_DEFAULT_WEIGHTS) do
    local oldW = tonumber(s.weights[k]) or baseline
    local f = tonumber(factors[k]) or 0.5
    local centered = f - 0.5
    s.weights[k] = TA_ClampQuestRouteWeight(oldW + (s.learningRate or 0.08) * reward * centered)
  end
  TA_NormalizeQuestRouteWeights(s.weights)
  s.samples = (tonumber(s.samples) or 0) + 1
  if qid == lastQ then
    s.correctSuggestions = (tonumber(s.correctSuggestions) or 0) + 1
  end
end

local function TA_QuestRouteTomTomWaypoint()
  local overlay = TA.questRouteOverlay
  if not overlay or not overlay.mapID or not overlay.xPct or not overlay.yPct then
    AddLine("system", "No active quest route marker. Run: questroute")
    return
  end
  local tomtom = _G.TomTom
  if not tomtom or type(tomtom.AddWaypoint) ~= "function" then
    AddLine("system", "TomTom is not available.")
    return
  end

  local ok = pcall(function()
    tomtom:AddWaypoint(overlay.mapID, overlay.xPct / 100, overlay.yPct / 100, {
      title = "TA Route: " .. tostring(overlay.title or "Quest"),
      persistent = false,
      minimap = true,
      world = true,
    })
  end)
  if ok then
    AddLine("quest", string.format("TomTom waypoint set for %s.", tostring(overlay.title or "quest")))
  else
    AddLine("system", "Failed to create TomTom waypoint for this quest marker.")
  end
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
  if TA.swingDanceHintEnabled then
    local lagSec = 0
    if GetNetStats then
      lagSec = (tonumber(select(4, GetNetStats())) or 0) / 1000
    end
    local reactionBuf = tonumber(TA.swingDanceReactionBuffer) or 0.05
    local hintThreshold = lagSec + reactionBuf
    if remain > -0.1 and remain <= hintThreshold and TA.lastSwingState ~= "hintnow" then
      AddLine("swingDance", "Your hands glow bright. SWING YOUR WEAPON NOW!")
      TA.lastSwingState = "hintnow"
      return
    end
  end
  if remain <= 0 and TA.lastSwingState ~= "ready" and TA.lastSwingState ~= "hintnow" then
    AddLine("playerCombat", "Your next strike is ready.")
    TA.lastSwingState = "ready"
  elseif remain > 0 and remain <= 0.3 and TA.lastSwingState ~= "soon" and not TA.swingDanceHintEnabled then
    AddLine("playerCombat", "Your strike is about to land again.")
    TA.lastSwingState = "soon"
  end
end

function TA_SetSwingDanceHint(args)
  args = (args or ""):match("^%s*(.-)%s*$")
  local cmd = (args:match("^(%S+)") or ""):lower()
  if cmd == "on" then
    TA.swingDanceHintEnabled = true
    AddLine("system", "Swing dance hint enabled. Fires before each swing at latency + reaction buffer.")
  elseif cmd == "off" then
    TA.swingDanceHintEnabled = false
    AddLine("system", "Swing dance hint disabled.")
  elseif cmd == "status" then
    local lagSec = 0
    if GetNetStats then
      lagSec = (tonumber(select(4, GetNetStats())) or 0) / 1000
    end
    local buf = tonumber(TA.swingDanceReactionBuffer) or 0.05
    AddLine("system", string.format(
      "Swing hint: %s | Latency: %d ms | Reaction buffer: %d ms | Fires at: %d ms before swing.",
      TA.swingDanceHintEnabled and "ON" or "OFF",
      math.floor(lagSec * 1000),
      math.floor(buf * 1000),
      math.floor((lagSec + buf) * 1000)
    ))
  elseif cmd == "reaction" then
    local ms = tonumber(args:match("%S+%s+(%d+)"))
    if not ms then
      AddLine("system", "Usage: swingtimer reaction <ms>  (e.g. swingtimer reaction 100)")
      return
    end
    TA.swingDanceReactionBuffer = ms / 1000
    AddLine("system", string.format("Reaction buffer set to %d ms.", ms))
  else
    AddLine("system", "Usage: swingtimer on|off|status|reaction <ms>")
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

function TA_EnsureSealDpsModelTable()
  TextAdventurerDB = TextAdventurerDB or {}
  if type(TextAdventurerDB.sealDpsModel) ~= "table" then
    TextAdventurerDB.sealDpsModel = {}
  end
  return TextAdventurerDB.sealDpsModel
end

function TA_GetSealDpsRowsSorted()
  local model = TA_EnsureSealDpsModelTable()
  local rows = {}
  for rawLevel, row in pairs(model) do
    local level = tonumber(rawLevel)
    if level and type(row) == "table" then
      local sor = tonumber(row.sor)
      local soc = tonumber(row.soc)
      if sor and soc then
        table.insert(rows, { level = level, sor = sor, soc = soc })
      end
    end
  end
  table.sort(rows, function(a, b) return a.level < b.level end)
  return rows
end

function TA_ReportSealDpsModelRows()
  local rows = TA_GetSealDpsRowsSorted()
  if #rows == 0 then
    AddLine("playerCombat", "Seal DPS model is empty. Use: sealdps set <level> <sorDps> <socDps>")
    AddLine("system", "Bulk import: sealdps import <level:sor:soc,level:sor:soc,...>")
    return
  end

  AddLine("playerCombat", string.format("Seal DPS model rows: %d", #rows))
  for i = 1, #rows do
    local row = rows[i]
    AddLine("playerCombat", string.format("  L%d -> SoR %.1f, SoC %.1f", row.level, row.sor, row.soc))
  end
end

function TA_SetSealDpsModelRow(level, sor, soc)
  level = math.floor(tonumber(level) or 0)
  sor = tonumber(sor)
  soc = tonumber(soc)
  if level < 1 or level > 60 or not sor or not soc then
    AddLine("system", "Usage: sealdps set <level 1-60> <sorDps> <socDps>")
    return
  end

  local model = TA_EnsureSealDpsModelTable()
  model[level] = { sor = sor, soc = soc }
  AddLine("playerCombat", string.format("Saved seal model row L%d: SoR %.1f, SoC %.1f", level, sor, soc))
end

function TA_ClearSealDpsModel()
  local model = TA_EnsureSealDpsModelTable()
  wipe(model)
  AddLine("playerCombat", "Seal DPS model cleared.")
end

function TA_ImportSealDpsModel(payload)
  local raw = (payload or ""):match("^%s*(.-)%s*$")
  if raw == "" then
    AddLine("system", "Usage: sealdps import <level:sor:soc,level:sor:soc,...>")
    return
  end

  local model = TA_EnsureSealDpsModelTable()
  local added = 0
  local skipped = 0
  for token in string.gmatch(raw, "[^,]+") do
    local part = token:match("^%s*(.-)%s*$")
    local level, sor, soc = part:match("^(%d+)%s*:%s*([%-]?[%d%.]+)%s*:%s*([%-]?[%d%.]+)$")
    level = tonumber(level)
    sor = tonumber(sor)
    soc = tonumber(soc)
    if level and level >= 1 and level <= 60 and sor and soc then
      model[level] = { sor = sor, soc = soc }
      added = added + 1
    else
      skipped = skipped + 1
    end
  end

  AddLine("playerCombat", string.format("Seal DPS import complete: %d row(s) saved, %d skipped.", added, skipped))
  if added > 0 then
    TA_ReportSealDpsModelRows()
  end
end

function TA_GetSealDpsEstimate(level)
  local rows = TA_GetSealDpsRowsSorted()
  if #rows == 0 then return nil end
  if #rows == 1 then
    return {
      level = level,
      sor = rows[1].sor,
      soc = rows[1].soc,
      source = string.format("single row L%d", rows[1].level),
    }
  end

  if level <= rows[1].level then
    return {
      level = level,
      sor = rows[1].sor,
      soc = rows[1].soc,
      source = string.format("clamped to lowest row L%d", rows[1].level),
    }
  end

  for i = 1, (#rows - 1) do
    local a = rows[i]
    local b = rows[i + 1]
    if level == a.level then
      return {
        level = level,
        sor = a.sor,
        soc = a.soc,
        source = string.format("exact row L%d", a.level),
      }
    end
    if level >= a.level and level <= b.level then
      local span = b.level - a.level
      local t = span > 0 and ((level - a.level) / span) or 0
      return {
        level = level,
        sor = a.sor + ((b.sor - a.sor) * t),
        soc = a.soc + ((b.soc - a.soc) * t),
        source = string.format("interpolated between L%d and L%d", a.level, b.level),
      }
    end
  end

  local last = rows[#rows]
  return {
    level = level,
    sor = last.sor,
    soc = last.soc,
    source = string.format("clamped to highest row L%d", last.level),
  }
end

function TA_ReportSealDpsComparison(levelArg)
  local level = math.floor(tonumber(levelArg) or (UnitLevel("player") or 1))
  if level < 1 then level = 1 end
  if level > 60 then level = 60 end

  local estimate = TA_GetSealDpsEstimate(level)
  if not estimate then
    AddLine("playerCombat", "No seal DPS model data loaded.")
    AddLine("system", "Add rows: sealdps set <level> <sorDps> <socDps>")
    AddLine("system", "Bulk import: sealdps import <level:sor:soc,level:sor:soc,...>")
    return
  end

  local delta = estimate.sor - estimate.soc
  local best = "Seal of Righteousness"
  if delta < 0 then
    best = "Seal of the Crusader"
  end

  AddLine("playerCombat", string.format("Seal model at L%d -> SoR %.1f DPS, SoC %.1f DPS", level, estimate.sor, estimate.soc))
  AddLine("playerCombat", string.format("Recommendation: %s (delta %.1f DPS)", best, math.abs(delta)))
  AddLine("system", "Model source: " .. estimate.source)
end

local TA_SEAL_RANK_DATA = {
  sor = {
    spellNames = { "Seal of Righteousness" },
    ranks = {
      { rank = 1, level = 1, min = 32.88696412, max = 32.88696412, coeff = 0.0359375 },
      { rank = 2, level = 10, min = 38.49514012, max = 38.49514012, coeff = 0.078125 },
      { rank = 3, level = 18, min = 45.55517212, max = 45.55517212, coeff = 0.115625 },
      { rank = 4, level = 26, min = 55.36654012, max = 55.36654012, coeff = 0.125 },
      { rank = 5, level = 34, min = 68.03306812, max = 68.03306812, coeff = 0.125 },
      { rank = 6, level = 42, min = 83.45084812, max = 83.45084812, coeff = 0.125 },
      { rank = 7, level = 50, min = 100.3222481, max = 100.3222481, coeff = 0.125 },
      { rank = 8, level = 58, min = 119.9971481, max = 119.9971481, coeff = 0.125 },
    },
  },
  jor = {
    spellNames = { "Judgement of Righteousness", "Judgment of Righteousness" },
    ranks = {
      { rank = 1, level = 1, min = 15.0, max = 15.0, coeff = 0.20536125 },
      { rank = 2, level = 10, min = 25.0, max = 27.0, coeff = 0.4464375 },
      { rank = 3, level = 18, min = 39.0, max = 43.0, coeff = 0.6607275 },
      { rank = 4, level = 26, min = 57.0, max = 63.0, coeff = 0.7143 },
      { rank = 5, level = 34, min = 78.0, max = 86.0, coeff = 0.7143 },
      { rank = 6, level = 42, min = 102.0, max = 112.0, coeff = 0.7143 },
      { rank = 7, level = 50, min = 131.0, max = 143.0, coeff = 0.7143 },
      { rank = 8, level = 58, min = 162.0, max = 178.0, coeff = 0.7143 },
    },
  },
  soc = {
    spellNames = { "Seal of Command" },
    ranks = {
      { rank = 1, level = 20, weaponCoeff = 0.70, coeff = 0.29 },
      { rank = 2, level = 30, weaponCoeff = 0.70, coeff = 0.29 },
      { rank = 3, level = 40, weaponCoeff = 0.70, coeff = 0.29 },
      { rank = 4, level = 50, weaponCoeff = 0.70, coeff = 0.29 },
      { rank = 5, level = 60, weaponCoeff = 0.70, coeff = 0.29 },
    },
  },
  joc = {
    spellNames = { "Judgement of Command", "Judgment of Command" },
    ranks = {
      { rank = 1, level = 20, min = 46.5, max = 50.5, coeff = 0.4286 },
      { rank = 2, level = 30, min = 73.0, max = 80.0, coeff = 0.4286 },
      { rank = 3, level = 40, min = 102.0, max = 112.0, coeff = 0.4286 },
      { rank = 4, level = 50, min = 130.5, max = 143.5, coeff = 0.4286 },
      { rank = 5, level = 60, min = 169.5, max = 186.5, coeff = 0.4286 },
    },
  },
}

local TA_WARRIOR_ABILITY_DATA = {
  heroicStrike = {
    spellIDs = { 78 },
    ranks = {
      { rank = 1, level = 1, rage = 15, value = 11 },
      { rank = 2, level = 8, rage = 15, value = 21 },
      { rank = 3, level = 16, rage = 15, value = 32 },
      { rank = 4, level = 24, rage = 15, value = 44 },
      { rank = 5, level = 32, rage = 15, value = 58 },
      { rank = 6, level = 40, rage = 15, value = 80 },
      { rank = 7, level = 48, rage = 15, value = 111 },
      { rank = 8, level = 56, rage = 15, value = 138 },
      { rank = 9, level = 60, rage = 15, value = 157 },
    },
  },
  rend = {
    spellIDs = { 772 },
    ranks = {
      { rank = 1, level = 4, rage = 10, value = 15, ticks = 3 },
      { rank = 2, level = 10, rage = 10, value = 28, ticks = 4 },
      { rank = 3, level = 20, rage = 10, value = 45, ticks = 5 },
      { rank = 4, level = 30, rage = 10, value = 66, ticks = 6 },
      { rank = 5, level = 40, rage = 10, value = 98, ticks = 7 },
      { rank = 6, level = 50, rage = 10, value = 126, ticks = 7 },
      { rank = 7, level = 60, rage = 10, value = 147, ticks = 7 },
    },
  },
  overpower = {
    spellIDs = { 7384 },
    ranks = {
      { rank = 1, level = 12, rage = 5, value = 5 },
      { rank = 2, level = 28, rage = 5, value = 15 },
      { rank = 3, level = 44, rage = 5, value = 25 },
      { rank = 4, level = 60, rage = 5, value = 35 },
    },
  },
  slam = {
    spellIDs = { 1464 },
    ranks = {
      { rank = 1, level = 30, rage = 15, value = 32, castTime = 1.5 },
      { rank = 2, level = 38, rage = 15, value = 43, castTime = 1.5 },
      { rank = 3, level = 46, rage = 15, value = 68, castTime = 1.5 },
      { rank = 4, level = 54, rage = 15, value = 87, castTime = 1.5 },
    },
  },
  whirlwind = {
    spellIDs = { 1680 },
    ranks = {
      { rank = 1, level = 36, rage = 25, value = 0, cooldown = 10 },
    },
  },
  mortalStrike = {
    spellIDs = { 12294 },
    ranks = {
      { rank = 1, level = 40, rage = 30, value = 85, cooldown = 6 },
      { rank = 2, level = 48, rage = 30, value = 110, cooldown = 6 },
      { rank = 3, level = 54, rage = 30, value = 135, cooldown = 6 },
      { rank = 4, level = 60, rage = 30, value = 160, cooldown = 6 },
    },
  },
}

function TA_GetSealLiveConfig()
  TextAdventurerDB = TextAdventurerDB or {}
  if type(TextAdventurerDB.sealDpsLiveConfig) ~= "table" then
    TextAdventurerDB.sealDpsLiveConfig = {}
  end
  local cfg = TextAdventurerDB.sealDpsLiveConfig
  if type(cfg.targetLevel) ~= "number" then cfg.targetLevel = UnitLevel("player") or 60 end
  if type(cfg.judgementCD) ~= "number" then cfg.judgementCD = 8 end
  if type(cfg.socPPM) ~= "number" then cfg.socPPM = 7 end
  if type(cfg.hybridWindow) ~= "number" then cfg.hybridWindow = 60 end
  if type(cfg.resealGCD) ~= "number" then cfg.resealGCD = 1.5 end
  if cfg.attackFromBehind == nil then cfg.attackFromBehind = true end
  return cfg
end

function TA_SetSealLiveNumber(key, value, minValue, maxValue, label)
  local n = tonumber(value)
  if not n then
    AddLine("system", string.format("Usage: sealdps live %s <%s-%s>", key, tostring(minValue), tostring(maxValue)))
    return
  end
  n = math.floor((n * 100) + 0.5) / 100
  if n < minValue then n = minValue end
  if n > maxValue then n = maxValue end
  local cfg = TA_GetSealLiveConfig()
  cfg[key] = n
  AddLine("playerCombat", string.format("Live seal setting: %s = %s", label, tostring(n)))
end

function TA_SetSealLiveBehind(arg)
  local v = (arg or ""):match("^%s*(.-)%s*$"):lower()
  local cfg = TA_GetSealLiveConfig()
  if v == "on" or v == "true" or v == "1" or v == "behind" then
    cfg.attackFromBehind = true
  elseif v == "off" or v == "false" or v == "0" or v == "front" then
    cfg.attackFromBehind = false
  else
    AddLine("system", "Usage: sealdps live behind <on|off>")
    return
  end
  AddLine("playerCombat", string.format("Live seal setting: attackFromBehind = %s", cfg.attackFromBehind and "true" or "false"))
end

function TA_ReportSealLiveAssumptions()
  local cfg = TA_GetSealLiveConfig()
  AddLine("playerCombat", "sealdps live assumptions:")
  AddLine("playerCombat", string.format("  target level: %d", cfg.targetLevel or 63))
  AddLine("playerCombat", string.format("  judgement CD: %.1fs", cfg.judgementCD or 8))
  AddLine("playerCombat", string.format("  SoC proc rate: %.2f PPM", cfg.socPPM or 7))
  AddLine("playerCombat", string.format("  hybrid test window: %.0fs", cfg.hybridWindow or 60))
  AddLine("playerCombat", string.format("  reseal GCD penalty: %.1fs", cfg.resealGCD or 1.5))
  AddLine("playerCombat", string.format("  attacking from behind: %s", cfg.attackFromBehind and "yes" or "no"))
  AddLine("playerCombat", "  tip: set target to your current level while leveling")
  AddLine("playerCombat", "  source: Despotus v0.3.6 Skills table rank coefficients")
end

function TA_SetSealLiveHybridWindow(seconds)
  TA_SetSealLiveNumber("hybridWindow", seconds, 15, 300, "hybridWindow")
end

function TA_SetSealLiveResealGCD(seconds)
  TA_SetSealLiveNumber("resealGCD", seconds, 0.5, 2.5, "resealGCD")
end

function TA_GetHighestKnownRank(spellNames)
  if type(spellNames) ~= "table" or #spellNames == 0 then return nil end
  local wanted = {}
  for i = 1, #spellNames do
    wanted[spellNames[i]:lower()] = true
  end

  local bestRank = nil
  local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
  for tab = 1, numTabs do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    offset = offset or 0
    numSpells = numSpells or 0
    for i = 1, numSpells do
      local idx = offset + i
      local name, subText = GetSpellBookItemName(idx, BOOKTYPE_SPELL)
      if name and wanted[name:lower()] then
        local parsedRank = nil
        if subText and subText ~= "" then
          parsedRank = tonumber((subText:match("(%d+)") or ""))
        end
        if parsedRank then
          bestRank = math.max(bestRank or 0, parsedRank)
        else
          bestRank = bestRank or 1
        end
      end
    end
  end
  return bestRank
end

function TA_PlayerKnowsSpellIDs(spellIDs)
  if type(spellIDs) ~= "table" then return false end
  for i = 1, #spellIDs do
    local spellID = tonumber(spellIDs[i])
    if spellID then
      if TA_IsSpellKnownCompat(spellID) then
        return true
      end
      if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if name and TA_GetHighestKnownRank({ name }) then
          return true
        end
      end
    end
  end
  return false
end

function TA_SelectRankByLevel(rankRows, level)
  if type(rankRows) ~= "table" or #rankRows == 0 then return nil end
  local pick = nil
  for i = 1, #rankRows do
    local row = rankRows[i]
    if (row.level or 1) <= level then
      pick = row
    end
  end
  return pick or rankRows[1]
end

function TA_SelectRankByNumber(rankRows, rank)
  if not rank then return nil end
  for i = 1, #rankRows do
    if rankRows[i].rank == rank then
      return rankRows[i]
    end
  end
  return nil
end

function TA_SelectWarriorAbilityRow(key)
  local data = TA_WARRIOR_ABILITY_DATA[key]
  if not data or type(data.ranks) ~= "table" then return nil end
  local playerLevel = UnitLevel("player") or 1
  return TA_SelectRankByLevel(data.ranks, playerLevel)
end

function TA_GetWarriorTalentRank(value, maxRank)
  local n = math.floor(tonumber(value) or 0)
  if n < 0 then n = 0 end
  if maxRank and n > maxRank then n = maxRank end
  return n
end

function TA_GetLiveSpellRankRow(dataKey)
  local data = TA_SEAL_RANK_DATA[dataKey]
  if not data then return nil, nil end
  local playerLevel = UnitLevel("player") or 60
  local knownRank = TA_GetHighestKnownRank(data.spellNames)
  local row = TA_SelectRankByNumber(data.ranks, knownRank) or TA_SelectRankByLevel(data.ranks, playerLevel)
  return row, knownRank
end

function TA_GetSpellPowerHoly()
  if GetSpellBonusDamage then
    local okSchool, vSchool = pcall(GetSpellBonusDamage, 2)
    if okSchool and tonumber(vSchool) then
      return tonumber(vSchool)
    end
    local okGeneric, vGeneric = pcall(GetSpellBonusDamage)
    if okGeneric and tonumber(vGeneric) then
      return tonumber(vGeneric)
    end
  end
  return 0
end

function TA_GetMeleeConnectChance(targetLevel, attackFromBehind)
  local level = UnitLevel("player") or 60
  local diff = math.max(0, (targetLevel or 63) - level)
  local baseMiss = 0.05 + (0.01 * diff)
  if baseMiss > 0.09 then baseMiss = 0.09 end
  local hitBonus = (GetHitModifier and (GetHitModifier() or 0) or 0) / 100
  local miss = math.max(0, baseMiss - hitBonus)
  local dodge = 0.065
  local parry = attackFromBehind and 0 or 0.14
  local block = attackFromBehind and 0 or 0.05
  local connect = 1 - miss - dodge - parry - block
  if connect < 0.05 then connect = 0.05 end
  if connect > 1 then connect = 1 end
  return connect
end

function TA_BuildLiveWarriorOptionMetrics(c)
  local profile = TA_NormalizeWarriorWeaponProfile and TA_NormalizeWarriorWeaponProfile(c.warriorWeaponProfile)
  if profile == "auto" and TA_DetectWarriorWeaponProfile then
    profile = TA_DetectWarriorWeaponProfile()
  end
  local tuning = TA_GetWarriorWeaponProfileTuning and TA_GetWarriorWeaponProfileTuning(profile)
  if tuning then
    c.warriorDodgeChance = tuning.warriorDodgeChance
    c.warriorGlancingChance = tuning.warriorGlancingChance
    c.warriorGlancingDamage = tuning.warriorGlancingDamage
    c.warriorNormalization = tuning.warriorNormalization
    c.warriorOverpowerPerMin = tuning.warriorOverpowerPerMin
    c.warriorWhirlwindTargets = tuning.warriorWhirlwindTargets
  end

  local cfg = TA_GetSealLiveConfig()
  local minMain, maxMain = UnitDamage("player")
  local mainSpeed = UnitAttackSpeed("player")
  if not minMain or not maxMain or not mainSpeed or mainSpeed <= 0 then
    return nil, "Live XP optimizer unavailable: no valid main-hand weapon data."
  end

  local avgWeaponHit = (minMain + maxMain) / 2
  local playerLevel = UnitLevel("player") or 1
  local targetLevel = tonumber(cfg.targetLevel) or playerLevel
  local meleeConnect = TA_GetMeleeConnectChance(targetLevel, cfg.attackFromBehind)
  local critChance = ((GetCritChance and (GetCritChance() or 0)) or 0) / 100
  local dodgeChance = tonumber(c.warriorDodgeChance) or 0.05
  local glancingChance = tonumber(c.warriorGlancingChance) or 0.10
  local glancingDamage = tonumber(c.warriorGlancingDamage) or 0.95

  if dodgeChance < 0 then dodgeChance = 0 end
  if dodgeChance > 0.35 then dodgeChance = 0.35 end
  if glancingChance < 0 then glancingChance = 0 end
  if glancingChance > 0.40 then glancingChance = 0.40 end
  if glancingDamage < 0.5 then glancingDamage = 0.5 end
  if glancingDamage > 1.0 then glancingDamage = 1.0 end

  local swingsPerSec = 1 / mainSpeed
  local baseAutoDps = avgWeaponHit * swingsPerSec * meleeConnect
  local ragePerHit = math.max(0.1, avgWeaponHit / 7.5)
  local ragePerSec = ragePerHit * swingsPerSec * math.max(0.35, meleeConnect)

  local impHS = TA_GetWarriorTalentRank(c.warriorImpHSRank, 3)
  local impRend = TA_GetWarriorTalentRank(c.warriorImpRendRank, 3)
  local impOP = TA_GetWarriorTalentRank(c.warriorImpOverpowerRank, 2)
  local impSlam = TA_GetWarriorTalentRank(c.warriorImpSlamRank, 5)
  local overpowerPerMin = tonumber(c.warriorOverpowerPerMin) or 1.2
  local deepWoundsPerPoint = tonumber(c.warriorDeepWoundsPerPoint) or 0.2
  local impalePerPoint = tonumber(c.warriorImpalePerPoint) or 0.1
  local impaleRank = TA_GetWarriorTalentRank(c.warriorImpaleRank, 2)

  local hsRow = TA_SelectWarriorAbilityRow("heroicStrike")
  local rendRow = TA_SelectWarriorAbilityRow("rend")
  local opRow = TA_SelectWarriorAbilityRow("overpower")
  local slamRow = TA_SelectWarriorAbilityRow("slam")
  local wwRow = TA_SelectWarriorAbilityRow("whirlwind")
  local msRow = TA_SelectWarriorAbilityRow("mortalStrike")

  local knowsHS = TA_PlayerKnowsSpellIDs(TA_WARRIOR_ABILITY_DATA.heroicStrike.spellIDs)
  local knowsRend = TA_PlayerKnowsSpellIDs(TA_WARRIOR_ABILITY_DATA.rend.spellIDs)
  local knowsOP = TA_PlayerKnowsSpellIDs(TA_WARRIOR_ABILITY_DATA.overpower.spellIDs)
  local knowsSlam = TA_PlayerKnowsSpellIDs(TA_WARRIOR_ABILITY_DATA.slam.spellIDs)
  local knowsWW = TA_PlayerKnowsSpellIDs(TA_WARRIOR_ABILITY_DATA.whirlwind.spellIDs)
  local knowsMS = TA_PlayerKnowsSpellIDs(TA_WARRIOR_ABILITY_DATA.mortalStrike.spellIDs)

  local normalizedWeaponHit = avgWeaponHit * ((tonumber(c.warriorNormalization) or 3.3) / math.max(1.6, mainSpeed))

  local function estimatePhysicalHit(base)
    local hitBase = math.max(0, tonumber(base) or 0)
    local nonGlancing = hitBase * (1 + critChance - dodgeChance - glancingChance)
    local glancing = hitBase * glancingChance * glancingDamage
    local deepWounds = hitBase * critChance * (TA_GetWarriorTalentRank(c.warriorDeepWoundsRank, 3) * deepWoundsPerPoint)
    return math.max(0, nonGlancing + glancing + deepWounds)
  end

  local hsCost = hsRow and math.max(0, (hsRow.rage or 15) - impHS) or 15
  local hsHit = hsRow and estimatePhysicalHit(avgWeaponHit + (hsRow.value or 0)) or 0
  local hsPerSec = math.max(0, math.min(hsCost > 0 and (ragePerSec / hsCost) or 0, swingsPerSec * 0.95))
  local hsDps = hsPerSec * hsHit

  local rendDps = 0
  if rendRow and knowsRend then
    local impRendBonus = 0
    if impRend == 1 then impRendBonus = 0.15
    elseif impRend == 2 then impRendBonus = 0.25
    elseif impRend >= 3 then impRendBonus = 0.35 end
    local rendDuration = math.max(1, tonumber(rendRow.ticks) or 1) * 3
    local rendTotal = (rendRow.value or 0) * (1 + impRendBonus) * math.max(0.45, 1 - dodgeChance)
    rendDps = rendTotal / rendDuration
  end

  local overpowerDps = 0
  if opRow and knowsOP then
    local opCritBonus = impOP * 0.25
    local opHit = (normalizedWeaponHit + (opRow.value or 0)) * (1 + critChance + (opCritBonus * (1 + (impaleRank * impalePerPoint))))
    overpowerDps = (math.max(0, overpowerPerMin) / 60) * opHit
  end

  local slamDps = 0
  if slamRow and knowsSlam then
    local slamCast = math.max(0.5, (slamRow.castTime or 1.5) - (0.1 * impSlam))
    local slamHit = estimatePhysicalHit(normalizedWeaponHit + (slamRow.value or 0))
    local slamPenalty = (slamCast / math.max(1.0, mainSpeed)) * avgWeaponHit * math.max(0.45, meleeConnect)
    local slamCycle = math.max(2.0, mainSpeed + slamCast)
    slamDps = math.max(0, (slamHit - slamPenalty) / slamCycle)
  end

  local wwDps = 0
  if wwRow and knowsWW then
    local wwTargets = math.floor(tonumber(c.warriorWhirlwindTargets) or 1)
    if wwTargets < 1 then wwTargets = 1 end
    if wwTargets > 4 then wwTargets = 4 end
    local wwHit = estimatePhysicalHit(normalizedWeaponHit) * wwTargets
    local wwCd = math.max(6, tonumber(wwRow.cooldown) or 10)
    wwDps = wwHit / wwCd
  end

  local msDps = 0
  if msRow and knowsMS then
    local msHit = estimatePhysicalHit(normalizedWeaponHit + (msRow.value or 0))
    local msCd = math.max(4, tonumber(msRow.cooldown) or 6)
    msDps = msHit / msCd
  end

  return {
    baseAutoDps = baseAutoDps,
    hsDps = hsDps,
    rendDps = rendDps,
    overpowerDps = overpowerDps,
    slamDps = slamDps,
    wwDps = wwDps,
    msDps = msDps,
    knowsHS = knowsHS,
    knowsRend = knowsRend,
    knowsOP = knowsOP,
    knowsSlam = knowsSlam,
    knowsWW = knowsWW,
    knowsMS = knowsMS,
  }
end

function TA_GetJudgementConnectChance(targetLevel)
  local level = UnitLevel("player") or 60
  local diff = math.max(0, (targetLevel or 63) - level)
  local miss = 0.04 + (0.01 * diff)
  if miss > 0.17 then miss = 0.17 end
  local connect = 1 - miss
  if connect < 0.5 then connect = 0.5 end
  return connect
end

local function TA_ScanWeaponTooltip(bag, slot, isEquipped, equippedSlot)
  if not CreateFrame or not UIParent then return nil end
  if not TA.bagInspectTooltip then
    TA.bagInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerBagInspectTooltip", UIParent, "GameTooltipTemplate")
  end
  local tip = TA.bagInspectTooltip
  if not tip then return nil end
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  if isEquipped then
    if tip.SetInventoryItem then
      tip:SetInventoryItem("player", equippedSlot or 16)
    else
      tip:Hide()
      return nil
    end
  else
    if tip.SetBagItem then
      tip:SetBagItem(bag, slot)
    else
      tip:Hide()
      return nil
    end
  end
  local tipName = tip:GetName()
  local speed, minDmg, maxDmg
  for i = 1, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local ltext = left and left:GetText() or ""
    local rtext = right and right:GetText() or ""
    local lo, hi = ltext:match("(%d+)%s*%-%s*(%d+)%s+Damage")
    if lo then minDmg = tonumber(lo); maxDmg = tonumber(hi) end
    local rlo, rhi = rtext:match("(%d+)%s*%-%s*(%d+)%s+Damage")
    if rlo then minDmg = tonumber(rlo); maxDmg = tonumber(rhi) end
    local ls = ltext:match("Speed%s+(%d+%.?%d*)")
    if ls then speed = tonumber(ls) end
    local rs = rtext:match("Speed%s+(%d+%.?%d*)")
    if rs then speed = tonumber(rs) end
  end
  tip:Hide()
  return speed, minDmg, maxDmg
end

function TA_BuildWeaponDanceReport()
  local sorRow = TA_GetLiveSpellRankRow("sor")
  if not sorRow then
    AddLine("playerCombat", "Weapon dance report unavailable: no Seal of Righteousness rank found in spellbook.")
    return
  end
  local spellPower = TA_GetSpellPowerHoly()
  local sorBase = ((sorRow.min or 0) + (sorRow.max or 0)) / 2
  local sorHit = sorBase + spellPower * (sorRow.coeff or 0)
  -- In Classic 1.12 SoR scales linearly with weapon speed; 3.0s is the reference point.
  local sorRef = 3.0
  local sorDpsRate = sorHit / sorRef

  local cfg = TA_GetSealLiveConfig and TA_GetSealLiveConfig() or {}
  local meleeConnect = TA_GetMeleeConnectChance(cfg.targetLevel, cfg.attackFromBehind)

  local weapons = {}

  -- Equipped main-hand (slot 16)
  local eqSpeed = UnitAttackSpeed("player")
  local eqMinDmg, eqMaxDmg = UnitDamage("player")
  if eqSpeed and eqSpeed > 0 and eqMinDmg and eqMaxDmg then
    local eqName = "Equipped"
    local eqLink = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    if eqLink then
      local n = GetItemInfo(eqLink)
      if n then eqName = n end
    end
    table.insert(weapons, {
      name = eqName,
      speed = eqSpeed,
      avgDmg = (eqMinDmg + eqMaxDmg) / 2,
      sorPerSwing = sorDpsRate * eqSpeed,
      whiteDps = ((eqMinDmg + eqMaxDmg) / 2) / eqSpeed,
      isEquipped = true,
      loc = "Main Hand",
    })
  end

  -- Bags 0-4
  if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
    for bag = 0, 4 do
      local numSlots = C_Container.GetContainerNumSlots(bag)
      if numSlots and numSlots > 0 then
        for slot = 1, numSlots do
          local info = C_Container.GetContainerItemInfo(bag, slot)
          if info and info.itemID then
            local itemLink = info.hyperlink
              or (C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot))
            if itemLink then
              local iName, _, _, _, _, _, _, _, iEquipLoc = GetItemInfo(itemLink)
              local isMainHand = iEquipLoc == "INVTYPE_WEAPON"
                or iEquipLoc == "INVTYPE_2HWEAPON"
                or iEquipLoc == "INVTYPE_WEAPONMAINHAND"
              if isMainHand then
                local speed, minDmg, maxDmg = TA_ScanWeaponTooltip(bag, slot, false)
                if speed and speed > 0 and minDmg and maxDmg then
                  local avgDmg = (minDmg + maxDmg) / 2
                  table.insert(weapons, {
                    name = iName or "Unknown",
                    speed = speed,
                    avgDmg = avgDmg,
                    sorPerSwing = sorDpsRate * speed,
                    whiteDps = avgDmg / speed,
                    isEquipped = false,
                    loc = string.format("Bag%d/%d", bag, slot),
                  })
                end
              end
            end
          end
        end
      end
    end
  end

  if #weapons == 0 then
    AddLine("playerCombat", "No weapons found. Equip a weapon or place weapons in your bags.")
    return
  end

  table.sort(weapons, function(a, b) return a.sorPerSwing > b.sorPerSwing end)

  AddLine("playerCombat", string.format(
    "=== Weapon Dance Report (SoR rank %d, %d SP) ===",
    sorRow.rank or 0, math.floor(spellPower)
  ))
  AddLine("playerCombat", string.format(
    "%-22s  %5s  %9s  %8s  %s",
    "Weapon", "Speed", "SoR/Swing", "WhiteDPS", "Where"
  ))
  for _, w in ipairs(weapons) do
    local tag = w.isEquipped and "[EQ]" or "    "
    AddLine("playerCombat", string.format(
      "%s %-18s  %5.2f  %9.1f  %8.1f  %s",
      tag, w.name:sub(1, 18), w.speed,
      w.sorPerSwing * meleeConnect,
      w.whiteDps * meleeConnect,
      w.loc
    ))
  end

  local equippedW = nil
  for _, w in ipairs(weapons) do
    if w.isEquipped then equippedW = w; break end
  end
  local bestDonor = weapons[1]
  if equippedW and bestDonor and not bestDonor.isEquipped then
    local danceGain = (bestDonor.sorPerSwing - equippedW.sorPerSwing) * meleeConnect
    local danceGainDps = danceGain / equippedW.speed
    AddLine("playerCombat", string.format(
      "Dance bonus: +%.1f SoR/swap with '%s' (%.2fs), ~+%.2f effective DPS.",
      danceGain, bestDonor.name:sub(1, 22), bestDonor.speed, danceGainDps
    ))
    AddLine("playerCombat", "Use 'swingtimer on' to enable the swap-now hint.")
  elseif #weapons == 1 and equippedW then
    AddLine("playerCombat", "No bag weapons found. Place slower weapons in bags for comparison.")
  elseif bestDonor and bestDonor.isEquipped then
    AddLine("playerCombat", "Your equipped weapon is already the best SoR donor in your bags.")
  end
end

function TA_ReportLiveSealDpsComparison()
  local cfg = TA_GetSealLiveConfig()
  local minMain, maxMain = UnitDamage("player")
  local mainSpeed = UnitAttackSpeed("player")
  if not minMain or not maxMain or not mainSpeed or mainSpeed <= 0 then
    AddLine("playerCombat", "Live seal model unavailable: no valid main-hand weapon data.")
    return
  end

  local spellPower = TA_GetSpellPowerHoly()
  local avgWeaponHit = (minMain + maxMain) / 2
  local meleeConnect = TA_GetMeleeConnectChance(cfg.targetLevel, cfg.attackFromBehind)
  local judgeConnect = TA_GetJudgementConnectChance(cfg.targetLevel)
  local swingsPerSec = 1 / mainSpeed

  local sorRow, sorKnownRank = TA_GetLiveSpellRankRow("sor")
  local jorRow, jorKnownRank = TA_GetLiveSpellRankRow("jor")
  local socRow, socKnownRank = TA_GetLiveSpellRankRow("soc")
  local jocRow, jocKnownRank = TA_GetLiveSpellRankRow("joc")

  if not sorRow and not socRow then
    AddLine("playerCombat", "Live seal model unavailable: no seal ranks found in spellbook.")
    return
  end

  local sorBase = sorRow and (((sorRow.min or 0) + (sorRow.max or 0)) / 2) or 0
  local jorBase = jorRow and (((jorRow.min or 0) + (jorRow.max or 0)) / 2) or 0
  local jocBase = jocRow and (((jocRow.min or 0) + (jocRow.max or 0)) / 2) or 0

  local sorCoeff = sorRow and (sorRow.coeff or 0) or 0
  local jorCoeff = jorRow and (jorRow.coeff or 0) or 0
  local socCoeff = socRow and (socRow.coeff or 0) or 0.29
  local socWeaponCoeff = socRow and (socRow.weaponCoeff or 0.70) or 0.70
  local jocCoeff = jocRow and (jocRow.coeff or 0) or 0

  local sorHit = sorBase + (spellPower * sorCoeff)
  local sorDps = sorHit * swingsPerSec * meleeConnect

  local jorHit = jorBase + (spellPower * jorCoeff)
  local jorDps = (jorHit / math.max(1, cfg.judgementCD)) * judgeConnect

  local socHit = (avgWeaponHit * socWeaponCoeff) + (spellPower * socCoeff)
  local socConnects = (math.max(0.5, cfg.socPPM) / 60) * meleeConnect
  local socDps = socHit * socConnects

  local jocHit = jocBase + (spellPower * jocCoeff)
  local jocDps = (jocHit / math.max(1, cfg.judgementCD)) * judgeConnect

  local totalSor = sorDps + jorDps
  local totalSoc = socDps + jocDps
  local delta = totalSor - totalSoc
  local best = delta >= 0 and "Seal of Righteousness" or "Seal of Command"

  AddLine("playerCombat", string.format("Live seal model (%s):", cfg.attackFromBehind and "behind" or "front"))
  AddLine("playerCombat", string.format("  SoR path: Seal %.1f + JoR %.1f = %.1f DPS", sorDps, jorDps, totalSor))
  AddLine("playerCombat", string.format("  SoC path: Seal %.1f + JoC %.1f = %.1f DPS", socDps, jocDps, totalSoc))
  AddLine("system", string.format("Ranks: SoR %d, JoR %d, SoC %d, JoC %d", sorKnownRank or (sorRow and sorRow.rank or 0), jorKnownRank or (jorRow and jorRow.rank or 0), socKnownRank or (socRow and socRow.rank or 0), jocKnownRank or (jocRow and jocRow.rank or 0)))
  AddLine("playerCombat", string.format("Recommendation: %s (delta %.1f DPS)", best, math.abs(delta)))
  AddLine("system", string.format("Inputs: SP %.0f, weapon %.0f-%.0f @ %.2fs, melee connect %.1f%%, judge connect %.1f%%", spellPower, minMain, maxMain, mainSpeed, meleeConnect * 100, judgeConnect * 100))
  AddLine("system", "Tip: run 'sealdps assumptions' to inspect or tune live model settings.")
end

function TA_ReportLiveSealHybridComparison(windowArg)
  local cfg = TA_GetSealLiveConfig()
  local window = tonumber(windowArg) or tonumber(cfg.hybridWindow) or 60
  if window < 15 then window = 15 end
  if window > 300 then window = 300 end
  local resealGCD = tonumber(cfg.resealGCD) or 1.5

  local minMain, maxMain = UnitDamage("player")
  local mainSpeed = UnitAttackSpeed("player")
  if not minMain or not maxMain or not mainSpeed or mainSpeed <= 0 then
    AddLine("playerCombat", "Hybrid test unavailable: no valid main-hand weapon data.")
    return
  end

  local spellPower = TA_GetSpellPowerHoly()
  local avgWeaponHit = (minMain + maxMain) / 2
  local meleeConnect = TA_GetMeleeConnectChance(cfg.targetLevel, cfg.attackFromBehind)
  local judgeConnect = TA_GetJudgementConnectChance(cfg.targetLevel)
  local swingsPerSec = 1 / mainSpeed

  local sorRow = TA_GetLiveSpellRankRow("sor")
  local jorRow = TA_GetLiveSpellRankRow("jor")
  local socRow = TA_GetLiveSpellRankRow("soc")
  local jocRow = TA_GetLiveSpellRankRow("joc")

  if not sorRow or not jorRow or not jocRow then
    AddLine("playerCombat", "Hybrid test unavailable: missing SoR/JoR/JoC ranks in spellbook.")
    return
  end

  local sorBase = ((sorRow.min or 0) + (sorRow.max or 0)) / 2
  local jorBase = ((jorRow.min or 0) + (jorRow.max or 0)) / 2
  local jocBase = ((jocRow.min or 0) + (jocRow.max or 0)) / 2

  local sorHit = sorBase + (spellPower * (sorRow.coeff or 0))
  local sorDps = sorHit * swingsPerSec * meleeConnect

  local jorHit = jorBase + (spellPower * (jorRow.coeff or 0))
  local jorDps = (jorHit / math.max(1, cfg.judgementCD)) * judgeConnect

  local socWeaponCoeff = socRow and (socRow.weaponCoeff or 0.70) or 0.70
  local socCoeff = socRow and (socRow.coeff or 0.29) or 0.29
  local socHit = (avgWeaponHit * socWeaponCoeff) + (spellPower * socCoeff)
  local socConnects = (math.max(0.5, cfg.socPPM) / 60) * meleeConnect
  local socDps = socHit * socConnects

  local jocHit = jocBase + (spellPower * (jocRow.coeff or 0))
  local jocDps = (jocHit / math.max(1, cfg.judgementCD)) * judgeConnect

  local pureSorDps = sorDps + jorDps
  local pureSocDps = socDps + jocDps

  local oneJudgeDeltaDmg = (jocHit - jorHit) * judgeConnect
  local resealPenaltyDmg = sorDps * resealGCD
  local hybridDps = pureSorDps + ((oneJudgeDeltaDmg - resealPenaltyDmg) / window)
  local hybridDelta = hybridDps - pureSorDps

  AddLine("playerCombat", string.format("Hybrid test over %.0fs:", window))
  AddLine("playerCombat", string.format("  Pure SoR loop: %.1f DPS", pureSorDps))
  AddLine("playerCombat", string.format("  SoC judge -> reseal SoR: %.1f DPS", hybridDps))
  AddLine("playerCombat", string.format("  Pure SoC loop (reference): %.1f DPS", pureSocDps))
  if hybridDelta >= 0 then
    AddLine("playerCombat", string.format("Result: JoC opener improves SoR path by %.1f DPS.", math.abs(hybridDelta)))
  else
    AddLine("playerCombat", string.format("Result: JoC opener lowers SoR path by %.1f DPS.", math.abs(hybridDelta)))
  end
  AddLine("system", string.format("Assumptions: one JoC replaces one JoR per window; reseal penalty %.1fs", resealGCD))
end

function TA_GetSpellPowerBySchool(school)
  if GetSpellBonusDamage then
    local okSchool, vSchool = pcall(GetSpellBonusDamage, school)
    if okSchool and tonumber(vSchool) then
      return tonumber(vSchool)
    end
    local okGeneric, vGeneric = pcall(GetSpellBonusDamage)
    if okGeneric and tonumber(vGeneric) then
      return tonumber(vGeneric)
    end
  end
  return 0
end

function TA_NormalizeWarlockMode(mode)
  local m = (mode or ""):match("^%s*(.-)%s*$"):lower()
  if m == "fire" or m == "firelock" then
    return "fire"
  end
  return "shadow"
end

local TA_WARLOCK_CONFIG_KEYS_HELP = "targetlevel, baseminshadow, basemaxshadow, baseminfire, basemaxfire, spellcoeff, spellcoeffshadow, spellcoefffire, casttime, casttimeshadow, casttimefire, damagemultshadow, damagemultfire, critbonus, flathitbonus, flatcritbonus, corruptionbasedps, corruptioncoeffps, corruptionuptime, cursebasedpsshadow, cursecoeffpsshadow, curseuptimeshadow, immolatebasedps, immolatecoeffps, immolateuptime, cursebasedpsfire, cursecoeffpsfire, curseuptimefire, petbasesuccubus, petbaseimp, petbasefelhunter, petbasevoidwalker, petbaseunknown, petspellpowerscale, petuptime, tapmanagain, tapcasttime, manapercastshadow, manapercastfire, manaregenweight, lowmanapct, lowmanapenaltymult, dotdps, petdps, manavaluedps, threatmultshadow, threatmultfire"
local TA_WARLOCK_CONFIG_SPECS = {
  targetlevel = { field = "targetLevel", min = 1, max = 63, round = true },
  baseminshadow = { field = "baseMinShadow", min = 0 },
  basemaxshadow = { field = "baseMaxShadow", min = 0 },
  baseminfire = { field = "baseMinFire", min = 0 },
  basemaxfire = { field = "baseMaxFire", min = 0 },
  spellcoeff = { field = "spellCoeffShadow", mirrorField = "spellCoeffFire", min = 0, max = 2 },
  spellcoeffshadow = { field = "spellCoeffShadow", min = 0, max = 2 },
  spellcoefffire = { field = "spellCoeffFire", min = 0, max = 2 },
  casttime = { field = "castTimeShadow", mirrorField = "castTimeFire", min = 1.0, max = 5.0 },
  casttimeshadow = { field = "castTimeShadow", min = 1.0, max = 5.0 },
  casttimefire = { field = "castTimeFire", min = 1.0, max = 5.0 },
  damagemultshadow = { field = "damageMultShadow", min = 0.1, max = 4.0 },
  damagemultfire = { field = "damageMultFire", min = 0.1, max = 4.0 },
  critbonus = { field = "critBonus", min = 0, max = 2 },
  flathitbonus = { field = "flatHitBonus", min = -0.5, max = 0.5 },
  flatcritbonus = { field = "flatCritBonus", min = -0.5, max = 0.5 },
  corruptionbasedps = { field = "corruptionBaseDps", min = 0, max = 500 },
  corruptioncoeffps = { field = "corruptionCoeffPerSec", min = 0, max = 1 },
  corruptionuptime = { field = "corruptionUptime", min = 0, max = 1 },
  cursebasedpsshadow = { field = "curseBaseDpsShadow", min = 0, max = 500 },
  cursecoeffpsshadow = { field = "curseCoeffPerSecShadow", min = 0, max = 1 },
  curseuptimeshadow = { field = "curseUptimeShadow", min = 0, max = 1 },
  immolatebasedps = { field = "immolateBaseDps", min = 0, max = 500 },
  immolatecoeffps = { field = "immolateCoeffPerSec", min = 0, max = 1 },
  immolateuptime = { field = "immolateUptime", min = 0, max = 1 },
  cursebasedpsfire = { field = "curseBaseDpsFire", min = 0, max = 500 },
  cursecoeffpsfire = { field = "curseCoeffPerSecFire", min = 0, max = 1 },
  curseuptimefire = { field = "curseUptimeFire", min = 0, max = 1 },
  petbasesuccubus = { field = "petBaseSuccubus", min = 0, max = 500 },
  petbaseimp = { field = "petBaseImp", min = 0, max = 500 },
  petbasefelhunter = { field = "petBaseFelhunter", min = 0, max = 500 },
  petbasevoidwalker = { field = "petBaseVoidwalker", min = 0, max = 500 },
  petbaseunknown = { field = "petBaseUnknown", min = 0, max = 500 },
  petspellpowerscale = { field = "petSpellPowerScale", min = 0, max = 1 },
  petuptime = { field = "petUptime", min = 0, max = 1 },
  tapmanagain = { field = "tapManaGain", min = 1, max = 3000 },
  tapcasttime = { field = "tapCastTime", min = 0.5, max = 5.0 },
  manapercastshadow = { field = "manaPerCastShadow", min = 0, max = 3000 },
  manapercastfire = { field = "manaPerCastFire", min = 0, max = 3000 },
  manaregenweight = { field = "manaRegenWeight", min = 0, max = 3 },
  lowmanapct = { field = "lowManaPct", min = 0, max = 1 },
  lowmanapenaltymult = { field = "lowManaPenaltyMult", min = 0, max = 2 },
  dotdps = { field = "dotDps", min = -500, max = 500 },
  petdps = { field = "petDps", min = -500, max = 500 },
  manavaluedps = { field = "manaValueDps", min = -500, max = 500 },
  threatmultshadow = { field = "threatMultShadow", min = 0, max = 3 },
  threatmultfire = { field = "threatMultFire", min = 0, max = 3 },
}
local TA_WARLOCK_MAPPING_ORDER = {
  "sheetCritSnapshot",
  "sheetHitSnapshot",
  "shadowDamageMult",
  "fireDamageMult",
  "threatAdjustment",
  "spellPowerBuffSnapshot",
  "spellHitBuffSnapshot",
}

function TA_GetWarlockSheetData()
  if type(TextAdventurerWarlockSheetData) == "table" then
    return TextAdventurerWarlockSheetData
  end
  return nil
end

local function TA_GetWarlockSheetDefault(key, fallback)
  local data = TA_GetWarlockSheetData()
  if data and type(data.defaults) == "table" and type(data.defaults[key]) == "number" then
    return tonumber(data.defaults[key]) or fallback
  end
  return fallback
end

local function TA_GetWarlockConfigNumber(config, laneKey, genericKey, fallback)
  local value = config and config[laneKey]
  if type(value) ~= "number" and genericKey then
    value = config and config[genericKey]
  end
  if type(value) ~= "number" then
    value = fallback
  end
  return tonumber(value) or fallback
end

function TA_GetWarlockLiveConfig()
  TextAdventurerDB = TextAdventurerDB or {}
  if type(TextAdventurerDB.warlockDpsLiveConfig) ~= "table" then
    TextAdventurerDB.warlockDpsLiveConfig = {}
  end
  local c = TextAdventurerDB.warlockDpsLiveConfig
  c.mode = TA_NormalizeWarlockMode(c.mode)
  if type(c.targetLevel) ~= "number" then c.targetLevel = 63 end
  if type(c.baseMinShadow) ~= "number" then c.baseMinShadow = 510 end
  if type(c.baseMaxShadow) ~= "number" then c.baseMaxShadow = 571 end
  if type(c.baseMinFire) ~= "number" then c.baseMinFire = 561 end
  if type(c.baseMaxFire) ~= "number" then c.baseMaxFire = 625 end
  if type(c.spellCoeffShadow) ~= "number" then c.spellCoeffShadow = tonumber(c.spellCoeff) or 0.8571 end
  if type(c.spellCoeffFire) ~= "number" then c.spellCoeffFire = tonumber(c.spellCoeff) or 0.8571 end
  if type(c.castTimeShadow) ~= "number" then c.castTimeShadow = tonumber(c.castTime) or 2.5 end
  if type(c.castTimeFire) ~= "number" then c.castTimeFire = tonumber(c.castTime) or 2.5 end
  c.spellCoeff = c.spellCoeffShadow
  c.castTime = c.castTimeShadow
  if type(c.damageMultShadow) ~= "number" then c.damageMultShadow = TA_GetWarlockSheetDefault("shadowDamageMult", 1.45475) end
  if type(c.damageMultFire) ~= "number" then c.damageMultFire = TA_GetWarlockSheetDefault("fireDamageMult", 1.10) end
  if type(c.critBonus) ~= "number" then c.critBonus = 1.0 end
  if type(c.flatHitBonus) ~= "number" then c.flatHitBonus = 0 end
  if type(c.flatCritBonus) ~= "number" then c.flatCritBonus = 0 end
  if type(c.corruptionBaseDps) ~= "number" then c.corruptionBaseDps = 45.7 end
  if type(c.corruptionCoeffPerSec) ~= "number" then c.corruptionCoeffPerSec = 0.0556 end
  if type(c.corruptionUptime) ~= "number" then c.corruptionUptime = 0.75 end
  if type(c.curseBaseDpsShadow) ~= "number" then c.curseBaseDpsShadow = 28.0 end
  if type(c.curseCoeffPerSecShadow) ~= "number" then c.curseCoeffPerSecShadow = 0.0160 end
  if type(c.curseUptimeShadow) ~= "number" then c.curseUptimeShadow = 0.85 end
  if type(c.immolateBaseDps) ~= "number" then c.immolateBaseDps = 38.0 end
  if type(c.immolateCoeffPerSec) ~= "number" then c.immolateCoeffPerSec = 0.0200 end
  if type(c.immolateUptime) ~= "number" then c.immolateUptime = 0.80 end
  if type(c.curseBaseDpsFire) ~= "number" then c.curseBaseDpsFire = 20.0 end
  if type(c.curseCoeffPerSecFire) ~= "number" then c.curseCoeffPerSecFire = 0.0120 end
  if type(c.curseUptimeFire) ~= "number" then c.curseUptimeFire = 0.75 end
  if type(c.petBaseSuccubus) ~= "number" then c.petBaseSuccubus = 60 end
  if type(c.petBaseImp) ~= "number" then c.petBaseImp = 46 end
  if type(c.petBaseFelhunter) ~= "number" then c.petBaseFelhunter = 40 end
  if type(c.petBaseVoidwalker) ~= "number" then c.petBaseVoidwalker = 24 end
  if type(c.petBaseUnknown) ~= "number" then c.petBaseUnknown = 32 end
  if type(c.petSpellPowerScale) ~= "number" then c.petSpellPowerScale = 0.03 end
  if type(c.petUptime) ~= "number" then c.petUptime = 0.90 end
  if type(c.tapManaGain) ~= "number" then c.tapManaGain = 420 end
  if type(c.tapCastTime) ~= "number" then c.tapCastTime = 1.5 end
  if type(c.manaPerCastShadow) ~= "number" then c.manaPerCastShadow = 380 end
  if type(c.manaPerCastFire) ~= "number" then c.manaPerCastFire = 420 end
  if type(c.manaRegenWeight) ~= "number" then c.manaRegenWeight = 1.0 end
  if type(c.lowManaPct) ~= "number" then c.lowManaPct = 0.20 end
  if type(c.lowManaPenaltyMult) ~= "number" then c.lowManaPenaltyMult = 0.10 end
  if type(c.dotDps) ~= "number" then c.dotDps = 0 end
  if type(c.petDps) ~= "number" then c.petDps = 0 end
  if type(c.manaValueDps) ~= "number" then c.manaValueDps = 0 end
  if type(c.sheetCritSnapshot) ~= "number" then c.sheetCritSnapshot = TA_GetWarlockSheetDefault("sheetCritSnapshot", 0) end
  if type(c.sheetHitSnapshot) ~= "number" then c.sheetHitSnapshot = TA_GetWarlockSheetDefault("sheetHitSnapshot", 0) end
  if type(c.spellPowerBuffSnapshot) ~= "number" then c.spellPowerBuffSnapshot = TA_GetWarlockSheetDefault("spellPowerBuffSnapshot", 0) end
  if type(c.spellHitBuffSnapshot) ~= "number" then c.spellHitBuffSnapshot = TA_GetWarlockSheetDefault("spellHitBuffSnapshot", 0) end
  if type(c.threatMultShadow) ~= "number" then c.threatMultShadow = TA_GetWarlockSheetDefault("shadowThreatMult", 0.70) end
  if type(c.threatMultFire) ~= "number" then c.threatMultFire = TA_GetWarlockSheetDefault("fireThreatMult", 1.00) end
  return c
end

function TA_GetSpellHitChance(targetLevel, flatHitBonus)
  local level = UnitLevel("player") or 60
  local diff = math.max(0, (tonumber(targetLevel) or 63) - level)
  local baseMiss
  if diff <= 2 then
    baseMiss = 0.04 + (0.01 * diff)
  else
    baseMiss = 0.17 + (0.01 * (diff - 3))
  end
  local hitFromStats = (GetSpellHitModifier and (tonumber(GetSpellHitModifier()) or 0) or 0) / 100
  local totalHit = hitFromStats + (tonumber(flatHitBonus) or 0)
  local miss = baseMiss - totalHit
  if miss < 0.01 then miss = 0.01 end
  if miss > 0.99 then miss = 0.99 end
  return 1 - miss
end

function TA_GetSpellCritChanceBySchool(school, flatCritBonus)
  local crit = 0
  if GetSpellCritChance then
    local ok, v = pcall(GetSpellCritChance, school)
    if ok and tonumber(v) then
      crit = tonumber(v) / 100
    end
  end
  crit = crit + (tonumber(flatCritBonus) or 0)
  if crit < 0 then crit = 0 end
  if crit > 0.99 then crit = 0.99 end
  return crit
end

local function TA_GetWarlockModeSpec(c)
  local mode = TA_NormalizeWarlockMode(c.mode)
  if mode == "fire" then
    return {
      mode = mode,
      school = 3,
      schoolName = "fire",
      baseMin = tonumber(c.baseMinFire) or 0,
      baseMax = tonumber(c.baseMaxFire) or 0,
      spellCoeff = TA_GetWarlockConfigNumber(c, "spellCoeffFire", "spellCoeff", 0.8571),
      castTime = TA_GetWarlockConfigNumber(c, "castTimeFire", "castTime", 2.5),
      damageMult = tonumber(c.damageMultFire) or 1,
      threatMult = tonumber(c.threatMultFire) or 1,
      manaPerCast = tonumber(c.manaPerCastFire) or 0,
      directLabel = "Fire nuke",
      dotLabel = "Immolate + Curse",
    }
  end
  return {
    mode = "shadow",
    school = 6,
    schoolName = "shadow",
    baseMin = tonumber(c.baseMinShadow) or 0,
    baseMax = tonumber(c.baseMaxShadow) or 0,
    spellCoeff = TA_GetWarlockConfigNumber(c, "spellCoeffShadow", "spellCoeff", 0.8571),
    castTime = TA_GetWarlockConfigNumber(c, "castTimeShadow", "castTime", 2.5),
    damageMult = tonumber(c.damageMultShadow) or 1,
    threatMult = tonumber(c.threatMultShadow) or 1,
    manaPerCast = tonumber(c.manaPerCastShadow) or 0,
    directLabel = "Shadow Bolt",
    dotLabel = "Corruption + Curse",
  }
end

local function TA_GetWarlockPetFamily()
  if not UnitExists("pet") or UnitIsDeadOrGhost("pet") then
    return nil
  end
  return UnitCreatureFamily("pet") or UnitName("pet")
end

local function TA_GetWarlockPetBaseDps(c, petFamily)
  local family = petFamily and petFamily:lower() or ""
  if family:find("succubus", 1, true) then return tonumber(c.petBaseSuccubus) or 0, "Succubus" end
  if family:find("felhunter", 1, true) then return tonumber(c.petBaseFelhunter) or 0, "Felhunter" end
  if family:find("voidwalker", 1, true) then return tonumber(c.petBaseVoidwalker) or 0, "Voidwalker" end
  if family:find("imp", 1, true) then return tonumber(c.petBaseImp) or 0, "Imp" end
  return tonumber(c.petBaseUnknown) or 0, petFamily or "Unknown"
end

local function TA_UnitHasPlayerDebuff(unit, spellName)
  if not UnitDebuff or not unit or not UnitExists(unit) or not spellName then
    return false
  end
  for i = 1, 40 do
    local name, _, _, _, _, _, _, caster = UnitDebuff(unit, i)
    if not name then break end
    local isMine = caster == "player"
    if not isMine and caster and UnitIsUnit then
      isMine = UnitIsUnit(caster, "player")
    end
    if isMine and name == spellName then
      return true
    end
  end
  return false
end

local function TA_GetWarlockDotPackage(c, mode, spellPower, hitChance)
  local hasTarget = UnitExists("target") and not UnitIsDeadOrGhost("target")
  local hasCorruption = hasTarget and TA_UnitHasPlayerDebuff("target", "Corruption")
  local hasImmolate = hasTarget and TA_UnitHasPlayerDebuff("target", "Immolate")
  local hasCurse = hasTarget and (TA_UnitHasPlayerDebuff("target", "Curse of Agony") or TA_UnitHasPlayerDebuff("target", "Curse of Doom"))

  if mode == "fire" then
    local immolateUptime = hasImmolate and 1 or (tonumber(c.immolateUptime) or 0)
    local curseUptime = hasCurse and 1 or (tonumber(c.curseUptimeFire) or 0)
    local immolateDps = ((tonumber(c.immolateBaseDps) or 0) + ((tonumber(c.immolateCoeffPerSec) or 0) * spellPower)) * hitChance * immolateUptime
    local curseDps = ((tonumber(c.curseBaseDpsFire) or 0) + ((tonumber(c.curseCoeffPerSecFire) or 0) * spellPower)) * hitChance * curseUptime
    return immolateDps + curseDps + (tonumber(c.dotDps) or 0), {
      immolate = immolateDps,
      curse = curseDps,
      corruption = 0,
      immolateLive = hasImmolate,
      curseLive = hasCurse,
    }
  end

  local corruptionUptime = hasCorruption and 1 or (tonumber(c.corruptionUptime) or 0)
  local curseUptime = hasCurse and 1 or (tonumber(c.curseUptimeShadow) or 0)
  local corruptionDps = ((tonumber(c.corruptionBaseDps) or 0) + ((tonumber(c.corruptionCoeffPerSec) or 0) * spellPower)) * hitChance * corruptionUptime
  local curseDps = ((tonumber(c.curseBaseDpsShadow) or 0) + ((tonumber(c.curseCoeffPerSecShadow) or 0) * spellPower)) * hitChance * curseUptime
  return corruptionDps + curseDps + (tonumber(c.dotDps) or 0), {
    immolate = 0,
    curse = curseDps,
    corruption = corruptionDps,
    immolateLive = false,
    curseLive = hasCurse,
    corruptionLive = hasCorruption,
  }
end

local function TA_GetWarlockPetContribution(c, mode, spellPower)
  local petFamily = TA_GetWarlockPetFamily()
  if not petFamily then
    return tonumber(c.petDps) or 0, {
      label = "No active pet",
      base = 0,
      uptime = 0,
      live = false,
    }
  end

  local baseDps, label = TA_GetWarlockPetBaseDps(c, petFamily)
  local uptime = tonumber(c.petUptime) or 0
  local scaled = (baseDps + (spellPower * (tonumber(c.petSpellPowerScale) or 0))) * uptime
  if mode == "shadow" and label == "Succubus" then
    scaled = scaled * 1.08
  elseif mode == "fire" and label == "Imp" then
    scaled = scaled * 1.08
  end
  return scaled + (tonumber(c.petDps) or 0), {
    label = label,
    base = baseDps,
    uptime = uptime,
    live = true,
  }
end

local function TA_GetWarlockManaContribution(c, mode, directDps)
  local powerType = UnitPowerType and UnitPowerType("player") or 0
  local mana = UnitPower and (UnitPower("player", powerType) or 0) or 0
  local manaMax = UnitPowerMax and (UnitPowerMax("player", powerType) or 0) or 0
  local manaPct = manaMax > 0 and (mana / manaMax) or 0
  local spec = TA_GetWarlockModeSpec(c)
  local regen = TA_GetManaRegenPerSecond()
  local manaPerCast = tonumber(spec.manaPerCast) or 0
  local castTime = math.max(0.5, tonumber(spec.castTime) or 2.5)
  local spendPerSec = manaPerCast / castTime
  local effectiveRegen = regen * math.max(0, tonumber(c.manaRegenWeight) or 0)
  local deficitPerSec = math.max(0, spendPerSec - effectiveRegen)
  local tapManaGain = math.max(1, tonumber(c.tapManaGain) or 1)
  local tapCastTime = math.max(0.5, tonumber(c.tapCastTime) or 1.5)
  local tapsPerSec = deficitPerSec / tapManaGain
  local tapTaxDps = tapsPerSec * tapCastTime * directDps
  local lowManaPenalty = 0
  if manaPct < (tonumber(c.lowManaPct) or 0) then
    lowManaPenalty = directDps * (tonumber(c.lowManaPenaltyMult) or 0)
  end
  local net = (tonumber(c.manaValueDps) or 0) - tapTaxDps - lowManaPenalty
  return net, {
    manaPct = manaPct,
    regen = regen,
    spendPerSec = spendPerSec,
    tapTaxDps = tapTaxDps,
    lowManaPenalty = lowManaPenalty,
  }
end

function TA_SetWarlockMode(mode)
  local c = TA_GetWarlockLiveConfig()
  c.mode = TA_NormalizeWarlockMode(mode)
  AddLine("playerCombat", "Warlock DPS mode set to: " .. c.mode)
end

function TA_ResetWarlockDpsConfigDefaults()
  TextAdventurerDB = TextAdventurerDB or {}
  local mode = TA_NormalizeWarlockMode(TextAdventurerDB.warlockDpsLiveConfig and TextAdventurerDB.warlockDpsLiveConfig.mode)
  TextAdventurerDB.warlockDpsLiveConfig = { mode = mode }
  TA_GetWarlockLiveConfig()
  AddLine("playerCombat", "Warlock DPS settings reset to spreadsheet-backed defaults.")
end

function TA_SetWarlockDpsConfigValue(key, value)
  local c = TA_GetWarlockLiveConfig()
  local k = (key or ""):match("^%s*(.-)%s*$"):lower()
  local v = tonumber(value)
  if not v then
    AddLine("system", "Usage: warlockdps set <key> <value>")
    return
  end

  local spec = TA_WARLOCK_CONFIG_SPECS[k]
  if not spec then
    AddLine("system", "Unknown key. Use: " .. TA_WARLOCK_CONFIG_KEYS_HELP)
    return
  end
  if spec.min ~= nil and v < spec.min then v = spec.min end
  if spec.max ~= nil and v > spec.max then v = spec.max end
  if spec.round then v = math.floor(v + 0.5) end

  c[spec.field] = v
  if spec.mirrorField then
    c[spec.mirrorField] = v
  end
  AddLine("playerCombat", string.format("Warlock DPS setting updated: %s = %s", k, tostring(v)))
end

function TA_ReportWarlockSheetMapping()
  local data = TA_GetWarlockSheetData()
  if not data or type(data.mappings) ~= "table" then
    AddLine("system", "No generated warlock sheet mapping is loaded.")
    return
  end

  AddLine("playerCombat", "warlockdps sheet mapping:")
  for _, key in ipairs(TA_WARLOCK_MAPPING_ORDER) do
    local mapping = data.mappings[key]
    if mapping then
      AddLine("system", string.format("  %s <- %s!%s = %.6f", key, tostring(mapping.sheet or "?"), tostring(mapping.cell or "?"), tonumber(mapping.value) or 0))
      if mapping.note and mapping.note ~= "" then
        AddLine("system", "    " .. tostring(mapping.note))
      end
    end
  end
  AddLine("system", "Regenerate with: VS Code task 'Generate Warlock Sheet Data'.")
end

function TA_ReportWarlockLiveAssumptions()
  local c = TA_GetWarlockLiveConfig()
  AddLine("playerCombat", "warlockdps assumptions:")
  AddLine("playerCombat", string.format("  mode: %s | target level: %d", c.mode, c.targetLevel))
  AddLine("playerCombat", string.format("  shadow nuke: %.0f-%.0f, coeff %.4f, cast %.2fs, mult %.4f", c.baseMinShadow, c.baseMaxShadow, c.spellCoeffShadow, c.castTimeShadow, c.damageMultShadow))
  AddLine("playerCombat", string.format("  fire nuke: %.0f-%.0f, coeff %.4f, cast %.2fs, mult %.4f", c.baseMinFire, c.baseMaxFire, c.spellCoeffFire, c.castTimeFire, c.damageMultFire))
  AddLine("playerCombat", string.format("  DoTs: corr %.1f + %.4f*SP @ %.0f%% | shadow curse %.1f + %.4f*SP @ %.0f%% | immolate %.1f + %.4f*SP @ %.0f%% | fire curse %.1f + %.4f*SP @ %.0f%%", c.corruptionBaseDps, c.corruptionCoeffPerSec, c.corruptionUptime * 100, c.curseBaseDpsShadow, c.curseCoeffPerSecShadow, c.curseUptimeShadow * 100, c.immolateBaseDps, c.immolateCoeffPerSec, c.immolateUptime * 100, c.curseBaseDpsFire, c.curseCoeffPerSecFire, c.curseUptimeFire * 100))
  AddLine("playerCombat", string.format("  Pet baselines: succ %.1f imp %.1f fel %.1f void %.1f unk %.1f | uptime %.0f%% | SP scale %.3f", c.petBaseSuccubus, c.petBaseImp, c.petBaseFelhunter, c.petBaseVoidwalker, c.petBaseUnknown, c.petUptime * 100, c.petSpellPowerScale))
  AddLine("playerCombat", string.format("  Mana model: shadow %.0f mana/cast, fire %.0f mana/cast, tap %.0f mana in %.2fs, regen weight %.2f, low mana %.0f%% -> %.0f%% penalty", c.manaPerCastShadow, c.manaPerCastFire, c.tapManaGain, c.tapCastTime, c.manaRegenWeight, c.lowManaPct * 100, c.lowManaPenaltyMult * 100))
  AddLine("playerCombat", string.format("  Flat adjustments: DoT %.1f, Pet %.1f, Mana %.1f | flat hit/crit bonus %.3f / %.3f | crit bonus %.2f", c.dotDps, c.petDps, c.manaValueDps, c.flatHitBonus, c.flatCritBonus, c.critBonus))
  AddLine("playerCombat", string.format("  Threat multipliers: shadow %.2f, fire %.2f", c.threatMultShadow, c.threatMultFire))
  AddLine("system", string.format("Sheet snapshots: crit %.1f%%, hit %.1f%%, spell-power buffs %.0f, hit buffs %.1f%%", c.sheetCritSnapshot * 100, c.sheetHitSnapshot * 100, c.spellPowerBuffSnapshot, c.spellHitBuffSnapshot * 100))
  AddLine("system", "Source: generated WarlockSheetData.lua from Zephan workbook inventory.")
end

function TA_ReportLiveWarlockDps()
  local classToken = select(2, UnitClass("player")) or "UNKNOWN"
  if classToken ~= "WARLOCK" then
    AddLine("system", "warlockdps is designed for Warlock characters.")
    return
  end

  local c = TA_GetWarlockLiveConfig()
  local promptCfg = TA_GetWarlockPromptConfig()
  local spec = TA_GetWarlockModeSpec(c)
  local spellPower = TA_GetSpellPowerBySchool(spec.school)
  local hitChance = TA_GetSpellHitChance(c.targetLevel, c.flatHitBonus)
  local critChance = TA_GetSpellCritChanceBySchool(spec.school, c.flatCritBonus)
  local castTime = math.max(1.0, tonumber(spec.castTime) or 2.5)
  local coeff = math.max(0, tonumber(spec.spellCoeff) or 0)
  local avgBase = (tonumber(spec.baseMin) + tonumber(spec.baseMax)) / 2
  local nonCritHit = (avgBase + (spellPower * coeff)) * spec.damageMult
  local expectedCast = nonCritHit * (1 + (critChance * (tonumber(c.critBonus) or 0))) * hitChance
  local directDps = expectedCast / castTime
  local dotDps, dotInfo = TA_GetWarlockDotPackage(c, spec.mode, spellPower, hitChance)
  local petDps, petInfo = TA_GetWarlockPetContribution(c, spec.mode, spellPower)
  local manaDps, manaInfo = TA_GetWarlockManaContribution(c, spec.mode, directDps)
  local totalDps = directDps + dotDps + petDps + manaDps
  local totalTps = totalDps * spec.threatMult

  AddLine("playerCombat", string.format("Warlock live model (%s):", spec.mode))
  AddLine("playerCombat", string.format("  %s DPS: %.1f", spec.directLabel, directDps))
  if spec.mode == "fire" then
    AddLine("playerCombat", string.format("  %s DPS: immolate %.1f%s + curse %.1f%s = %.1f", spec.dotLabel, dotInfo.immolate or 0, (dotInfo.immolateLive and " [live]" or ""), dotInfo.curse or 0, (dotInfo.curseLive and " [live]" or ""), dotDps))
  else
    AddLine("playerCombat", string.format("  %s DPS: corruption %.1f%s + curse %.1f%s = %.1f", spec.dotLabel, dotInfo.corruption or 0, (dotInfo.corruptionLive and " [live]" or ""), dotInfo.curse or 0, (dotInfo.curseLive and " [live]" or ""), dotDps))
  end
  AddLine("playerCombat", string.format("  Pet DPS: %.1f (%s, uptime %.0f%%)", petDps, petInfo.label or "Unknown", (petInfo.uptime or 0) * 100))
  AddLine("playerCombat", string.format("  Mana sustain DPS: %.1f (regen %.1f/s, tap tax %.1f, low-mana %.1f)", manaDps, manaInfo.regen or 0, manaInfo.tapTaxDps or 0, manaInfo.lowManaPenalty or 0))
  AddLine("playerCombat", string.format("  Total: %.1f DPS | %.1f TPS", totalDps, totalTps))
  AddLine("system", string.format("Inputs: SP %d (%s), hit %.1f%%, crit %.1f%%, cast %.2fs, coeff %.4f, dmg mult %.4f, mana %.0f%%", math.floor(spellPower + 0.5), spec.schoolName, hitChance * 100, critChance * 100, castTime, coeff, spec.damageMult, (manaInfo.manaPct or 0) * 100))
  AddLine("system", string.format("Sheet comparison: crit %.1f%% vs sheet %.1f%% | hit %.1f%% vs sheet %.1f%%", critChance * 100, (tonumber(c.sheetCritSnapshot) or 0) * 100, hitChance * 100, (tonumber(c.sheetHitSnapshot) or 0) * 100))
  AddLine("system", "Tune with: warlockdps set <key> <value> | warlockdps mode <shadow|fire> | warlockdps assumptions | warlockdps mapping")
end

function TA_GetWarlockPromptConfig()
  TextAdventurerDB = TextAdventurerDB or {}
  if type(TextAdventurerDB.warlockPrompt) ~= "table" then
    TextAdventurerDB.warlockPrompt = {}
  end
  local p = TextAdventurerDB.warlockPrompt
  if p.enabled == nil then p.enabled = false end
  if type(p.minManaPct) ~= "number" then p.minManaPct = 0.25 end
  if type(p.minHealthPctForTap) ~= "number" then p.minHealthPctForTap = 0.45 end
  return p
end

local function TA_GetPlayerDebuffRemaining(unit, spellName)
  if not UnitDebuff or not unit or not UnitExists(unit) or not spellName then
    return 0, false
  end
  for i = 1, 40 do
    local name, _, _, _, _, duration, expirationTime, caster = UnitDebuff(unit, i)
    if not name then break end
    local isMine = caster == "player"
    if not isMine and caster and UnitIsUnit then
      isMine = UnitIsUnit(caster, "player")
    end
    if isMine and name == spellName then
      if tonumber(expirationTime) and tonumber(duration) and expirationTime > 0 and duration > 0 then
        return math.max(0, expirationTime - GetTime()), true
      end
      return 999, true
    end
  end
  return 0, false
end

local function TA_PlayerKnowsAnySpell(names)
  if type(names) ~= "table" then return false end
  return TA_GetHighestKnownRank(names) ~= nil
end

local function TA_GetWarlockPromptState()
  local classToken = select(2, UnitClass("player")) or "UNKNOWN"
  if classToken ~= "WARLOCK" then
    return nil, "warlockdps prompt is designed for Warlock characters."
  end
  if not UnitExists("target") or UnitIsDeadOrGhost("target") or (UnitCanAttack and not UnitCanAttack("player", "target")) then
    return nil, "No hostile target selected."
  end

  local c = TA_GetWarlockLiveConfig()
  local promptCfg = TA_GetWarlockPromptConfig()
  local spec = TA_GetWarlockModeSpec(c)
  local powerType = UnitPowerType and UnitPowerType("player") or 0
  local mana = UnitPower and (UnitPower("player", powerType) or 0) or 0
  local manaMax = UnitPowerMax and (UnitPowerMax("player", powerType) or 0) or 0
  local manaPct = manaMax > 0 and (mana / manaMax) or 0
  local health = UnitHealth and (UnitHealth("player") or 0) or 0
  local healthMax = UnitHealthMax and (UnitHealthMax("player") or 0) or 0
  local healthPct = healthMax > 0 and (health / healthMax) or 0

  local moving = false
  if GetUnitSpeed then
    moving = (tonumber(GetUnitSpeed("player")) or 0) > 0
  end

  local corrRemain = 0
  local immolateRemain = 0
  local curseRemain = 0
  if spec.mode == "shadow" then
    corrRemain = select(1, TA_GetPlayerDebuffRemaining("target", "Corruption"))
  else
    immolateRemain = select(1, TA_GetPlayerDebuffRemaining("target", "Immolate"))
  end
  local agonyRemain = select(1, TA_GetPlayerDebuffRemaining("target", "Curse of Agony"))
  local doomRemain = select(1, TA_GetPlayerDebuffRemaining("target", "Curse of Doom"))
  curseRemain = math.max(agonyRemain or 0, doomRemain or 0)

  local knowsCorruption = TA_PlayerKnowsAnySpell({ "Corruption" })
  local knowsImmolate = TA_PlayerKnowsAnySpell({ "Immolate" })
  local knowsAgony = TA_PlayerKnowsAnySpell({ "Curse of Agony" })
  local knowsDoom = TA_PlayerKnowsAnySpell({ "Curse of Doom" })
  local knowsLifeTap = TA_PlayerKnowsAnySpell({ "Life Tap" })
  local knowsShadowBolt = TA_PlayerKnowsAnySpell({ "Shadow Bolt" })
  local knowsSearingPain = TA_PlayerKnowsAnySpell({ "Searing Pain" })

  local function BuildPrompt(key, action, reason)
    local detail = string.format("mana %.0f%%, hp %.0f%%", manaPct * 100, healthPct * 100)
    return {
      key = key,
      action = action,
      reason = reason,
      detail = detail,
    }
  end

  if moving then
    if spec.mode == "shadow" and knowsCorruption and corrRemain <= 1.5 then
      return BuildPrompt("corr-refresh-moving", "Cast Corruption", "instant DoT while moving")
    end
    if spec.mode == "fire" and knowsImmolate and immolateRemain <= 1.5 then
      return BuildPrompt("immolate-refresh-moving", "Cast Immolate", "refresh DoT while moving")
    end
    if (knowsAgony or knowsDoom) and curseRemain <= 2.0 then
      local curseName = knowsAgony and "Curse of Agony" or "Curse of Doom"
      return BuildPrompt("curse-refresh-moving", "Cast " .. curseName, "curse refresh while moving")
    end
  end

  if manaPct <= (tonumber(promptCfg.minManaPct) or 0.25) and knowsLifeTap and healthPct >= (tonumber(promptCfg.minHealthPctForTap) or 0.45) then
    return BuildPrompt("lifetap-lowmana", "Cast Life Tap", "mana below threshold")
  end

  if spec.mode == "shadow" and knowsCorruption and corrRemain <= 1.5 then
    return BuildPrompt("corr-refresh", "Cast Corruption", "maintain corruption uptime")
  end
  if spec.mode == "fire" and knowsImmolate and immolateRemain <= 1.5 then
    return BuildPrompt("immolate-refresh", "Cast Immolate", "maintain immolate uptime")
  end
  if (knowsAgony or knowsDoom) and curseRemain <= 2.0 then
    local curseName = knowsAgony and "Curse of Agony" or "Curse of Doom"
    return BuildPrompt("curse-refresh", "Cast " .. curseName, "maintain curse uptime")
  end

  if spec.mode == "shadow" and knowsShadowBolt then
    return BuildPrompt("shadowbolt-fill", "Cast Shadow Bolt", "highest-value shadow filler")
  end
  if spec.mode == "fire" and knowsSearingPain then
    return BuildPrompt("searingpain-fill", "Cast Searing Pain", "fire filler")
  end
  if knowsShadowBolt then
    return BuildPrompt("shadowbolt-fallback", "Cast Shadow Bolt", "fallback nuke")
  end

  return BuildPrompt("no-spell", "Use wand / reposition", "no known filler spell found")
end

function TA_ReportWarlockActionPrompt(force)
  local rec, blockedReason = TA_GetWarlockPromptState()
  if not rec then
    if force then
      AddLine("system", "warlockprompt: " .. tostring(blockedReason or "no prompt available"))
    end
    return
  end

  local now = GetTime()
  local isSame = (TA.lastWarlockPromptKey == rec.key)
  local shouldEmit = force or (not isSame) or (now >= (TA.lastWarlockPromptEmitAt or 0) + 5)
  if not shouldEmit then
    return
  end

  TA.lastWarlockPromptKey = rec.key
  TA.lastWarlockPromptEmitAt = now
  AddLine("playerCombat", string.format("Warlock prompt: %s (%s; %s)", rec.action, rec.reason, rec.detail or ""))
end

function TA_SetWarlockPromptEnabled(enabled)
  local p = TA_GetWarlockPromptConfig()
  p.enabled = enabled and true or false
  AddLine("system", string.format("warlockprompt %s", p.enabled and "enabled" or "disabled"))
end

function TA_ReportWarlockPromptStatus()
  local p = TA_GetWarlockPromptConfig()
  AddLine("system", string.format("warlockprompt: %s | mana threshold %.0f%% | life tap hp floor %.0f%%", p.enabled and "on" or "off", (tonumber(p.minManaPct) or 0.25) * 100, (tonumber(p.minHealthPctForTap) or 0.45) * 100))
  TA_ReportWarlockActionPrompt(true)
end

function TA_SetWarlockPromptValue(key, value)
  local p = TA_GetWarlockPromptConfig()
  local k = (key or ""):lower()
  local v = tonumber(value)
  if not v then
    AddLine("system", "Usage: warlockprompt set <manapct|taphpfloor> <value>")
    return
  end
  if k == "manapct" then
    if v > 1 then v = v / 100 end
    if v < 0 then v = 0 end
    if v > 0.95 then v = 0.95 end
    p.minManaPct = v
    AddLine("system", string.format("warlockprompt min mana set to %.0f%%", v * 100))
    return
  end
  if k == "taphpfloor" then
    if v > 1 then v = v / 100 end
    if v < 0.10 then v = 0.10 end
    if v > 0.95 then v = 0.95 end
    p.minHealthPctForTap = v
    AddLine("system", string.format("warlockprompt life-tap hp floor set to %.0f%%", v * 100))
    return
  end
  AddLine("system", "Unknown key. Use: manapct or taphpfloor")
end

function TA_MaybeAutoWarlockPrompt()
  local p = TA_GetWarlockPromptConfig()
  if p.enabled ~= true then
    return
  end
  local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
  if not inCombat then
    return
  end
  TA_ReportWarlockActionPrompt(false)
end

function TA_GetWarriorPromptConfig()
  TextAdventurerDB = TextAdventurerDB or {}
  if type(TextAdventurerDB.warriorPrompt) ~= "table" then
    TextAdventurerDB.warriorPrompt = {}
  end
  local p = TextAdventurerDB.warriorPrompt
  if p.enabled == nil then p.enabled = false end
  if type(p.minRage) ~= "number" then p.minRage = 35 end
  if type(p.rendRefreshSec) ~= "number" then p.rendRefreshSec = 2.0 end
  return p
end

function TA_GetWarriorPromptState()
  local classToken = select(2, UnitClass("player")) or "UNKNOWN"
  if classToken ~= "WARRIOR" then
    return nil, "warriorprompt is designed for Warrior characters."
  end
  if not UnitExists("target") or UnitIsDeadOrGhost("target") or (UnitCanAttack and not UnitCanAttack("player", "target")) then
    return nil, "No hostile target selected."
  end

  local promptCfg = TA_GetWarriorPromptConfig()
  local rage = UnitPower and (UnitPower("player", 1) or 0) or 0
  local health = UnitHealth and (UnitHealth("player") or 0) or 0
  local healthMax = UnitHealthMax and (UnitHealthMax("player") or 0) or 0
  local healthPct = healthMax > 0 and (health / healthMax) or 0
  local moving = false
  if GetUnitSpeed then
    moving = (tonumber(GetUnitSpeed("player")) or 0) > 0
  end

  local function cooldownReady(spellID)
    if not spellID or not GetSpellCooldown then
      return false
    end
    local start, duration = GetSpellCooldown(spellID)
    if not start or not duration then
      return false
    end
    return (start == 0) or (duration <= 1.5)
  end

  local function usableByName(name)
    if not IsUsableSpell or not name then
      return false
    end
    local usable = IsUsableSpell(name)
    return usable == true
  end

  local function makeRec(key, action, reason)
    return {
      key = key,
      action = action,
      reason = reason,
      detail = string.format("rage %d, hp %.0f%%", rage, healthPct * 100),
    }
  end

  local hsRow = TA_SelectWarriorAbilityRow and TA_SelectWarriorAbilityRow("heroicStrike") or nil
  local rendRow = TA_SelectWarriorAbilityRow and TA_SelectWarriorAbilityRow("rend") or nil
  local opRow = TA_SelectWarriorAbilityRow and TA_SelectWarriorAbilityRow("overpower") or nil
  local slamRow = TA_SelectWarriorAbilityRow and TA_SelectWarriorAbilityRow("slam") or nil
  local wwRow = TA_SelectWarriorAbilityRow and TA_SelectWarriorAbilityRow("whirlwind") or nil
  local msRow = TA_SelectWarriorAbilityRow and TA_SelectWarriorAbilityRow("mortalStrike") or nil

  local hsCost = hsRow and (hsRow.rage or 15) or 15
  local rendCost = rendRow and (rendRow.rage or 10) or 10
  local opCost = opRow and (opRow.rage or 5) or 5
  local slamCost = slamRow and (slamRow.rage or 15) or 15
  local wwCost = wwRow and (wwRow.rage or 25) or 25
  local msCost = msRow and (msRow.rage or 30) or 30

  local knowsHS = TA_PlayerKnowsSpellIDs and TA_PlayerKnowsSpellIDs({ 78 })
  local knowsRend = TA_PlayerKnowsSpellIDs and TA_PlayerKnowsSpellIDs({ 772 })
  local knowsOP = TA_PlayerKnowsSpellIDs and TA_PlayerKnowsSpellIDs({ 7384 })
  local knowsSlam = TA_PlayerKnowsSpellIDs and TA_PlayerKnowsSpellIDs({ 1464 })
  local knowsWW = TA_PlayerKnowsSpellIDs and TA_PlayerKnowsSpellIDs({ 1680 })
  local knowsMS = TA_PlayerKnowsSpellIDs and TA_PlayerKnowsSpellIDs({ 12294 })

  if knowsMS and rage >= msCost and cooldownReady(12294) then
    return makeRec("ms-ready", "Cast Mortal Strike", "high-priority strike is ready")
  end

  if knowsWW and rage >= wwCost and cooldownReady(1680) then
    return makeRec("ww-ready", "Cast Whirlwind", "high-value instant attack is ready")
  end

  if knowsOP and rage >= opCost and usableByName("Overpower") then
    return makeRec("op-ready", "Cast Overpower", "Overpower proc is available")
  end

  if knowsRend and rage >= rendCost then
    local rendRemain = select(1, TA_GetPlayerDebuffRemaining("target", "Rend"))
    if rendRemain <= (tonumber(promptCfg.rendRefreshSec) or 2.0) then
      return makeRec("rend-refresh", "Cast Rend", "refreshing Rend uptime")
    end
  end

  if (not moving) and knowsSlam and rage >= slamCost then
    return makeRec("slam-filler", "Cast Slam", "stationary filler with sufficient rage")
  end

  local hsDumpThreshold = math.max(tonumber(promptCfg.minRage) or 35, hsCost)
  if knowsHS and rage >= hsDumpThreshold then
    return makeRec("hs-dump", "Queue Heroic Strike", "rage above dump threshold")
  end

  if rage < hsCost then
    return makeRec("build-rage", "Build rage with auto attacks", "insufficient rage for main abilities")
  end

  return makeRec("maintain-pressure", "Maintain pressure and queue Heroic Strike", "no higher-priority cooldown ready")
end

function TA_ReportWarriorActionPrompt(force)
  local rec, blockedReason = TA_GetWarriorPromptState()
  if not rec then
    if force then
      AddLine("system", "warriorprompt: " .. tostring(blockedReason or "no prompt available"))
    end
    return
  end

  local now = GetTime()
  local isSame = (TA.lastWarriorPromptKey == rec.key)
  local shouldEmit = force or (not isSame) or (now >= (TA.lastWarriorPromptEmitAt or 0) + 5)
  if not shouldEmit then
    return
  end

  TA.lastWarriorPromptKey = rec.key
  TA.lastWarriorPromptEmitAt = now
  AddLine("playerCombat", string.format("Warrior prompt: %s (%s; %s)", rec.action, rec.reason, rec.detail or ""))
end

function TA_SetWarriorPromptEnabled(enabled)
  local p = TA_GetWarriorPromptConfig()
  p.enabled = enabled and true or false
  AddLine("system", string.format("warriorprompt %s", p.enabled and "enabled" or "disabled"))
end

function TA_ReportWarriorPromptStatus()
  local p = TA_GetWarriorPromptConfig()
  AddLine("system", string.format("warriorprompt: %s | rage threshold %d | rend refresh %.1fs", p.enabled and "on" or "off", math.floor(tonumber(p.minRage) or 35), tonumber(p.rendRefreshSec) or 2.0))
  TA_ReportWarriorActionPrompt(true)
end

function TA_SetWarriorPromptValue(key, value)
  local p = TA_GetWarriorPromptConfig()
  local k = (key or ""):lower()
  local v = tonumber(value)
  if not v then
    AddLine("system", "Usage: warriorprompt set <rage|rendrefresh> <value>")
    return
  end
  if k == "rage" then
    if v < 10 then v = 10 end
    if v > 100 then v = 100 end
    p.minRage = math.floor(v + 0.5)
    AddLine("system", string.format("warriorprompt rage threshold set to %d", p.minRage))
    return
  end
  if k == "rendrefresh" then
    if v < 0.5 then v = 0.5 end
    if v > 6.0 then v = 6.0 end
    p.rendRefreshSec = math.floor((v * 10) + 0.5) / 10
    AddLine("system", string.format("warriorprompt rend refresh set to %.1fs", p.rendRefreshSec))
    return
  end
  AddLine("system", "Unknown key. Use: rage or rendrefresh")
end

function TA_MaybeAutoWarriorPrompt()
  local p = TA_GetWarriorPromptConfig()
  if p.enabled ~= true then
    return
  end
  local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
  if not inCombat then
    return
  end
  TA_ReportWarriorActionPrompt(false)
end

function TA_GetMLStore()
  TextAdventurerDB = TextAdventurerDB or {}
  if type(TextAdventurerDB.ml) ~= "table" then
    TextAdventurerDB.ml = {}
  end
  local ml = TextAdventurerDB.ml
  if type(ml.logs) ~= "table" then ml.logs = {} end
  if type(ml.model) ~= "table" then ml.model = {} end
  if type(ml.xpRateModel) ~= "table" then ml.xpRateModel = {} end
  if ml.loggingEnabled == nil then ml.loggingEnabled = true end
  if type(ml.maxLogs) ~= "number" then ml.maxLogs = 200 end
  return ml
end

function TA_GetMLXPRateModel()
  local ml = TA_GetMLStore()
  if type(ml.xpRateModel) ~= "table" then
    ml.xpRateModel = {}
  end
  local m = ml.xpRateModel
  if type(m.questXPH) ~= "number" then m.questXPH = 0 end
  if type(m.grindXPH) ~= "number" then m.grindXPH = 0 end
  if type(m.unknownXPH) ~= "number" then m.unknownXPH = 0 end
  if type(m.totalXPH) ~= "number" then m.totalXPH = 0 end
  if type(m.questSamples) ~= "number" then m.questSamples = 0 end
  if type(m.grindSamples) ~= "number" then m.grindSamples = 0 end
  if type(m.unknownSamples) ~= "number" then m.unknownSamples = 0 end
  if type(m.totalSamples) ~= "number" then m.totalSamples = 0 end
  if type(m.history) ~= "table" then m.history = {} end
  return m
end

function TA_ResetMLXPRateModel()
  local ml = TA_GetMLStore()
  ml.xpRateModel = {
    questXPH = 0,
    grindXPH = 0,
    unknownXPH = 0,
    totalXPH = 0,
    questSamples = 0,
    grindSamples = 0,
    unknownSamples = 0,
    totalSamples = 0,
    history = {},
  }
  TA.mlXPTrackerLastXP = nil
  TA.mlXPTrackerLastXPMax = nil
  TA.mlXPTrackerLastLevel = nil
  TA.mlXPTrackerLastAt = 0
  TA.mlXPTrackerAbsolute = 0
  TA.mlXPSourceHints = {}
  AddLine("system", "ML XP/hour source model reset.")
end

function TA_InitMLXPTracker()
  TA.mlXPTrackerLastXP = UnitXP("player") or 0
  TA.mlXPTrackerLastXPMax = UnitXPMax("player") or 0
  TA.mlXPTrackerLastLevel = UnitLevel("player") or 1
  TA.mlXPTrackerLastAt = GetTime()
  TA.mlXPTrackerAbsolute = 0
end

function TA_ParseXPNumberFromText(text)
  if not text or text == "" then return nil end
  local raw = text:match("([%d,]+)%s+experience") or text:match("([%d,]+)%s+XP") or text:match("([%d,]+)%s+xp")
  if not raw then return nil end
  raw = raw:gsub(",", "")
  return tonumber(raw)
end

function TA_MarkMLXPSourceHint(source, hintedXP)
  if source ~= "quest" and source ~= "grind" then return end
  TA.mlXPSourceHints = TA.mlXPSourceHints or {}
  TA.mlXPSourceHints[source] = {
    at = GetTime(),
    xp = tonumber(hintedXP) or 0,
  }
end

function TA_UpdateMLXPObservedRate(source, xpDelta, dt)
  local m = TA_GetMLXPRateModel()
  local xph = (tonumber(xpDelta) or 0) / math.max(0.2, tonumber(dt) or 0.2) * 3600
  if xph < 0 then xph = 0 end
  if xph > 500000 then xph = 500000 end

  local function updateEMA(fieldRate, fieldSamples)
    local n = tonumber(m[fieldSamples]) or 0
    local alpha = 0.12
    if n < 8 then
      alpha = 0.35
    elseif n < 30 then
      alpha = 0.22
    end
    if n <= 0 or (tonumber(m[fieldRate]) or 0) <= 0 then
      m[fieldRate] = xph
    else
      m[fieldRate] = (m[fieldRate] * (1 - alpha)) + (xph * alpha)
    end
    m[fieldSamples] = n + 1
  end

  if source == "quest" then
    updateEMA("questXPH", "questSamples")
  elseif source == "grind" then
    updateEMA("grindXPH", "grindSamples")
  else
    updateEMA("unknownXPH", "unknownSamples")
  end
  updateEMA("totalXPH", "totalSamples")

  local h = m.history
  h[#h + 1] = {
    t = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime()),
    source = source,
    xp = xpDelta,
    dt = dt,
    xph = xph,
  }
  while #h > 120 do
    table.remove(h, 1)
  end
end

function TA_ResolveMLXPSource(deltaXP)
  local now = GetTime()
  local hints = TA.mlXPSourceHints or {}
  local questHint = hints.quest
  local grindHint = hints.grind
  local questAge = questHint and (now - (questHint.at or 0)) or 999
  local grindAge = grindHint and (now - (grindHint.at or 0)) or 999
  local questFresh = questAge <= 2.5
  local grindFresh = grindAge <= 2.5

  if questFresh and grindFresh then
    local questXP = tonumber(questHint.xp) or 0
    local grindXP = tonumber(grindHint.xp) or 0
    if questXP > 0 or grindXP > 0 then
      local qd = math.abs(deltaXP - questXP)
      local gd = math.abs(deltaXP - grindXP)
      return (qd <= gd) and "quest" or "grind"
    end
    return (questAge <= grindAge) and "quest" or "grind"
  end
  if questFresh then
    return "quest"
  end
  if grindFresh then
    return "grind"
  end
  if TA.dpsCombatStart and TA.dpsCombatStart > 0 then
    return "grind"
  end
  if TA.lastCombatEndedAt and (now - TA.lastCombatEndedAt) <= 3.0 then
    return "grind"
  end
  return "unknown"
end

function TA_GetTrackedXPDelta()
  local currentXP = UnitXP("player") or 0
  local currentXPMax = UnitXPMax("player") or 0
  local currentLevel = UnitLevel("player") or 1
  local previousXP = TA.mlXPTrackerLastXP
  local previousXPMax = TA.mlXPTrackerLastXPMax
  local previousLevel = TA.mlXPTrackerLastLevel

  TA.mlXPTrackerLastXP = currentXP
  TA.mlXPTrackerLastXPMax = currentXPMax
  TA.mlXPTrackerLastLevel = currentLevel

  if previousXP == nil then
    return 0
  end

  if currentLevel > (previousLevel or currentLevel) then
    local remainder = math.max(0, (previousXPMax or 0) - (previousXP or 0))
    return remainder + currentXP
  end
  return currentXP - previousXP
end

function TA_HandleMLXPSourceEvent(event, ...)
  if event == "CHAT_MSG_COMBAT_XP_GAIN" then
    local msg = ...
    local xp = TA_ParseXPNumberFromText(msg)
    TA_MarkMLXPSourceHint("grind", xp)
    return
  end

  if event == "QUEST_TURNED_IN" then
    local _, xpReward = ...
    TA_MarkMLXPSourceHint("quest", xpReward)
    return
  end

  if event ~= "PLAYER_XP_UPDATE" and event ~= "PLAYER_LEVEL_UP" then
    return
  end
  if TA.mlXPTrackerLastXP == nil then
    TA_InitMLXPTracker()
    return
  end

  local now = GetTime()
  local prevAt = TA.mlXPTrackerLastAt or now
  local delta = TA_GetTrackedXPDelta()
  TA.mlXPTrackerLastAt = now
  if delta <= 0 then return end

  TA.mlXPTrackerAbsolute = (TA.mlXPTrackerAbsolute or 0) + delta
  local dt = now - prevAt
  if dt <= 0 then dt = 0.2 end
  local source = TA_ResolveMLXPSource(delta)
  TA_UpdateMLXPObservedRate(source, delta, dt)
end

function TA_GetGuideTopQuestXPPerHour()
  if type(TA_CollectQuestGuideRows) ~= "function" then
    return 0
  end
  local rows = TA_CollectQuestGuideRows()
  local top = rows and rows[1]
  if not top then
    return 0
  end
  local xpm = tonumber(top.xpPerMin) or 0
  return math.max(0, xpm * 60)
end

function TA_BlendObservedRate(observed, samples, prior, priorWeight)
  local obs = tonumber(observed) or 0
  local n = math.max(0, tonumber(samples) or 0)
  local p = math.max(0, tonumber(prior) or 0)
  local w = math.max(0.5, tonumber(priorWeight) or 8)
  return ((obs * n) + (p * w)) / (n + w)
end

function TA_ReportMLXPRateStatus()
  if TA.mlXPTrackerLastXP == nil then
    TA_InitMLXPTracker()
  end
  local m = TA_GetMLXPRateModel()
  local c = TA_GetMLXPConfig()
  local modeWeight, mode = TA_GetMLXPModeQuestWeight(c)
  local questConf = (m.questSamples or 0) / math.max(1, (m.questSamples or 0) + (c.priorWeight or 8))
  local grindConf = (m.grindSamples or 0) / math.max(1, (m.grindSamples or 0) + (c.priorWeight or 8))
  AddLine("system", string.format("ML XP/hour rates: grind %.0f (%d samples, conf %.0f%%) | quest %.0f (%d samples, conf %.0f%%)", m.grindXPH or 0, m.grindSamples or 0, grindConf * 100, m.questXPH or 0, m.questSamples or 0, questConf * 100))
  AddLine("system", string.format("Other: total %.0f (%d) | unknown %.0f (%d)", m.totalXPH or 0, m.totalSamples or 0, m.unknownXPH or 0, m.unknownSamples or 0))
  AddLine("system", string.format("ML blend knobs: mode %s, effective questweight %.2f, base questweight %.2f, priorweight %.1f, grindscale %.1f", mode or "balanced", modeWeight or 0.55, c.questWeight or 0.55, c.priorWeight or 8, c.grindScale or 240))
end

function TA_CaptureMLFeatures()
  local cfg = TA_GetSealLiveConfig()
  local playerLevel = UnitLevel("player") or 60
  local targetLevel = tonumber(cfg.targetLevel) or playerLevel
  local minMain, maxMain = UnitDamage("player")
  local mainSpeed = UnitAttackSpeed("player")
  local avgWeaponHit = 0
  if minMain and maxMain then
    avgWeaponHit = (minMain + maxMain) / 2
  end
  local baseAP, posAP, negAP = UnitAttackPower("player")
  local ap = (baseAP or 0) + (posAP or 0) + (negAP or 0)
  local powerType = UnitPowerType("player") or 0
  local mana = UnitPower("player", powerType) or 0
  local manaMax = UnitPowerMax("player", powerType) or 0
  local manaPct = manaMax > 0 and (mana / manaMax) * 100 or 0
  local spellPower = TA_GetSpellPowerHoly()
  local crit = (GetCritChance and (GetCritChance() or 0)) or 0
  local hit = (GetHitModifier and (GetHitModifier() or 0)) or 0
  local meleeConnect = TA_GetMeleeConnectChance(targetLevel, cfg.attackFromBehind)
  local judgeConnect = TA_GetJudgementConnectChance(targetLevel)

  return {
    playerLevel = playerLevel,
    targetLevel = targetLevel,
    levelDiff = targetLevel - playerLevel,
    weaponSpeed = tonumber(mainSpeed) or 0,
    avgWeaponHit = avgWeaponHit,
    ap = ap,
    spellPower = spellPower,
    crit = crit,
    hit = hit,
    manaPct = manaPct,
    attackFromBehind = cfg.attackFromBehind and 1 or 0,
    meleeConnect = meleeConnect,
    judgeConnect = judgeConnect,
  }
end

function TA_LogMLFightResult(duration, damage)
  local ml = TA_GetMLStore()
  if not ml.loggingEnabled then return end
  if not TA.mlFightSnapshot then return end

  local dur = math.max(0.001, tonumber(duration) or 0.001)
  local dmg = tonumber(damage) or 0
  local dps = dmg / dur

  local row = {
    t = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime()),
    playerLevel = TA.mlFightSnapshot.playerLevel,
    targetLevel = TA.mlFightSnapshot.targetLevel,
    levelDiff = TA.mlFightSnapshot.levelDiff,
    weaponSpeed = TA.mlFightSnapshot.weaponSpeed,
    avgWeaponHit = TA.mlFightSnapshot.avgWeaponHit,
    ap = TA.mlFightSnapshot.ap,
    spellPower = TA.mlFightSnapshot.spellPower,
    crit = TA.mlFightSnapshot.crit,
    hit = TA.mlFightSnapshot.hit,
    manaPct = TA.mlFightSnapshot.manaPct,
    attackFromBehind = TA.mlFightSnapshot.attackFromBehind,
    meleeConnect = TA.mlFightSnapshot.meleeConnect,
    judgeConnect = TA.mlFightSnapshot.judgeConnect,
    fightDuration = dur,
    fightDamage = dmg,
    fightDps = dps,
  }

  table.insert(ml.logs, row)
  local maxLogs = math.max(20, math.floor(tonumber(ml.maxLogs) or 200))
  while #ml.logs > maxLogs do
    table.remove(ml.logs, 1)
  end
end

function TA_SetMLLogging(enabled)
  local ml = TA_GetMLStore()
  ml.loggingEnabled = enabled and true or false
  AddLine("system", string.format("ML fight logging %s.", ml.loggingEnabled and "enabled" or "disabled"))
end

function TA_ClearMLLogs()
  local ml = TA_GetMLStore()
  wipe(ml.logs)
  AddLine("system", "ML logs cleared.")
end

function TA_SetMLMaxLogs(n)
  local v = math.floor(tonumber(n) or 0)
  if v < 20 then v = 20 end
  if v > 2000 then v = 2000 end
  local ml = TA_GetMLStore()
  ml.maxLogs = v
  AddLine("system", string.format("ML max logs set to %d.", v))
end

function TA_FormatCSVField(v)
  v = tostring(v or "")
  if v:find('[,\"]') then
    v = '"' .. v:gsub('"', '""') .. '"'
  end
  return v
end

function TA_ExportMLLogs(countArg)
  local ml = TA_GetMLStore()
  if #ml.logs == 0 then
    AddLine("system", "No ML logs to export yet.")
    return
  end

  local count = math.floor(tonumber(countArg) or 20)
  if count < 1 then count = 1 end
  if count > 100 then count = 100 end
  if count > #ml.logs then count = #ml.logs end

  local header = "t,playerLevel,targetLevel,levelDiff,weaponSpeed,avgWeaponHit,ap,spellPower,crit,hit,manaPct,attackFromBehind,meleeConnect,judgeConnect,fightDuration,fightDamage,fightDps"
  AddLine("system", "ML CSV export (newest last):")
  AddLine("system", header)

  local startIdx = #ml.logs - count + 1
  for i = startIdx, #ml.logs do
    local row = ml.logs[i]
    local csv = table.concat({
      TA_FormatCSVField(row.t),
      TA_FormatCSVField(string.format("%.0f", row.playerLevel or 0)),
      TA_FormatCSVField(string.format("%.0f", row.targetLevel or 0)),
      TA_FormatCSVField(string.format("%.0f", row.levelDiff or 0)),
      TA_FormatCSVField(string.format("%.4f", row.weaponSpeed or 0)),
      TA_FormatCSVField(string.format("%.4f", row.avgWeaponHit or 0)),
      TA_FormatCSVField(string.format("%.4f", row.ap or 0)),
      TA_FormatCSVField(string.format("%.4f", row.spellPower or 0)),
      TA_FormatCSVField(string.format("%.4f", row.crit or 0)),
      TA_FormatCSVField(string.format("%.4f", row.hit or 0)),
      TA_FormatCSVField(string.format("%.4f", row.manaPct or 0)),
      TA_FormatCSVField(string.format("%.0f", row.attackFromBehind or 0)),
      TA_FormatCSVField(string.format("%.6f", row.meleeConnect or 0)),
      TA_FormatCSVField(string.format("%.6f", row.judgeConnect or 0)),
      TA_FormatCSVField(string.format("%.4f", row.fightDuration or 0)),
      TA_FormatCSVField(string.format("%.4f", row.fightDamage or 0)),
      TA_FormatCSVField(string.format("%.4f", row.fightDps or 0)),
    }, ",")
    AddLine("system", csv)
  end
end

function TA_EvalMLTreeNode(node, features, trace)
  if not node then return { sor = 0, soc = 0, hybrid = 0 }, "empty" end
  if node.leaf then
    return node.leaf, "leaf"
  end

  local f = tonumber(features[node.feature] or 0) or 0
  local threshold = tonumber(node.value or 0) or 0
  local op = node.op or "<="
  local pass = false
  if op == "<" then pass = (f < threshold)
  elseif op == "<=" then pass = (f <= threshold)
  elseif op == ">" then pass = (f > threshold)
  elseif op == ">=" then pass = (f >= threshold)
  else pass = (f <= threshold)
  end

  local branch = pass and node.left or node.right
  local leaf, leafTrace = TA_EvalMLTreeNode(branch, features, trace)
  local step = string.format("%s %.4f %s %.4f -> %s", node.feature or "?", f, op, threshold, pass and "left" or "right")
  if leafTrace and leafTrace ~= "" then
    return leaf, step .. " | " .. leafTrace
  end
  return leaf, step
end

function TA_RecommendWithML(explain)
  local ml = TA_GetMLStore()
  if type(ml.model) ~= "table" or type(ml.model.trees) ~= "table" or #ml.model.trees == 0 then
    AddLine("system", "No ML model loaded. Use: ml model sample")
    return
  end

  local features = TA_CaptureMLFeatures()
  local scores = { sor = 0, soc = 0, hybrid = 0 }
  local traces = {}
  for i = 1, #ml.model.trees do
    local tree = ml.model.trees[i]
    local leaf, trace = TA_EvalMLTreeNode(tree, features)
    local weight = tonumber(tree.weight) or 1
    scores.sor = scores.sor + (tonumber(leaf.sor) or 0) * weight
    scores.soc = scores.soc + (tonumber(leaf.soc) or 0) * weight
    scores.hybrid = scores.hybrid + (tonumber(leaf.hybrid) or 0) * weight
    traces[i] = trace
  end

  local bestKey = "sor"
  if scores.soc > scores[bestKey] then bestKey = "soc" end
  if scores.hybrid > scores[bestKey] then bestKey = "hybrid" end

  local labels = {
    sor = "Pure SoR loop",
    soc = "Pure SoC loop",
    hybrid = "JoC opener -> SoR",
  }

  AddLine("playerCombat", string.format("ML recommendation: %s", labels[bestKey] or bestKey))
  AddLine("system", string.format("ML scores: SoR %.3f | SoC %.3f | Hybrid %.3f", scores.sor, scores.soc, scores.hybrid))
  if explain then
    AddLine("system", string.format("Features: lvlDiff %.0f, speed %.2f, AP %.0f, SP %.0f, mana %.1f%%, connect %.1f%%", features.levelDiff or 0, features.weaponSpeed or 0, features.ap or 0, features.spellPower or 0, features.manaPct or 0, (features.meleeConnect or 0) * 100))
    for i = 1, #traces do
      AddLine("system", string.format("  tree %d: %s", i, traces[i] or ""))
    end
  end
end

function TA_LoadSampleMLModel()
  local ml = TA_GetMLStore()
  ml.model = {
    name = "ta-seal-sample-v1",
    labels = { "sor", "soc", "hybrid" },
    trees = {
      {
        feature = "levelDiff",
        op = ">=",
        value = 2,
        left = { leaf = { sor = 0.75, soc = 0.10, hybrid = 0.15 } },
        right = { leaf = { sor = 0.35, soc = 0.40, hybrid = 0.25 } },
      },
      {
        feature = "weaponSpeed",
        op = ">=",
        value = 3.3,
        left = { leaf = { sor = 0.20, soc = 0.55, hybrid = 0.25 } },
        right = { leaf = { sor = 0.55, soc = 0.20, hybrid = 0.25 } },
      },
      {
        feature = "manaPct",
        op = "<=",
        value = 20,
        left = { leaf = { sor = 0.20, soc = 0.60, hybrid = 0.20 } },
        right = {
          feature = "spellPower",
          op = ">=",
          value = 180,
          left = { leaf = { sor = 0.60, soc = 0.10, hybrid = 0.30 } },
          right = { leaf = { sor = 0.35, soc = 0.30, hybrid = 0.35 } },
        },
      },
    },
  }
  AddLine("system", "Sample ML model loaded. Use 'ml recommend' or 'ml recommend explain'.")
end

function TA_ClearMLModel()
  local ml = TA_GetMLStore()
  ml.model = {}
  AddLine("system", "ML model cleared.")
end

function TA_ReportMLStatus()
  local ml = TA_GetMLStore()
  local treeCount = (ml.model and ml.model.trees and #ml.model.trees) or 0
  AddLine("system", string.format("ML status: logging=%s logs=%d/%d trees=%d", ml.loggingEnabled and "on" or "off", #ml.logs, ml.maxLogs or 200, treeCount))
  if ml.model and ml.model.name then
    AddLine("system", "ML model: " .. tostring(ml.model.name))
  end
end

function TA_GetMLXPConfig()
  local ml = TA_GetMLStore()
  if type(ml.xpConfig) ~= "table" then
    ml.xpConfig = {}
  end
  local c = ml.xpConfig
  if type(c.weight) ~= "number" then c.weight = 0.65 end
  if type(c.sealManaPct) ~= "number" then c.sealManaPct = 0.040 end
  if type(c.judgeManaPct) ~= "number" then c.judgeManaPct = 0.050 end
  if type(c.sealCycleSec) ~= "number" then c.sealCycleSec = 30 end
  if type(c.socManaMult) ~= "number" then c.socManaMult = 1.06 end
  if type(c.warriorImpHSRank) ~= "number" then c.warriorImpHSRank = 0 end
  if type(c.warriorImpRendRank) ~= "number" then c.warriorImpRendRank = 0 end
  if type(c.warriorImpOverpowerRank) ~= "number" then c.warriorImpOverpowerRank = 0 end
  if type(c.warriorImpSlamRank) ~= "number" then c.warriorImpSlamRank = 0 end
  if type(c.warriorDeepWoundsRank) ~= "number" then c.warriorDeepWoundsRank = 0 end
  if type(c.warriorImpaleRank) ~= "number" then c.warriorImpaleRank = 0 end
  if type(c.warriorOverpowerPerMin) ~= "number" then c.warriorOverpowerPerMin = 1.2 end
  if type(c.warriorDodgeChance) ~= "number" then c.warriorDodgeChance = 0.05 end
  if type(c.warriorGlancingChance) ~= "number" then c.warriorGlancingChance = 0.10 end
  if type(c.warriorGlancingDamage) ~= "number" then c.warriorGlancingDamage = 0.95 end
  if type(c.warriorNormalization) ~= "number" then c.warriorNormalization = 3.3 end
  if type(c.warriorDeepWoundsPerPoint) ~= "number" then c.warriorDeepWoundsPerPoint = 0.2 end
  if type(c.warriorImpalePerPoint) ~= "number" then c.warriorImpalePerPoint = 0.1 end
  if type(c.warriorWhirlwindTargets) ~= "number" then c.warriorWhirlwindTargets = 1 end
  if type(c.warriorWeaponProfile) ~= "string" or c.warriorWeaponProfile == "" then c.warriorWeaponProfile = "auto" end
  if type(c.questWeight) ~= "number" then c.questWeight = 0.55 end
  if type(c.priorWeight) ~= "number" then c.priorWeight = 8.0 end
  if type(c.grindScale) ~= "number" then c.grindScale = 240 end
  if type(c.mode) ~= "string" or c.mode == "" then c.mode = "balanced" end
  return c
end

function TA_NormalizeMLXPMode(mode)
  local m = tostring(mode or ""):lower():gsub("_", "-")
  if m == "" or m == "balanced" or m == "balance" then
    return "balanced"
  end
  if m == "grind" or m == "grind-first" or m == "grindfirst" then
    return "grind-first"
  end
  if m == "quest" or m == "quest-first" or m == "questfirst" then
    return "quest-first"
  end
  return nil
end

function TA_GetMLXPModeQuestWeight(c)
  local mode = TA_NormalizeMLXPMode(c.mode) or "balanced"
  if mode == "grind-first" then
    return 0.20, mode
  end
  if mode == "quest-first" then
    return 0.80, mode
  end
  return c.questWeight or 0.55, "balanced"
end

function TA_SetMLXPMode(mode)
  local normalized = TA_NormalizeMLXPMode(mode)
  if not normalized then
    AddLine("system", "Unknown mode. Use: balanced | grind-first | quest-first")
    return
  end
  local c = TA_GetMLXPConfig()
  c.mode = normalized
  local qWeight = TA_GetMLXPModeQuestWeight(c)
  AddLine("system", string.format("ML XP mode set to %s (effective quest weight %.2f).", normalized, qWeight or 0))
end

function TA_ReportMLXPMode()
  local c = TA_GetMLXPConfig()
  local qWeight, mode = TA_GetMLXPModeQuestWeight(c)
  AddLine("system", string.format("ML XP mode: %s (effective quest weight %.2f)", mode or "balanced", qWeight or 0))
  AddLine("system", "Modes: balanced | grind-first | quest-first")
end

function TA_NormalizeWarriorWeaponProfile(profile)
  local p = tostring(profile or ""):lower():gsub("_", "-")
  if p == "" or p == "auto" then return "auto" end
  if p == "slow" or p == "2h-slow" or p == "slow2h" or p == "slow-2h" then return "slow-2h" end
  if p == "fast" or p == "2h-fast" or p == "fast2h" or p == "fast-2h" then return "fast-2h" end
  if p == "1h" or p == "one" or p == "onehand" or p == "one-hand" then return "one-hand" end
  if p == "dw" or p == "dual" or p == "dualwield" or p == "dual-wield" then return "dual-wield" end
  return nil
end

function TA_DetectWarriorWeaponProfile()
  local mainSpeed, offSpeed = UnitAttackSpeed("player")
  mainSpeed = tonumber(mainSpeed) or 0
  offSpeed = tonumber(offSpeed) or 0
  if offSpeed > 0 then
    return "dual-wield", mainSpeed, offSpeed
  end
  if mainSpeed >= 3.3 then
    return "slow-2h", mainSpeed, 0
  end
  if mainSpeed >= 2.6 then
    return "fast-2h", mainSpeed, 0
  end
  return "one-hand", mainSpeed, 0
end

function TA_GetWarriorWeaponProfileTuning(profile)
  local p = TA_NormalizeWarriorWeaponProfile(profile)
  if p == "slow-2h" then
    return { warriorDodgeChance = 0.05, warriorGlancingChance = 0.10, warriorGlancingDamage = 0.95, warriorNormalization = 3.3, warriorOverpowerPerMin = 1.6, warriorWhirlwindTargets = 1 }
  end
  if p == "fast-2h" then
    return { warriorDodgeChance = 0.05, warriorGlancingChance = 0.12, warriorGlancingDamage = 0.92, warriorNormalization = 3.3, warriorOverpowerPerMin = 1.2, warriorWhirlwindTargets = 1 }
  end
  if p == "one-hand" then
    return { warriorDodgeChance = 0.05, warriorGlancingChance = 0.18, warriorGlancingDamage = 0.90, warriorNormalization = 2.4, warriorOverpowerPerMin = 0.9, warriorWhirlwindTargets = 1 }
  end
  if p == "dual-wield" then
    return { warriorDodgeChance = 0.05, warriorGlancingChance = 0.24, warriorGlancingDamage = 0.85, warriorNormalization = 2.4, warriorOverpowerPerMin = 0.7, warriorWhirlwindTargets = 2 }
  end
  return nil
end

function TA_ApplyWarriorWeaponProfile(profile, silent)
  local p = TA_NormalizeWarriorWeaponProfile(profile)
  if not p then
    if not silent then AddLine("system", "Usage: ml xp warrior weapon <auto|slow-2h|fast-2h|one-hand|dual-wield>") end
    return false
  end

  local c = TA_GetMLXPConfig()
  c.warriorWeaponProfile = p
  if p == "auto" then
    if not silent then
      local detected, mainSpeed, offSpeed = TA_DetectWarriorWeaponProfile()
      AddLine("system", string.format("Warrior weapon profile set to auto (detected now: %s, speed %.2f%s).", detected, mainSpeed or 0, offSpeed > 0 and (", offhand " .. string.format("%.2f", offSpeed)) or ""))
    end
    return true
  end

  local t = TA_GetWarriorWeaponProfileTuning(p)
  if not t then
    if not silent then AddLine("system", "Unknown warrior weapon profile.") end
    return false
  end
  c.warriorDodgeChance = t.warriorDodgeChance
  c.warriorGlancingChance = t.warriorGlancingChance
  c.warriorGlancingDamage = t.warriorGlancingDamage
  c.warriorNormalization = t.warriorNormalization
  c.warriorOverpowerPerMin = t.warriorOverpowerPerMin
  c.warriorWhirlwindTargets = t.warriorWhirlwindTargets
  if not silent then AddLine("system", string.format("Warrior weapon profile applied: %s", p)) end
  return true
end

function TA_ApplyWarriorPreset(presetName)
  local preset = tostring(presetName or ""):lower():gsub("_", "-")
  local c = TA_GetMLXPConfig()
  if preset == "arms" then
    c.warriorImpHSRank = 0
    c.warriorImpRendRank = 3
    c.warriorImpOverpowerRank = 2
    c.warriorImpSlamRank = 0
    c.warriorDeepWoundsRank = 3
    c.warriorImpaleRank = 2
    c.warriorOverpowerPerMin = 1.6
    TA_ApplyWarriorWeaponProfile("slow-2h", true)
    AddLine("system", "Warrior preset applied: arms (2H leveling baseline).")
    return
  end
  if preset == "fury" then
    c.warriorImpHSRank = 3
    c.warriorImpRendRank = 0
    c.warriorImpOverpowerRank = 0
    c.warriorImpSlamRank = 0
    c.warriorDeepWoundsRank = 0
    c.warriorImpaleRank = 0
    c.warriorOverpowerPerMin = 0.8
    TA_ApplyWarriorWeaponProfile("dual-wield", true)
    AddLine("system", "Warrior preset applied: fury (dual-wield leveling baseline).")
    return
  end
  AddLine("system", "Usage: ml xp warrior preset <arms|fury>")
end

function TA_ResetMLXPConfigDefaults()
  local ml = TA_GetMLStore()
  ml.xpConfig = {
    weight = 0.65,
    sealManaPct = 0.040,
    judgeManaPct = 0.050,
    sealCycleSec = 30,
    socManaMult = 1.06,
    warriorImpHSRank = 0,
    warriorImpRendRank = 0,
    warriorImpOverpowerRank = 0,
    warriorImpSlamRank = 0,
    warriorDeepWoundsRank = 0,
    warriorImpaleRank = 0,
    warriorOverpowerPerMin = 1.2,
    warriorDodgeChance = 0.05,
    warriorGlancingChance = 0.10,
    warriorGlancingDamage = 0.95,
    warriorNormalization = 3.3,
    warriorDeepWoundsPerPoint = 0.2,
    warriorImpalePerPoint = 0.1,
    warriorWhirlwindTargets = 1,
    warriorWeaponProfile = "auto",
    questWeight = 0.55,
    priorWeight = 8.0,
    grindScale = 240,
    mode = "balanced",
  }
  AddLine("system", "ML XP optimizer settings reset to defaults.")
end

function TA_SetMLXPConfigValue(key, value)
  local c = TA_GetMLXPConfig()
  local k = tostring(key or ""):lower()
  local v = tonumber(value)
  if not v then
    AddLine("system", "Invalid value. Usage: ml xp set <weight|sealpct|judgepct|sealcycle|socmult> <value>")
    return
  end

  if k == "weight" then
    if v < 0 then v = 0 end
    if v > 5 then v = 5 end
    c.weight = v
  elseif k == "sealpct" then
    if v < 0 then v = 0 end
    if v > 0.30 then v = 0.30 end
    c.sealManaPct = v
  elseif k == "judgepct" then
    if v < 0 then v = 0 end
    if v > 0.40 then v = 0.40 end
    c.judgeManaPct = v
  elseif k == "sealcycle" then
    if v < 10 then v = 10 end
    if v > 120 then v = 120 end
    c.sealCycleSec = v
  elseif k == "socmult" then
    if v < 0.5 then v = 0.5 end
    if v > 2.0 then v = 2.0 end
    c.socManaMult = v
  elseif k == "warriorimphs" then
    if v < 0 then v = 0 end
    if v > 3 then v = 3 end
    c.warriorImpHSRank = math.floor(v + 0.5)
    v = c.warriorImpHSRank
  elseif k == "warriorimprend" then
    if v < 0 then v = 0 end
    if v > 3 then v = 3 end
    c.warriorImpRendRank = math.floor(v + 0.5)
    v = c.warriorImpRendRank
  elseif k == "warriorimpop" then
    if v < 0 then v = 0 end
    if v > 2 then v = 2 end
    c.warriorImpOverpowerRank = math.floor(v + 0.5)
    v = c.warriorImpOverpowerRank
  elseif k == "warriorimpslam" then
    if v < 0 then v = 0 end
    if v > 5 then v = 5 end
    c.warriorImpSlamRank = math.floor(v + 0.5)
    v = c.warriorImpSlamRank
  elseif k == "warriordeepwounds" then
    if v < 0 then v = 0 end
    if v > 3 then v = 3 end
    c.warriorDeepWoundsRank = math.floor(v + 0.5)
    v = c.warriorDeepWoundsRank
  elseif k == "warriorimpale" then
    if v < 0 then v = 0 end
    if v > 2 then v = 2 end
    c.warriorImpaleRank = math.floor(v + 0.5)
    v = c.warriorImpaleRank
  elseif k == "warrioropppm" then
    if v < 0 then v = 0 end
    if v > 12 then v = 12 end
    c.warriorOverpowerPerMin = v
  elseif k == "warriordodge" then
    if v < 0 then v = 0 end
    if v > 0.35 then v = 0.35 end
    c.warriorDodgeChance = v
  elseif k == "warriorglance" then
    if v < 0 then v = 0 end
    if v > 0.40 then v = 0.40 end
    c.warriorGlancingChance = v
  elseif k == "warriorglancedmg" then
    if v < 0.5 then v = 0.5 end
    if v > 1.0 then v = 1.0 end
    c.warriorGlancingDamage = v
  elseif k == "warriornorm" then
    if v < 2.2 then v = 2.2 end
    if v > 3.8 then v = 3.8 end
    c.warriorNormalization = v
  elseif k == "warriorwwtargets" then
    if v < 1 then v = 1 end
    if v > 4 then v = 4 end
    c.warriorWhirlwindTargets = math.floor(v + 0.5)
    v = c.warriorWhirlwindTargets
  elseif k == "questweight" then
    if v < 0 then v = 0 end
    if v > 1 then v = 1 end
    c.questWeight = v
  elseif k == "priorweight" then
    if v < 0.5 then v = 0.5 end
    if v > 60 then v = 60 end
    c.priorWeight = v
  elseif k == "grindscale" then
    if v < 50 then v = 50 end
    if v > 2000 then v = 2000 end
    c.grindScale = v
  else
    AddLine("system", "Unknown key. Use: weight, sealpct, judgepct, sealcycle, socmult, warriorimphs, warriorimprend, warriorimpop, warriorimpslam, warriordeepwounds, warriorimpale, warrioropppm, warriordodge, warriorglance, warriorglancedmg, warriornorm, warriorwwtargets, questweight, priorweight, grindscale")
    return
  end

  AddLine("system", string.format("ML XP setting %s updated to %.4f", k, v))
end

function TA_GetManaRegenPerSecond()
  local inactive, active
  if GetPowerRegen then
    inactive, active = GetPowerRegen()
    inactive = tonumber(inactive) or 0
    active = tonumber(active) or 0
  elseif GetManaRegen then
    inactive, active = GetManaRegen()
    inactive = tonumber(inactive) or 0
    active = tonumber(active) or 0
  else
    inactive, active = 0, 0
  end

  local combatRegen = active > 0 and active or inactive
  if combatRegen < 0 then combatRegen = 0 end
  return combatRegen
end

function TA_BuildLiveSealOptionMetrics(windowArg)
  local cfg = TA_GetSealLiveConfig()
  local window = tonumber(windowArg) or tonumber(cfg.hybridWindow) or 60
  if window < 15 then window = 15 end
  if window > 300 then window = 300 end
  local resealGCD = tonumber(cfg.resealGCD) or 1.5

  local minMain, maxMain = UnitDamage("player")
  local mainSpeed = UnitAttackSpeed("player")
  if not minMain or not maxMain or not mainSpeed or mainSpeed <= 0 then
    return nil, "Live XP optimizer unavailable: no valid main-hand weapon data."
  end

  local spellPower = TA_GetSpellPowerHoly()
  local avgWeaponHit = (minMain + maxMain) / 2
  local meleeConnect = TA_GetMeleeConnectChance(cfg.targetLevel, cfg.attackFromBehind)
  local judgeConnect = TA_GetJudgementConnectChance(cfg.targetLevel)
  local swingsPerSec = 1 / mainSpeed

  local sorRow = TA_GetLiveSpellRankRow("sor")
  local jorRow = TA_GetLiveSpellRankRow("jor")
  local socRow = TA_GetLiveSpellRankRow("soc")
  local jocRow = TA_GetLiveSpellRankRow("joc")

  if not sorRow or not jorRow or not jocRow then
    return nil, "Live XP optimizer unavailable: missing SoR/JoR/JoC ranks in spellbook."
  end

  local sorBase = ((sorRow.min or 0) + (sorRow.max or 0)) / 2
  local jorBase = ((jorRow.min or 0) + (jorRow.max or 0)) / 2
  local jocBase = ((jocRow.min or 0) + (jocRow.max or 0)) / 2

  local sorHit = sorBase + (spellPower * (sorRow.coeff or 0))
  local sorDps = sorHit * swingsPerSec * meleeConnect

  local jorHit = jorBase + (spellPower * (jorRow.coeff or 0))
  local jorDps = (jorHit / math.max(1, cfg.judgementCD)) * judgeConnect

  local socWeaponCoeff = socRow and (socRow.weaponCoeff or 0.70) or 0.70
  local socCoeff = socRow and (socRow.coeff or 0.29) or 0.29
  local socHit = (avgWeaponHit * socWeaponCoeff) + (spellPower * socCoeff)
  local socConnects = (math.max(0.5, cfg.socPPM) / 60) * meleeConnect
  local socDps = socHit * socConnects

  local jocHit = jocBase + (spellPower * (jocRow.coeff or 0))
  local jocDps = (jocHit / math.max(1, cfg.judgementCD)) * judgeConnect

  local pureSorDps = sorDps + jorDps
  local pureSocDps = socDps + jocDps

  local oneJudgeDeltaDmg = (jocHit - jorHit) * judgeConnect
  local resealPenaltyDmg = sorDps * resealGCD
  local hybridDps = pureSorDps + ((oneJudgeDeltaDmg - resealPenaltyDmg) / window)

  return {
    cfg = cfg,
    window = window,
    pureSorDps = pureSorDps,
    pureSocDps = pureSocDps,
    hybridDps = hybridDps,
    spellPower = spellPower,
    mainSpeed = mainSpeed,
    meleeConnect = meleeConnect,
    judgeConnect = judgeConnect,
  }
end

function TA_RecommendXPWithML(explain)
  local c = TA_GetMLXPConfig()
  local m = TA_GetMLXPRateModel()
  local classToken = select(2, UnitClass("player")) or "UNKNOWN"
  local mana = 0
  local manaMax = 0
  local manaPct = 100
  local regen = TA_GetManaRegenPerSecond()
  local options = nil
  local classLabel = classToken
  local effectiveQuestWeight, mode = TA_GetMLXPModeQuestWeight(c)

  if classToken == "PALADIN" then
    local metrics, err = TA_BuildLiveSealOptionMetrics()
    if not metrics then
      AddLine("system", err or "Live XP optimizer unavailable.")
      return
    end

    local powerType = UnitPowerType("player") or 0
    mana = UnitPower("player", powerType) or 0
    manaMax = UnitPowerMax("player", powerType) or 0
    manaPct = manaMax > 0 and (mana / manaMax) * 100 or 0

    local judgeCost = manaMax * c.judgeManaPct
    local sorSealCost = manaMax * c.sealManaPct
    local socSealCost = sorSealCost * c.socManaMult
    local judgePerSec = judgeCost / math.max(1, metrics.cfg.judgementCD)
    local sealRefreshPerSec = 1 / math.max(10, c.sealCycleSec)
    local extraHybridSealPerSec = 1 / math.max(15, metrics.window)

    options = {
      {
        key = "sor",
        label = "Pure SoR loop",
        dps = metrics.pureSorDps,
        manaPerSec = judgePerSec + (sorSealCost * sealRefreshPerSec),
      },
      {
        key = "soc",
        label = "Pure SoC loop",
        dps = metrics.pureSocDps,
        manaPerSec = judgePerSec + (socSealCost * sealRefreshPerSec),
      },
      {
        key = "hybrid",
        label = "JoC opener -> SoR",
        dps = metrics.hybridDps,
        manaPerSec = judgePerSec + (sorSealCost * sealRefreshPerSec) + (socSealCost * extraHybridSealPerSec),
      },
    }
    classLabel = "Paladin"
  elseif classToken == "WARRIOR" then
    local metrics, err = TA_BuildLiveWarriorOptionMetrics(c)
    if not metrics then
      AddLine("system", err or "Live XP optimizer unavailable.")
      return
    end

    options = {}
    if metrics.knowsHS then
      options[#options + 1] = {
        key = "warrior_hs",
        label = "Heroic Strike dump",
        dps = metrics.baseAutoDps + metrics.hsDps,
        manaPerSec = 0,
      }
    end
    if metrics.knowsRend then
      options[#options + 1] = {
        key = "warrior_rend_hs",
        label = "Rend maintain + Heroic Strike",
        dps = metrics.baseAutoDps + metrics.rendDps + (metrics.hsDps * 0.85),
        manaPerSec = 0,
      }
    end
    if metrics.knowsOP then
      options[#options + 1] = {
        key = "warrior_op_hs",
        label = "Overpower procs + Heroic Strike",
        dps = metrics.baseAutoDps + metrics.overpowerDps + (metrics.hsDps * 0.75),
        manaPerSec = 0,
      }
    end
    if metrics.knowsMS then
      options[#options + 1] = {
        key = "warrior_arms",
        label = "Mortal Strike rotation",
        dps = metrics.baseAutoDps + metrics.msDps + (metrics.rendDps * 0.7) + (metrics.overpowerDps * 0.7),
        manaPerSec = 0,
      }
    elseif metrics.knowsWW then
      options[#options + 1] = {
        key = "warrior_fury",
        label = "Whirlwind rotation",
        dps = metrics.baseAutoDps + metrics.wwDps + (metrics.hsDps * 0.55),
        manaPerSec = 0,
      }
    elseif metrics.knowsSlam then
      options[#options + 1] = {
        key = "warrior_slam",
        label = "Slam weaving",
        dps = metrics.baseAutoDps + metrics.slamDps + (metrics.hsDps * 0.45),
        manaPerSec = 0,
      }
    end

    if #options == 0 then
      AddLine("system", "Warrior XP optimizer: no supported learned abilities found yet.")
      return
    end
    classLabel = "Warrior"
  else
    AddLine("system", string.format("ML XP optimizer currently supports Paladin and Warrior. You are: %s", classToken))
    return
  end

  local manaStress = 0
  if manaPct < 40 then
    manaStress = (40 - manaPct) / 40
  end
  local effectiveWeight = c.weight * (1 + (1.5 * manaStress))
  local best = nil
  local bestScore = 0

  for i = 1, #options do
    local row = options[i]
    local netDrain = row.manaPerSec - regen
    if netDrain < 0 then netDrain = 0 end
    local downtimeRatio = netDrain / math.max(0.01, regen)
    local score = row.dps / (1 + (effectiveWeight * downtimeRatio))
    row.netDrain = netDrain
    row.downtimeRatio = downtimeRatio
    row.score = score
    row.timeToOOM = netDrain > 0 and (mana / netDrain) or 9999
    if row.score > bestScore then bestScore = row.score end
  end

  if bestScore <= 0 then bestScore = 1 end
  local questPriorBase = TA_GetGuideTopQuestXPPerHour()
  if questPriorBase <= 0 then
    questPriorBase = math.max(300, (UnitLevel("player") or 1) * 220)
  end

  for i = 1, #options do
    local row = options[i]
    local scoreRatio = math.max(0.35, (row.score or 0) / bestScore)
    local priorGrind = math.max(150, (row.score or 0) * (c.grindScale or 240))
    local priorQuest = math.max(150, questPriorBase * (0.86 + (0.24 * scoreRatio)))
    row.predGrindXPH = TA_BlendObservedRate(m.grindXPH, m.grindSamples, priorGrind, c.priorWeight)
    row.predQuestXPH = TA_BlendObservedRate(m.questXPH, m.questSamples, priorQuest, c.priorWeight)
    row.predBlendXPH = (row.predGrindXPH * (1 - effectiveQuestWeight)) + (row.predQuestXPH * effectiveQuestWeight)
    if (not best) or row.predBlendXPH > best.predBlendXPH then
      best = row
    end
  end

  AddLine("playerCombat", string.format("ML XP recommendation (%s): %s", classLabel, best.label))
  AddLine("system", string.format("XP score model: higher is better (weight %.2f, mana %.1f%%, regen %.2f/s)", effectiveWeight, manaPct, regen))
  AddLine("system", string.format("XP mode: %s (effective quest weight %.2f)", mode or "balanced", effectiveQuestWeight or 0.55))
  local scoreParts = {}
  for i = 1, #options do
    scoreParts[#scoreParts + 1] = string.format("%s %.2f", options[i].label, options[i].score or 0)
  end
  AddLine("system", "Scores: " .. table.concat(scoreParts, " | "))
  AddLine("system", string.format("Predicted XP/hour: grind %.0f | quest %.0f | blend %.0f", best.predGrindXPH or 0, best.predQuestXPH or 0, best.predBlendXPH or 0))
  if explain then
    local questConf = (m.questSamples or 0) / math.max(1, (m.questSamples or 0) + (c.priorWeight or 8))
    local grindConf = (m.grindSamples or 0) / math.max(1, (m.grindSamples or 0) + (c.priorWeight or 8))
    AddLine("system", string.format("  source model: grind %.0f/h (%d samples, conf %.0f%%), quest %.0f/h (%d samples, conf %.0f%%)", m.grindXPH or 0, m.grindSamples or 0, grindConf * 100, m.questXPH or 0, m.questSamples or 0, questConf * 100))
    AddLine("system", string.format("  priors: quest base %.0f/h, mode %s, effective quest weight %.2f (base %.2f)", questPriorBase, mode or "balanced", effectiveQuestWeight or 0.55, c.questWeight or 0.55))
    for i = 1, #options do
      local row = options[i]
      AddLine("system", string.format("  %s: dps %.2f, mana/s %.3f, net drain/s %.3f, downtime ratio %.2f, oom %.0fs, grind %.0f/h, quest %.0f/h, blend %.0f/h", row.label, row.dps or 0, row.manaPerSec or 0, row.netDrain or 0, row.downtimeRatio or 0, row.timeToOOM or 0, row.predGrindXPH or 0, row.predQuestXPH or 0, row.predBlendXPH or 0))
    end
    if classToken == "PALADIN" then
      AddLine("system", string.format("  knobs: weight %.2f, sealpct %.3f, judgepct %.3f, sealcycle %.1fs, socmult %.2f, questweight %.2f, priorweight %.1f, grindscale %.1f", c.weight, c.sealManaPct, c.judgeManaPct, c.sealCycleSec, c.socManaMult, c.questWeight or 0.55, c.priorWeight or 8, c.grindScale or 240))
      AddLine("system", "  tune: ml xp set <weight|sealpct|judgepct|sealcycle|socmult|questweight|priorweight|grindscale> <value>")
    elseif classToken == "WARRIOR" then
      AddLine("system", string.format("  knobs: weight %.2f, warrioropppm %.2f, warriordodge %.3f, warriorglance %.3f, warriorglancedmg %.3f, warriornorm %.2f, questweight %.2f, priorweight %.1f, grindscale %.1f", c.weight, c.warriorOverpowerPerMin, c.warriorDodgeChance, c.warriorGlancingChance, c.warriorGlancingDamage, c.warriorNormalization, c.questWeight or 0.55, c.priorWeight or 8, c.grindScale or 240))
      AddLine("system", string.format("  talents: warriorimphs %d, warriorimprend %d, warriorimpop %d, warriorimpslam %d, warriordeepwounds %d, warriorimpale %d, warriorwwtargets %d", c.warriorImpHSRank or 0, c.warriorImpRendRank or 0, c.warriorImpOverpowerRank or 0, c.warriorImpSlamRank or 0, c.warriorDeepWoundsRank or 0, c.warriorImpaleRank or 0, c.warriorWhirlwindTargets or 1))
      AddLine("system", "  tune: ml xp set <weight|warriorimphs|warriorimprend|warriorimpop|warriorimpslam|warriordeepwounds|warriorimpale|warrioropppm|warriordodge|warriorglance|warriorglancedmg|warriornorm|warriorwwtargets|questweight|priorweight|grindscale> <value>")
    end
  end
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

TA.QUALITY_NAMES = TA.QUALITY_NAMES or { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" }

TA.STAT_LABELS = TA.STAT_LABELS or {
  ITEM_MOD_STAMINA_SHORT            = "Stamina",
  ITEM_MOD_STRENGTH_SHORT           = "Strength",
  ITEM_MOD_AGILITY_SHORT            = "Agility",
  ITEM_MOD_INTELLECT_SHORT          = "Intellect",
  ITEM_MOD_SPIRIT_SHORT             = "Spirit",
  ITEM_MOD_SPELL_POWER              = "Spell Power",
  ITEM_MOD_HEALING_POWER            = "Healing Power",
  ITEM_MOD_SPELL_HIT_RATING         = "Spell Hit",
  ITEM_MOD_SPELL_CRIT_RATING        = "Spell Crit",
  ITEM_MOD_HIT_RATING               = "Hit",
  ITEM_MOD_CRIT_RATING              = "Crit",
  ITEM_MOD_DODGE_RATING             = "Dodge",
  ITEM_MOD_PARRY_RATING             = "Parry",
  ITEM_MOD_BLOCK_RATING             = "Block Rating",
  ITEM_MOD_BLOCK_VALUE              = "Block Value",
  ITEM_MOD_DEFENSE_SKILL_RATING     = "Defense",
  ITEM_MOD_ATTACK_POWER             = "Attack Power",
  ITEM_MOD_RANGED_ATTACK_POWER      = "Ranged AP",
  ITEM_MOD_FERAL_ATTACK_POWER       = "Feral AP",
  ITEM_MOD_ARMOR_PENETRATION_RATING = "Armor Pen",
  ITEM_MOD_RESILIENCE_RATING        = "Resilience",
  ITEM_MOD_HASTE_RATING             = "Haste",
  ITEM_MOD_EXPERTISE_RATING         = "Expertise",
  ITEM_MOD_MANA_REGENERATION        = "MP5",
  ITEM_MOD_HEALTH_REGEN             = "HP5",
}

local function ReportEquipment()
  local qualityNames = TA.QUALITY_NAMES or {}
  for _, entry in ipairs(EQUIP_SLOTS) do
    local slotId, label = entry[1], entry[2]
    local link = GetInventoryItemLink("player", slotId)
    if not link then
      AddLine("target", string.format("%s: Empty", label))
    else
      -- Basic info
      local name = link
      local quality
      local itemLevel
      local className
      local subClassName
      local sellPrice
      if GetItemInfo then
        local itemName, _, itemQuality, itemItemLevel, _, itemClassName, itemSubClassName, _, _, _, itemSellPrice = GetItemInfo(link)
        name = itemName or link
        quality = itemQuality
        itemLevel = itemItemLevel
        className = itemClassName
        subClassName = itemSubClassName
        sellPrice = itemSellPrice
      end
      local qualityStr = quality and (qualityNames[quality + 1] or tostring(quality)) or "?"
      local ilvlStr = (itemLevel and itemLevel > 0) and ("ilvl " .. itemLevel) or ""
      local typeStr = className or ""
      if subClassName and subClassName ~= "" and subClassName ~= className then
        typeStr = typeStr .. " - " .. subClassName
      end
      local headerParts = { qualityStr }
      if ilvlStr ~= "" then table.insert(headerParts, ilvlStr) end
      if typeStr ~= "" then table.insert(headerParts, typeStr) end
      AddLine("target", string.format("%s: %s [%s]", label, link, table.concat(headerParts, ", ")))

      -- Stats via GetItemStats
      local statsTable = {}
      if GetItemStats and link then
        GetItemStats(link, statsTable)
      end
      local statLines = {}
      for k, v in pairs(statsTable) do
        local friendlyName = (TA.STAT_LABELS and TA.STAT_LABELS[k]) or k
        table.insert(statLines, string.format("%s +%s", friendlyName, tostring(v)))
      end
      if #statLines > 0 then
        table.sort(statLines)
        AddLine("system", "  Stats: " .. table.concat(statLines, ", "))
      end

      -- Armor value (from stats table)
      local rawArmor = statsTable["RESISTANCE0_NAME"] or statsTable["ITEM_MOD_ARMOR"]
      if rawArmor and tonumber(rawArmor) and tonumber(rawArmor) > 0 then
        AddLine("system", string.format("  Armor: %d", tonumber(rawArmor)))
      end

      -- Durability
      if GetInventoryItemDurability then
        local curDur, maxDur = GetInventoryItemDurability(slotId)
        if maxDur and maxDur > 0 then
          AddLine("system", string.format("  Durability: %d / %d", curDur or 0, maxDur))
        end
      end

      -- Sell value
      if sellPrice and sellPrice > 0 then
        AddLine("system", string.format("  Sell value: %s", FormatMoney(sellPrice)))
      end
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

local function ReportBank()
  if not (BankFrame and BankFrame:IsShown()) then
    AddLine("system", "You must be at a banker with the bank window open to view bank contents.")
    return
  end

  local totalItems = 0

  -- Main 28 bank slots (bag index -1)
  local mainSlots = C_Container.GetContainerNumSlots(-1) or 28
  local mainItems = 0
  for slot = 1, mainSlots do
    local info = C_Container.GetContainerItemInfo(-1, slot)
    if info then
      AddLine("loot", string.format("Bank slot %d: %s x%d", slot, info.hyperlink or ("item:" .. tostring(info.itemID or "?")), info.stackCount or 1))
      mainItems = mainItems + 1
      totalItems = totalItems + 1
    end
  end
  if mainItems == 0 then
    AddLine("system", "Bank main slots: empty.")
  end

  -- Bank bag slots (indices 5–11)
  for bag = 5, 11 do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    if numSlots > 0 then
      local bagItems = 0
      for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
          AddLine("loot", string.format("Bank bag %d slot %d: %s x%d", bag - 4, slot, info.hyperlink or ("item:" .. tostring(info.itemID or "?")), info.stackCount or 1))
          bagItems = bagItems + 1
          totalItems = totalItems + 1
        end
      end
      if bagItems == 0 then
        AddLine("system", string.format("Bank bag %d: empty (%d slots).", bag - 4, numSlots))
      end
    end
  end

  AddLine("system", string.format("Bank total: %d item stack(s).", totalItems))
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

local function ReportActionBars(fromSlot, toSlot)
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
    -- TargetNearestEnemy() does not pick up corpses in Classic Era. Instead,
    -- use our tracked dfModeCorpseContacts list and target the closest one
    -- by name via TargetUnit. Falls back to TargetNearestEnemy(true) if we
    -- have no recent corpse contacts (some private servers do honor it).
    local now = (GetTime and GetTime()) or 0
    local px, py
    if UnitPosition then px, py = UnitPosition("player") end
    local bestName, bestDist
    for _, c in pairs(TA.dfModeCorpseContacts or {}) do
      if type(c) == "table" and c.name and c.expiresAt and c.expiresAt > now then
        local d
        if px and py and c.worldX and c.worldY then
          local dx = c.worldX - px
          local dy = c.worldY - py
          d = (dx * dx) + (dy * dy)
        else
          d = math.huge
        end
        if not bestDist or d < bestDist then
          bestDist = d
          bestName = c.name
        end
      end
    end
    if bestName and TargetUnit then
      TargetUnit(bestName)
      AddLine("target", "You attempt to target the corpse of " .. bestName .. ".")
    elseif TargetNearestEnemy then
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
  -- Prime every page so GetMerchantItemInfo returns full data for items past
  -- page 1. Without this the immersive (hidden MerchantFrame) mode lists
  -- nothing but the first page's items.
  if TA_PrimeMerchantPageForIndex then
    local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
    for p = 1, math.ceil(num / perPage) do
      TA_PrimeMerchantPageForIndex(((p - 1) * perPage) + 1)
    end
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
  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "You cannot sell items while in combat.")
    return
  end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Container.UseContainerItem) then
    AddLine("system", "Container API unavailable.")
    return
  end

  if TA.sellJunkState and TA.sellJunkState.active then
    AddLine("system", "selljunk is already in progress.")
    return
  end

  local queue = {}
  local queuedUnits = 0
  local estimatedValue = 0
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
          table.insert(queue, {
            bag = bag,
            slot = slot,
            itemRef = itemRef,
            stackCount = stackCount,
          })
          queuedUnits = queuedUnits + stackCount
          estimatedValue = estimatedValue + ((tonumber(sellPrice) or 0) * stackCount)
        end
      end
    end
  end

  if #queue == 0 then
    AddLine("loot", "No junk-quality items found to sell.")
  else
    TA.sellJunkState = {
      active = true,
      queue = queue,
      index = 1,
      soldStacks = 0,
      soldUnits = 0,
      totalValue = 0,
      queuedStacks = #queue,
      queuedUnits = queuedUnits,
      estimatedValue = estimatedValue,
      waitingForBagUpdate = false,
      moneyChanged = false,
      lastActionAt = 0,
      warnedCombat = false,
    }
    AddLine("loot", string.format("Selling junk (%d stack(s), %d item(s), est. %s)...", #queue, queuedUnits, FormatMoney(estimatedValue)))
    TA_ProcessSellJunkQueue("start")
  end
end

function TA_ProcessSellJunkQueue(trigger)
  local state = TA.sellJunkState
  if not state or not state.active then
    return
  end

  if not TA.vendorOpen then
    AddLine("system", "Stopped selljunk: merchant window is no longer open.")
    TA.sellJunkState = nil
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    if not state.warnedCombat then
      AddLine("system", "Paused selljunk: you are in combat.")
      state.warnedCombat = true
    end
    return
  end
  state.warnedCombat = false

  local now = GetTime()
  if state.waitingForBagUpdate and trigger ~= "bagupdate" then
    if (now - (state.lastActionAt or 0)) < 0.40 then
      return
    end
    state.waitingForBagUpdate = false
  end

  while state.index <= #state.queue do
    local entry = state.queue[state.index]
    state.index = state.index + 1

    local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if info and (info.hyperlink or info.itemID) then
      local quality = info.quality
      local itemRef = info.hyperlink or info.itemID
      local stackCount = tonumber(info.stackCount) or tonumber(entry.stackCount) or 1
      local _, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemRef)
      if quality == nil then
        quality = itemQuality
      end
      if quality == 0 then
        C_Container.UseContainerItem(entry.bag, entry.slot)
        state.soldStacks = state.soldStacks + 1
        state.soldUnits = state.soldUnits + stackCount
        state.totalValue = state.totalValue + ((tonumber(sellPrice) or 0) * stackCount)
        state.waitingForBagUpdate = true
        state.lastActionAt = now
        C_Timer.After(0.45, function()
          TA_ProcessSellJunkQueue("timeout")
        end)
        return
      end
    end
  end

  AddLine("loot", string.format("Sold junk: %d/%d stack(s), %d item(s), estimated value %s.", state.soldStacks, state.queuedStacks, state.soldUnits, FormatMoney(state.totalValue)))
  if state.moneyChanged then
    ReportMoney()
  end
  TA.sellJunkState = nil
end

function TA:ReportXPStatusEvent()
  local level = UnitLevel("player") or 0
  local xp = UnitXP("player") or 0
  local xpMax = UnitXPMax("player") or 0
  local pct = xpMax > 0 and (xp / xpMax * 100) or 0
  local bucket = string.format("%d:%d", level, math.floor(pct / 5))
  if bucket ~= TA.lastXPStatusBucket then
    TA.lastXPStatusBucket = bucket
    ReportXP()
  end
end

function TA:ReportMoneyStatusEvent()
  local copper = GetMoney() or 0
  if copper == TA.lastMoneyCopper then
    return
  end
  TA.lastMoneyCopper = copper
  local sellState = TA.sellJunkState
  if sellState and sellState.active then
    sellState.moneyChanged = true
    return
  end
  ReportMoney()
end

-- In Classic Era the default MerchantFrame is paginated (10 items per page) and
-- only "primes" item data for the page that has been rendered at least once.
-- When immersive mode hides the MerchantFrame, pages beyond 1 are never
-- rendered, so GetMerchantItemInfo(i) returns nil and BuyMerchantItem(i, n)
-- silently fails for indexes 11+. We work around this by forcing
-- MerchantFrame.page to the page containing `index` and calling
-- MerchantFrame_Update so the client reads each slot at least once.
function TA_PrimeMerchantPageForIndex(index)
  index = tonumber(index)
  if not index or index < 1 then return end
  local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
  local page = math.floor((index - 1) / perPage) + 1
  if MerchantFrame and MerchantFrame_Update then
    local prevPage = MerchantFrame.page or 1
    if MerchantFrame.page ~= page then
      MerchantFrame.page = page
    end
    -- MerchantFrame_Update reads slot data for the current page even when the
    -- frame itself is not visible, which is enough to populate name/price for
    -- GetMerchantItemInfo and BuyMerchantItem.
    pcall(MerchantFrame_Update)
    -- Restore the page so the user's default UI (if they ever Esc to it) is
    -- not yanked around.
    if MerchantFrame.page ~= prevPage then
      MerchantFrame.page = prevPage
      pcall(MerchantFrame_Update)
    end
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

  -- Prime every page so name lookups succeed for items past page 1.
  if TA_PrimeMerchantPageForIndex then
    local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
    for p = 1, math.ceil(num / perPage) do
      TA_PrimeMerchantPageForIndex(((p - 1) * perPage) + 1)
    end
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

  if TA_PrimeMerchantPageForIndex then TA_PrimeMerchantPageForIndex(index) end
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

function TA_ReportBagItemDetails(bag, slot)
  bag = tonumber(bag)
  slot = tonumber(slot)
  if bag == nil or slot == nil then
    AddLine("system", "Usage: baginfo <bag> <slot>")
    return
  end
  if not (C_Container and C_Container.GetContainerItemInfo) then
    AddLine("system", "Bag API unavailable on this client.")
    return
  end

  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  local itemRef = info.hyperlink or info.itemID
  local name = info.itemName or (GetItemInfo and GetItemInfo(itemRef)) or tostring(itemRef or "item")
  local stackCount = tonumber(info.stackCount) or 1
  AddLine("loot", string.format("%s slot %d: %s x%d", BagLabel(bag), slot, tostring(name), stackCount))

  if itemRef and GetItemInfo then
    local _, _, quality, itemLevel, reqLevel, className, subClassName, _, equipLoc, _, sellPrice = GetItemInfo(itemRef)
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
  if not TA.bagInspectTooltip then
    TA.bagInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerBagInspectTooltip", UIParent, "GameTooltipTemplate")
  end
  local tip = TA.bagInspectTooltip
  if not tip or not tip.NumLines or not tip.GetName then
    return
  end

  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  if tip.SetBagItem then
    tip:SetBagItem(bag, slot)
  elseif itemRef and tip.SetHyperlink then
    tip:SetHyperlink(itemRef)
  else
    tip:Hide()
    return
  end

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
  if TA_PrimeMerchantPageForIndex then TA_PrimeMerchantPageForIndex(index) end
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

  if TA_PrimeMerchantPageForIndex then TA_PrimeMerchantPageForIndex(index) end
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
  -- exposes this via merchant sell slot â€” we instead sell by item link from bags.
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

-- INVSLOT 16 = MainHandSlot, 17 = SecondaryHandSlot (off-hand)
TA.WEAPON_SLOT_IDS = TA.WEAPON_SLOT_IDS or { mainhand = 16, offhand = 17, main = 16, off = 17, mh = 16, oh = 17 }

function TA_ApplyWeaponBuff(bag, slot, weaponSlotArg)
  local function Feedback(msg, ch) AddLine(ch or "system", msg) end

  if InCombatLockdown and InCombatLockdown() then
    Feedback("Cannot apply weapon buffs while in combat.")
    return
  end

  local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    Feedback(string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end
  local itemRef = info.hyperlink or tostring(info.itemID or "item")

  -- Guard against accidentally trying to equip non-consumables to weapon slots.
  if GetItemInfoInstant then
    local _, _, _, _, _, itemClassID = GetItemInfoInstant(info.hyperlink or info.itemID)
    local consumableClassID = LE_ITEM_CLASS_CONSUMABLE or 0
    if itemClassID ~= nil and itemClassID ~= consumableClassID then
      Feedback("That item is not a consumable weapon buff (stone/oil/poison).")
      return
    end
  end

  local targetSlotID = nil
  if weaponSlotArg then
    targetSlotID = TA.WEAPON_SLOT_IDS[weaponSlotArg:lower()]
    if not targetSlotID then
      Feedback(string.format("Unknown weapon slot '%s'. Use: mainhand, offhand, mh, oh.", weaponSlotArg))
      return
    end
  end

  -- Pick up the buff item from the bag onto the cursor.
  ClearCursor()
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  elseif PickupContainerItem then
    PickupContainerItem(bag, slot)
  else
    Feedback("Container pickup API unavailable.")
    return
  end

  local cursorType = GetCursorInfo and GetCursorInfo() or nil
  if cursorType ~= "item" then
    ClearCursor()
    Feedback(string.format("Could not pick up %s — may be on cooldown or already in use.", itemRef))
    return
  end

  if not targetSlotID then
    -- UseContainerItem opens a protected Blizzard dialog and cannot be called from addon code.
    ClearCursor()
    Feedback("Weapon slot required. Usage: wbuff <bag> <slot> mainhand|offhand", "error")
    return
  end

  -- Apply to the specified weapon slot via EquipCursorItem (safe outside combat).
  if EquipCursorItem then
    EquipCursorItem(targetSlotID)

    -- If the cursor still holds the same item, the use/apply attempt failed.
    local postCursorType = GetCursorInfo and GetCursorInfo() or nil
    if postCursorType == "item" then
      ClearCursor()
      Feedback("Could not apply that buff to the selected weapon slot.")
      return
    end

    local slotName = (targetSlotID == 16) and "Main Hand" or "Off Hand"
    Feedback(string.format("Applied %s to %s.", itemRef, slotName), "loot")
  else
    ClearCursor()
    Feedback("EquipCursorItem API unavailable.")
  end
end

function TA_ApplyWeaponBuffByQuery(query, weaponSlotArg)
  local itemName = (query or ""):match("^%s*(.-)%s*$")
  if itemName == "" then
    AddLine("system", "Usage: wbuff <item name> <mainhand|offhand>")
    return
  end
  if not weaponSlotArg then
    AddLine("system", "Usage: wbuff <item name> <mainhand|offhand>")
    return
  end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then
    AddLine("system", "Container API unavailable.")
    return
  end

  local queryLower = itemName:lower()
  local maxBag = tonumber(NUM_BAG_SLOTS) or 4
  local exactBag, exactSlot, partialBag, partialSlot = nil, nil, nil, nil

  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info then
        local name = info.itemName
        if not name and GetItemInfo then name = GetItemInfo(info.hyperlink or info.itemID) end
        if name then
          local nameLower = name:lower()
          if nameLower == queryLower then exactBag, exactSlot = bag, slot; break end
          if not partialBag and nameLower:find(queryLower, 1, true) then partialBag, partialSlot = bag, slot end
        end
      end
    end
    if exactBag then break end
  end

  local foundBag = exactBag or partialBag
  local foundSlot = exactSlot or partialSlot
  if foundBag then
    TA_ApplyWeaponBuff(foundBag, foundSlot, weaponSlotArg)
  else
    AddLine("system", string.format("No bag item matched '%s'.", itemName))
  end
end

local function SellBagItem(bag, slot)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "You cannot sell items while in combat.")
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
  local function TA_GetTrainerServiceNumAbilityReqCompat(serviceIndex)
    if not GetTrainerServiceNumAbilityReq then
      return 0
    end

    local ok, value = pcall(GetTrainerServiceNumAbilityReq, serviceIndex)
    if ok and tonumber(value) then
      return math.max(0, math.floor(tonumber(value) or 0))
    end

    ok, value = pcall(GetTrainerServiceNumAbilityReq)
    if ok and tonumber(value) then
      return math.max(0, math.floor(tonumber(value) or 0))
    end

    return 0
  end

  local function TA_GetTrainerServiceAbilityReqCompat(serviceIndex, reqIndex)
    if not GetTrainerServiceAbilityReq then
      return nil, nil
    end

    local ok, reqName, hasReq = pcall(GetTrainerServiceAbilityReq, serviceIndex, reqIndex)
    if ok then
      return reqName, hasReq
    end

    ok, reqName, hasReq = pcall(GetTrainerServiceAbilityReq, reqIndex)
    if ok then
      return reqName, hasReq
    end

    return nil, nil
  end

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
        local reqCount = TA_GetTrainerServiceNumAbilityReqCompat(i)
        local reqParts = {}
        for r = 1, reqCount do
          local reqName, hasReq = TA_GetTrainerServiceAbilityReqCompat(i, r)
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

local function TA_ReportRecipeDetails(index)
  index = tonumber(index)
  if not index or index < 1 then
    AddLine("system", "Usage: recipeinfo <index>")
    return
  end

  if GetNumTradeSkills and GetTradeSkillInfo then
    local total = tonumber(GetNumTradeSkills()) or 0
    if total <= 0 then
      AddLine("system", "No open trade skill window.")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, numAvailable = GetTradeSkillInfo(index)
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    AddLine("cast", string.format("Recipe [%d]: %s | Available: %s", index, name, tostring(numAvailable or 0)))

    if GetTradeSkillNumMade then
      local madeMin, madeMax = GetTradeSkillNumMade(index)
      if madeMin and madeMax and madeMax > 0 then
        if madeMin == madeMax then
          AddLine("cast", string.format("Produces: %d", madeMin))
        else
          AddLine("cast", string.format("Produces: %d-%d", madeMin, madeMax))
        end
      end
    end

    if GetTradeSkillNumReagents and GetTradeSkillReagentInfo then
      local reagentCount = tonumber(GetTradeSkillNumReagents(index)) or 0
      if reagentCount > 0 then
        AddLine("cast", "Reagents:")
        for r = 1, reagentCount do
          local reagentName, _, needed, owned = GetTradeSkillReagentInfo(index, r)
          if reagentName then
            AddLine("cast", string.format("  - %s x%d (you have %d)", reagentName, tonumber(needed) or 0, tonumber(owned) or 0))
          end
        end
      end
    end

    if GetTradeSkillTools then
      local tools = GetTradeSkillTools(index)
      if tools and tools ~= "" then
        AddLine("cast", "Tools: " .. tools)
      end
    end
    return
  end

  if GetNumCrafts and GetCraftInfo then
    local total = tonumber(GetNumCrafts()) or 0
    if total <= 0 then
      AddLine("system", "No open crafting window.")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, numAvailable = GetCraftInfo(index)
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    AddLine("cast", string.format("Recipe [%d]: %s | Available: %s", index, name, tostring(numAvailable or 0)))

    if GetCraftNumReagents and GetCraftReagentInfo then
      local reagentCount = tonumber(GetCraftNumReagents(index)) or 0
      if reagentCount > 0 then
        AddLine("cast", "Reagents:")
        for r = 1, reagentCount do
          local reagentName, _, needed, owned = GetCraftReagentInfo(index, r)
          if reagentName then
            AddLine("cast", string.format("  - %s x%d (you have %d)", reagentName, tonumber(needed) or 0, tonumber(owned) or 0))
          end
        end
      end
    end

    if GetCraftDescription then
      local desc = GetCraftDescription(index)
      if desc and desc ~= "" then
        AddLine("cast", "Description: " .. desc)
      end
    end
    return
  end

  AddLine("system", "Recipe API unavailable on this client.")
end

local function TA_ReportProfessionRecipes()
  if GetNumTradeSkills and GetTradeSkillInfo then
    local total = tonumber(GetNumTradeSkills()) or 0
    if total <= 0 then
      AddLine("system", "No open trade skill window.")
      return
    end

    local skillName = (GetTradeSkillLine and GetTradeSkillLine()) or "Trade Skill"
    AddLine("cast", string.format("%s recipes:", tostring(skillName)))
    local shown = 0
    for i = 1, total do
      local name, category, numAvailable = GetTradeSkillInfo(i)
      if name then
        if category == "header" then
          AddLine("cast", string.format("-- %s --", name))
        else
          AddLine("cast", string.format("[%d] %s | Available: %s", i, name, tostring(numAvailable or 0)))
          shown = shown + 1
        end
      end
    end
    if shown == 0 then
      AddLine("system", "No craftable recipes were found in this trade skill window.")
    else
      AddLine("system", "Use: recipeinfo <index> for reagent details.")
    end
    return
  end

  if GetNumCrafts and GetCraftInfo then
    local total = tonumber(GetNumCrafts()) or 0
    if total <= 0 then
      AddLine("system", "No open crafting window.")
      return
    end

    local skillName = (GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()) or "Crafting"
    AddLine("cast", string.format("%s recipes:", tostring(skillName)))
    local shown = 0
    for i = 1, total do
      local name, category, numAvailable = GetCraftInfo(i)
      if name then
        if category == "header" then
          AddLine("cast", string.format("-- %s --", name))
        else
          AddLine("cast", string.format("[%d] %s | Available: %s", i, name, tostring(numAvailable or 0)))
          shown = shown + 1
        end
      end
    end
    if shown == 0 then
      AddLine("system", "No craftable recipes were found in this crafting window.")
    else
      AddLine("system", "Use: recipeinfo <index> for reagent details.")
    end
    return
  end

  AddLine("system", "Recipe API unavailable. Open a profession window and try again.")
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
  -- Map-space Y increases downward on the map: +dy is south, -dy is north.
  if dy < 0 then vert = "north" elseif dy > 0 then vert = "south" end
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

local function TA_SetTickerProfile(profile)
  if profile == "performance" then
    TA.tickerIntervals.move = 0.05
    TA.tickerIntervals.nearby = 0.10
    TA.tickerIntervals.memory = 0.10
    TA.tickerIntervals.df = 0.10
    TA.tickerIntervals.warlockPrompt = 1.50
    TA.tickerIntervals.warriorPrompt = 1.50
  else
    TA.tickerIntervals.move = 0.2
    TA.tickerIntervals.nearby = 0.25
    TA.tickerIntervals.memory = 0.5
    TA.tickerIntervals.df = 0.15
    TA.tickerIntervals.warlockPrompt = 0.75
    TA.tickerIntervals.warriorPrompt = 0.75
  end
end

local function TA_ApplyPerformanceFrameSuppression()
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
  TA_SetTickerProfile("performance")
  if TA_RestartRuntimeTickers then TA_RestartRuntimeTickers() end
  TA_ApplyPerformanceFrameSuppression()
  AddLine("system", "Performance mode enabled: suppressed Blizzard frames and reduced ticker rates.")
end

function TA_DisablePerformanceMode()
  TA.performanceModeEnabled = false
  TA.performancePendingApply = false
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.performanceModeEnabled = false
  TA_SetTickerProfile("normal")
  if TA_RestartRuntimeTickers then TA_RestartRuntimeTickers() end
  TA_RestoreSuppressedFrames()
  AddLine("system", "Performance mode disabled: restored frame visibility and high-frequency ticker rates.")
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

local function TA_TryInteractDistance(unit, checkType)
  if not unit or not CheckInteractDistance then
    return false
  end
  -- This API can be protected in combat when execution is tainted.
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  local ok, result = pcall(CheckInteractDistance, unit, checkType)
  return ok and result or false
end

local function CollectNearbyUnitsWithPositions()
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
        
        -- Get distance estimate -- prefer exact world-position math (works at
        -- any range and is accurate to <1 yard). Fall back to interact-distance
        -- buckets when positions are unavailable. Fall back to "far" only when
        -- both methods fail. Previously CheckInteractDistance ran first and
        -- locked very-close units to 5 yards even when exact pos would have
        -- said 0.3, which propagated into clamped grid placement.
        local unitX, unitY = UnitPosition(unit)
        local distance = 0
        if unitX and unitY and playerX and playerY then
          local dx = unitX - playerX
          local dy = unitY - playerY
          distance = math.sqrt(dx*dx + dy*dy)
        elseif CheckInteractDistance then
          for i = 1, 4 do
            if TA_TryInteractDistance(unit, i) then
              distance = i * 5
              break
            end
          end
        end
        if distance == 0 and not (unitX and unitY and playerX and playerY) then
          distance = 50  -- assume far if we truly cannot measure
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

  local function GetNearbyUnitsWithPositions(forceRefresh)
    if not GetTime then
      return CollectNearbyUnitsWithPositions()
    end

    local now = GetTime()
    local refreshInterval = tonumber(TA.nearbyUnitsCacheInterval) or 0.15
    if refreshInterval < 0.1 then refreshInterval = 0.1 end
    if refreshInterval > 0.2 then refreshInterval = 0.2 end

    local hasCached = (type(TA.lastNearbyUnits) == "table") and (type(TA.nearbyUnitsCacheAt) == "number")
    if hasCached and not forceRefresh and (now - TA.nearbyUnitsCacheAt) < refreshInterval then
      return TA.lastNearbyUnits
    end

    local units = CollectNearbyUnitsWithPositions()
    TA.lastNearbyUnits = units
    TA.nearbyUnitsCacheAt = now
    return units
  end

local function TA_RecordDFLastKnownUnits(units, mapID)
  if not units or not mapID then return end
  local now = GetTime()
  local lastKnown = TA.dfModeLastKnownUnits or {}
  local function ingest(kind, list)
    for _, u in ipairs(list or {}) do
      if u and u.hasExactPos and u.worldX and u.worldY and u.guid then
        lastKnown[u.guid] = {
          guid = u.guid,
          name = u.name or "Unknown",
          kind = kind,
          mapID = mapID,
          worldX = u.worldX,
          worldY = u.worldY,
          seenAt = now,
          expiresAt = now + 30,
        }
      end
    end
  end
  ingest("hostile", units.hostile)
  ingest("neutral", units.neutral)
  ingest("friendly", units.friendly)
  TA.dfModeLastKnownUnits = lastKnown
end

local function TA_PruneDFLastKnownUnits(mapID)
  local now = GetTime()
  for key, u in pairs(TA.dfModeLastKnownUnits or {}) do
    if type(u) ~= "table" or not u.expiresAt or u.expiresAt <= now or (mapID and u.mapID and u.mapID ~= mapID) then
      TA.dfModeLastKnownUnits[key] = nil
    end
  end
end

TA_RecordDFCorpseFromGUID = function(guid, name, mapID)
  if not guid then return end
  local known = TA.dfModeLastKnownUnits and TA.dfModeLastKnownUnits[guid]
  if type(known) ~= "table" then return end
  if mapID and known.mapID and known.mapID ~= mapID then return end
  if not known.worldX or not known.worldY then return end

  local now = GetTime()
  local ttl = math.max(5, tonumber(TA.dfModeCorpseTTL) or 45)
  local corpses = TA.dfModeCorpseContacts or {}
  local key = "corpse:" .. tostring(guid)
  corpses[key] = {
    key = key,
    guid = guid,
    name = name or known.name or "Unknown",
    mapID = known.mapID or mapID,
    worldX = known.worldX,
    worldY = known.worldY,
    seenAt = now,
    expiresAt = now + ttl,
  }
  TA.dfModeCorpseContacts = corpses
end

local function TA_PruneDFCorpseContacts(mapID)
  local now = GetTime()
  for key, c in pairs(TA.dfModeCorpseContacts or {}) do
    if type(c) ~= "table" or not c.expiresAt or c.expiresAt <= now or (mapID and c.mapID and c.mapID ~= mapID) then
      TA.dfModeCorpseContacts[key] = nil
    end
  end
end

local function TA_GetLoadedTerrainData()
  local data = rawget(_G, "TextAdventurerTerrainData")
  if type(data) ~= "table" then
    return nil
  end
  if type(data.chunks) ~= "table" then
    return nil
  end
  return data
end

local function TA_GetTerrainChunkIndex(data)
  if not data then
    return nil
  end
  if type(data._chunkIndex) == "table" then
    return data._chunkIndex
  end

  local index = {}
  for i = 1, #data.chunks do
    local c = data.chunks[i]
    if type(c) == "table" and type(c.tile) == "table" and type(c.chunk) == "table" then
      local tx = tonumber(c.tile[1])
      local ty = tonumber(c.tile[2])
      local cx = tonumber(c.chunk[1])
      local cy = tonumber(c.chunk[2])
      if tx and ty and cx and cy then
        index[string.format("%d:%d:%d:%d", tx, ty, cx, cy)] = c
      end
    end
  end

  data._chunkIndex = index
  return index
end

local function TA_TerrainStatsFromGrid(grid)
  if type(grid) ~= "table" then
    return nil
  end
  local sum = 0
  local count = 0
  for y = 1, #grid do
    local row = grid[y]
    if type(row) == "table" then
      for x = 1, #row do
        local v = tonumber(row[x])
        if v then
          sum = sum + v
          count = count + 1
        end
      end
    end
  end
  if count <= 0 then
    return nil
  end
  return sum / count
end

local function TA_TerrainMaxFromGrid(grid)
  if type(grid) ~= "table" then
    return nil
  end
  local maxV = nil
  for y = 1, #grid do
    local row = grid[y]
    if type(row) == "table" then
      for x = 1, #row do
        local v = tonumber(row[x])
        if v and (maxV == nil or v > maxV) then
          maxV = v
        end
      end
    end
  end
  return maxV
end

local function TA_TerrainSampleFromGrid(grid, fx, fy)
  if type(grid) ~= "table" or #grid <= 0 then
    return nil
  end

  local height = #grid
  local width = 0
  for y = 1, height do
    local row = grid[y]
    if type(row) == "table" and #row > width then
      width = #row
    end
  end
  if width <= 0 then
    return nil
  end

  local xNorm = tonumber(fx) or 0
  local yNorm = tonumber(fy) or 0
  if xNorm < 0 then xNorm = 0 elseif xNorm > 1 then xNorm = 1 end
  if yNorm < 0 then yNorm = 0 elseif yNorm > 1 then yNorm = 1 end

  local gx = xNorm * (width - 1) + 1
  local gy = yNorm * (height - 1) + 1
  local x0 = math.floor(gx)
  local y0 = math.floor(gy)
  local x1 = math.min(width, x0 + 1)
  local y1 = math.min(height, y0 + 1)
  if x0 < 1 then x0 = 1 end
  if y0 < 1 then y0 = 1 end

  local tx = gx - x0
  local ty = gy - y0

  local function getCell(ix, iy)
    local row = grid[iy]
    if type(row) ~= "table" then
      return nil
    end
    return tonumber(row[ix])
  end

  local v00 = getCell(x0, y0)
  local v10 = getCell(x1, y0) or v00
  local v01 = getCell(x0, y1) or v00
  local v11 = getCell(x1, y1) or v10 or v01 or v00
  if not v00 then
    return nil
  end

  local top = v00 + (v10 - v00) * tx
  local bottom = v01 + (v11 - v01) * tx
  return top + (bottom - top) * ty
end

local function TA_BuildTerrainMarkerDensity(data, index)
  if not data or type(index) ~= "table" then
    return {}
  end
  if type(data._markerDensityByChunk) == "table" then
    return data._markerDensityByChunk
  end

  local markers = data.markers
  if type(markers) ~= "table" or #markers == 0 then
    data._markerDensityByChunk = {}
    return data._markerDensityByChunk
  end

  local ADT_TILE_SIZE = 1600 / 3
  local ADT_HALF = 32 * ADT_TILE_SIZE

  local function worldToChunkKey(wx, wy)
    if type(wx) ~= "number" or type(wy) ~= "number" then
      return nil
    end
    local rawTileX = (wx + ADT_HALF) / ADT_TILE_SIZE
    local rawTileY = (ADT_HALF - wy) / ADT_TILE_SIZE
    if rawTileX < 0 or rawTileX >= 64 or rawTileY < 0 or rawTileY >= 64 then
      return nil
    end

    local tx = math.floor(rawTileX)
    local ty = math.floor(rawTileY)
    local cx = math.floor((rawTileX - tx) * 16)
    local cy = math.floor((rawTileY - ty) * 16)
    if cx < 0 or cx > 15 or cy < 0 or cy > 15 then
      return nil
    end
    return string.format("%d:%d:%d:%d", tx, ty, cx, cy)
  end

  local transforms = {
    { name = "xy_centered", fn = function(a, b, c) return a, b end },
    { name = "yx_centered", fn = function(a, b, c) return b, a end },
    { name = "xz_centered", fn = function(a, b, c) return a, c end },
    { name = "yz_centered", fn = function(a, b, c) return b, c end },
    { name = "xy_shifted",  fn = function(a, b, c) return a - ADT_HALF, ADT_HALF - b end },
    { name = "yx_shifted",  fn = function(a, b, c) return b - ADT_HALF, ADT_HALF - a end },
    { name = "xz_shifted",  fn = function(a, b, c) return a - ADT_HALF, ADT_HALF - c end },
    { name = "yz_shifted",  fn = function(a, b, c) return b - ADT_HALF, ADT_HALF - c end },
  }

  local sampleCount = math.min(#markers, 1500)
  local best = nil
  for i = 1, #transforms do
    local t = transforms[i]
    local score = 0
    local mapped = 0
    for mIdx = 1, sampleCount do
      local m = markers[mIdx]
      if type(m) == "table" and type(m.pos) == "table" then
        local a = tonumber(m.pos[1])
        local b = tonumber(m.pos[2])
        local c = tonumber(m.pos[3])
        if a and b and c then
          local wx, wy = t.fn(a, b, c)
          local key = worldToChunkKey(wx, wy)
          if key then
            mapped = mapped + 1
            if index[key] then
              score = score + 1
            end
          end
        end
      end
    end
    if (not best) or score > best.score or (score == best.score and mapped > best.mapped) then
      best = { transform = t, score = score, mapped = mapped }
    end
  end

  local density = {}
  if not best or best.score <= 0 then
    data._markerDensityByChunk = density
    data._markerDensityTransform = best and best.transform and best.transform.name or "none"
    return density
  end

  data._markerDensityTransform = best.transform.name
  for i = 1, #markers do
    local m = markers[i]
    if type(m) == "table" and type(m.pos) == "table" then
      local a = tonumber(m.pos[1])
      local b = tonumber(m.pos[2])
      local c = tonumber(m.pos[3])
      if a and b and c then
        local wx, wy = best.transform.fn(a, b, c)
        local key = worldToChunkKey(wx, wy)
        if key and index[key] then
          local w = (m.kind == "wmo") and 2 or 1
          density[key] = (density[key] or 0) + w
        end
      end
    end
  end

  data._markerDensityByChunk = density
  return density
end

local function TA_GetTerrainContextAtWorldPos(posX, posY, preferredMode)
  if type(posX) ~= "number" or type(posY) ~= "number" then
    return nil
  end

  local data = TA_GetLoadedTerrainData()
  if not data then
    return nil
  end

  local index = TA_GetTerrainChunkIndex(data)
  if type(index) ~= "table" then
    return nil
  end

  local ADT_TILE_SIZE = 1600 / 3          -- 533.333... yards per tile
  local ADT_HALF = 32 * ADT_TILE_SIZE     -- 17066.666... yards to world center

  local function buildLookup(worldX, worldY, mode)
    local rawTileX = (worldX + ADT_HALF) / ADT_TILE_SIZE
    local rawTileY = (ADT_HALF - worldY) / ADT_TILE_SIZE

    local tileX = math.floor(rawTileX)
    local tileY = math.floor(rawTileY)
    local chunkPosX = (rawTileX - tileX) * 16
    local chunkPosY = (rawTileY - tileY) * 16
    local chunkX = math.floor(chunkPosX)
    local chunkY = math.floor(chunkPosY)
    local localX = chunkPosX - chunkX
    local localY = chunkPosY - chunkY

    tileX = math.max(0, math.min(63, tileX))
    tileY = math.max(0, math.min(63, tileY))
    chunkX = math.max(0, math.min(15, chunkX))
    chunkY = math.max(0, math.min(15, chunkY))
    if localX < 0 then localX = 0 elseif localX > 1 then localX = 1 end
    if localY < 0 then localY = 0 elseif localY > 1 then localY = 1 end

    local key = string.format("%d:%d:%d:%d", tileX, tileY, chunkX, chunkY)
    return {
      mode = mode,
      tileX = tileX,
      tileY = tileY,
      chunkX = chunkX,
      chunkY = chunkY,
      localX = localX,
      localY = localY,
      key = key,
      chunk = index[key],
    }
  end

  local lookup = nil
  if preferredMode == "xy" then
    lookup = buildLookup(posX, posY, "xy")
  elseif preferredMode == "yx" then
    lookup = buildLookup(posY, posX, "yx")
  else
    lookup = buildLookup(posX, posY, "xy")
    if not lookup.chunk then
      local swapped = buildLookup(posY, posX, "yx")
      if swapped.chunk then
        lookup = swapped
      end
    end
  end

  local chunk = lookup.chunk
  local markerDensity = TA_BuildTerrainMarkerDensity(data, index)
  local selected = chunk and { lookup.tileX, lookup.tileY, lookup.chunkX, lookup.chunkY } or nil
  local mapBounds = (type(data.mapBounds) == "table") and data.mapBounds or nil

  local inCompiledTileBounds = nil
  if mapBounds and type(mapBounds.tileMin) == "table" and type(mapBounds.tileMax) == "table" then
    local minTx = tonumber(mapBounds.tileMin[1])
    local minTy = tonumber(mapBounds.tileMin[2])
    local maxTx = tonumber(mapBounds.tileMax[1])
    local maxTy = tonumber(mapBounds.tileMax[2])
    if minTx and minTy and maxTx and maxTy then
      inCompiledTileBounds = (lookup.tileX >= minTx and lookup.tileX <= maxTx and lookup.tileY >= minTy and lookup.tileY <= maxTy)
    end
  end

  if not chunk or not selected then
    return {
      loaded = true,
      chunk = nil,
      tileX = lookup.tileX,
      tileY = lookup.tileY,
      chunkX = lookup.chunkX,
      chunkY = lookup.chunkY,
      lookupMode = lookup.mode,
      inCompiledTileBounds = inCompiledTileBounds,
      mapBounds = mapBounds,
      resolved = false,
    }
  end

  local sampledHeight = TA_TerrainSampleFromGrid(chunk.heights, lookup.localX, lookup.localY)
  local sampledSlope = TA_TerrainSampleFromGrid(chunk.slope, lookup.localX, lookup.localY)

  return {
    loaded = true,
    chunk = chunk,
    tileX = selected[1],
    tileY = selected[2],
    chunkX = selected[3],
    chunkY = selected[4],
    lookupMode = lookup.mode,
    inCompiledTileBounds = inCompiledTileBounds,
    mapBounds = mapBounds,
    resolved = true,
    hasWater = chunk.hasWater and true or false,
    obstacleCount = markerDensity[lookup.key] or 0,
    texture = chunk.texture,
    avgHeight = sampledHeight or TA_TerrainStatsFromGrid(chunk.heights),
    avgSlope = sampledSlope or TA_TerrainStatsFromGrid(chunk.slope),
    maxSlope = TA_TerrainMaxFromGrid(chunk.slope),
  }

end

local function TA_GetTerrainContextAtMapPos(mapX, mapY)
  -- mapX/mapY are zone-relative fractions; ignore them.
  -- Use UnitPosition for raw world coordinates to derive ADT tile indices.
  -- WoW ADT grid: 64x64 tiles, each 533.333... yards.
  -- tileX increases west→east (same direction as WoW posX, which increases east).
  -- tileY increases north→south (opposite to WoW posY, which increases north).
  local posX, posY = UnitPosition("player")
  if type(posX) ~= "number" or type(posY) ~= "number" then
    return nil
  end
  return TA_GetTerrainContextAtWorldPos(posX, posY)
end

local function TA_GetTerrainGlyph(terrain, referenceHeight, referenceSlope, forwardBias, distCells, localHeightBaseline, localSlopeBaseline, localSlopeRelief, localHeightRelief)
  if type(terrain) ~= "table" or not terrain.resolved then
    return "."
  end

  -- Focus: detect deadly drop hazards only, ignore rolling hills.
  -- Show: water, deadly drops (V), obstacles, else ignore.

  if terrain.hasWater then
    return "~"
  end

  local obstacleCount = tonumber(terrain.obstacleCount) or 0
  if obstacleCount >= 4 then return "#" end
  if obstacleCount >= 2 then return "X" end
  if obstacleCount >= 1 then return "+" end

  -- Check for deadly drop differences only.
  -- Anchor to player reference height for stability while moving.
  local height = tonumber(terrain.avgHeight)
  local baselineHeight = tonumber(referenceHeight)
  if baselineHeight == nil then baselineHeight = tonumber(localHeightBaseline) end
  if baselineHeight and height then
    local deltaHeight = height - baselineHeight
    local dist = tonumber(distCells) or 1
    local forward = tonumber(forwardBias) or 0
    local localDeltaHeight = nil
    local localRelief = tonumber(localHeightRelief) or 0
    if localHeightBaseline ~= nil then
      local localBaseline = tonumber(localHeightBaseline)
      if localBaseline ~= nil then
        localDeltaHeight = height - localBaseline
      end
    end
    if dist < 1 then dist = 1 end
    local gradePerCell = deltaHeight / dist

    -- Safety filter: ignore impossible near-field deltas caused by bad chunk
    -- samples or coordinate mismatches.
    if math.abs(deltaHeight) > 300 then
      return "."
    end

    -- Fall-risk focus: only render cliffs that are close enough to matter.
    if dist > 5 then
      return "."
    end

    -- Suppress side/back jitter; prioritize hazards in travel/front arc.
    if forward < 0 then
      return "."
    end

    -- Deadly drop: strict requirements to avoid false positives on fields.
    local localDropPass = true
    if localDeltaHeight ~= nil then
      localDropPass = localDeltaHeight <= -4
    end
    if deltaHeight <= -10 and gradePerCell <= -1.6 and localDropPass and localRelief >= 2.5 then
      return "V"
    end
  end

  -- Ignore everything else (rolling hills, small slopes, textures, etc)
  return "."

end

local function GetEntitySymbol(unit)
  if unit.class then
    local classLower = unit.class:sub(1, 1):lower()
    return classLower
  end
  return "?"
end

function TA_ClassifyStandingTerrain(terrain, localSlopeBaseline)
  if type(terrain) ~= "table" or not terrain.resolved then
    return nil, nil
  end

  if terrain.hasWater then
    return "Ground: waterline", "WATER"
  end

  local slope = tonumber(terrain.avgSlope) or 0
  local maxSlope = tonumber(terrain.maxSlope) or slope
  local baseline = tonumber(localSlopeBaseline)
  local slopeDelta = baseline and (slope - baseline) or 0

  if maxSlope >= 18 or (slope >= 13 and slopeDelta >= 1.8) then
    return "Ground: mountain face", "MTN"
  end
  if maxSlope >= 15 or (slope >= 10 and slopeDelta >= 1.1) then
    return "Ground: steep hillside", "STEEP"
  end
  if maxSlope >= 11 or slope >= 7 then
    return "Ground: rolling hills", "HILL"
  end
  return "Ground: mostly flat", "FLAT"
end

function TA_Clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

function TA_ColorLerp(a, b, t)
  local s = 1 - t
  return (a[1] * s) + (b[1] * t), (a[2] * s) + (b[2] * t), (a[3] * s) + (b[3] * t)
end

function TA_HeatToRGB(heat)
  local t = TA_Clamp01(tonumber(heat) or 0)
  local stops = {
    { 0.00, { 0.22, 0.52, 1.00 } }, -- blue
    { 0.33, { 0.20, 0.90, 0.42 } }, -- green
    { 0.66, { 0.98, 0.83, 0.20 } }, -- yellow
    { 1.00, { 1.00, 0.33, 0.18 } }, -- red
  }

  for i = 1, #stops - 1 do
    local lo = stops[i]
    local hi = stops[i + 1]
    if t <= hi[1] then
      local span = hi[1] - lo[1]
      local localT = span > 0 and ((t - lo[1]) / span) or 0
      return TA_ColorLerp(lo[2], hi[2], localT)
    end
  end

  local last = stops[#stops][2]
  return last[1], last[2], last[3]
end

function TA_ColorizeCellByHeat(cell, heat)
  if type(cell) ~= "string" or cell == "" then
    return cell
  end
  local r, g, b = TA_HeatToRGB(heat)
  return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), cell)
end

function TA_TerrainHeatFromContext(terrain, slopeRelief, heightRelief)
  if type(terrain) ~= "table" or not terrain.resolved then
    return 0
  end
  if terrain.hasWater then
    return 0.08
  end

  local avgSlope = tonumber(terrain.avgSlope) or 0
  local maxSlope = tonumber(terrain.maxSlope) or avgSlope
  local reliefSlope = tonumber(slopeRelief) or 0
  local reliefHeight = tonumber(heightRelief) or 0

  -- Use average slope + local relief as primary signals. Max-slope spikes are
  -- only used as excess over average so one outlier does not saturate all cells.
  local avgNorm = TA_Clamp01(avgSlope / 22.0)
  local spikeExcess = math.max(0, maxSlope - avgSlope)
  local spikeNorm = TA_Clamp01(spikeExcess / 14.0)
  local reliefNorm = TA_Clamp01(reliefSlope / 10.0)
  local verticalNorm = TA_Clamp01(reliefHeight / 20.0)

  local raw = (avgNorm * 0.50) + (spikeNorm * 0.20) + (reliefNorm * 0.20) + (verticalNorm * 0.10)
  -- Slightly compress the top-end so hills and mid-slopes retain distinct hues.
  local heat = raw ^ 1.2
  return TA_Clamp01(heat)
end

local function BuildDFModeDisplay()
  local mapID, _, _, x, y, continentX, continentY, continentID = GetPlayerMapCell()
  if not mapID then
    return "ERROR: Could not determine map position."
  end

  TA.dfModeTerrainContext = TA_GetTerrainContextAtMapPos()

  local gridSize = TA.dfModeGridSize or 21
  local radius = math.floor(gridSize / 2)
  -- innerRadius covers all display cells after rotation. In fixed orientation no rotation
  -- happens so we can save grid allocation by using radius directly.
  local orientation = TA.dfModeOrientation or "fixed"
  local rotationMode = TA.dfModeRotationMode or "smooth"
  local innerRadiusKey = gridSize * 2 + (orientation == "fixed" and 0 or 1)
  if TA.dfModeInnerRadiusGridSize ~= innerRadiusKey then
    TA.dfModeInnerRadius = (orientation == "fixed") and radius or math.ceil(radius * 1.45)
    TA.dfModeInnerRadiusGridSize = innerRadiusKey
  end
  local innerRadius = TA.dfModeInnerRadius or math.ceil(radius * 1.45)
  -- Each DF grid cell represents this many in-game yards. Must be a whole number
  -- so mark and unit positions map cleanly: N yards = exactly N/yardsPerCell cells.
  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  local calibrationEnabled = TA.dfModeCalibrationEnabled and true or false
  local viewMode = TA.dfModeViewMode or "threat"
  local profile = TA.dfModeProfile or "full"
  local balanced = (profile ~= "full")

  -- Get facing direction
  local facing = GetPlayerFacing() or 0
  local basePlayerWorldX, basePlayerWorldY = UnitPosition("player")
  local playerWorldX, playerWorldY = TA_GetProjectedDFPlayerWorldPosition(basePlayerWorldX, basePlayerWorldY)
  local now = GetTime()
  local facingDegrees = math.floor(math.deg(facing))
  TA.dfModeNavHint = nil

  -- Build the world grid at innerRadius so rotation never hits an out-of-bounds edge.
  -- Reuse scratch tables across builds: this avoids 2*(innerRadius*2+1)^2 table allocations per tick.
  TA._dfScratch = TA._dfScratch or {}
  local scratch = TA._dfScratch
  local grid = scratch.grid or {}
  local threatHeat = scratch.threatHeat or {}
  scratch.grid = grid
  scratch.threatHeat = threatHeat
  -- Resize if needed (grow only; shrinking is unnecessary for a steady grid size).
  for y = -innerRadius, innerRadius do
    local row = grid[y]; if not row then row = {}; grid[y] = row end
    local hrow = threatHeat[y]; if not hrow then hrow = {}; threatHeat[y] = hrow end
    for x = -innerRadius, innerRadius do
      row[x] = "."
      hrow[x] = 0
    end
  end

  -- Place player at center; use @ when standing inside a marked cell.
  grid[0][0] = (TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID) and "@" or "P"

  -- Get nearby units
  local units = GetNearbyUnitsWithPositions()
  TA_RecordDFLastKnownUnits(units, mapID)
  TA_PruneDFLastKnownUnits(mapID)
  TA_PruneDFCorpseContacts(mapID)

  -- Get target
  local targetName = UnitName("target")
  local targetUnit = targetName and "target" or nil
  local targetGUID = targetUnit and UnitGUID("target") or nil
  local targetPlaced = false
  local targetDistance = nil
  local targetDistanceExact = nil
  local targetDistanceApprox = nil
  local targetRenderedCellDist = nil
  local targetUsedFallback = false
  local glyphEnemy = "|cffff4040E|r"
  local glyphFriendly = "|cffb366ffF|r"
  local targetGlyphNear = "T"
  local targetGlyphMid = "t"
  local targetHostile = targetUnit and UnitCanAttack("player", "target") and true or false
  if targetHostile then
    targetGlyphNear = "|cffff4040T|r"
    targetGlyphMid = "|cffff4040t|r"
  end

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

    -- Reconciliation: if this unit IS the current target, render as target glyph
    -- so a single entity does not appear as both E and T in different cells.
    local isTarget = (targetGUID and unit.guid and unit.guid == targetGUID) and true or false
    if isTarget then
      symbol = targetGlyphNear
      if balanced and unit.distance and unit.distance > 14 then
        symbol = targetGlyphMid
      end
      -- Refresh the target's world position from the live API. The unit pool
      -- is cached for ~150ms; right after Charge/Intercept/teleport this
      -- caches stale coords and renders the target at the wrong cell. The
      -- player's current target is the one cell users notice, so refresh it.
      if UnitPosition then
        local lx, ly = UnitPosition("target")
        if lx and ly then
          unit.worldX = lx
          unit.worldY = ly
          unit.hasExactPos = true
          local dxLive = lx - (playerWorldX or 0)
          local dyLive = ly - (playerWorldY or 0)
          unit.distance = math.sqrt(dxLive * dxLive + dyLive * dyLive)
        end
      end
    end

    local dist = math.floor(unit.distance / yardsPerCell)
    if dist <= 0 then dist = 1 end
    if dist <= 0 then dist = 1 end
    if dist > innerRadius then dist = innerRadius end

    local x, y
    if unit.hasExactPos and unit.worldX and unit.worldY and playerWorldX and playerWorldY then
      -- WoW Classic UnitPosition returns (posY, posX) -- the first return is
      -- NORTH and the second is EAST. CollectNearbyUnitsWithPositions stores
      -- those into worldX/worldY without renaming, so the field "worldX" is
      -- actually NORTH and "worldY" is actually EAST. Map them to the grid
      -- correctly here.
      local north = unit.worldX - playerWorldX
      local east  = -(unit.worldY - playerWorldY)  -- WoW Classic east axis is negated relative to grid +x
      x = east  >= 0 and math.floor((east  / yardsPerCell) + 0.5) or math.ceil((east  / yardsPerCell) - 0.5)
      y = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
      if isTarget and TA.dfModeDebugTarget then
        local lpx, lpy = UnitPosition("player")
        local ltx, lty = UnitPosition("target")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
          "|cffff8800[TA-DBG]|r tgt=%s player(p)=(%.1f,%.1f) live(p)=(%.1f,%.1f) tgt(u)=(%.1f,%.1f) live(t)=(%.1f,%.1f) N=%.1f E=%.1f -> cell(%d,%d) ypc=%d",
          tostring(unit.name), playerWorldX, playerWorldY, lpx or 0, lpy or 0,
          unit.worldX, unit.worldY, ltx or 0, lty or 0, north, east, x, y, yardsPerCell))
      end
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

      -- For the player's current target specifically, the hash angle gives a
      -- random direction that often disagrees with where the player is looking.
      -- Override with the facing vector so the target glyph appears in front of
      -- the player rather than scattered (e.g. NW when facing E).
      if isTarget and facing then
        angle = math.atan2(math.cos(facing), -math.sin(facing))
      end

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
      if isTarget then
        -- Target glyph always wins; record placement so standalone target
        -- block can skip and we never render duplicate E/T cells.
        if grid[y][x] ~= "P" then
          grid[y][x] = symbol
        end
        targetPlaced = true
        targetDistance = unit.distance
        targetDistanceExact = unit.hasExactPos and unit.distance or nil
        targetDistanceApprox = (not unit.hasExactPos) and unit.distance or nil
        targetRenderedCellDist = math.sqrt((x * x) + (y * y))
        if unitType == "hostile" then
          threatHeat[y][x] = (threatHeat[y][x] or 0) + 1
        end
      elseif grid[y][x] == "." then
        grid[y][x] = symbol
      elseif grid[y][x] ~= "P" and grid[y][x] ~= symbol then
        grid[y][x] = "*"
      end
      if (not isTarget) and unitType == "hostile" then
        threatHeat[y][x] = (threatHeat[y][x] or 0) + 1
      end
    end
  end

  -- Place units
  for _, unit in ipairs(units.hostile or {}) do
    PlaceUnitByDistance(unit, glyphEnemy, "hostile")
  end
  for _, unit in ipairs(units.neutral or {}) do
    PlaceUnitByDistance(unit, "N", "neutral")
  end
  for _, unit in ipairs(units.friendly or {}) do
    PlaceUnitByDistance(unit, glyphFriendly, "friendly")
  end

  -- Place target with near-visual emphasis in balanced mode.
  -- Skip when PlaceUnitByDistance already handled it (GUID-matched against nameplate pool).
  if targetUnit and not targetPlaced then
    if TA.dfModeDebugTarget then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[TA-DBG]|r entering standalone target block (no nameplate match)")
    end
    local tx, ty
    local playerX, playerY = playerWorldX, playerWorldY
    local targetX, targetY = nil, nil

    local targetGUID = UnitGUID("target")

    -- Always prefer LIVE UnitPosition("target") over the cached unit pool.
    -- The pool is only refreshed every nearbyUnitsCacheInterval (~150ms), so
    -- after a Charge/Intercept/Death-Grip the cached worldX/worldY still
    -- reflect the pre-teleport position. Subtracting the new player position
    -- produces a huge bogus delta that pins the target to the grid edge.
    targetX, targetY = UnitPosition("target")

    -- Cache fallback: only use stored position if live UnitPosition failed.
    if (not targetX or not targetY) and targetGUID then
      local pools = { units.hostile or {}, units.neutral or {}, units.friendly or {} }
      for i = 1, #pools do
        local pool = pools[i]
        for j = 1, #pool do
          local u = pool[j]
          if u and u.guid == targetGUID and u.hasExactPos and u.worldX and u.worldY then
            targetX, targetY = u.worldX, u.worldY
            break
          end
        end
        if targetX and targetY then break end
      end
    end

    if playerX and playerY and targetX and targetY then
      -- Same UnitPosition axis swap as PlaceUnitByDistance: first return is
      -- NORTH, second is EAST. The variables are mis-named upstream but the
      -- math here treats the deltas as their true world axes.
      local north = targetX - playerX
      local east  = -(targetY - playerY)  -- WoW Classic east axis is negated relative to grid +x
      targetDistance = math.sqrt(north * north + east * east)
      targetDistanceExact = targetDistance
      tx = east  >= 0 and math.floor((east  / yardsPerCell) + 0.5) or math.ceil((east  / yardsPerCell) - 0.5)
      ty = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
      if TA.dfModeDebugTarget then
        local lpx, lpy = UnitPosition("player")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
          "|cffff8800[TA-DBG-S]|r player(p)=(%.1f,%.1f) live(p)=(%.1f,%.1f) tgt=(%.1f,%.1f) N=%.1f E=%.1f cell(%d,%d) ypc=%d",
          playerX, playerY, lpx or 0, lpy or 0, targetX, targetY, north, east, tx, ty, yardsPerCell))
      end
    else
      targetUsedFallback = true

      -- Determine actual distance before placement
      if CheckInteractDistance then
        if TA_TryInteractDistance("target", 1) then targetDistance = 10
        elseif TA_TryInteractDistance("target", 2) then targetDistance = 11
        elseif TA_TryInteractDistance("target", 3) then targetDistance = 28
        elseif TA_TryInteractDistance("target", 4) then targetDistance = 30
        end
        targetDistanceApprox = targetDistance
      end

      -- Without exact world coords, best guess is the direction the player is
      -- looking (you almost always face what you target). Place the glyph in
      -- front of P along the facing vector at the measured distance.
      -- Previously this used a hash of the target name to pick a random angle,
      -- which scattered targets to incorrect quadrants like NW when facing E.
      local cellDist = targetDistance and math.floor(targetDistance / yardsPerCell + 0.5) or 2
      if cellDist < 1 then cellDist = 1 end
      local forwardX = -math.sin(facing or 0)  -- east component of facing
      local forwardY = math.cos(facing or 0)   -- north component of facing
      tx = math.floor((forwardX * cellDist) + 0.5)
      ty = math.floor((forwardY * cellDist) + 0.5)
      if tx == 0 and ty == 0 then ty = 1 end
    end

    if tx and ty then
      -- Track whether we had to clamp the target into the visible grid. When
      -- the target is far enough that its real position lands beyond the
      -- innerRadius edge, we still want to show it -- but pin it to the edge
      -- so the user understands "this thing is past the edge of my map".
      local clampedToEdge = false
      if tx > innerRadius then tx = innerRadius; clampedToEdge = true end
      if tx < -innerRadius then tx = -innerRadius; clampedToEdge = true end
      if ty > innerRadius then ty = innerRadius; clampedToEdge = true end
      if ty < -innerRadius then ty = -innerRadius; clampedToEdge = true end
      targetRenderedCellDist = math.sqrt((tx * tx) + (ty * ty))

      if tx == 0 and ty == 0 then
        tx = math.floor((-math.sin(facing)) + 0.5)
        ty = math.floor((math.cos(facing)) + 0.5)
        if tx == 0 and ty == 0 then tx = 1 end
        targetRenderedCellDist = math.sqrt((tx * tx) + (ty * ty))
      end

      if math.abs(tx) <= innerRadius and math.abs(ty) <= innerRadius and grid[ty] and grid[ty][tx] ~= "P" then
        local targetGlyph = targetGlyphNear
        if balanced and targetDistance and targetDistance > 14 then targetGlyph = targetGlyphMid end
        if clampedToEdge then targetGlyph = targetGlyphMid end
        grid[ty][tx] = targetGlyph
      end
    end
  end

  -- Place marked cells last so marks stay visible over other map symbols.
  local markRadius = math.floor(tonumber(TA.dfModeMarkRadius) or 0)
  local maxMarkRadius = math.floor((TA.dfModeGridSize or 35) / 2)
  local markEdgeGlyph = "|cff33ff66o|r"
  local markCenterGlyph = "|cff33ff66M|r"
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
      -- Per-axis cell size in yards = mapWorldYards / gridDimension. We use
      -- GetMapWorldDimensions (corner-sampled, cached) so the perimeter
      -- reflects the cell's true rectangular footprint instead of assuming a
      -- square markCellYards x markCellYards box.
      local markCellYardsX = markCellYards
      local markCellYardsY = markCellYards
      local markMapW, markMapH = GetMapWorldDimensions(mark.mapID)
      if markMapW and markMapH and markGridX > 0 and markGridY > 0 then
        markCellYardsX = markMapW / markGridX
        markCellYardsY = markMapH / markGridY
      end
      dx_yards = (markCenterX - playerPosX) * markCellYardsX
      -- Map-space Y grows southward; DF-space Y grows northward.
      dy_yards = (playerPosY - markCenterY) * markCellYardsY

      -- Units are placed relative to the SNAPPED player world position (see
      -- TA_GetProjectedDFPlayerWorldPosition), but dx_yards/dy_yards above are
      -- relative to the player's TRUE map position. Shift by the snap delta so
      -- marks share the same sub-cell frame as units; otherwise a mark sitting
      -- on the same world cell as the player/target/friendly/enemy can render
      -- one cell off and look like it "moved" that glyph.
      local snapDeltaEast = (basePlayerWorldX or 0) - (playerWorldX or 0)
      local snapDeltaNorth = (basePlayerWorldY or 0) - (playerWorldY or 0)
      local markDist = math.sqrt((dx_yards * dx_yards) + (dy_yards * dy_yards))
      local east = dx_yards + snapDeltaEast
      local north = dy_yards + snapDeltaNorth
      local mx = east >= 0 and math.floor((east / yardsPerCell) + 0.5) or math.ceil((east / yardsPerCell) - 0.5)
      local my = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)

      if nearestMarkDist == nil or markDist < nearestMarkDist then
        nearestMarkDist = markDist
        nearestMarkID = mark.id or -1
        nearestMarkName = mark.name or "Unnamed"
        nearestMarkMX = mx
        nearestMarkMY = my
      end

      if math.abs(mx) <= innerRadius and math.abs(my) <= innerRadius then
        local exMin, exMax, eyMin, eyMax
        if orientation == "fixed" then
          -- Fixed orientation: marked cell is axis-aligned with the DF grid.
          -- The DF renderer prints each column as 2 chars (glyph + space) but
          -- each row as 1 char tall, so a visually-square rectangle needs
          -- ~half as many columns as rows. We force ODD counts so the M is
          -- perfectly centered with equal cells on each side.
          local rowsPerSide = math.max(1, math.floor((markCellYards / yardsPerCell) + 0.5))
          local extra = markRadius or 0
          rowsPerSide = rowsPerSide + (extra * 2)
          if rowsPerSide % 2 == 0 then rowsPerSide = rowsPerSide + 1 end
          local colsPerSide = math.max(1, math.floor((rowsPerSide / 2) + 0.5))
          if colsPerSide % 2 == 0 then colsPerSide = colsPerSide + 1 end
          local halfRow = (rowsPerSide - 1) / 2
          local halfCol = (colsPerSide - 1) / 2
          exMin = mx - halfCol
          exMax = mx + halfCol
          eyMin = my - halfRow + 2  -- shift south edge up by 2 cells to match in-game yard scale
          eyMax = my + halfRow - 2  -- shift north edge down by 2 cells to match in-game yard scale
        elseif markCellYardsX > 0 and markCellYardsY > 0 then
          -- Rotating orientation: the marked cell is no longer aligned with
          -- the screen, so we have to project from yard-space and snap each
          -- edge independently to the rotated DF grid.
          local halfYardsX = (markCellYardsX * 0.5) + (markRadius * yardsPerCell)
          local halfYardsY = (markCellYardsY * 0.5) + (markRadius * yardsPerCell)
          local halfYardsLeft  = halfYardsX
          local halfYardsRight = halfYardsX
          local halfYardsSouth = halfYardsY
          local halfYardsNorth = halfYardsY
          local function SnapToCell(yards)
            if yards >= 0 then return math.floor((yards / yardsPerCell) + 0.5) end
            return math.ceil((yards / yardsPerCell) - 0.5)
          end
          exMin = SnapToCell(east  - halfYardsLeft)
          exMax = SnapToCell(east  + halfYardsRight)
          eyMin = SnapToCell(north - halfYardsSouth)
          eyMax = SnapToCell(north + halfYardsNorth)
        end
        if exMin and exMax and eyMin and eyMax then
          for ey = eyMin, eyMax do
            for ex = exMin, exMax do
              if ex == exMin or ex == exMax or ey == eyMin or ey == eyMax then
                if math.abs(ex) <= innerRadius and math.abs(ey) <= innerRadius and grid[ey] and grid[ey][ex] then
                  -- Only draw edge on empty cells so entities are never overwritten.
                  if grid[ey][ex] == "." then
                    grid[ey][ex] = markEdgeGlyph
                  end
                end
              end
            end
          end
        end

        if grid[my] and grid[my][mx] then
          local current = grid[my][mx]
          if current ~= "P" and current ~= "@" and current ~= "T" and current ~= "t" and current ~= targetGlyphNear and current ~= targetGlyphMid then
            grid[my][mx] = markCenterGlyph
          end
        end
      end
    end
  end

  -- Quest route marker overlay: show the best suggested next-quest origin as Q.
  if TA_GetQuestRouterStore and TA_BuildQuestRouteCandidates then
    local qstore = TA_GetQuestRouterStore()
    if qstore and qstore.enabled ~= false then
      local overlay = TA.questRouteOverlay
      if overlay and overlay.mapID == mapID and overlay.dxCells and overlay.dyCells then
        local qx = overlay.dxCells >= 0 and math.floor(overlay.dxCells + 0.5) or math.ceil(overlay.dxCells - 0.5)
        local qy = overlay.dyCells >= 0 and math.floor(overlay.dyCells + 0.5) or math.ceil(overlay.dyCells - 0.5)
        if qx > innerRadius then qx = innerRadius end
        if qx < -innerRadius then qx = -innerRadius end
        if qy > innerRadius then qy = innerRadius end
        if qy < -innerRadius then qy = -innerRadius end
        if grid[qy] and grid[qy][qx] and grid[qy][qx] == "." then
          grid[qy][qx] = "Q"
        elseif grid[qy] and grid[qy][qx] and grid[qy][qx] ~= "P" and grid[qy][qx] ~= "@" then
          grid[qy][qx] = "*"
        end
      end
    end
  end

  -- DFDanger integration: lightweight hazard overlay layer for known cliff/elevator anchors.
  if DFDanger and DFDanger.enabled and DFDanger.AddHazardOverlayToMap then
    local overlayContext = {
      zone = GetZoneText and (GetZoneText() or "") or "",
      mapID = mapID,
      playerX = x,
      playerY = y,
      innerRadius = innerRadius,
      yardsPerCell = yardsPerCell,
      playerFacing = facing,
    }
    local okDangerOverlay = pcall(function()
      DFDanger:AddHazardOverlayToMap(grid, overlayContext)
    end)
    if not okDangerOverlay then
      -- Keep DF rendering resilient if danger overlay has transient errors.
    end
  end

  -- Corpse overlay: recently killed units at their last known exact position.
  for _, c in pairs(TA.dfModeCorpseContacts or {}) do
    if c and c.mapID == mapID and c.worldX and c.worldY and playerWorldX and playerWorldY and c.expiresAt and c.expiresAt > now then
      local dx_yards = c.worldX - playerWorldX
      local dy_yards = c.worldY - playerWorldY
      local east = dx_yards
      local north = dy_yards
      local cx = east >= 0 and math.floor((east / yardsPerCell) + 0.5) or math.ceil((east / yardsPerCell) - 0.5)
      local cy = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
      if math.abs(cx) <= innerRadius and math.abs(cy) <= innerRadius and grid[cy] and grid[cy][cx] and grid[cy][cx] == "." then
        grid[cy][cx] = "|cffb0b0b0x|r"
      end
    end
  end

  -- Build output: grid rows only, no header or footer
  local lines = {}
  local navRotationAngle = facing
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
  local forwardX = -math.sin(facing)
  local forwardY = math.cos(facing)
  local centerTerrainHeight = TA.dfModeTerrainContext and TA.dfModeTerrainContext.avgHeight or nil
  local centerTerrainSlope = TA.dfModeTerrainContext and TA.dfModeTerrainContext.avgSlope or nil
  local terrainLookupMode = TA.dfModeTerrainContext and TA.dfModeTerrainContext.lookupMode or nil

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
    TA.dfModeNavHint = nil
  end

  local terrainStats = {
    samples = 0,
    lookups = 0,
    resolved = 0,
    unresolved = 0,
    painted = 0,
    blocked = 0,
    noGlyph = 0,
    heatMin = nil,
    heatMax = nil,
    compared = 0,
    ignoredOutlier = 0,
    deltaMin = nil,
    deltaMax = nil,
    cliffDrops = 0,
  }
  -- Persistent terrain cache: TA_GetTerrainContextAtWorldPos is the single biggest cost in
  -- BuildDFModeDisplay. Cache it across DF builds, keyed by the snapped player cell + map +
  -- yards/cell + lookup mode. Wipe whenever the key changes (i.e. the player crosses a cell).
  local snappedPlayerCellX = (playerWorldX and yardsPerCell and yardsPerCell > 0) and math.floor(playerWorldX / yardsPerCell + 0.5) or 0
  local snappedPlayerCellY = (playerWorldY and yardsPerCell and yardsPerCell > 0) and math.floor(playerWorldY / yardsPerCell + 0.5) or 0
  local terrainCacheKey = string.format("%s:%s:%d:%d:%d", tostring(mapID or "?"), tostring(terrainLookupMode or "?"), snappedPlayerCellX, snappedPlayerCellY, math.floor(yardsPerCell or 0))
  if TA._dfTerrainCacheKey ~= terrainCacheKey then
    TA._dfTerrainCache = {}
    TA._dfTerrainCacheKey = terrainCacheKey
  end
  local terrainCache = TA._dfTerrainCache
  local gridDistanceCache = {}

  local function TA_GetGridDistance(x, y)
    local row = gridDistanceCache[y]
    if not row then
      row = {}
      gridDistanceCache[y] = row
    end
    local d = row[x]
    if not d then
      d = math.sqrt((x * x) + (y * y))
      row[x] = d
    end
    return d
  end

  local function TA_GetTerrainCellAtOffset(wx, wy)
    if not playerWorldX or not playerWorldY then
      return nil
    end
    local key = tostring(wx) .. ":" .. tostring(wy)
    if terrainCache[key] ~= nil then
      return terrainCache[key] ~= false and terrainCache[key] or nil
    end

    terrainStats.lookups = terrainStats.lookups + 1
    local sampleX = playerWorldX + (wx * yardsPerCell)
    local sampleY = playerWorldY + (wy * yardsPerCell)
    local terrainCell = TA_GetTerrainContextAtWorldPos(sampleX, sampleY, terrainLookupMode)
    terrainCache[key] = terrainCell or false
    return terrainCell
  end

  local function TA_IsSameTerrainChunk(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
      return false
    end
    return (a.tileX == b.tileX) and (a.tileY == b.tileY) and (a.chunkX == b.chunkX) and (a.chunkY == b.chunkY)
  end

  local function TA_GetLocalTerrainBaselines(wx, wy, anchorTerrainCell)
    local slopeSum = 0
    local heightSum = 0
    local count = 0
    local slopeMin, slopeMax = nil, nil
    local heightMin, heightMax = nil, nil
    for oy = -1, 1 do
      for ox = -1, 1 do
        if not (ox == 0 and oy == 0) then
          local n = TA_GetTerrainCellAtOffset(wx + ox, wy + oy)
          if n and n.resolved then
            if anchorTerrainCell and not TA_IsSameTerrainChunk(anchorTerrainCell, n) then
              -- Keep the baseline local to the same ADT chunk so nearby chunk
              -- transitions do not flatten or overstate local slope cues.
              n = nil
            end
          end
          if n and n.resolved then
            local nSlope = tonumber(n.avgSlope)
            local nHeight = tonumber(n.avgHeight)
            if nSlope ~= nil and nHeight ~= nil then
              count = count + 1
              slopeSum = slopeSum + nSlope
              heightSum = heightSum + nHeight
              if slopeMin == nil or nSlope < slopeMin then slopeMin = nSlope end
              if slopeMax == nil or nSlope > slopeMax then slopeMax = nSlope end
              if heightMin == nil or nHeight < heightMin then heightMin = nHeight end
              if heightMax == nil or nHeight > heightMax then heightMax = nHeight end
            end
          end
        end
      end
    end

    if count >= 3 then
      local slopeRelief = (slopeMax and slopeMin) and (slopeMax - slopeMin) or 0
      local heightRelief = (heightMax and heightMin) and (heightMax - heightMin) or 0
      return (heightSum / count), (slopeSum / count), slopeRelief, heightRelief
    end

    if anchorTerrainCell and anchorTerrainCell.resolved then
      -- Fallback: if there are too few same-chunk neighbors, use the anchor
      -- cell sample itself instead of averaging across other chunks.
      local aHeight = tonumber(anchorTerrainCell.avgHeight)
      local aSlope = tonumber(anchorTerrainCell.avgSlope)
      return aHeight, aSlope, 0, 0
    end

    return nil, nil, 0, 0
  end

  -- Keep terrain warnings closer to the player in threat mode.
  local terrainRenderRadius = radius
  if viewMode == "threat" then
    terrainRenderRadius = math.max(6, math.floor(radius * 0.6))
  end

  local showTerrainView = (viewMode == "threat" or viewMode == "combined")
  scratch.terrainLayer = scratch.terrainLayer or {}
  scratch.terrainHeatLayer = scratch.terrainHeatLayer or {}
  local terrainLayer = scratch.terrainLayer
  local terrainHeatLayer = scratch.terrainHeatLayer

  -- Pass 1: sample terrain glyphs for each display cell so we can smooth noisy
  -- one-off spikes without requerying terrain on the render pass.
  for y = radius, -radius, -1 do
    local tlrow = terrainLayer[y]; if not tlrow then tlrow = {}; terrainLayer[y] = tlrow end
    local throw = terrainHeatLayer[y]; if not throw then throw = {}; terrainHeatLayer[y] = throw end
    for x = -radius, radius do
      terrainStats.samples = terrainStats.samples + 1

      local wx = RoundNearest((x * displayCosA) - (y * displaySinA))
      local wy = RoundNearest((x * displaySinA) + (y * displayCosA))
      local dist = TA_GetGridDistance(x, y)

      local baseCell = "."
      if math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and grid[wy] and grid[wy][wx] then
        baseCell = grid[wy][wx]
      end

      local glyph = "."
      local heat = 0
      if showTerrainView then
        if baseCell ~= "." then
          terrainStats.blocked = terrainStats.blocked + 1
        elseif dist > terrainRenderRadius then
          -- Intentionally skip far-edge terrain in threat mode to avoid
          -- warnings appearing only at the outer border.
        elseif playerWorldX and playerWorldY then
          local terrainCell = TA_GetTerrainCellAtOffset(wx, wy)
          if terrainCell and terrainCell.resolved then
            terrainStats.resolved = terrainStats.resolved + 1
          else
            terrainStats.unresolved = terrainStats.unresolved + 1
          end

          local forwardBias = 0
          if dist > 0 then
            forwardBias = ((wx * forwardX) + (wy * forwardY)) / dist
          end
          local localHeightBaseline, localSlopeBaseline, localSlopeRelief, localHeightRelief = TA_GetLocalTerrainBaselines(wx, wy, terrainCell)
          heat = TA_TerrainHeatFromContext(terrainCell, localSlopeRelief, localHeightRelief)
          if terrainStats.heatMin == nil or heat < terrainStats.heatMin then terrainStats.heatMin = heat end
          if terrainStats.heatMax == nil or heat > terrainStats.heatMax then terrainStats.heatMax = heat end
          local sampleHeight = terrainCell and tonumber(terrainCell.avgHeight) or nil
          local baselineHeight = tonumber(localHeightBaseline)
          if baselineHeight == nil then baselineHeight = centerTerrainHeight end
          if baselineHeight and sampleHeight then
            local deltaHeight = sampleHeight - baselineHeight
            if math.abs(deltaHeight) > 300 then
              terrainStats.ignoredOutlier = terrainStats.ignoredOutlier + 1
            else
              terrainStats.compared = terrainStats.compared + 1
              if terrainStats.deltaMin == nil or deltaHeight < terrainStats.deltaMin then terrainStats.deltaMin = deltaHeight end
              if terrainStats.deltaMax == nil or deltaHeight > terrainStats.deltaMax then terrainStats.deltaMax = deltaHeight end
              local gradeDist = dist
              if gradeDist < 1 then gradeDist = 1 end
              local gradePerCell = deltaHeight / gradeDist
              local localRelief = tonumber(localHeightRelief) or 0
              local localDeltaHeight = nil
              if localHeightBaseline ~= nil then
                local localBaseline = tonumber(localHeightBaseline)
                if localBaseline ~= nil then
                  localDeltaHeight = sampleHeight - localBaseline
                end
              end
              local localDropPass = true
              if localDeltaHeight ~= nil then
                localDropPass = localDeltaHeight <= -4
              end
              if dist <= 5 and forwardBias >= 0 and deltaHeight <= -10 and gradePerCell <= -1.6 and localDropPass and localRelief >= 2.5 then
                terrainStats.cliffDrops = terrainStats.cliffDrops + 1
              end
            end
          end
          glyph = TA_GetTerrainGlyph(
            terrainCell,
            centerTerrainHeight,
            centerTerrainSlope,
            forwardBias,
            dist,
            localHeightBaseline,
            localSlopeBaseline,
            localSlopeRelief,
            localHeightRelief
          )
          if glyph ~= "." then
            terrainStats.painted = terrainStats.painted + 1
          else
            terrainStats.noGlyph = terrainStats.noGlyph + 1
          end
        end
      end

      terrainLayer[y][x] = glyph
      terrainHeatLayer[y][x] = heat
    end
  end

  local centerLocalSlope = nil
  if playerWorldX and playerWorldY then
    local centerTerrainCell = TA_GetTerrainCellAtOffset(0, 0)
    local _, localSlope = TA_GetLocalTerrainBaselines(0, 0, centerTerrainCell)
    centerLocalSlope = localSlope
  end
  local standingLabel, standingShort = TA_ClassifyStandingTerrain(TA.dfModeTerrainContext, centerLocalSlope)
  TA.dfModeTerrainStandingLabel = standingLabel
  TA.dfModeTerrainStandingShort = standingShort

  local function TA_GetSmoothedTerrainGlyph(x, y)
    local raw = terrainLayer[y] and terrainLayer[y][x] or "."
    if raw ~= "A" and raw ~= "V" and raw ~= "/" and raw ~= "^" then
      return raw
    end

    local counts = { ["A"] = 0, ["V"] = 0, ["/"] = 0, ["^"] = 0 }
    for oy = -1, 1 do
      for ox = -1, 1 do
        if not (ox == 0 and oy == 0) then
          local ny = y + oy
          local nx = x + ox
          local g = terrainLayer[ny] and terrainLayer[ny][nx] or nil
          if counts[g] ~= nil then
            counts[g] = counts[g] + 1
          end
        end
      end
    end

    -- Cliff-only mode: require stronger local consensus and never propagate
    -- A/V into neighbors (prevents wave-like advancing vertical bands).
    if raw == "V" then
      if counts[raw] < 3 then
        return "."
      end
      return raw
    end
    if raw == "^" and counts["^"] < 2 and counts["/"] >= 2 then
      return "/"
    end

    local bestGlyph = raw
    local bestCount = counts[raw] or 0
    local candidates = { "^", "/" }
    for i = 1, #candidates do
      local g = candidates[i]
      local c = counts[g] or 0
      if c > bestCount then
        bestCount = c
        bestGlyph = g
      end
    end

    if bestGlyph ~= raw and bestCount >= 3 then
      return bestGlyph
    end
    return raw
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

      local showThreat = (viewMode == "threat" or viewMode == "combined")
      local showExploration = (viewMode == "exploration" or viewMode == "combined")
      local showRange = (viewMode == "tactical" or viewMode == "combined")
      local showTerrain = showTerrainView

      if showTerrain and cell == "." then
        local glyph = TA_GetSmoothedTerrainGlyph(x, y)
        if glyph and glyph ~= "." then
          if TA.dfModeHueEnabled then
            if glyph == "V" or glyph == "A" then
              cell = glyph
            else
              local heat = (terrainHeatLayer[y] and terrainHeatLayer[y][x]) or 0
              cell = TA_ColorizeCellByHeat(glyph, heat)
            end
          else
            cell = glyph
          end
        end
      end

      -- Only adorn "background" cells. Mark glyphs (|c..|r), entities (P/@/T/t/Q/*),
      -- and any multi-char/colored cell must NOT receive a prepend, otherwise that
      -- cell becomes visually wider than its neighbors and breaks row alignment
      -- (this is what made horizontal mark edges look like they had extra spacing).
      local adornable = (cell == "." or (#cell == 1
        and cell ~= "P" and cell ~= "@" and cell ~= "T" and cell ~= "t"
        and cell ~= "Q" and cell ~= "*" and cell ~= "M"))

      local threatVal = 0
      if math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and threatHeat[wy] and threatHeat[wy][wx] then
        threatVal = threatHeat[wy][wx] or 0
      end
      if showThreat and adornable and threatVal > 0 then
        if threatVal >= 3 then cell = "!" .. cell
        elseif threatVal >= 2 then cell = "~" .. cell
        end
      end

      if showExploration and adornable and math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and TA.dfModeRecentCells[wy] and TA.dfModeRecentCells[wy][wx] then
        cell = "+" .. cell
      end

      if showRange then
        local distSq = (x * x) + (y * y)
        local ring2 = (distSq >= 2.25 and distSq < 6.25)
        local ring4 = (distSq >= 12.25 and distSq < 20.25)
        local ring6 = (distSq >= 30.25 and distSq < 42.25)
        if (ring2 or ring4 or ring6) and cell == "." then
          cell = "-"
        end
      end

      table.insert(row, cell)
    end

    -- Horizontal mark-edge rows: when 3+ consecutive cells are the (unadorned)
    -- mark edge glyph, drop the spaces between just those cells so they read as a
    -- continuous "ooooo" segment instead of "o o o o o" (which over-stretches
    -- the rectangle horizontally relative to its vertical sides).
    local pieces = {}
    local i = 1
    while i <= #row do
      local cell = row[i]
      if cell == markEdgeGlyph then
        local j = i
        while j <= #row and row[j] == markEdgeGlyph do j = j + 1 end
        local runLen = j - i
        if runLen >= 3 then
          if #pieces > 0 then table.insert(pieces, " ") end
          for k = i, j - 1 do table.insert(pieces, row[k]) end
          i = j
        else
          if #pieces > 0 then table.insert(pieces, " ") end
          table.insert(pieces, cell)
          i = i + 1
        end
      else
        if #pieces > 0 then table.insert(pieces, " ") end
        table.insert(pieces, cell)
        i = i + 1
      end
    end
    table.insert(lines, table.concat(pieces, ""))
  end

  TA.dfModeTerrainRenderStats = terrainStats
  local display = table.concat(lines, "\n")
  -- Stash the raw rendered grid (no color codes stripped) so /ta df copy
  -- can show it in a copyable popup for debugging perimeter rendering.
  TA.dfModeLastRawDisplay = display

  if viewMode == "threat" or viewMode == "combined" then
    local legendEnabled = (TA.dfModeLegendEnabled ~= false)
    local legend = {
      "",
      "Legend: P player  E enemy  T/t target  M mark  * contested",
      "Threat: ! high  ~ medium  . empty  x corpse",
      "Terrain: V drop hazard  X/# obstacles",
    }
    if TA.dfModeHueEnabled then
      table.insert(legend, "Terrain hue: blue low  green medium  yellow high  red extreme")
    end
    if standingLabel then
      table.insert(legend, standingLabel)
    end
    if calibrationEnabled then
      local radiusYards = radius * yardsPerCell
      local ring2 = 2 * yardsPerCell
      local ring4 = 4 * yardsPerCell
      local ring6 = 6 * yardsPerCell
      table.insert(legend, string.format("Cal: grid=%dx%d radius=%d cells (~%d yd) cell=%d yd", gridSize, gridSize, radius, radiusYards, yardsPerCell))
      table.insert(legend, string.format("Cal: rings 2/4/6 cells => ~%d/%d/%d yd", ring2, ring4, ring6))
      if centerTerrainHeight and terrainStats.compared > 0 and terrainStats.deltaMin and terrainStats.deltaMax then
        table.insert(legend, string.format("Cal terrain: centerH=%.1f dH[min/max]=%.1f/%.1f yd compared=%d ignored=%d", centerTerrainHeight, terrainStats.deltaMin, terrainStats.deltaMax, terrainStats.compared, terrainStats.ignoredOutlier))
        table.insert(legend, string.format("Cal terrain: cliff cells V=%d (rule: dH<=-10 & grade<=-1.6 & localDrop<=-4 & relief>=2.5 & dist<=5 & forward>=0)", terrainStats.cliffDrops))
      elseif centerTerrainHeight then
        table.insert(legend, string.format("Cal terrain: centerH=%.1f (no comparable terrain samples, ignored=%d)", centerTerrainHeight, terrainStats.ignoredOutlier))
      else
        table.insert(legend, "Cal terrain: center terrain unresolved")
      end
      if targetUnit and targetRenderedCellDist then
        local renderedYards = targetRenderedCellDist * yardsPerCell
        if targetDistanceExact then
          local expectedCells = targetDistanceExact / yardsPerCell
          local cellError = targetRenderedCellDist - expectedCells
          local yardError = renderedYards - targetDistanceExact
          table.insert(legend, string.format("Cal target: exact=%.1f yd expected=%.2f cells rendered=%.2f cells (err %.2f cells / %.1f yd)", targetDistanceExact, expectedCells, targetRenderedCellDist, cellError, yardError))
        elseif targetDistanceApprox then
          local expectedCells = targetDistanceApprox / yardsPerCell
          local cellError = targetRenderedCellDist - expectedCells
          local yardError = renderedYards - targetDistanceApprox
          table.insert(legend, string.format("Cal target: approx~%.1f yd expected~%.2f cells rendered=%.2f cells (err %.2f cells / %.1f yd)", targetDistanceApprox, expectedCells, targetRenderedCellDist, cellError, yardError))
        elseif targetUsedFallback then
          table.insert(legend, string.format("Cal target: fallback placement rendered=%.2f cells (~%.1f yd), no distance estimate", targetRenderedCellDist, renderedYards))
        else
          table.insert(legend, string.format("Cal target: rendered=%.2f cells (~%.1f yd), no distance source", targetRenderedCellDist, renderedYards))
        end
      elseif targetUnit then
        table.insert(legend, "Cal target: target selected but not rendered (off-grid or unresolved position)")
      else
        table.insert(legend, "Cal target: no target selected")
      end
    end
    if legendEnabled then
      display = display .. "\n" .. table.concat(legend, "\n")
    end
  end

  return display
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
    local current = tonumber(TA.dfModeMarkRadius) or 0
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
  elseif facingDegrees >= 45 and facingDegrees < 135 then dirStr = "W"
  elseif facingDegrees >= 135 and facingDegrees < 225 then dirStr = "S"
  elseif facingDegrees >= 225 and facingDegrees < 315 then dirStr = "E"
  end

  local mapID, cellX, cellY, px, py = GetPlayerMapCell()
  local zoneName = GetZoneText() or "Unknown"
  local units = GetNearbyUnitsWithPositions() or { hostile = {}, neutral = {}, friendly = {} }

  local totalHostile = #(units.hostile or {})
  local totalNeutral = #(units.neutral or {})
  local totalFriendly = #(units.friendly or {})

  AddLine("system", "=== DF MODE STATUS ===")
  AddLine("system", "View: " .. viewMode:upper() .. "  |  Profile: " .. profile:upper())
  local cellText = ""
  if mapID and cellX ~= nil and cellY ~= nil then
    cellText = string.format("  |  Cell: [%s,%s]", tostring(cellX), tostring(cellY))
  elseif mapID then
    cellText = "  |  Cell: [unknown]"
  end
  AddLine("system", "Zone: " .. zoneName .. cellText)
  AddLine("system", "Facing: " .. dirStr .. " (" .. facingDegrees .. " deg)")
  AddLine("system", "Legend overlay: " .. ((TA.dfModeLegendEnabled ~= false) and "ON" or "OFF") .. " (use /ta df legend on|off)")
  if TA.dfModeLegendEnabled ~= false then
    AddLine("system", "Legend: P=Player  E=Enemy  T/t=Target  M=Mark  *=Contested")
    AddLine("system", "Threat: !=high  ~=medium  .=empty  x=corpse")
    AddLine("system", "Terrain: ^=steep  /=incline  A/V=up/down  X/#=obstacles")
  end
  AddLine("system", "Terrain hue: " .. (TA.dfModeHueEnabled and "ON" or "OFF") .. " (use /ta df hue on|off)")
  AddLine("system", "DF calibration: " .. (TA.dfModeCalibrationEnabled and "ON" or "OFF") .. " (use /ta df calibrate on|off)")
  AddLine("system", "Mark radius: " .. (tonumber(TA.dfModeMarkRadius) or 0) .. " cell(s)")
  AddLine("system", "Orientation: " .. ((TA.dfModeOrientation or "fixed"):upper()))
  AddLine("system", "Rotation mode: " .. ((TA.dfModeRotationMode or "smooth"):upper()))
  local terrain = nil
  local terrainOk, terrainOrErr = pcall(TA_GetTerrainContextAtMapPos)
  if terrainOk then
    terrain = terrainOrErr
  else
    AddLine("system", "Terrain: lookup error: " .. tostring(terrainOrErr))
  end

  if not terrain then
    AddLine("system", "Terrain: no compiled terrain data loaded")
  elseif not terrain.resolved then
    AddLine("system", string.format("Terrain: loaded but no chunk match near tile/chunk %d:%d / %d:%d (mode %s)", terrain.tileX or -1, terrain.tileY or -1, terrain.chunkX or -1, terrain.chunkY or -1, tostring(terrain.lookupMode or "?")))
    if terrain.inCompiledTileBounds == false then
      local b = terrain.mapBounds
      if b and b.tileMin and b.tileMax then
        AddLine("system", string.format("Terrain coverage: outside compiled tile bounds (%d:%d to %d:%d). Export and compile this zone.", tonumber(b.tileMin[1]) or -1, tonumber(b.tileMin[2]) or -1, tonumber(b.tileMax[1]) or -1, tonumber(b.tileMax[2]) or -1))
      else
        AddLine("system", "Terrain coverage: outside compiled tile bounds. Export and compile this zone.")
      end
    else
      AddLine("system", "Terrain coverage: tile is inside compiled bounds, but this chunk is missing from the dataset.")
    end
  else
    local water = terrain.hasWater and "yes" or "no"
    local texture = tostring(terrain.texture or "unknown")
    local height = terrain.avgHeight and string.format("%.1f", terrain.avgHeight) or "?"
    local slope = terrain.avgSlope and string.format("%.2f", terrain.avgSlope) or "?"
    local maxSlope = terrain.maxSlope and string.format("%.2f", terrain.maxSlope) or "?"
    AddLine("system", string.format("Terrain: tile/chunk %d:%d / %d:%d  water=%s  texture=%s  height~%s  slope~%s (max %s, mode %s)", terrain.tileX or -1, terrain.tileY or -1, terrain.chunkX or -1, terrain.chunkY or -1, water, texture, height, slope, maxSlope, tostring(terrain.lookupMode or "?")))
  end
  local standingLabel = TA.dfModeTerrainStandingLabel
  if not standingLabel and terrain and terrain.resolved then
    standingLabel = select(1, TA_ClassifyStandingTerrain(terrain, nil))
  end
  if standingLabel then
    AddLine("system", standingLabel)
  end
  local tr = TA.dfModeTerrainRenderStats
  if type(tr) == "table" then
    AddLine("system", string.format("Terrain render: samples=%d lookups=%d resolved=%d painted=%d blocked=%d no-glyph=%d unresolved=%d", tr.samples or 0, tr.lookups or 0, tr.resolved or 0, tr.painted or 0, tr.blocked or 0, tr.noGlyph or 0, tr.unresolved or 0))
    if tr.heatMin ~= nil and tr.heatMax ~= nil then
      AddLine("system", string.format("Terrain hue range: min=%.2f max=%.2f", tonumber(tr.heatMin) or 0, tonumber(tr.heatMax) or 0))
    end
  end
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
  local dfInterval = tonumber(TA.tickerIntervals and TA.tickerIntervals.df) or 0.1
  if now - TA.dfModeLastUpdate < dfInterval then
    return  -- Update at most every configured DF ticker interval.
  end
  TA.dfModeLastUpdate = now

  -- DFDanger integration: evaluate passive warnings on a slower internal cadence.
  if DFDanger and DFDanger.Tick then
    pcall(function()
      DFDanger:Tick()
    end)
  end
  
  local display = BuildDFModeDisplay()
  local mapLines = dfModeFrame.mapLines
  local i = 1
  if display then
    for line in display:gmatch("[^\n]+") do
      if mapLines[i] then
        if mapLines[i]:GetText() ~= line then
          mapLines[i]:SetText(line)
        end
        i = i + 1
      end
    end
  else
    if mapLines[1] and mapLines[1]:GetText() ~= "Error generating tactical map." then
      mapLines[1]:SetText("Error generating tactical map.")
    end
    i = 2
  end
  -- Blank out any rows below the current map
  for j = i, #mapLines do
    if mapLines[j]:GetText() ~= "" then
      mapLines[j]:SetText("")
    end
  end
  local viewMode = TA.dfModeViewMode or "threat"
  local terrain = TA.dfModeTerrainContext
  if terrain and terrain.resolved then
    local waterFlag = terrain.hasWater and "W" or "D"
    dfTitle:SetText(string.format("%s | %s", viewMode, waterFlag))
  else
    dfTitle:SetText(viewMode)
  end
end

function TA_ToggleDFMode()
  TA.dfModeEnabled = not TA.dfModeEnabled
  if TA.dfModeEnabled then
    TA.dfModeViewMode = "threat"
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

-- Positional awareness without protected APIs.
-- UnitPosition only returns coordinates for player/pet/group members in
-- Classic Era; for arbitrary mobs we fall back to the nameplate-derived
-- cache (TA.lastNearbyUnits) populated by CollectNearbyUnitsWithPositions,
-- and finally to LibRangeCheck-3.0 for a range-bucket distance (no bearing).
-- Axis convention follows the rest of the addon (see ~10174):
--   first return  = world NORTH (Y)
--   second return = needs negation for EAST
-- GetPlayerFacing: 0 = north, increases CCW (90deg = west).
local function TA_GetRangeCheck()
  if TA._rangeCheck ~= nil then return TA._rangeCheck or nil end
  local ok, lib = pcall(function() return LibStub and LibStub("LibRangeCheck-3.0", true) end)
  TA._rangeCheck = (ok and lib) or false
  return TA._rangeCheck or nil
end

function TA_RelativeBearing(unitToken)
  if not unitToken then return nil end
  if not UnitExists(unitToken) then return nil end
  local pa, pb = UnitPosition("player")

  local ua, ub
  if pa and pb then
    ua, ub = UnitPosition(unitToken)
    if not (ua and ub) then
      local guid = UnitGUID(unitToken)
      if guid and TA.lastNearbyUnits then
        for _, bucket in pairs(TA.lastNearbyUnits) do
          if type(bucket) == "table" then
            for i = 1, #bucket do
              local u = bucket[i]
              if u and u.guid == guid and u.hasExactPos and u.worldX and u.worldY then
                ua, ub = u.worldX, u.worldY
                break
              end
            end
          end
          if ua and ub then break end
        end
      end
    end
  end

  if pa and pb and ua and ub then
    local dn = ua - pa
    local de = pb - ub
    local dist = math.sqrt(dn * dn + de * de)
    if dist < 0.01 then
      return { distance = 0, bearingRad = 0, bearingDeg = 0, clock = 12, forward = 0, strafe = 0, behind = false, source = "exact" }
    end
    local f = GetPlayerFacing() or 0
    local sinf, cosf = math.sin(f), math.cos(f)
    local forward = de * (-sinf) + dn * cosf
    local strafe  = de *  cosf  + dn * sinf
    local bodyAng = math.atan2(strafe, forward)
    local deg = (bodyAng * 180 / math.pi) % 360
    local clock = math.floor(deg / 30 + 0.5)
    if clock <= 0 or clock >= 12 then clock = 12 end
    return {
      distance   = dist,
      bearingRad = bodyAng,
      bearingDeg = deg,
      clock      = clock,
      forward    = forward,
      strafe     = strafe,
      behind     = forward < 0,
      source     = "exact",
    }
  end

  -- Fall back to LibRangeCheck-3.0 for a distance bucket. No bearing info.
  local rc = TA_GetRangeCheck()
  if rc then
    local minR, maxR = rc:GetRange(unitToken)
    if minR then
      local mid = maxR and ((minR + maxR) * 0.5) or minR
      return {
        distance    = mid,
        distanceMin = minR,
        distanceMax = maxR,
        clock       = nil,
        forward     = nil,
        strafe      = nil,
        behind      = nil,
        source      = "rangecheck",
      }
    end
  end
  return nil
end

-- Narrate the relative bearing to the current target (or any unit) as a
-- terse text-adventure line. Cheap; safe to call from CheckTarget or a
-- throttled awareness tick.
function TA_NarrateBearing(unitToken, label)
  local b = TA_RelativeBearing(unitToken or "target")
  if not b then return end
  local who = label or (UnitName(unitToken or "target")) or "target"
  if b.clock then
    AddLine("trace", string.format(
      "%s is %.1fyd at your %d o'clock (%s%.1fyd fwd, %s%.1fyd %s).",
      who, b.distance, b.clock,
      b.forward >= 0 and "+" or "", b.forward,
      b.strafe  >= 0 and "+" or "", math.abs(b.strafe),
      b.strafe >= 0 and "right" or "left"
    ))
  else
    if b.distanceMax then
      AddLine("trace", string.format("%s is %.0f-%.0fyd away (range-check, no bearing).", who, b.distanceMin or 0, b.distanceMax))
    else
      AddLine("trace", string.format("%s is more than %.0fyd away (range-check, no bearing).", who, b.distanceMin or b.distance or 0))
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

-- Returns an 8-direction compass string (N/NE/E/SE/S/SW/W/NW) from map-space dx/dy.
-- In map-space, +dx is east and +dy is south, so convert to east/north before atan2.
function TA_CompassDir(dx, dy)
  local east = dx
  local north = -dy
  local deg = math.deg(math.atan2(north, east)) % 360
  local dirs = { "E", "NE", "N", "NW", "W", "SW", "S", "SE" }
  return dirs[math.floor((deg + 22.5) / 45) % 8 + 1]
end

local DF_YARDS_PER_CELL = 3
function TA_GetEffectiveDFYardsPerCell()
  local yards = tonumber(TA.dfModeYardsPerCell)
  if not yards then
    -- Keep DF tactical map at its own scale; do not inherit world cell-yard sizing.
    yards = tonumber(DF_YARDS_PER_CELL) or 3
  end
  yards = math.floor(yards + 0.5)
  if yards < 3 then yards = 3 end
  if yards > 100 then yards = 100 end
  return yards
end

function TA_GetProjectedDFPlayerWorldPosition(playerWorldX, playerWorldY)
  if not playerWorldX or not playerWorldY then
    playerWorldX, playerWorldY = UnitPosition("player")
  end
  if not playerWorldX or not playerWorldY then
    return nil, nil
  end

  local speed = tonumber(GetUnitSpeed("player")) or 0
  if speed <= 0 then
    return playerWorldX, playerWorldY
  end

  local facing = GetPlayerFacing()
  if not facing then
    return playerWorldX, playerWorldY
  end

  local lookaheadSeconds = tonumber(TA.dfModeLookaheadSeconds) or 0
  local projectedWorldX = playerWorldX
  local projectedWorldY = playerWorldY
  if lookaheadSeconds > 0 then
    -- Lookahead cap: max half a cell so projection cannot leap past the snap zone.
    local lookaheadCap = 0.5 * (TA_GetEffectiveDFYardsPerCell() or 3)
    local lookaheadYards = math.min(speed * lookaheadSeconds, lookaheadCap)
    local forwardX = -math.sin(facing)
    local forwardY = math.cos(facing)
    projectedWorldX = projectedWorldX + (forwardX * lookaheadYards)
    projectedWorldY = projectedWorldY + (forwardY * lookaheadYards)
  end

  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  if not yardsPerCell or yardsPerCell <= 0 then
    return projectedWorldX, projectedWorldY
  end

  local threshold = tonumber(TA.dfModeHysteresisEnterPct) or 0.38
  if threshold < 0.05 then threshold = 0.05 end
  if threshold > 0.49 then threshold = 0.49 end

  local function RoundNearest(n)
    if n >= 0 then
      return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
  end

  local function SnapAxis(rawCell, stateKey)
    local snappedCell = tonumber(TA[stateKey])
    if not snappedCell or math.abs(rawCell - snappedCell) > 2 then
      snappedCell = RoundNearest(rawCell)
    else
      while (rawCell - snappedCell) >= threshold do
        snappedCell = snappedCell + 1
      end
      while (rawCell - snappedCell) <= -threshold do
        snappedCell = snappedCell - 1
      end
    end
    TA[stateKey] = snappedCell
    return snappedCell * yardsPerCell
  end

  return SnapAxis(projectedWorldX / yardsPerCell, "dfModeAnchorCellX"), SnapAxis(projectedWorldY / yardsPerCell, "dfModeAnchorCellY")
end


local function BuildNearbyLine(kind, units)
  if #units == 0 then return nil end
  local parts = {}
  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  for _, u in ipairs(units) do
    local label = u.isTarget and ("[T]" .. u.name) or u.name
    if u.dist then
      local cells = math.max(1, math.floor(u.dist / yardsPerCell + 0.5))
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
          if TA_TryInteractDistance(unit, 1) then dist = 3      -- ~0 cells (right next to you)
          elseif TA_TryInteractDistance(unit, 2) then dist = 9  -- ~1-2 cells
          elseif TA_TryInteractDistance(unit, 3) then dist = 24 -- ~4 cells
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
  -- Bearing narration: only emit when the target changes or its
  -- distance-band/clock-face moves, to avoid per-tick spam.
  if UnitExists("target") and not UnitIsDead("target") then
    local b = TA_RelativeBearing("target")
    if b then
      local guid = UnitGUID("target") or "?"
      local distBucket = math.floor((b.distance or 0) / 5)
      local clockKey = b.clock or "rc"
      local bucket = guid .. ":" .. tostring(clockKey) .. ":" .. distBucket
      if bucket ~= TA.lastTargetBearingBucket then
        TA_NarrateBearing("target")
        TA.lastTargetBearingBucket = bucket
      end
    end
  else
    TA.lastTargetBearingBucket = nil
  end
end

function TA_RequestAwarenessRefresh(force)
  TA.awarenessDirty = true
  local now = GetTime()
  local minInterval = tonumber(TA.awarenessEventMinInterval) or 0.20
  if not force and (now - (TA.awarenessLastRunAt or 0)) < minInterval then
    return
  end
  CheckAwareness()
  TA.awarenessLastRunAt = now
  TA.awarenessDirty = false
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
      elseif text:find("bound to you", 1, true) or text:find("become soulbound", 1, true)
          or text:find("become non%-refundable") or text:find("BIND") or text:find("soulbound") then
        -- BoE equip / refundable-loss confirmation. Default action is accept
        -- so the player can finish equipping the upgrade with /ta accept 1.
        kind = "equipBind"
        title = "Confirm bind on equip"
        defaultAction = "accept"
      end

      -- Generic fallback: surface any popup with at least one button so the
      -- user is never stuck unable to interact with a Blizzard dialog. Title
      -- previews the first ~60 chars of the dialog text.
      if not kind then
        local btn1 = _G[frameName .. "Button1"]
        if btn1 and btn1:IsShown() and text and text ~= "" then
          kind = "generic"
          title = "Dialog: " .. (text:sub(1, 60):gsub("\n", " "))
          defaultAction = "accept"
        end
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
      elseif p.kind == "equipBind" then
        AddLine("loot", "Equip confirmed (item is now soulbound).")
      else
        AddLine("system", string.format("Accepted: %s", p.title))
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
      elseif p.kind == "equipBind" then
        AddLine("loot", "Equip cancelled.")
      else
        AddLine("system", string.format("Declined: %s", p.title))
      end
    else
      AddLine("system", string.format("%s decline button not accessible.", p.title))
    end
  end
end

TA.hiddenFrames = { "MinimapCluster", "MiniMapTracking", "MinimapZoneTextButton", "GameTimeFrame", "PlayerFrame", "TargetFrame", "BuffFrame", "DurabilityFrame" }

function TA_ForceHideFrameByName(name)
  local frame = _G[name]
  if frame then frame:Hide() end
end

function TA_ApplyTextModeFrames()
  for _, name in ipairs(TA.hiddenFrames or {}) do TA_ForceHideFrameByName(name) end
end

SyncTextModeOverlay = function()
  if TA.textMode then
    overlay:Show()
  else
    overlay:Hide()
  end
  TA_SyncProtectedCommandEditBoxes(TA.textMode and true or false)
  TA_UpdateCommandPreviewBox()
end

function TA_EnableTextModeInternal()
  TA.textMode = true
  panel:Show()
  panel:SetFrameStrata("TOOLTIP")
  panel:SetFrameLevel(11000)
  panel.inputBox:Show()
  SyncTextModeOverlay()
  TA_ApplyTextModeFrames()
  AddLine("system", "Text mode enabled.")
end

function TA_DisableTextModeInternal()
  TA.textMode = false
  SyncTextModeOverlay()
  panel.inputBox:Hide()
  AddLine("system", "Text mode disabled. Hidden frames may need /reload to return.")
end

local function TogglePanel()
  if panel:IsShown() then
    panel:Hide()
    SyncTextModeOverlay()
    if ChatFrame1 then ChatFrame1:Show() end
  else
    panel:Show()
    SyncTextModeOverlay()
  end
end

function TA_ClearTerminalLog()
  wipe(TA.lines)
  panel.text:Clear()
  AddLine("system", "Log cleared.")
end

function TA_ShowPanelCommand()
  panel:Show()
  SyncTextModeOverlay()
  AddLine("system", "Text Adventurer opened.")
end

function TA_HidePanelCommand()
  panel:Hide()
  SyncTextModeOverlay()
  if ChatFrame1 then ChatFrame1:Show() end
end

function TA_TogglePanelCommand()
  TogglePanel()
end

function TA_EnableTextModeCommand()
  TA_EnableTextModeInternal()
end

function TA_DisableTextModeCommand()
  TA_DisableTextModeInternal()
end

function TA_FocusTerminalInput(deferFocus)
  panel:Show()
  panel.inputBox:Show()

  local function FocusNow()
    if panel and panel.inputBox then
      panel.inputBox:SetFocus()
    end
  end

  if deferFocus and C_Timer and C_Timer.After then
    C_Timer.After(0, FocusNow)
  else
    FocusNow()
  end

  AddLine("system", "Terminal input ready.")
end

local function TA_ExecuteTerminalInputLines(lines, opts)
  opts = opts or {}
  if type(lines) ~= "table" or #lines == 0 then
    return false
  end

  if opts.recordLastBlock ~= false then
    TA.lastInputBlock = {}
    for i = 1, #lines do
      TA.lastInputBlock[i] = lines[i]
    end
  end

  for i = 1, #lines do
    local line = lines[i]
    AddLine("system", "> " .. line)
    table.insert(TA.inputHistory, line)
    if #TA.inputHistory > TA.inputHistoryMax then table.remove(TA.inputHistory, 1) end
  end
  TA.inputHistoryPos = 0
  TA.inputDraft = ""

  -- Multi-line body folding: if the first line is a body-taking command
  -- (macrocreate / macroset), treat ALL subsequent lines as additional body
  -- lines so multi-line macros can be authored with Shift+Enter.
  if #lines >= 2 then
    local first = lines[1]
    local firstLower = first:lower()

    -- macrocreate <name> [body...] + subsequent body lines
    if firstLower:match("^macrocreate%s+") then
      local rest = first:match("^%S+%s+(.-)%s*$")
      if rest and rest ~= "" then
        local macroName, inlineBody
        if rest:sub(1, 1) == '"' then
          -- quoted name with optional inline body: "Name" body...
          macroName, inlineBody = rest:match('^"([^"]+)"%s*(.*)$')
        else
          -- unquoted single-token name with optional inline body
          macroName, inlineBody = rest:match("^(%S+)%s*(.*)$")
        end
        if macroName and macroName ~= "" then
          local extra = table.concat(lines, "\n", 2)
          local multiBody
          if inlineBody and inlineBody ~= "" then
            multiBody = inlineBody .. "\n" .. extra
          else
            multiBody = extra
          end
          CreateNewMacro(macroName, multiBody)
          return false
        end
      end
    end

    -- macroset <idx> [body...] + subsequent body lines
    local msIdx, msInline = first:match("^[Mm][Aa][Cc][Rr][Oo][Ss][Ee][Tt]%s+(%d+)%s*(.*)$")
    if msIdx then
      local extra = table.concat(lines, "\n", 2)
      local multiBody
      if msInline and msInline ~= "" then
        multiBody = msInline .. "\n" .. extra
      else
        multiBody = extra
      end
      SetMacroBody(tonumber(msIdx), multiBody)
      return false
    end
  end

  TA.deferTerminalRefocus = false
  for i = 1, #lines do
    TA_ProcessInputCommand(lines[i])
    if TA.deferTerminalRefocus then
      return true
    end
  end

  return false
end

function TA_RunLastInputBlock()
  if TA.isReplayingLastBlock then
    AddLine("system", "runlast is already replaying.")
    return
  end
  if type(TA.lastInputBlock) ~= "table" or #TA.lastInputBlock == 0 then
    AddLine("system", "No previous multiline block to replay.")
    return
  end

  local lines = {}
  for i = 1, #TA.lastInputBlock do
    lines[i] = TA.lastInputBlock[i]
  end

  TA.isReplayingLastBlock = true
  local ok, err = pcall(function()
    TA_ExecuteTerminalInputLines(lines, { recordLastBlock = false })
  end)
  TA.isReplayingLastBlock = false

  if not ok then
    AddLine("system", "runlast failed: " .. tostring(err))
  end
end

function TA_SendFromTerminal(msg)
  local cmd, rest = msg:match("^/(%S+)%s*(.*)$")
  if not cmd then return false end
  cmd = cmd:lower()
  local protectedSlashCommands = {
    logout = true,
    camp = true,
    quit = true,
    exit = true,
    cast = true,
    stopcasting = true,
    castsequence = true,
    use = true,
    equip = true,
    equipslot = true,
    petattack = true,
    petfollow = true,
    petpassive = true,
    petdefensive = true,
    petaggressive = true,
    startattack = true,
    stopattack = true,
    cancelaura = true,
    cancelform = true,
    click = true,
  }
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
    -- Pass unknown slash commands (e.g., /logout) to Blizzard's chat parser.
    if ChatFrame_OpenChat then
      TA.deferTerminalRefocus = true
      local openText = msg
      if protectedSlashCommands[cmd] then
        -- Do not inject protected commands via addon code; require manual typing
        -- in the chat edit box to avoid tainting secure slash handlers.
        openText = ""
        TA.deferTerminalRefocus = false
      end
      ChatFrame_OpenChat(openText)
      if TA.textMode then
        TA_SyncProtectedCommandEditBoxes(true)
      end
      if ChatFrame1EditBox then
        ChatFrame1EditBox:Show()
        ChatFrame1EditBox:SetFocus()
        if ChatEdit_ActivateChat then
          ChatEdit_ActivateChat(ChatFrame1EditBox)
        end
      end
      TA_UpdateCommandPreviewBox()
      if protectedSlashCommands[cmd] then
        AddLine("system", "Protected command requires manual typing. Type /" .. cmd .. " in chat input, then press Enter.")
      else
        AddLine("system", "Slash command opened in chat input.")
      end
    else
      AddLine("system", "Unknown chat prefix. Use /s, /p, /g, /w, /raid, or /rw.")
    end
  end
  return true
end

function TA_ShowHelpOverview()
  if TA_Help_ShowOverview then
    TA_Help_ShowOverview()
    return
  end
  AddLine("system", "Help module is not loaded yet.")
end

function TA_ShowHelpTopic(topicArg)
  if TA_Help_ShowTopic then
    TA_Help_ShowTopic(topicArg)
    return
  end
  AddLine("system", "Help module is not loaded yet.")
  TA_ShowHelpOverview()
end

function TA_RunCommandSelfTest(modeArg)
  if not TA or not TA.EXACT_INPUT_HANDLERS then
    AddLine("system", "Self-test unavailable: command table is not ready.")
    return
  end

  local mode = tostring(modeArg or "safe"):lower()
  local denyContains = {
    "reload",
    "destroy",
    "sell",
    "delete",
    "equip",
    "train",
    "buy",
    "accept",
    "decline",
    "turnin",
    "complete",
    "macrocreate",
    "macroset",
    "macrorename",
    "autostart",
    "textmode",
  }

  local safeAllow = {
    ["help"] = true,
    ["status"] = true,
    ["stats"] = true,
    ["skills"] = true,
    ["xp"] = true,
    ["buffs"] = true,
    ["tracking"] = true,
    ["actions"] = true,
    ["spells"] = true,
    ["macros"] = true,
    ["inventory"] = true,
    ["equipment"] = true,
    ["money"] = true,
    ["where"] = true,
    ["cell"] = true,
    ["markedcells"] = true,
    ["map"] = true,
    ["df status"] = true,
    ["performance status"] = true,
    ["settings"] = true,
  }

  local function isDenied(cmd)
    for i = 1, #denyContains do
      if string.find(cmd, denyContains[i], 1, true) then
        return true
      end
    end
    return false
  end

  local cmds = {}
  for cmd, _ in pairs(TA.EXACT_INPUT_HANDLERS) do
    if cmd ~= "selftest" and cmd ~= "selftest full" and not isDenied(cmd) then
      if mode == "full" or safeAllow[cmd] then
        table.insert(cmds, cmd)
      end
    end
  end
  table.sort(cmds)

  if #cmds == 0 then
    AddLine("system", "Self-test found no runnable commands for mode: " .. mode)
    return
  end

  AddLine("system", string.format("Self-test starting (%s): %d command(s)", mode, #cmds))

  local okCount = 0
  local failCount = 0
  for i = 1, #cmds do
    local cmd = cmds[i]
    local ok, err = pcall(function()
      TA_ProcessInputCommand(cmd)
    end)
    if ok then
      okCount = okCount + 1
    else
      failCount = failCount + 1
      AddLine("system", string.format("[FAIL] %s -> %s", cmd, tostring(err)))
    end
  end

  AddLine("system", string.format("Self-test complete: ok=%d fail=%d", okCount, failCount))
  if mode ~= "full" then
    AddLine("system", "Tip: run 'selftest full' for broader non-destructive exact-handler coverage.")
  end
end

function TA_RunPatternSelfTest(modeArg)
  if not TA_ProcessInputCommand then
    AddLine("system", "Pattern self-test unavailable: command parser is not ready.")
    return
  end

  local mode = tostring(modeArg or "safe"):lower()
  local cmdsSafe = {
    "help navigation",
    "skills weapons",
    "skill professions",
    "who tester",
    "markcell alpha",
    "cellsize 40",
    "cellcal 20 30",
    "cellyards 30",
    "showmark 1",
    "renamemark 1 alpha",
    "df size 300 600",
    "df grid 35",
    "df markradius 2",
    "route show test",
    "route list",
    "questinfo 1",
    "questroute top 3",
    "questroute weight xp 1.0",
    "choose 1",
    "rewardinfo 1",
    "set maxfps 60",
    "cvar maxfps",
    "cvarlist maxfps",
    "sealdps 30",
    "sealdps live target 30",
    "warlockdps mode shadow",
    "warlockprompt set manapct 40",
    "ml xp mode balanced",
    "ml xp set priorweight 8",
    "ml export 10",
    "ml log max 50",
    "ml xp warrior preset arms",
    "ml xp warrior weapon auto",
    "macroinfo 1",
    "macro 1",
    "train 1",
    "recipeinfo 1",
    "recipe 1",
  }

  local cmdsFull = {
    "help combat",
    "help automation",
    "target nearest",
    "bind 1 1",
    "bindmacro 1 1",
    "binditem 1 0 1",
    "moveitem 0 1 1 1",
    "buycheck 1",
    "buycheck 1 2",
    "vendorinfo 1",
    "shopinfo 1",
    "iteminfo 1",
    "readitem 0 1",
    "restock food 5",
    "buyback 1",
    "bank",
    "spellbook all",
    "spells full",
    "map on",
    "map off",
    "df profile balanced",
    "df orientation rotating",
    "df rotation octant",
    "df cell 4",
    "df cell auto",
    "df level 2",
    "df level off",
    "df adaptive on",
    "df adaptive mode combat",
    "df adaptive thresholds 10 20 40",
    "route start test",
    "route follow test",
    "route follow off",
    "route clear test",
    "quest route top 2",
    "quest route weight proximity 1.2",
    "reward 1",
    "accept 1",
    "decline 1",
    "cvar maxfps 60",
    "warlockdps set targetlevel 30",
    "warlock prompt set taphpfloor 45",
    "ml xp set grindscale 1.0",
    "ml xp warrior preset fury",
    "ml xp warrior weapon dual-wield",
    "sealdps set 30 100 90",
    "sealdps import 30:100:90",
    "weapondance",
    "sordance",
    "swingtimer on",
    "swingtimer off",
    "swingtimer status",
    "swingtimer reaction 100",
    "macroset 1 /say test",
    "macrorename 1 test",
    "macrocreate test /say hi",
    "macrodelete 1",
    "train all",
  }

  local cmds = {}
  for i = 1, #cmdsSafe do
    table.insert(cmds, cmdsSafe[i])
  end
  if mode == "full" then
    for i = 1, #cmdsFull do
      table.insert(cmds, cmdsFull[i])
    end
  end

  AddLine("system", string.format("Pattern self-test starting (%s): %d sample command(s)", mode, #cmds))

  local okCount = 0
  local failCount = 0
  for i = 1, #cmds do
    local cmd = cmds[i]
    local ok, err = pcall(function()
      TA_ProcessInputCommand(cmd)
    end)
    if ok then
      okCount = okCount + 1
    else
      failCount = failCount + 1
      AddLine("system", string.format("[FAIL] %s -> %s", cmd, tostring(err)))
    end
  end

  AddLine("system", string.format("Pattern self-test complete: ok=%d fail=%d", okCount, failCount))
  if mode ~= "full" then
    AddLine("system", "Tip: run 'selftest patterns full' for broader curated pattern coverage.")
  end
end

-- Command handlers moved to Modules/Commands.lua
function TA_EnsureRuntimeTickers()
  if not TA.moveTicker then
    TA.moveTicker = C_Timer.NewTicker(TA.tickerIntervals.move or 0.01, function()
      TA:ProfileStart("moveTicker")
      CheckMovement()
      CheckFallState()
      CheckWallHeuristic()
      CheckSwingTimer()
      TA:ProfileEnd("moveTicker")
    end)
  end
  if not TA.awarenessNearbyTicker then
    TA.awarenessNearbyTicker = C_Timer.NewTicker(TA.tickerIntervals.nearby or 0.01, function()
      TA:ProfileStart("awarenessNearbyTicker")
      local now = GetTime()
      local fallbackInterval = tonumber(TA.awarenessFallbackInterval) or 0.75
      if TA.awarenessDirty or (now - (TA.awarenessLastRunAt or 0)) >= fallbackInterval then
        TA_RequestAwarenessRefresh(false)
      end
      TA:ProfileEnd("awarenessNearbyTicker")
    end)
  end
  if not TA.awarenessMemoryTicker then
    TA.awarenessMemoryTicker = C_Timer.NewTicker(TA.tickerIntervals.memory or 0.01, function()
      TA:ProfileStart("awarenessMemoryTicker")
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
        for dy = -1, 1 do
          if not TA.dfModeRecentCells[dy] then TA.dfModeRecentCells[dy] = {} end
          for dx = -1, 1 do
            TA.dfModeRecentCells[dy][dx] = true
          end
        end
      end

      -- Keep quest-route candidate refresh out of DF render loop.
      if TA_GetQuestRouterStore and TA_BuildQuestRouteCandidates then
        local qstore = TA_GetQuestRouterStore()
        if qstore and qstore.enabled ~= false then
          local qnow = GetTime()
          if not TA.questRouteOverlay or (qnow - (TA.questRouteLastAt or 0)) > 3 then
            TA_BuildQuestRouteCandidates(1)
          end
        else
          TA.questRouteOverlay = nil
        end
      end
      TA:ProfileEnd("awarenessMemoryTicker")
    end)
  end
  if not TA.dfModeTicker then
    TA.dfModeTicker = C_Timer.NewTicker(TA.tickerIntervals.df or 0.1, function()
      TA:ProfileStart("dfModeTicker")
      TA_UpdateDFMode()
      TA:ProfileEnd("dfModeTicker")
    end)
  end
  if not TA.warlockPromptTicker then
    TA.warlockPromptTicker = C_Timer.NewTicker(TA.tickerIntervals.warlockPrompt or 0.75, function()
      if TA_MaybeAutoWarlockPrompt then
        TA_MaybeAutoWarlockPrompt()
      end
    end)
  end
  if not TA.warriorPromptTicker then
    TA.warriorPromptTicker = C_Timer.NewTicker(TA.tickerIntervals.warriorPrompt or 0.75, function()
      if TA_MaybeAutoWarriorPrompt then
        TA_MaybeAutoWarriorPrompt()
      end
    end)
  end
end

function TA_StopRuntimeTickers()
  if TA.moveTicker then TA.moveTicker:Cancel(); TA.moveTicker = nil end
  if TA.awarenessNearbyTicker then TA.awarenessNearbyTicker:Cancel(); TA.awarenessNearbyTicker = nil end
  if TA.awarenessMemoryTicker then TA.awarenessMemoryTicker:Cancel(); TA.awarenessMemoryTicker = nil end
  if TA.dfModeTicker then TA.dfModeTicker:Cancel(); TA.dfModeTicker = nil end
  if TA.warlockPromptTicker then TA.warlockPromptTicker:Cancel(); TA.warlockPromptTicker = nil end
  if TA.warriorPromptTicker then TA.warriorPromptTicker:Cancel(); TA.warriorPromptTicker = nil end
end

function TA_RestartRuntimeTickers()
  TA_StopRuntimeTickers()
  TA_EnsureRuntimeTickers()
end

panel.inputBox:EnableKeyboard(true)
panel.inputBox:SetScript("OnEditFocusGained", function(self)
  self:SetCursorPosition((self:GetText() and #self:GetText()) or 0)
  if self.customCaret then
    self.customCaret:Show()
    if self.customCaretFlash and not self.customCaretFlash:IsPlaying() then
      self.customCaretFlash:Play()
    end
  end
end)
panel.inputBox:SetScript("OnEditFocusLost", function(self)
  if self.customCaretFlash and self.customCaretFlash:IsPlaying() then
    self.customCaretFlash:Stop()
  end
  if self.customCaret then
    self.customCaret:Hide()
  end
end)
panel.inputBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
  if not self.customCaret then
    return
  end
  self.customCaret:ClearAllPoints()
  self.customCaret:SetPoint("TOPLEFT", self, "TOPLEFT", (x or 0) + (TA.INPUTBOX_LAYOUT.insetLeft or 8), (y or 0) - (TA.INPUTBOX_LAYOUT.insetTop or 6))
  if h and h > 0 then
    self.customCaret:SetHeight(h)
  end
end)
panel.inputBox:SetScript("OnTextChanged", function(self)
  TA_UpdateInputBoxLayout(self)
end)
panel.inputBox:SetScript("OnEnterPressed", function(self)
  if IsShiftKeyDown and IsShiftKeyDown() then
    local text = self:GetText() or ""
    local cursor = self:GetCursorPosition() or #text
    local before = text:sub(1, cursor)
    local after = text:sub(cursor + 1)
    local combined = before .. "\n" .. after
    self:SetText(combined)
    self:SetCursorPosition(cursor + 1)
    return
  end

  local msg = self:GetText()
  local lines = {}
  if msg and msg ~= "" then
    for line in msg:gmatch("[^\r\n]+") do
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed ~= "" and not trimmed:match("^#") then
        table.insert(lines, trimmed)
      end
    end
    if #lines == 0 then
      local trimmed = msg:match("^%s*(.-)%s*$")
      if trimmed ~= "" and not trimmed:match("^#") then
        table.insert(lines, trimmed)
      end
    end
  end

  self:SetText("")
  local shouldBlur = TA_ExecuteTerminalInputLines(lines, { recordLastBlock = true })
  if TA.deferTerminalRefocus then
    self:ClearFocus()
    return
  end
  if shouldBlur then
    self:ClearFocus()
    return
  end
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
  elseif key == "TAB" then
    local partial = (self:GetText() or ""):match("^%s*(.-)%s*$")
    if partial == "" then return end
    local partialLower = partial:lower()

    -- Collect candidates from exact handlers + a static prefix list
    local candidates = {}
    local seen = {}
    if TA.EXACT_INPUT_HANDLERS then
      for cmd in pairs(TA.EXACT_INPUT_HANDLERS) do
        if not seen[cmd] and cmd:sub(1, #partialLower) == partialLower then
          seen[cmd] = true
          table.insert(candidates, cmd)
        end
      end
    end
    -- Also include known prefix commands not fully in EXACT_INPUT_HANDLERS
    local prefixCmds = {
      "equip ", "binditem ", "moveitem ", "bind ", "bindmacro ",
      "actions ", "bars ", "sell ", "destroy ", "use ",
      "mark ", "unmark ", "renamemark ", "goto ", "route ",
      "ml xp ", "ml xp warrior ", "ml xp set ", "ml xp mode ",
      "recipes ", "recipes search", "recipes makeable",
      "bug show ", "bug copy ",
      "df ", "df size ", "df grid ", "df cell ", "df markradius ",
      "df rotation ", "df orientation ", "df square ",
      "df profile ", "df view ", "df hue ", "df legend ", "df calibrate ",
      "memory ", "focus ", "castfocus ", "macro ", "macroinfo ",
      "skills weapons", "skills professions", "skills defense",
      "help ", "help advanced", "help combat", "help economy",
      "help navigation", "help social", "help quests",
      "swingtimer ",
    }
    for _, cmd in ipairs(prefixCmds) do
      local cmdLower = cmd:lower()
      if not seen[cmdLower] and cmdLower:sub(1, #partialLower) == partialLower then
        seen[cmdLower] = true
        table.insert(candidates, cmd)
      end
    end

    if #candidates == 0 then return end

    table.sort(candidates)

    if #candidates == 1 then
      -- Unique match: complete it
      self:SetText(candidates[1])
      self:SetCursorPosition(#candidates[1])
    else
      -- Multiple matches: find longest common prefix then show list
      local common = candidates[1]
      for i = 2, #candidates do
        local c = candidates[i]
        local newCommon = ""
        for j = 1, math.min(#common, #c) do
          if common:sub(j, j):lower() == c:sub(j, j):lower() then
            newCommon = newCommon .. common:sub(j, j)
          else
            break
          end
        end
        common = newCommon
      end
      if #common > #partial then
        self:SetText(common)
        self:SetCursorPosition(#common)
      end
      -- Print candidates to terminal
      local MAX_SHOW = 12
      local display = {}
      for i = 1, math.min(#candidates, MAX_SHOW) do
        table.insert(display, candidates[i])
      end
      local suffix = #candidates > MAX_SHOW and string.format(" (+%d more)", #candidates - MAX_SHOW) or ""
      AddLine("system", "  " .. table.concat(display, "  |  ") .. suffix)
    end
  end
end)

SLASH_TEXTADVENTURER1 = "/ta"
rawset(SlashCmdList, "TEXTADVENTURER", function(msg)
  local original = (msg or ""):match("^%s*(.-)%s*$")
  local lower = original:lower()
  if lower == "" then
    TA_FocusTerminalInput(true)
  elseif lower == "input" or lower == "i" or lower == "t" then
    TA_FocusTerminalInput(true)
  elseif lower == "stream" or lower:sub(1, 7) == "stream " then
    local rest = original:sub(7):match("^%s*(.-)%s*$") or ""
    local handler = SlashCmdList and SlashCmdList["TASTREAM"]
    if handler then handler(rest) else AddLine("system", "Stream handler unavailable.") end
  else
    TA_ProcessInputCommand(original)
  end
end)

TA:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    TextAdventurerDB = TextAdventurerDB or {}
    TextAdventurerDB.exploration = TextAdventurerDB.exploration or {}
    TextAdventurerDB.routes = type(TextAdventurerDB.routes) == "table" and TextAdventurerDB.routes or {}
    TextAdventurerDB.sealDpsModel = type(TextAdventurerDB.sealDpsModel) == "table" and TextAdventurerDB.sealDpsModel or {}
    TextAdventurerDB.sealDpsLiveConfig = type(TextAdventurerDB.sealDpsLiveConfig) == "table" and TextAdventurerDB.sealDpsLiveConfig or {}
    TextAdventurerDB.ml = type(TextAdventurerDB.ml) == "table" and TextAdventurerDB.ml or {}
    TA_GetMLStore()
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
    if TextAdventurerDB.performanceModeEnabled == nil then
      TextAdventurerDB.performanceModeEnabled = false
    end
    TA.performanceModeEnabled = TextAdventurerDB.performanceModeEnabled and true or false
    if TA.performanceModeEnabled then
      TA_SetTickerProfile("performance")
    else
      TA_SetTickerProfile("normal")
    end
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
    if TextAdventurerDB.dfModeHueEnabled == nil then
      TextAdventurerDB.dfModeHueEnabled = true
    end
    -- One-time migration: adopt new default (hue on) for legacy characters
    -- that still have old hue=false saved.
    if TextAdventurerDB.dfModeHueDefaultMigratedToOn ~= true then
      TextAdventurerDB.dfModeHueEnabled = true
      TextAdventurerDB.dfModeHueDefaultMigratedToOn = true
    end
    TA.dfModeHueEnabled = TextAdventurerDB.dfModeHueEnabled and true or false
    if TextAdventurerDB.dfModeCalibrationEnabled == nil then
      TextAdventurerDB.dfModeCalibrationEnabled = false
    end
    TA.dfModeCalibrationEnabled = TextAdventurerDB.dfModeCalibrationEnabled and true or false
    if TextAdventurerDB.dfModeLegendEnabled == nil then
      TextAdventurerDB.dfModeLegendEnabled = true
    end
    TA.dfModeLegendEnabled = (TextAdventurerDB.dfModeLegendEnabled ~= false)
    if type(TextAdventurerDB.dfModeGridSize) == "number" then
      local savedGrid = math.floor(TextAdventurerDB.dfModeGridSize)
      if savedGrid < 5 then savedGrid = 5 end
      if savedGrid > 99 then savedGrid = 99 end
      if savedGrid % 2 == 0 then savedGrid = savedGrid + 1 end
      TA.dfModeGridSize = savedGrid
    end
    if type(TextAdventurerDB.dfModeYardsPerCell) == "number" then
      local savedCellYards = math.floor(TextAdventurerDB.dfModeYardsPerCell + 0.5)
      if savedCellYards >= 3 and savedCellYards <= 100 then
        TA.dfModeYardsPerCell = savedCellYards
      else
        TA.dfModeYardsPerCell = nil
        TextAdventurerDB.dfModeYardsPerCell = nil
      end
    else
      TA.dfModeYardsPerCell = nil
    end
    local isFirstRunSafeMode = (TextAdventurerDB.firstRunSafetyAcknowledged ~= true)
    if isFirstRunSafeMode then
      TextAdventurerDB.dfModeWidth = DF_MODE_DEFAULT_WIDTH
      TextAdventurerDB.dfModeHeight = DF_MODE_DEFAULT_HEIGHT
    end
    local maxMarkRadius = math.floor((TA.dfModeGridSize or 35) / 2)
    if type(TextAdventurerDB.dfModeMarkRadius) ~= "number" or TextAdventurerDB.dfModeMarkRadius < 0 or TextAdventurerDB.dfModeMarkRadius > maxMarkRadius then
      TextAdventurerDB.dfModeMarkRadius = 0
    end
    -- One-time migration: old default radius 3 drew extra edge glyphs around marks.
    -- New default is single-cell marks (radius 0) for exact cell visualization.
    if TextAdventurerDB.dfModeMarkRadiusMigratedToZero ~= true and TextAdventurerDB.dfModeMarkRadius == 3 then
      TextAdventurerDB.dfModeMarkRadius = 0
      TextAdventurerDB.dfModeMarkRadiusMigratedToZero = true
    end
    TA_SetDFModeMarkRadius(TextAdventurerDB.dfModeMarkRadius, true)
    if type(TextAdventurerDB.dfModeWidth) ~= "number" or type(TextAdventurerDB.dfModeHeight) ~= "number" then
      TextAdventurerDB.dfModeWidth = DF_MODE_DEFAULT_WIDTH
      TextAdventurerDB.dfModeHeight = DF_MODE_DEFAULT_HEIGHT
    end
    -- One-time migration: expand frames stuck below the new minimum usable width
    if TextAdventurerDB.dfModeWidthExpandedMigration ~= true then
      if TextAdventurerDB.dfModeWidth < DF_MODE_MIN_USABLE_WIDTH then
        TextAdventurerDB.dfModeWidth = DF_MODE_DEFAULT_WIDTH
      end
      TextAdventurerDB.dfModeWidthExpandedMigration = true
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
      if TextAdventurerDB.autoEnable == nil then
        TextAdventurerDB.autoEnable = false
      end
      TextAdventurerDB.firstRunSafetyAcknowledged = true
    elseif TextAdventurerDB.autoEnable == nil then
      TextAdventurerDB.autoEnable = false
    end
    if type(TextAdventurerDB.lineLimit) ~= "number" then
      TextAdventurerDB.lineLimit = TA.lineLimit or 400
    end
    TA_SetLineLimit(TextAdventurerDB.lineLimit, true)
    if TextAdventurerDB.hideScreenshotMessage == nil then
      TextAdventurerDB.hideScreenshotMessage = true
    end
    TA.hideScreenshotMessage = TextAdventurerDB.hideScreenshotMessage and true or false
    TA_InstallScreenshotFilter()
    if ChatFrame1 then
      ChatFrame1:Show()
      ChatFrame1:SetFrameLevel(5000)
    end
    if TextAdventurerDB.autoEnable then
      panel:Show()
    else
      panel:Hide()
    end
    if TA.performanceModeEnabled then
      TA_ApplyPerformanceFrameSuppression()
    end
    TA.bagState = SnapshotBags()
    TA.skillSnapshot = TA_BuildSkillSnapshot()
    TA.lastBuffSnapshot = SnapshotBuffs()
    TA.questObjectiveSnapshot = BuildQuestObjectiveSnapshot()
    TA_GetWarlockPromptConfig()
    local qStore = TA_GetQuestRouterStore()
    TA.questRouteOverlay = nil
    TA.questRouteCandidates = {}
    TA.questRouteLastAt = 0
    if qStore.enabled ~= false then
      TA_BuildQuestRouteCandidates(qStore.topN or 3)
    end
    TA.dpsSessionStart = GetTime()
    TA.dpsTotalDamage = TA.dpsTotalDamage or 0
    TA.dpsCombatStart = 0
    TA.dpsCombatDamage = 0
    TA.lastCombatDamage = TA.lastCombatDamage or 0
    TA.lastCombatDuration = TA.lastCombatDuration or 0
    ResetSwingTimer()
    AddLine("system", "You enter the world.")
    AddLine("system", "WARNING: This addon is extremely dangerous and WILL eventually get your character killed.")
    if TextAdventurerDB.autoEnable then
      AddLine("system", "Autostart is ON. Type 'autostart off' to disable.")
    else
      AddLine("system", "Autostart is OFF. Type 'autostart on' to auto-open on login.")
    end
    AddLine("system", "Type /ta textmode on for full black-screen text mode.")
    AddLine("system", "Type /ta status for health and rage.")
    AddLine("system", "Type /ta xp for experience.")
    AddLine("system", "Type /ta quests to list your quest log.")
    AddLine("system", "Type /ta questinfo <index or name> to read full quest details.")
    AddLine("quest", "Route planner: /ta questroute, /ta questroute explain, /ta questroute top 5, /ta questroute mark.")
    AddLine("playerCombat", "Warlock prompt: /ta warlockprompt for next action, /ta warlockprompt on for auto prompts in combat.")
    if (select(2, UnitClass("player")) or "") == "WARRIOR" then
      AddLine("playerCombat", "Warrior prompt: /ta warriorprompt for next action, /ta warriorprompt on for auto prompts in combat.")
    end
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
    local terrainData = TA_GetLoadedTerrainData()
    if terrainData then
      local chunkCount = (type(terrainData.chunks) == "table") and #terrainData.chunks or 0
      local markerCount = (type(terrainData.markers) == "table") and #terrainData.markers or 0
      local tileCount = (type(terrainData.tilesPresent) == "table") and #terrainData.tilesPresent or 0
      AddLine("system", string.format("Terrain dataset loaded: zone=%s map=%s chunks=%d markers=%d tiles=%d", tostring(terrainData.zoneKey or "?"), tostring(terrainData.mapName or "?"), chunkCount, markerCount, tileCount))
    else
      AddLine("system", "Terrain dataset not loaded. Expected: TerrainData_Azeroth.lua")
    end
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
    TA_EnsureRuntimeTickers()
    TA_PublishPublicAPI()
    TA_EmitExternal("READY", TA_GetIntegrationStateSnapshot())
    if TextAdventurerDB.autoEnable then
      TA_EnableTextModeInternal()
      panel.inputBox:SetFocus()
    end
    TA_InitCommandPreviewBox()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    TA:ProfileStart("COMBAT_LOG_EVENT_UNFILTERED")
    local subevent = HandleCombatLog()
    if subevent and AWARENESS_SUBEVENTS[subevent] then
      TA_RequestAwarenessRefresh(false)
    end
    TA:ProfileEnd("COMBAT_LOG_EVENT_UNFILTERED")
  elseif CHAT_EVENT_INFO[event] then
    TA:ProfileStart("HandleChatEvent")
    HandleChatEvent(event, ...)
    TA:ProfileEnd("HandleChatEvent")
  elseif event == "PLAYER_TARGET_CHANGED" then
    CheckTarget()
    TA.lastTargetBearingBucket = nil
    if UnitExists("target") and not UnitIsDead("target") then
      TA_NarrateBearing("target")
      if TA._streamEnabled then
        local b = TA_RelativeBearing("target")
        TA_EmitExternal("TARGET", {
          name = UnitName("target"),
          guid = UnitGUID("target"),
          level = UnitLevel("target"),
          hp = UnitHealth("target"), hpMax = UnitHealthMax("target"),
          hostile = UnitCanAttack("player", "target") and true or false,
          bearing = b,
        })
      end
    elseif TA._streamEnabled then
      TA_EmitExternal("TARGET", { cleared = true })
    end
    TA_RequestAwarenessRefresh(true)
  elseif event == "PLAYER_MONEY" then
    TA:ReportMoneyStatusEvent()
  elseif event == "PLAYER_REGEN_DISABLED" then
    TA.dpsCombatStart = GetTime()
    TA.dpsCombatDamage = 0
    TA.mlFightSnapshot = TA_CaptureMLFeatures()
    AddLine("playerCombat", "You enter combat.")
    ShowWarningMessage("UNDER ATTACK!")
    ReportStatus(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if TA.dpsCombatStart and TA.dpsCombatStart > 0 then
      local dur = math.max(0.001, GetTime() - TA.dpsCombatStart)
      TA.lastCombatDuration = dur
      TA.lastCombatDamage = TA.dpsCombatDamage or 0
      TA_LogMLFightResult(dur, TA.lastCombatDamage)
      TA.dpsCombatStart = 0
      TA.dpsCombatDamage = 0
      AddLine("playerCombat", string.format("Fight summary: %.1f DPS (%d damage over %.1fs)", (TA.lastCombatDamage or 0) / dur, math.floor((TA.lastCombatDamage or 0) + 0.5), dur))
    end
    TA.lastCombatEndedAt = GetTime()
    TA.mlFightSnapshot = nil
    AddLine("playerCombat", "You leave combat.")
    ReportStatus(true)
    TA_ProcessSellJunkQueue("combat_end")
    if TA.performanceModeEnabled and TA.performancePendingApply then
      TA_ApplyPerformanceFrameSuppression()
    end
  elseif event == "QUEST_TURNED_IN" then
    TA_HandleMLXPSourceEvent(event, ...)
    local questID, xpReward = ...
    TA_QuestRouteLearnFromTurnIn(questID, xpReward)
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
    TA_HandleMLXPSourceEvent(event, ...)
  elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    TA_HandleMLXPSourceEvent(event, ...)
    if TA_RecordGuideXPSample then
      TA_RecordGuideXPSample()
    end
    TA:ReportXPStatusEvent()
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
      TA_ApplyTextModeFrames()
      panel:Show()
      panel.inputBox:Show()
      panel.inputBox:SetFocus()
    end
    SyncTextModeOverlay()
    ReportLocation(true)
    UpdateExplorationMemory()
    UpdateRecentPath()
  elseif event == "LOOT_OPENED" then
    AddLine("loot", "You begin looting.")
    ReportLootWindowPreview()
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
    TA_ProcessSellJunkQueue("bagupdate")
  elseif event == "MERCHANT_SHOW" then
    TA.vendorOpen = true
    AddLine("loot", "A merchant opens their wares. Type 'vendor' to browse, 'buy <n>', 'buyback [n]', 'sell <bag> <slot>', 'selljunk', or 'repair'/'repairstatus'.")
    ReportVendorItems()
  elseif event == "WHO_LIST_UPDATE" then
    TA_ReportWhoList()
  elseif event == "MERCHANT_CLOSED" then
    if TA.sellJunkState and TA.sellJunkState.active then
      AddLine("system", "Stopped selljunk: merchant window closed.")
      TA.sellJunkState = nil
    end
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
  elseif event == "TRADE_SKILL_SHOW" then
    AddLine("quest", "Profession opened. Type recipes or recipeinfo <index>.")
  elseif event == "CRAFT_SHOW" then
    AddLine("quest", "Crafting opened. Type recipes or recipeinfo <index>.")
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
    local qStore = TA_GetQuestRouterStore()
    if qStore.enabled ~= false then
      if (GetTime() - (TA.questRouteLastAt or 0)) > 1 then
        TA_BuildQuestRouteCandidates(qStore.topN or 3)
      end
    end
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
      TA_RequestAwarenessRefresh(false)
    elseif unit == "focus" then
      TA_RequestAwarenessRefresh(false)
    end
  elseif event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" then
      ReportBuffChanges()
    elseif unit == "target" or unit == "focus" then
      TA_RequestAwarenessRefresh(false)
    end
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    TA_RequestAwarenessRefresh(true)
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
  elseif event == "SKILL_LINES_CHANGED" then
    TA_ReportSkillLevels(false)
  end
end)

TA:RegisterEvent("PLAYER_MONEY")
TA:RegisterEvent("PLAYER_LOGIN")
TA:RegisterEvent("PLAYER_ENTERING_WORLD")
TA:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
TA:RegisterEvent("PLAYER_TARGET_CHANGED")
TA:RegisterEvent("PLAYER_REGEN_DISABLED")
TA:RegisterEvent("PLAYER_REGEN_ENABLED")
TA:RegisterEvent("NAME_PLATE_UNIT_ADDED")
TA:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
TA:RegisterEvent("PLAYER_XP_UPDATE")
TA:RegisterEvent("PLAYER_LEVEL_UP")
TA:RegisterEvent("QUEST_TURNED_IN")
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
TA:RegisterEvent("TRADE_SKILL_SHOW")
TA:RegisterEvent("CRAFT_SHOW")
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
TA:RegisterEvent("SKILL_LINES_CHANGED")
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
TA:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
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

-- Module bridge exports: command modules run in separate chunks and cannot access
-- this file's local functions directly.
_G.AddLine = AddLine

_G.ReportLocation = ReportLocation
_G.ReportStatus = ReportStatus
_G.ReportXP = ReportXP
_G.ReportTracking = ReportTracking
_G.ReportQuestLog = ReportQuestLog
_G.ReportQuestInfo = ReportQuestInfo
_G.ReportBuffs = ReportBuffs
_G.ReportBuffChanges = ReportBuffChanges
_G.ReportMoney = ReportMoney
_G.ResetDPSStats = ResetDPSStats
_G.ReportWeaponDPS = ReportWeaponDPS
_G.ReportDPS = ReportDPS
_G.ReportCharacterStats = ReportCharacterStats
_G.ReportEquipmentChange = ReportEquipmentChange
_G.ReportEquipment = ReportEquipment
_G.ReportInventory = ReportInventory
_G.ReportBank = ReportBank
_G.ReportActionBars = ReportActionBars
_G.ReportMacros = ReportMacros
_G.ReportSpellbook = ReportSpellbook
_G.ReportVendorItems = ReportVendorItems
_G.ReportTrainerServices = ReportTrainerServices
_G.ReportRange = ReportRange
_G.ReportPathMemory = ReportPathMemory
_G.ReportExplorationMemory = ReportExplorationMemory
_G.ReportStaticPopups = ReportStaticPopups
_G.DebugVisiblePopups = DebugVisiblePopups
_G.ReportGossipOptions = ReportGossipOptions
_G.ReportQuestRewardInfo = ReportQuestRewardInfo
_G.ReportLootWindowPreview = ReportLootWindowPreview
_G.ReportSpacingEstimate = ReportSpacingEstimate
_G.ReportTargetPositioning = ReportTargetPositioning

_G.MarkFacingA = MarkFacingA
_G.MarkFacingB = MarkFacingB
_G.MarkCurrentCell = MarkCurrentCell
_G.ListMarkedCells = ListMarkedCells
_G.ClearMarkedCells = ClearMarkedCells
_G.ShowMarkedCellOnMap = ShowMarkedCellOnMap
_G.DeleteMarkedCell = DeleteMarkedCell
_G.ReportCurrentCell = ReportCurrentCell
_G.RecenterCurrentCellAnchor = RecenterCurrentCellAnchor
_G.SetGridSize = SetGridSize
_G.SetCellSizeYards = SetCellSizeYards
_G.DisableCellSizeYardsMode = DisableCellSizeYardsMode
_G.UpdateMapCellOverlay = UpdateMapCellOverlay

_G.BuyVendorItem = BuyVendorItem
_G.SellBagItem = SellBagItem
_G.DestroyBagItem = DestroyBagItem
_G.TrainServiceByIndex = TrainServiceByIndex
_G.TrainAllAvailableServices = TrainAllAvailableServices
_G.ShowMacroInfo = ShowMacroInfo
_G.CastMacroByIndex = CastMacroByIndex
_G.CastMacroByName = CastMacroByName
_G.SetMacroBody = SetMacroBody
_G.ParseRenameArgs = ParseRenameArgs
_G.ParseNameAndBodyArgs = ParseNameAndBodyArgs
_G.RenameMacro = RenameMacro
_G.CreateNewMacro = CreateNewMacro
_G.DeleteMacroByIndex = DeleteMacroByIndex
_G.BindSpellbookSpellToActionSlot = BindSpellbookSpellToActionSlot
_G.BindMacroToActionSlot = BindMacroToActionSlot
_G.DoTargetCommand = DoTargetCommand

_G.ChooseGossipOption = ChooseGossipOption
_G.CompleteQuestFromTerminal = CompleteQuestFromTerminal
_G.ListQuestRewards = ListQuestRewards
_G.SelectQuestReward = SelectQuestReward
_G.GetQuestRewardChoice = GetQuestRewardChoice
_G.RespondToPopup = RespondToPopup

_G.TA_ReportRecipeDetails = TA_ReportRecipeDetails
_G.TA_ReportProfessionRecipes = TA_ReportProfessionRecipes
_G.TA_ReportSkillLevels = TA_ReportSkillLevels
_G.TA_ReportQuestRouteSuggestions = TA_ReportQuestRouteSuggestions
_G.TA_ReportQuestRouteWeights = TA_ReportQuestRouteWeights
_G.TA_ReportQuestRouteDebug = TA_ReportQuestRouteDebug
_G.TA_SetQuestRouteWeight = TA_SetQuestRouteWeight
_G.TA_SetQuestRouteToggle = TA_SetQuestRouteToggle
_G.TA_QuestRouteTomTomWaypoint = TA_QuestRouteTomTomWaypoint
_G.TA_ReportFPS = TA_ReportFPS
_G.TA_ReportPerformanceStatus = TA_ReportPerformanceStatus
_G.TA_EnablePerformanceMode = TA_EnablePerformanceMode
_G.TA_DisablePerformanceMode = TA_DisablePerformanceMode
_G.TA_ReportOpenItemText = TA_ReportOpenItemText
_G.TA_ReportGameSettings = TA_ReportGameSettings
_G.TA_HandleSettingCommand = TA_HandleSettingCommand
_G.TA_SetNamedCVar = TA_SetNamedCVar
_G.TA_ReportNamedCVar = TA_ReportNamedCVar
_G.GRID_SIZE_STANDARD = GRID_SIZE_STANDARD
_G.TA_BuildWeaponDanceReport = TA_BuildWeaponDanceReport
_G.TA_SetSwingDanceHint = TA_SetSwingDanceHint


