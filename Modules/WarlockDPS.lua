-- Modules/WarlockDPS.lua
-- Warlock DPS sheet model + action prompt for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * Warlock mode normalisation/setting (TA_NormalizeWarlockMode, TA_SetWarlockMode).
--   * Sheet/live-config accessors (TA_GetWarlockSheetData, TA_GetWarlockLiveConfig,
--     plus internal helpers TA_GetWarlockSheetDefault, TA_GetWarlockConfigNumber).
--   * Damage modelling helpers (TA_GetWarlockModeSpec, pet/dot/mana contributions,
--     TA_UnitHasPlayerDebuff).
--   * Reporting (TA_ReportWarlockSheetMapping, TA_ReportWarlockLiveAssumptions,
--     TA_ReportLiveWarlockDps).
--   * Action prompt state and reporting (TA_GetWarlockPromptConfig/State,
--     TA_ReportWarlockActionPrompt, TA_SetWarlockPromptEnabled/Value,
--     TA_ReportWarlockPromptStatus, TA_MaybeAutoWarlockPrompt).
--   * General debuff helper TA_GetPlayerDebuffRemaining (also used by warrior
--     prompt in textadventurer.lua) - promoted to global.
--   * Spell-knowledge helper TA_PlayerKnowsAnySpell (warlock-only, kept local).
--
-- Must load AFTER textadventurer.lua (depends on AddLine, ChatPrintf,
-- TA_GetSpellPowerBySchool, TA_GetSpellHitChance, TA_GetSpellCritChanceBySchool,
-- TA_GetWarlockSheetData fallback table TA_WARLOCK_SHEET_DATA, TA, etc.).
-- Must load BEFORE Modules/WarlockMLCommands.lua. See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 3509-4172 ----
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

function TA_GetPlayerDebuffRemaining(unit, spellName)
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

