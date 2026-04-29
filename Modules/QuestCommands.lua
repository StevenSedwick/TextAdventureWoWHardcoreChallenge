---@diagnostic disable: undefined-global

function TA_RegisterQuestCommandHandlers(exactHandlers, addPatternHandler)
  if TA.questCommandHandlersRegistered then
    return
  end

  exactHandlers["quests"] = function() ReportQuestLog() end
  exactHandlers["questlog"] = function() ReportQuestLog() end
  exactHandlers["quest log"] = function() ReportQuestLog() end
  exactHandlers["questinfo"] = function() ReportQuestInfo(nil) end
  exactHandlers["questroute"] = function() TA_ReportQuestRouteSuggestions(false, nil) end
  exactHandlers["quest route"] = function() TA_ReportQuestRouteSuggestions(false, nil) end
  exactHandlers["questroute explain"] = function() TA_ReportQuestRouteSuggestions(true, nil) end
  exactHandlers["quest route explain"] = function() TA_ReportQuestRouteSuggestions(true, nil) end
  exactHandlers["questroute weights"] = function() TA_ReportQuestRouteWeights() end
  exactHandlers["quest route weights"] = function() TA_ReportQuestRouteWeights() end
  exactHandlers["questroute debug"] = function() TA_ReportQuestRouteDebug() end
  exactHandlers["quest route debug"] = function() TA_ReportQuestRouteDebug() end
  exactHandlers["questroute mark"] = function() TA_QuestRouteTomTomWaypoint() end
  exactHandlers["quest route mark"] = function() TA_QuestRouteTomTomWaypoint() end
  exactHandlers["questroute on"] = function() TA_SetQuestRouteToggle(true) end
  exactHandlers["quest route on"] = function() TA_SetQuestRouteToggle(true) end
  exactHandlers["questroute off"] = function() TA_SetQuestRouteToggle(false) end
  exactHandlers["quest route off"] = function() TA_SetQuestRouteToggle(false) end
  exactHandlers["gossip"] = function() ReportGossipOptions() end
  exactHandlers["complete"] = function() CompleteQuestFromTerminal() end
  exactHandlers["turnin"] = function() CompleteQuestFromTerminal() end
  exactHandlers["rewards"] = function() ListQuestRewards() end
  exactHandlers["rewardinfo"] = function() AddLine("system", "Usage: rewardinfo <index>") end

  addPatternHandler("^questroute%s+top%s+(%d+)$", function(n) TA_ReportQuestRouteSuggestions(false, tonumber(n)) end)
  addPatternHandler("^quest%s+route%s+top%s+(%d+)$", function(n) TA_ReportQuestRouteSuggestions(false, tonumber(n)) end)
  addPatternHandler("^questroute%s+weight%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetQuestRouteWeight(k, v) end)
  addPatternHandler("^quest%s+route%s+weight%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetQuestRouteWeight(k, v) end)
  addPatternHandler("^questinfo%s+(.+)$", function(arg) ReportQuestInfo(arg) end)
  addPatternHandler("^choose%s+(%d+)$", function(idx) ChooseGossipOption(tonumber(idx)) end)
  addPatternHandler("^select%s+(%d+)$", function(idx) SelectQuestReward(tonumber(idx)) end)
  addPatternHandler("^rewardinfo%s+(%d+)$", function(idx) ReportQuestRewardInfo(tonumber(idx)) end)
  addPatternHandler("^reward%s+(%d+)$", function(idx)
    idx = tonumber(idx)
    SelectQuestReward(idx)
    GetQuestRewardChoice(idx)
  end)
  addPatternHandler("^accept%s+(%d+)$", function(idx) RespondToPopup(tonumber(idx), "accept") end)
  addPatternHandler("^decline%s+(%d+)$", function(idx) RespondToPopup(tonumber(idx), "decline") end)

  TA.questCommandHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterQuestCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
