-- Modules/MLXPTracker.lua
-- ML XP rate model, fight logging, recommendation engine, and warrior weapon
-- profile helpers for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * ML store + xpRateModel accessors (TA_GetMLStore, TA_GetMLXPRateModel,
--     TA_ResetMLXPRateModel, TA_InitMLXPTracker).
--   * XP source tracking (TA_ParseXPNumberFromText, TA_MarkMLXPSourceHint,
--     TA_UpdateMLXPObservedRate, TA_ResolveMLXPSource, TA_GetTrackedXPDelta,
--     TA_HandleMLXPSourceEvent, TA_GetGuideTopQuestXPPerHour,
--     TA_BlendObservedRate, TA_ReportMLXPRateStatus).
--   * ML logging + tree eval (TA_CaptureMLFeatures, TA_LogMLFightResult,
--     TA_SetMLLogging, TA_ClearMLLogs, TA_SetMLMaxLogs, TA_FormatCSVField,
--     TA_ExportMLLogs, TA_EvalMLTreeNode, TA_RecommendWithML,
--     TA_LoadSampleMLModel, TA_ClearMLModel, TA_ReportMLStatus).
--   * ML XP config (TA_GetMLXPConfig, TA_NormalizeMLXPMode,
--     TA_GetMLXPModeQuestWeight, TA_SetMLXPMode, TA_ReportMLXPMode,
--     TA_ResetMLXPConfigDefaults, TA_SetMLXPConfigValue).
--   * Warrior weapon profile helpers (TA_NormalizeWarriorWeaponProfile,
--     TA_DetectWarriorWeaponProfile, TA_GetWarriorWeaponProfileTuning,
--     TA_ApplyWarriorWeaponProfile, TA_ApplyWarriorPreset) - they live
--     here because they read/write fields on the MLXP config table.
--
-- All functions in this range are declared as plain `function NAME(...)`
-- (true globals) so no promotions are required. Must load AFTER
-- textadventurer.lua (depends on TA, AddLine, ChatPrintf, GetTime, and the
-- warlock/warrior live-config plumbing). Must load BEFORE
-- WarlockMLCommands.lua which binds slash commands to many of these
-- functions. See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 3695-4526 ----
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

