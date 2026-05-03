-- Modules/QuestRouter.lua
-- Quest router scoring + suggestion engine for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * Default weight table TA_QUEST_ROUTE_DEFAULT_WEIGHTS and clamp/normalize
--     helpers TA_ClampQuestRouteWeight / TA_NormalizeQuestRouteWeights.
--   * Persistent store accessor TA_GetQuestRouterStore.
--   * Questie integration helpers (TA_GetQuestieModule, TA_GetQuestRouteContext,
--     TA_GetQuestStartFromQuestie) and quest log walkers
--     (TA_CollectQuestRouteEntries, TA_GetQuestObjectiveProgressRatio,
--     TA_GetGuideSignal, TA_MapPercentToCells, header/complete flag helpers).
--   * Candidate builder TA_BuildQuestRouteCandidates.
--   * Reporting + slash-command targets: TA_ReportQuestRouteSuggestions,
--     TA_ReportQuestRouteWeights, TA_ReportQuestRouteDebug,
--     TA_SetQuestRouteWeight, TA_SetQuestRouteToggle,
--     TA_QuestRouteLearnFromTurnIn, TA_QuestRouteTomTomWaypoint.
--
-- Must load AFTER textadventurer.lua (depends on AddLine, TA, ChatPrintf,
-- BuildQuestObjectiveSnapshot, GetMapWorldDimensions, GetGridSize,
-- GetCellGridForMap, etc.). See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2315-3010 ----
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

function TA_GetQuestRouterStore()
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

function TA_BuildQuestRouteCandidates(topN)
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

function TA_ReportQuestRouteSuggestions(explain, topN)
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

function TA_ReportQuestRouteWeights()
  local s = TA_GetQuestRouterStore()
  local w = s.weights or {}
  AddLine("system", string.format("Quest route weights: xp=%.3f proximity=%.3f levelFit=%.3f progress=%.3f guide=%.3f", tonumber(w.xp) or 0, tonumber(w.proximity) or 0, tonumber(w.levelFit) or 0, tonumber(w.progress) or 0, tonumber(w.guide) or 0))
  AddLine("system", string.format("learningRate=%.3f samples=%d correct=%d", tonumber(s.learningRate) or 0, tonumber(s.samples) or 0, tonumber(s.correctSuggestions) or 0))
end

function TA_ReportQuestRouteDebug()
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

function TA_SetQuestRouteWeight(key, value)
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

function TA_SetQuestRouteToggle(enabled)
  local s = TA_GetQuestRouterStore()
  s.enabled = enabled and true or false
  if s.enabled then
    AddLine("system", "Quest routing enabled.")
  else
    AddLine("system", "Quest routing disabled.")
    TA.questRouteOverlay = nil
  end
end

function TA_QuestRouteLearnFromTurnIn(questID, xpReward)
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

function TA_QuestRouteTomTomWaypoint()
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

