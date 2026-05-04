-- Modules/CharacterReports.lua
-- Character stat / equipment / inventory / bank reporting commands.
--
-- Extracted from textadventurer.lua. Owns:
--   * ReportCharacterStats (promoted; Commands.lua "stats").
--   * ReportEquipmentChange (promoted; called from main file's
--     PLAYER_EQUIPMENT_CHANGED handler).
--   * ReportEquipment (promoted; EconomyCommands.lua "gear"/"equipment").
--   * ReportInventory (promoted; EconomyCommands.lua "inventory"/"bags").
--   * ReportBank (promoted; EconomyCommands.lua "bank").
--   * EQUIP_SLOT_NAMES, EQUIP_SLOTS tables (module-local).
--
-- Depends on shared globals: AddLine, FormatMoney, BagLabel,
-- TA.QUALITY_NAMES, TA.STAT_LABELS. The QUALITY_NAMES / STAT_LABELS
-- TA.* assignments stay in textadventurer.lua's primary location and are
-- referenced here through the TA table.
--
-- Removes the trailing _G.X = X mirrors for the five promoted functions
-- since each is now declared global at definition.
--
-- Loads after textadventurer.lua and before Modules/Commands.lua and
-- Modules/EconomyCommands.lua. .toc slot: between
-- Modules/MacrosAndBindings.lua and Modules/VendorInventory.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2764-2977 ----
function ReportCharacterStats()
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

function ReportEquipmentChange(slotId)
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

function ReportEquipment()
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

      -- Stats via GetItemStats. Classic API: GetItemStats(link) -> table.
      local statsTable = (GetItemStats and link and GetItemStats(link)) or {}
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

function ReportInventory()
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

function ReportBank()
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

