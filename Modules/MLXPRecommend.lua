-- MLXPRecommend.lua
-- TA_RecommendXPWithML — blends MLXP rate model + observed rate, factors in Paladin/
-- Warrior live option metrics, mana, quest XP, and recommends the best XP source.
-- Depends on globals exposed by MLXPTracker, PaladinSealDPS, WarriorDPS, QuestNarration.
-- All referenced helpers are loaded before this module per .toc ordering.

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
