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
TA.questNarration = "cinematic"
TA.questAcceptDelay = 1.5
TA.questTextWrapWidth = 80
TA.lastQuestNarration = { kind = nil, title = nil, body = nil, npc = nil }
TA.captureChat = true
TA.lastBuffSnapshot = {}
TA.swingReadyAt = 0
TA.swingDanceLog = {}
TA.swingDanceLogMax = 20
TA.lastSwingHintAt = nil
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
_G.GRID_SIZE_DEFAULT = GRID_SIZE_DEFAULT
local GRID_SIZE_MIN = 8
local GRID_SIZE_MAX = 240
_G.GRID_SIZE_MIN = GRID_SIZE_MIN
_G.GRID_SIZE_MAX = GRID_SIZE_MAX
local CELL_YARDS_STANDARD = 30
_G.CELL_YARDS_STANDARD = CELL_YARDS_STANDARD
local CELL_YARDS_MIN = 5
local CELL_YARDS_MAX = 500
_G.CELL_YARDS_MIN = CELL_YARDS_MIN
_G.CELL_YARDS_MAX = CELL_YARDS_MAX
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
  questText = { 0.95, 0.85, 0.55 },
  questNpc  = { 1.00, 0.92, 0.70 },
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
local RecordOutgoingDamage
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
    if CombatLog_Object_IsA and COMBATLOG_FILTER_ME and CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME) then
      TA_RecordSwingReaction()
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
    if CombatLog_Object_IsA and COMBATLOG_FILTER_ME and CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_ME) then
      TA_RecordSwingReaction()
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

function TA_ResolveQuestIndex(arg)
  local total = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
  if total <= 0 then return nil, "Your quest log is empty." end
  if arg and arg ~= "" then
    local n = tonumber(arg)
    if n then
      local title, _, _, isHeader = GetQuestLogTitle(n)
      if not title or isHeader then return nil, string.format("No quest at index %d.", n) end
      return n
    end
    local idx = FindQuestIndexByName(arg)
    if not idx then return nil, string.format("No quest matched '%s'.", arg) end
    return idx
  end
  local idx = GetFallbackQuestIndex()
  if not idx then return nil, "No quest selected. Use the index or quest name." end
  return idx
end

function TA_ReportActiveQuestRewards(arg)
  if not SelectQuestLogEntry or not GetNumQuestLogRewards then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  local index, err = TA_ResolveQuestIndex(arg)
  if not index then AddLine("system", err); return end
  local title = GetQuestLogTitle(index)
  local prevSel = GetQuestLogSelection and GetQuestLogSelection() or 0
  SelectQuestLogEntry(index)

  AddLine("quest", string.format("Rewards for [%d] %s:", index, title or "?"))

  local money = GetQuestLogRewardMoney and GetQuestLogRewardMoney() or 0
  if money and money > 0 then
    if TA_FormatMoneyString then
      AddLine("quest", "  Money: " .. TA_FormatMoneyString(money))
    else
      AddLine("quest", string.format("  Money: %d copper", money))
    end
  end

  local xp = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
  if xp and xp > 0 then
    AddLine("quest", string.format("  XP: %d", xp))
  end

  local numChoices = GetNumQuestLogChoices and GetNumQuestLogChoices() or 0
  if numChoices > 0 then
    AddLine("quest", string.format("  Choose 1 of %d:", numChoices))
    for i = 1, numChoices do
      local name, _, num, quality = GetQuestLogChoiceInfo(i)
      AddLine("quest", string.format("    [%d] %s x%d", i, name or "?", num or 1))
    end
  end

  local numRewards = GetNumQuestLogRewards() or 0
  if numRewards > 0 then
    AddLine("quest", "  Guaranteed:")
    for i = 1, numRewards do
      local name, _, num, quality = GetQuestLogRewardInfo(i)
      AddLine("quest", string.format("    - %s x%d", name or "?", num or 1))
    end
  end

  local spell = GetQuestLogRewardSpell and (GetQuestLogRewardSpell()) or nil
  if spell and spell ~= "" then
    AddLine("quest", "  Spell: " .. tostring(spell))
  end

  if money == 0 and (xp or 0) == 0 and numChoices == 0 and numRewards == 0 and not spell then
    AddLine("quest", "  (no rewards listed)")
  end

  if prevSel and prevSel > 0 and prevSel ~= index then
    SelectQuestLogEntry(prevSel)
  end
  TA.lastQuestRewardsIndex = index
end

-- Tooltip scraper shared by both active turn-in and quest-log reward detail
local function TA_ScrapeQuestLogItemTooltip(itemType, slot)
  if not CreateFrame or not UIParent then return false end
  if not TA.questLogItemTip then
    TA.questLogItemTip = CreateFrame("GameTooltip", "TextAdventurerQuestLogItemTip", UIParent, "GameTooltipTemplate")
  end
  local tip = TA.questLogItemTip
  if not tip or not tip.SetQuestLogItem then
    AddLine("system", "Tooltip API unavailable.")
    return false
  end
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetQuestLogItem(itemType, slot)
  local tipName = tip:GetName()
  local shown = 0
  for i = 1, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local lt = left and left:GetText() or ""
    local rt = right and right:GetText() or ""
    if lt ~= "" or rt ~= "" then
      local line = (rt ~= "") and (lt ~= "" and lt .. "  " .. rt or rt) or lt
      AddLine("quest", line)
      shown = shown + 1
      if shown >= 20 then AddLine("quest", "(truncated)"); break end
    end
  end
  tip:Hide()
  return shown > 0
end

function TA_ReportQuestLogRewardItemInfo(arg)
  -- arg: "[choice|reward] <slot>" or "<questArg> [choice|reward] <slot>"
  -- Falls back to TA.lastQuestRewardsIndex if no quest specified
  if not SelectQuestLogEntry then
    AddLine("system", "Quest log API unavailable.")
    return
  end

  local questArg, itemType, slot
  -- Try "<questArg> choice|reward <n>"
  local qa, it, sn = arg:match("^(.-)%s+(choice)%s+(%d+)$")
  if not qa then qa, it, sn = arg:match("^(.-)%s+(reward)%s+(%d+)$") end
  if qa and it and sn then
    questArg = qa ~= "" and qa or nil
    itemType = it
    slot = tonumber(sn)
  else
    -- Try "choice|reward <n>" with no quest prefix
    it, sn = arg:match("^(choice)%s+(%d+)$")
    if not it then it, sn = arg:match("^(reward)%s+(%d+)$") end
    if it and sn then
      itemType = it
      slot = tonumber(sn)
    else
      -- Try just "<n>" (treat as choice)
      sn = arg:match("^(%d+)$")
      if sn then
        itemType = "choice"
        slot = tonumber(sn)
      else
        -- Try "<questArg> <n>"
        qa, sn = arg:match("^(.-)%s+(%d+)$")
        if qa and sn then
          questArg = qa ~= "" and qa or nil
          itemType = "choice"
          slot = tonumber(sn)
        end
      end
    end
  end

  if not slot or slot < 1 then
    AddLine("system", "Usage: quest reward info [choice|reward] <slot>  OR  quest reward info <quest> [choice|reward] <slot>")
    return
  end

  local index
  if questArg then
    local err
    index, err = TA_ResolveQuestIndex(questArg)
    if not index then AddLine("system", err); return end
  else
    index = TA.lastQuestRewardsIndex or GetFallbackQuestIndex()
    if not index then
      AddLine("system", "Run 'quest rewards' first to pick a quest, or specify: quest reward info <quest> <slot>")
      return
    end
  end

  local prevSel = GetQuestLogSelection and GetQuestLogSelection() or 0
  SelectQuestLogEntry(index)

  local name, _, num, quality
  if itemType == "choice" then
    name, _, num, quality = GetQuestLogChoiceInfo and GetQuestLogChoiceInfo(slot)
  else
    name, _, num, quality = GetQuestLogRewardInfo and GetQuestLogRewardInfo(slot)
  end

  if not name then
    AddLine("system", string.format("No %s item at slot %d for that quest.", itemType, slot))
    if prevSel and prevSel > 0 then SelectQuestLogEntry(prevSel) end
    return
  end

  local qualityName = ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" })[(quality or 1) + 1] or "Unknown"
  AddLine("quest", string.format("%s [%d]: %s x%d  (%s)", itemType == "choice" and "Choice" or "Reward", slot, name, num or 1, qualityName))

  local ok = TA_ScrapeQuestLogItemTooltip(itemType, slot)
  if not ok then
    AddLine("quest", "No additional tooltip data available.")
  end

  if prevSel and prevSel > 0 and prevSel ~= index then
    SelectQuestLogEntry(prevSel)
  end
end

TA.pendingAbandon = TA.pendingAbandon or nil

function TA_AbandonQuestFromTerminal(arg)
  if not SelectQuestLogEntry or not SetAbandonQuest or not AbandonQuest then
    AddLine("system", "Abandon API unavailable.")
    return
  end
  local index, err = TA_ResolveQuestIndex(arg)
  if not index then AddLine("system", err); return end
  local title = GetQuestLogTitle(index)
  SelectQuestLogEntry(index)
  TA.pendingAbandon = { index = index, title = title, at = GetTime() }
  AddLine("system", string.format("Abandon [%d] '%s' ? Type 'abandon confirm' within 15s to proceed, or 'abandon cancel'.", index, title or "?"))
end

function TA_ConfirmAbandonQuest()
  local p = TA.pendingAbandon
  if not p then
    AddLine("system", "No quest pending abandon. Use: abandon <index|name>")
    return
  end
  if GetTime() - (p.at or 0) > 15 then
    TA.pendingAbandon = nil
    AddLine("system", "Abandon request timed out. Try again.")
    return
  end
  if not SelectQuestLogEntry or not SetAbandonQuest or not AbandonQuest then
    AddLine("system", "Abandon API unavailable.")
    TA.pendingAbandon = nil
    return
  end
  SelectQuestLogEntry(p.index)
  SetAbandonQuest()
  local confirmName = GetAbandonQuestName and GetAbandonQuestName() or p.title
  AbandonQuest()
  AddLine("system", string.format("Abandoned: %s.", confirmName or p.title or "?"))
  TA.pendingAbandon = nil
end

function TA_CancelAbandonQuest()
  if TA.pendingAbandon then
    AddLine("system", string.format("Abandon of '%s' cancelled.", TA.pendingAbandon.title or "?"))
    TA.pendingAbandon = nil
  else
    AddLine("system", "No abandon pending.")
  end
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
      TA.lastSwingHintAt = GetTime()
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

function TA_RecordSwingReaction()
  local hintAt = TA.lastSwingHintAt
  if not hintAt then return end
  local now = GetTime()
  local delta = now - hintAt
  TA.lastSwingHintAt = nil
  if delta < 0 or delta > 5 then return end
  TA.swingDanceLog = TA.swingDanceLog or {}
  table.insert(TA.swingDanceLog, 1, { delta = delta, at = now })
  local maxN = tonumber(TA.swingDanceLogMax) or 20
  while #TA.swingDanceLog > maxN do
    table.remove(TA.swingDanceLog)
  end
end

function TA_ReportSwingDanceLog(n)
  n = tonumber(n) or 5
  if n < 1 then n = 1 end
  if n > 20 then n = 20 end
  local log = TA.swingDanceLog
  if not log or #log == 0 then
    AddLine("system", "No swing reaction samples yet. Enable 'swingtimer on' and weapon-swap to collect data.")
    return
  end
  local count = math.min(n, #log)
  local sum, best, worst = 0, math.huge, -math.huge
  AddLine("swingDance", string.format("Last %d swing reaction(s) (time from SWING NOW prompt to actual swing):", count))
  for i = 1, count do
    local entry = log[i]
    local ms = entry.delta * 1000
    local ago = GetTime() - entry.at
    sum = sum + ms
    if ms < best then best = ms end
    if ms > worst then worst = ms end
    AddLine("swingDance", string.format("  %d. %.0f ms  (%.0fs ago)", i, ms, ago))
  end
  local avg = sum / count
  AddLine("swingDance", string.format("Avg: %.0f ms | Best: %.0f ms | Worst: %.0f ms", avg, best, worst))
  if GetNetStats then
    local lagMs = tonumber(select(4, GetNetStats())) or 0
    local buf = (tonumber(TA.swingDanceReactionBuffer) or 0.05) * 1000
    AddLine("system", string.format("Lead time given: latency %d ms + buffer %.0f ms = %.0f ms before swing.", lagMs, buf, lagMs + buf))
  end
end

function TA_ResetSwingDanceLog()
  TA.swingDanceLog = {}
  TA.lastSwingHintAt = nil
  AddLine("system", "Swing reaction log cleared.")
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
  elseif cmd == "log" then
    local sub = (args:match("^%S+%s+(%S+)") or ""):lower()
    if sub == "reset" or sub == "clear" then
      TA_ResetSwingDanceLog()
    else
      local n = tonumber(args:match("%S+%s+(%d+)"))
      TA_ReportSwingDanceLog(n or 5)
    end
  else
    AddLine("system", "Usage: swingtimer on|off|status|reaction <ms>|log [n]|log reset")
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

function TA_TryInteractDistance(unit, checkType)
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

function CollectNearbyUnitsWithPositions()
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

  function GetNearbyUnitsWithPositions(forceRefresh)
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
    if type(TextAdventurerDB.questNarration) == "string" then
      local m = TextAdventurerDB.questNarration:lower()
      if m == "cinematic" or m == "instant" or m == "manual" then
        TA.questNarration = m
      end
    end
    local savedDelay = tonumber(TextAdventurerDB.questAcceptDelay)
    if savedDelay and savedDelay >= 0 and savedDelay <= 10 then
      TA.questAcceptDelay = savedDelay
    end
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
      TA_SetTickerProfile("responsive")
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
      if TA._dfModeFrame then TA._dfModeFrame:Show() end
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
  elseif event == "MAIL_SHOW" then
    AddLine("loot", "You open the mailbox.")
    if TA_ReportMailInbox then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.4, function() TA_ReportMailInbox() end)
      else
        TA_ReportMailInbox()
      end
    end
  elseif event == "MAIL_INBOX_UPDATE" then
    if TA.mailInboxAutoRefresh and TA_ReportMailInbox then
      TA_ReportMailInbox()
    end
  elseif event == "MAIL_CLOSED" then
    AddLine("loot", "You close the mailbox.")
  elseif event == "MAIL_SEND_SUCCESS" then
    AddLine("loot", "Your letter is on its way.")
  elseif event == "MAIL_FAILED" then
    AddLine("system", "Mail failed to send.")
  elseif event == "PLAYER_DEAD" then
    AddLine("status", "Your spirit drifts free of your body. Type 'release' to wake at the graveyard.")
  elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
      -- still ghost, ignore
    else
      AddLine("status", "Life returns to you. You stand once more.")
    end
  elseif event == "RESURRECT_REQUEST" then
    local sender = ...
    AddLine("status", string.format("%s offers to bring you back. Type 'accept rez' or 'decline rez'.", tostring(sender or "Someone")))
  elseif event == "CORPSE_IN_RANGE" then
    AddLine("status", "Your corpse lies within reach. Type 'retrieve' to reclaim your body.")
  elseif event == "CORPSE_IN_INSTANCE" then
    AddLine("status", "Your corpse rests inside an instance. Type 'retrieve' to enter and reclaim it.")
  elseif event == "CONFIRM_XP_LOSS" then
    AddLine("status", "The spirit healer offers swift resurrection at a cost. Type 'accept rez' to accept the durability and XP loss.")
  elseif event == "CONFIRM_BINDER" then
    local name = ...
    AddLine("quest", string.format("The innkeeper%s offers to make this your home. Type 'bind' to accept.", name and (" "..name) or ""))
  elseif event == "DUEL_REQUESTED" then
    local challenger = ...
    AddLine("playerCombat", string.format("%s challenges you to a duel! Type 'accept duel' or 'decline duel'.", tostring(challenger or "Someone")))
  elseif event == "DUEL_FINISHED" then
    AddLine("playerCombat", "The duel ends.")
  elseif event == "PARTY_INVITE_REQUEST" then
    local inviter = ...
    AddLine("chat", string.format("%s invites you to a party. Type 'accept group' or 'decline group'.", tostring(inviter or "Someone")))
  elseif event == "READY_CHECK" then
    local initiator, duration = ...
    AddLine("chat", string.format("%s calls a ready check (%ds). Type 'ready' or 'notready'.", tostring(initiator or "The leader"), tonumber(duration) or 0))
  elseif event == "TIME_PLAYED_MSG" then
    local total, level = ...
    if total then
      local h = math.floor(total / 3600)
      AddLine("status", string.format("Time played: %dh on this character.", h))
    end
  elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    local message = ...
    if type(message) == "string" and message ~= "" then
      AddLine("status", "* " .. message)
    end
  elseif event == "PLAYER_UPDATE_RESTING" then
    if IsResting and IsResting() then
      AddLine("status", "You feel a hearth's warmth wash over you. (Rested)")
    else
      AddLine("status", "You step away from rest. The world stirs again.")
    end
  elseif event == "GOSSIP_SHOW" then
    TA_NarrateGossipText()
    TryAutoQuestFromGossip()
    ReportGossipOptions()
  elseif event == "QUEST_GREETING" then
    TA_NarrateQuestGreeting()
    TryAutoQuestFromGossip()
    ReportGossipOptions()


  elseif event == "TRAINER_SHOW" then
    AddLine("quest", "Trainer opened. Type trainer, train 1, or train all.")
  elseif event == "TAXIMAP_OPENED" then
    AddLine("place", "The flight master spreads out a map of routes.")
    if TA_ReportTaxiNodes then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function() TA_ReportTaxiNodes() end)
      else
        TA_ReportTaxiNodes()
      end
    end
  elseif event == "TAXIMAP_CLOSED" then
    AddLine("place", "You roll up the flight master's map.")
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
    TA_NarrateQuestDetail()
    if TA.autoQuests and TA.questNarration ~= "manual" then
      if TA.questNarration == "cinematic" then
        local delay = tonumber(TA.questAcceptDelay) or 1.5
        if C_Timer and C_Timer.After then
          C_Timer.After(delay, function() TryAcceptQuest() end)
        else
          TryAcceptQuest()
        end
      else
        TryAcceptQuest()
      end
    end
  elseif event == "QUEST_PROGRESS" then
    TA_NarrateQuestProgress()
    if TA.autoQuests and TA.questNarration ~= "manual" then
      TryCompleteQuest()
    end
  elseif event == "QUEST_COMPLETE" then
    TA_NarrateQuestReward()
    if TA.autoQuests and TA.questNarration ~= "manual" then
      TryGetQuestReward()
    end
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
TA:RegisterEvent("TAXIMAP_OPENED")
TA:RegisterEvent("TAXIMAP_CLOSED")
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
TA:RegisterEvent("MAIL_SHOW")
TA:RegisterEvent("MAIL_CLOSED")
TA:RegisterEvent("MAIL_INBOX_UPDATE")
TA:RegisterEvent("MAIL_SEND_SUCCESS")
TA:RegisterEvent("MAIL_FAILED")
TA:RegisterEvent("PLAYER_DEAD")
TA:RegisterEvent("PLAYER_UNGHOST")
TA:RegisterEvent("PLAYER_ALIVE")
TA:RegisterEvent("RESURRECT_REQUEST")
TA:RegisterEvent("CORPSE_IN_RANGE")
TA:RegisterEvent("CORPSE_IN_INSTANCE")
TA:RegisterEvent("CONFIRM_XP_LOSS")
TA:RegisterEvent("CONFIRM_BINDER")
TA:RegisterEvent("DUEL_REQUESTED")
TA:RegisterEvent("DUEL_FINISHED")
TA:RegisterEvent("PARTY_INVITE_REQUEST")
TA:RegisterEvent("READY_CHECK")
TA:RegisterEvent("TIME_PLAYED_MSG")
TA:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
TA:RegisterEvent("PLAYER_UPDATE_RESTING")
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
_G.ReportTrainerServices = ReportTrainerServices
_G.ReportRange = ReportRange
_G.ReportPathMemory = ReportPathMemory
_G.ReportExplorationMemory = ReportExplorationMemory
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

_G.TrainServiceByIndex = TrainServiceByIndex
_G.TrainAllAvailableServices = TrainAllAvailableServices
_G.DoTargetCommand = DoTargetCommand


_G.TA_ReportRecipeDetails = TA_ReportRecipeDetails
_G.TA_ReportProfessionRecipes = TA_ReportProfessionRecipes
_G.TA_ReportSkillLevels = TA_ReportSkillLevels
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
_G.TA_SetSwingDanceHint = TA_SetSwingDanceHint


