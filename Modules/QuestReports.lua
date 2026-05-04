-- QuestReports.lua
-- Quest log inspection, info display, reward scraping, abandon flow, and objective
-- snapshot/diff helpers. BuildQuestObjectiveSnapshot and ReportQuestObjectiveChanges
-- are promoted to globals (called from main file event hooks).

function ReportQuestLog()
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

function ReportQuestInfo(arg)
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

function BuildQuestObjectiveSnapshot()
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

function ReportQuestObjectiveChanges()
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
