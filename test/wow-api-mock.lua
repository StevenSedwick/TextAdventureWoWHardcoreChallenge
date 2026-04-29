-- WoW Classic Era API Mock Library for TextAdventurer Testing
-- Provides realistic stubs for core WoW APIs to test addon logic without the game

local MockWoWAPI = {}

-- ============================================================================
-- Global Functions & Tables (make them available globally)
-- ============================================================================

-- Unit tracking
local units = {
  player = {
    name = "TestCharacter",
    level = 60,
    class = "WARRIOR",
    race = "HUMAN",
    health = 2000,
    healthMax = 2000,
    mana = 0,
    manaMax = 0,
    energy = 100,
    energyMax = 100,
    rage = 0,
    rageMax = 100,
    inCombat = false,
  },
  target = {
    name = "TestMob",
    level = 60,
    health = 1000,
    healthMax = 1000,
  },
}

-- Inventory mock
local inventorySlots = {
  [1] = { itemID = 18832, name = "Perdition's Blade", link = "|cff1eff00|Hitem:18832::::::::60::|h[Perdition's Blade]|h|r", quantity = 1, rarity = 4, level = 60 },
  [16] = { itemID = 19323, name = "Nightblade", link = "|cff1eff00|Hitem:19323::::::::60::|h[Nightblade]|h|r", quantity = 1, rarity = 4, level = 60 },
  [5] = { itemID = 22729, name = "Rune of the Guard", link = "|cff0070dd|Hitem:22729::::::::60::|h[Rune of the Guard]|h|r", quantity = 1, rarity = 3, level = 60 },
}

local containers = {
  [0] = { [1] = { itemID = 12345, quantity = 5, rarity = 1, name = "Copper Ore" } },
  [1] = { [1] = { itemID = 12346, quantity = 3, rarity = 1, name = "Tin Ore" } },
}

local actions = {
  [1] = { kind = "spell", id = 100, subType = "spell" },
  [2] = { kind = "spell", id = 6343, subType = "spell" },
  [3] = { kind = "item", id = 12345, subType = "item" },
}

-- Item database
local itemDatabase = {
  [18832] = { name = "Perdition's Blade", rarity = 4, level = 60, type = "Weapon", subtype = "Dagger", stats = { STR = 7, STA = 5 }, armor = 0, durability = 75, maxDurability = 100, sellPrice = 50000 },
  [19323] = { name = "Nightblade", rarity = 4, level = 60, type = "Weapon", subtype = "Sword", stats = { STR = 9, AGI = 6, STA = 4 }, armor = 0, durability = 100, maxDurability = 100, sellPrice = 65000 },
  [22729] = { name = "Rune of the Guard", rarity = 3, level = 60, type = "Armor", subtype = "Chest", stats = { STA = 10, ARM = 200 }, armor = 200, durability = 100, maxDurability = 100, sellPrice = 30000 },
  [12345] = { name = "Copper Ore", rarity = 1, level = 1, type = "Trade Good", stats = {}, armor = 0, sellPrice = 10 },
  [12346] = { name = "Tin Ore", rarity = 1, level = 1, type = "Trade Good", stats = {}, armor = 0, sellPrice = 15 },
}

-- Spell database
local spellDatabase = {
  [100] = { name = "Mortal Strike", icon = "Interface/Icons/ability_warrior_mortalstrike", school = "physical" },
  [6343] = { name = "Thunder Clap", icon = "Interface/Icons/spell_nature_thunderclap", school = "physical" },
  [1680] = { name = "Whirlwind", icon = "Interface/Icons/ability_whirlwind", school = "physical" },
  [48] = { name = "Fireball", icon = "Interface/Icons/spell_fire_fireball", school = "fire" },
  [9472] = { name = "Holy Light", icon = "Interface/Icons/spell_holy_holylight", school = "holy" },
}

-- ============================================================================
-- Item Functions
-- ============================================================================

function GetItemInfo(itemID)
  if not itemDatabase[itemID] then return nil end
  local item = itemDatabase[itemID]
  local qualityIndex = item.rarity or 1
  return item.name, item.link or "", qualityIndex, item.level, item.type, item.subtype, "", "", "", "", item.sellPrice
end

function GetItemStats(itemID)
  if not itemDatabase[itemID] then return {} end
  return itemDatabase[itemID].stats or {}
end

-- For hyperlinks
function GetItemInfoFromHyperlink(link)
  local itemID = link:match("|Hitem:(%d+)")
  if itemID then
    return GetItemInfo(tonumber(itemID))
  end
  return nil
end

-- ============================================================================
-- Container / Inventory Functions
-- ============================================================================

_G.C_Container = {
  GetContainerNumSlots = function(bag)
    if bag == 0 then return 16 end
    if containers[bag] then return 10 end
    return 0
  end,

  GetContainerItemInfo = function(bag, slot)
    if containers[bag] and containers[bag][slot] then
      local item = containers[bag][slot]
      return {
        itemID = item.itemID,
        quantity = item.quantity,
        quality = item.rarity,
        name = item.name,
      }
    elseif bag == 0 and inventorySlots[slot] then
      local item = inventorySlots[slot]
      return {
        itemID = item.itemID,
        quantity = item.quantity,
        quality = item.rarity,
        name = item.name,
      }
    end
    return nil
  end,
}

-- ============================================================================
-- Unit Functions
-- ============================================================================

function UnitHealth(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].health end
  return 0
end

function UnitHealthMax(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].healthMax end
  return 1
end

function UnitMana(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].mana end
  return 0
end

function UnitManaMax(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].manaMax end
  return 1
end

function UnitPower(unit, powerType)
  unit = unit or "player"
  local u = units[unit]
  if not u then return 0 end
  if powerType == 1 then return u.rage or 0 end
  if powerType == 3 then return u.energy or 0 end
  return u.mana or 0
end

function UnitPowerMax(unit, powerType)
  unit = unit or "player"
  local u = units[unit]
  if not u then return 1 end
  if powerType == 1 then return u.rageMax or 100 end
  if powerType == 3 then return u.energyMax or 100 end
  return u.manaMax or 1
end

function UnitPowerType(unit)
  unit = unit or "player"
  local class = units[unit] and units[unit].class or "WARRIOR"
  if class == "WARRIOR" then return 1, "RAGE" end
  if class == "ROGUE" then return 3, "ENERGY" end
  return 0, "MANA"
end

function UnitStat(unit, statIndex)
  local stats = {
    [1] = 120, -- STR
    [2] = 85,  -- AGI
    [3] = 110, -- STA
    [4] = 30,  -- INT
    [5] = 40,  -- SPI
  }
  local base = stats[statIndex] or 0
  return base, base, 0, 0
end

function UnitArmor(unit)
  local base = 1850
  return base, base, 0, 0, 0
end

function UnitAttackPower(unit)
  local base = 420
  return base, 0, 0
end

function UnitRangedAttackPower(unit)
  local base = 180
  return base, 0, 0
end

function UnitAttackSpeed(unit)
  return 2.6, 2.6
end

function GetCritChance()
  return 12.5
end

function GetDodgeChance()
  return 6.2
end

function GetParryChance()
  return 5.1
end

function GetBlockChance()
  return 3.0
end

function UnitLevel(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].level end
  return 1
end

function UnitName(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].name end
  return "Unknown"
end

function UnitClass(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].class end
  return "UNKNOWN"
end

function UnitRace(unit)
  unit = unit or "player"
  if units[unit] then return units[unit].race end
  return "UNKNOWN"
end

function InCombatLockdown()
  return units.player.inCombat
end

-- ============================================================================
-- Spell Functions
-- ============================================================================

function GetSpellInfo(spellID)
  if not spellDatabase[spellID] then return nil end
  local spell = spellDatabase[spellID]
  return spell.name, nil, spell.icon, 0, 0, spell.school
end

function GetSpellCooldown(spellID)
  return 0, 0, true -- (startTime, duration, enabled)
end

-- ============================================================================
-- Money Functions
-- ============================================================================

function GetMoney()
  return 5000000 -- 500 gold
end

function GetInventoryItemLink(unit, slot)
  local item = inventorySlots[slot]
  return item and item.link or nil
end

function GetInventoryItemID(unit, slot)
  local item = inventorySlots[slot]
  return item and item.itemID or nil
end

function GetInventoryItemDurability(slot)
  local item = inventorySlots[slot]
  if not item then return nil, nil end
  local db = itemDatabase[item.itemID] or {}
  return db.durability or 0, db.maxDurability or 0
end

function GetInventoryItemCount(unit, slot)
  local item = inventorySlots[slot]
  return item and (item.quantity or 1) or 0
end

function GetActionInfo(slot)
  local a = actions[slot]
  if not a then return nil end
  return a.kind, a.id, a.subType
end

function GetActionTexture(slot)
  local a = actions[slot]
  if not a then return nil end
  if a.kind == "spell" then
    local spell = spellDatabase[a.id]
    return spell and spell.icon or nil
  end
  return "Interface/Icons/inv_misc_questionmark"
end

function GetActionText(slot)
  return nil
end

function GetActionCooldown(slot)
  return 0, 0, true
end

function IsUsableAction(slot)
  return true, false
end

function IsCurrentAction(slot)
  return false
end

function IsAutoRepeatAction(slot)
  return false
end

-- ============================================================================
-- Money Conversion Helper
-- ============================================================================

function FormatMoney(copper)
  if not copper then copper = 0 end
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local bronze = copper % 100
  return string.format("%dg %ds %dc", gold, silver, bronze)
end

-- ============================================================================
-- UI Frame Functions (Simplified Mocks)
-- ============================================================================

local frameRegistry = {}
local frameCounter = 0

function CreateFrame(frameType, name, parent, template)
  frameCounter = frameCounter + 1
  local id = frameCounter
  
  local frame = {
    _type = frameType,
    _name = name or ("MockFrame" .. id),
    _parent = parent,
    _template = template,
    _visible = true,
    _width = 300,
    _height = 200,
    _x = 0,
    _y = 0,
    _children = {},
    _scripts = {},
    _text = "",
    _fontString = nil,
    _eventHandlers = {},
  }

  function frame:Show() self._visible = true end
  function frame:Hide() self._visible = false end
  function frame:IsVisible() return self._visible end
  function frame:IsShown() return self._visible end
  function frame:SetSize(w, h) self._width = w; self._height = h end
  function frame:SetWidth(w) self._width = w end
  function frame:SetHeight(h) self._height = h end
  function frame:GetWidth() return self._width end
  function frame:GetHeight() return self._height end
  function frame:GetSize() return self._width, self._height end
  function frame:SetPoint(point, relFrame, relPoint, xOfs, yOfs) end
  function frame:SetAllPoints(target) end
  function frame:ClearAllPoints() end
  function frame:SetFrameStrata(strata) self._strata = strata end
  function frame:GetFrameStrata() return self._strata end
  function frame:SetFrameLevel(level) self._level = level end
  function frame:SetAlpha(alpha) self._alpha = alpha end
  function frame:GetAlpha() return self._alpha or 1 end
  function frame:SetMovable(movable) self._movable = movable end
  function frame:EnableMouse(enabled) self._mouse = enabled end
  function frame:EnableKeyboard(enabled) self._keyboard = enabled end
  function frame:RegisterForDrag(...) end
  function frame:SetResizable(enabled) self._resizable = enabled end
  function frame:SetMinResize(w, h) self._minW, self._minH = w, h end
  function frame:SetMaxResize(w, h) self._maxW, self._maxH = w, h end
  function frame:StartMoving() end
  function frame:StopMovingOrSizing() end
  function frame:SetClampedToScreen(enabled) self._clamped = enabled end
  function frame:AddChild(child) table.insert(self._children, child) end
  function frame:SetScript(scriptName, handler) self._scripts[scriptName] = handler end
  function frame:GetScript(scriptName) return self._scripts[scriptName] end
  function frame:RegisterEvent(event) self._eventHandlers[event] = true end
  function frame:UnregisterEvent(event) self._eventHandlers[event] = nil end
  function frame:SetText(text) self._text = text end
  function frame:GetText() return self._text end
  function frame:SetAutoFocus(enabled) self._autoFocus = enabled end
  function frame:SetMaxLetters(maxLetters) self._maxLetters = maxLetters end
  function frame:SetMultiLine(enabled) self._multiLine = enabled end
  function frame:SetTextColor(r, g, b, a) self._textColor = { r = r, g = g, b = b, a = a } end
  function frame:SetTextInsets(left, right, top, bottom) self._textInsets = { left = left, right = right, top = top, bottom = bottom } end
  function frame:SetBlinkSpeed(speed) self._blinkSpeed = speed end
  function frame:SetCursorPosition(pos) self._cursorPos = pos end
  function frame:GetCursorPosition() return self._cursorPos or 0 end
  function frame:Insert(text) self._text = (self._text or "") .. (text or "") end
  function frame:HighlightText(startPos, endPos) end
  function frame:SetFocus() self._hasFocus = true end
  function frame:ClearFocus() self._hasFocus = false end
  function frame:HasFocus() return self._hasFocus or false end
  function frame:SetJustifyH(align) self._justifyH = align end
  function frame:SetJustifyV(align) self._justifyV = align end
  function frame:SetFontObject(fontObject) self._fontObject = fontObject end
  function frame:SetFading(enabled) self._fading = enabled end
  function frame:SetMaxLines(maxLines) self._maxLines = maxLines end
  function frame:SetInsertMode(mode) self._insertMode = mode end
  function frame:SetIndentedWordWrap(enabled) self._wordWrap = enabled end
  function frame:EnableMouseWheel(enabled) self._mouseWheel = enabled end
  function frame:ScrollUp() end
  function frame:ScrollDown() end
  function frame:ScrollToBottom() end
  function frame:AddMessage(msg, r, g, b)
    self._lastMessage = msg
    if self ~= _G.ChatFrame1 and _G.ChatFrame1 and _G.ChatFrame1.AddMessage then
      _G.ChatFrame1:AddMessage(msg, r, g, b)
    end
  end
  function frame:Clear() self._text = "" end
  function frame:SetTexture(path) end
  function frame:SetNormalTexture(path) end
  function frame:SetHighlightTexture(path) end
  function frame:SetPushedTexture(path) end
  function frame:SetBackdrop(backdrop) end
  function frame:SetBackdropColor(r, g, b, a) end
  function frame:SetBackdropBorderColor(r, g, b, a) end
  function frame:CreateTexture(name, layer, template)
    local tx = {
      SetTexture = function(self, path) self._texture = path end,
      SetColorTexture = function(self, r, g, b, a) self._color = { r = r, g = g, b = b, a = a } end,
      SetAllPoints = function(self, target) end,
      SetPoint = function(self, point, relFrame, relPoint, xOfs, yOfs) end,
      SetSize = function(self, w, h) self._width = w; self._height = h end,
      SetWidth = function(self, w) self._width = w end,
      SetHeight = function(self, h) self._height = h end,
      SetAlpha = function(self, alpha) self._alpha = alpha end,
      GetAlpha = function(self) return self._alpha or 1 end,
      SetTexCoord = function(self, left, right, top, bottom) end,
      SetVertexColor = function(self, r, g, b, a) end,
      Show = function(self) self._visible = true end,
      Hide = function(self) self._visible = false end,
      CreateAnimationGroup = function(self)
        local group = {
          CreateAnimation = function(self, animType)
            local anim = {
              SetOrder = function(self, order) self._order = order end,
              SetDuration = function(self, duration) self._duration = duration end,
              SetFromAlpha = function(self, alpha) self._fromAlpha = alpha end,
              SetToAlpha = function(self, alpha) self._toAlpha = alpha end,
            }
            return anim
          end,
          SetLooping = function(self, mode) self._looping = mode end,
          Play = function(self) self._playing = true end,
          Stop = function(self) self._playing = false end,
          IsPlaying = function(self) return self._playing or false end,
        }
        return group
      end,
    }
    return tx
  end
  function frame:CreateFontString(name, layer, template) 
    local fs = {
      _text = "",
      SetText = function(self, t) self._text = t end,
      GetText = function(self) return self._text end,
      SetFont = function(self, font, size, flags) end,
      SetTextColor = function(self, r, g, b, a) end,
      SetJustifyH = function(self, align) self._justifyH = align end,
      SetJustifyV = function(self, align) self._justifyV = align end,
      SetAllPoints = function(self, target) end,
      SetPoint = function(self, point, relFrame, relPoint, xOfs, yOfs) end,
    }
    return fs
  end
  
  if name then frameRegistry[name] = frame end
  return frame
end

function CreateFramePool(frameType, parent, template, resetterFunc, creationFunc)
  return {
    Acquire = function(self) return CreateFrame(frameType, nil, parent, template) end,
    Release = function(self, frame) end,
  }
end

_G.UIParent = CreateFrame("Frame", "UIParent")
_G.SlashCmdList = _G.SlashCmdList or {}

-- ============================================================================
-- Chat Functions
-- ============================================================================

function ChatFrame_AddMessageEventFilter(frame, event, filterFunc)
  -- Stub
end

function ChatFrame_RemoveMessageEventFilter(frame, event, filterFunc)
  -- Stub
end

local chatMessages = {}

function DEFAULT_CHAT_FRAME_AddMessage(frame, msg, r, g, b)
  table.insert(chatMessages, msg)
  print("[CHAT]", msg)
end

_G.ChatFrame1 = CreateFrame("Frame", "ChatFrame1")
_G.ChatFrame1.AddMessage = DEFAULT_CHAT_FRAME_AddMessage

for i = 2, 10 do
  _G["ChatFrame" .. i] = CreateFrame("Frame", "ChatFrame" .. i)
  _G["ChatFrame" .. i].AddMessage = DEFAULT_CHAT_FRAME_AddMessage
end

-- ============================================================================
-- Ace3 Library Stubs
-- ============================================================================

_G.LibStub = function(name, silent)
  if name == "AceEvent-3.0" then
    return {
      RegisterEvent = function(self, event, callback) end,
      UnregisterEvent = function(self, event) end,
      SendMessage = function(self, msg, ...) end,
    }
  elseif name == "AceConsole-3.0" then
    return {
      Print = function(self, ...) print(...) end,
      Printf = function(self, fmt, ...) print(string.format(fmt, ...)) end,
    }
  elseif name == "AceDB-3.0" then
    return {
      New = function(self, defaultData, ...) return defaultData or {} end,
    }
  end
  return {}
end

-- ============================================================================
-- Event System (Simplified)
-- ============================================================================

_G.GameTooltip = CreateFrame("Frame", "GameTooltip")

function RegisterEvent(event, callback)
  -- Stub
end

-- ============================================================================
-- Misc Functions
-- ============================================================================

function GetAddOnMetadata(addon, field)
  if addon == "TextAdventurer" then
    if field == "Version" then return "0.3-alpha10" end
    if field == "Title" then return "TextAdventurer" end
  end
  return nil
end

function IsAddOnLoaded(addon)
  return addon == "TextAdventurer" or addon == "Ace3"
end

_G.date = _G.date or os.date
_G.time = _G.time or os.time

function C_Timer_After(delay, callback)
  callback()
end

_G.C_Timer = {
  After = C_Timer_After,
  NewTicker = function(interval, callback)
    return {
      Cancel = function(self) self._canceled = true end,
    }
  end,
}

-- Map of built-in globals for safe evaluation
function MockWoWAPI.GetMockGlobals()
  return {
    -- Core
    GetItemInfo = GetItemInfo,
    GetItemStats = GetItemStats,
    GetItemInfoFromHyperlink = GetItemInfoFromHyperlink,
    C_Container = C_Container,
    UnitHealth = UnitHealth,
    UnitHealthMax = UnitHealthMax,
    UnitMana = UnitMana,
    UnitManaMax = UnitManaMax,
    UnitLevel = UnitLevel,
    UnitName = UnitName,
    UnitClass = UnitClass,
    UnitRace = UnitRace,
    InCombatLockdown = InCombatLockdown,
    GetSpellInfo = GetSpellInfo,
    GetSpellCooldown = GetSpellCooldown,
    GetMoney = GetMoney,
    FormatMoney = FormatMoney,
    CreateFrame = CreateFrame,
    CreateFramePool = CreateFramePool,
    ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter,
    ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter,
    ChatFrame1 = ChatFrame1,
    UIParent = UIParent,
    LibStub = LibStub,
    GetAddOnMetadata = GetAddOnMetadata,
    IsAddOnLoaded = IsAddOnLoaded,
    C_Timer = C_Timer,
  }
end

-- Setter functions for testing
function MockWoWAPI.SetPlayerHealth(hp, hpMax)
  units.player.health = hp
  units.player.healthMax = hpMax or units.player.healthMax
end

function MockWoWAPI.SetPlayerInCombat(inCombat)
  units.player.inCombat = inCombat
end

function MockWoWAPI.GetChatMessages()
  return chatMessages
end

function MockWoWAPI.ClearChatMessages()
  chatMessages = {}
end

return MockWoWAPI
