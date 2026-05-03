-- Modules/PaladinSealDPS.lua
-- Paladin Seal-of-Righteousness vs Seal-of-Command DPS modelling and the
-- live warrior action-prompt metrics for TextAdventurer.
--
-- Extracted from textadventurer.lua. Owns:
--   * SavedVariables-backed seal DPS model: TA_EnsureSealDpsModelTable,
--     TA_GetSealDpsRowsSorted, TA_ReportSealDpsModelRows,
--     TA_SetSealDpsModelRow, TA_ClearSealDpsModel, TA_ImportSealDpsModel,
--     TA_GetSealDpsEstimate, TA_ReportSealDpsComparison.
--   * Live seal-tuning config: TA_GetSealLiveConfig, TA_SetSealLiveNumber,
--     TA_SetSealLiveBehind, TA_ReportSealLiveAssumptions,
--     TA_SetSealLiveHybridWindow, TA_SetSealLiveResealGCD.
--   * Spell rank/talent helpers: TA_GetHighestKnownRank,
--     TA_PlayerKnowsSpellIDs, TA_SelectRankByLevel, TA_SelectRankByNumber,
--     TA_SelectWarriorAbilityRow, TA_GetWarriorTalentRank,
--     TA_GetLiveSpellRankRow.
--   * Caster math: TA_GetSpellPowerHoly, TA_GetSpellPowerBySchool,
--     TA_GetMeleeConnectChance, TA_GetJudgementConnectChance,
--     TA_GetManaRegenPerSecond.
--   * Live warrior prompt state machine: TA_GetWarriorPromptConfig,
--     TA_GetWarriorPromptState, TA_ReportWarriorActionPrompt,
--     TA_SetWarriorPromptEnabled, TA_ReportWarriorPromptStatus,
--     TA_SetWarriorPromptValue, TA_MaybeAutoWarriorPrompt.
--   * Weapon dance reports + comparisons: TA_BuildLiveWarriorOptionMetrics,
--     TA_BuildWeaponDanceReport (was redundantly _G-mirrored — mirror
--     dropped), TA_ReportLiveSealDpsComparison,
--     TA_ReportLiveSealHybridComparison, TA_BuildLiveSealOptionMetrics.
--   * Module-local TA_ScanWeaponTooltip — only used inside the dance
--     report; kept local.
--
-- Must load AFTER textadventurer.lua and BEFORE Modules/PaladinCommands.lua,
-- Modules/WarlockMLCommands.lua, and any module that binds the seal/warrior
-- commands. WarlockDPS.lua already calls TA_GetSpellPowerBySchool and
-- TA_GetManaRegenPerSecond at runtime; load order in the .toc resolves
-- those before any command fires.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2578-3781 ----
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


