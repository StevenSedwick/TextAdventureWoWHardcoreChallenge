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

function TA_IsSpellKnownCompat(spellID)
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


local DF_MODE_DEFAULT_WIDTH = 400
local DF_MODE_DEFAULT_HEIGHT = 600
local DF_MODE_MIN_USABLE_WIDTH = 300

if ChatFrame1 then
  ChatFrame1:Show()
  ChatFrame1:SetFrameStrata("LOW")
  ChatFrame1:SetFrameLevel(1)
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










-- Command handlers moved to Modules/Commands.lua


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
_G.ReportLootWindowPreview = ReportLootWindowPreview

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

_G.DoTargetCommand = DoTargetCommand


_G.TA_ReportSkillLevels = TA_ReportSkillLevels
_G.TA_ReportOpenItemText = TA_ReportOpenItemText
_G.GRID_SIZE_STANDARD = GRID_SIZE_STANDARD


