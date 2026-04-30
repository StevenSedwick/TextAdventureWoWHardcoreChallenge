function TA_RegisterWarlockMLCommandHandlers(exactHandlers, addPatternHandler)
  if TA.warlockMLCommandHandlersRegistered then
    return
  end

  exactHandlers["sealdps"] = function() TA_ReportSealDpsComparison(nil) end
  exactHandlers["seal dps"] = function() TA_ReportSealDpsComparison(nil) end
  exactHandlers["sealdps live"] = function() TA_ReportLiveSealDpsComparison() end
  exactHandlers["sealdps live hybrid"] = function() TA_ReportLiveSealHybridComparison(nil) end
  exactHandlers["sealdps assumptions"] = function() TA_ReportSealLiveAssumptions() end
  exactHandlers["sealdps list"] = function() TA_ReportSealDpsModelRows() end
  exactHandlers["sealdps clear"] = function() TA_ClearSealDpsModel() end
  exactHandlers["sealdps set"] = function() AddLine("system", "Usage: sealdps set <level> <sorDps> <socDps>") end
  exactHandlers["sealdps import"] = function() AddLine("system", "Usage: sealdps import <level:sor:soc,level:sor:soc,...>") end

  exactHandlers["warlockdps"] = function() TA_ReportLiveWarlockDps() end
  exactHandlers["warlock dps"] = function() TA_ReportLiveWarlockDps() end
  exactHandlers["warlockdps live"] = function() TA_ReportLiveWarlockDps() end
  exactHandlers["warlockdps assumptions"] = function() TA_ReportWarlockLiveAssumptions() end
  exactHandlers["warlockdps mapping"] = function() TA_ReportWarlockSheetMapping() end
  exactHandlers["warlockdps reset"] = function() TA_ResetWarlockDpsConfigDefaults() end
  exactHandlers["warlockdps mode"] = function() AddLine("system", "Usage: warlockdps mode <shadow|fire>") end
  exactHandlers["warlockdps set"] = function() AddLine("system", "Usage: warlockdps set <key> <value> (try: warlockdps assumptions)") end
  exactHandlers["warlockprompt"] = function() TA_ReportWarlockActionPrompt(true) end
  exactHandlers["warlock prompt"] = function() TA_ReportWarlockActionPrompt(true) end
  exactHandlers["warlockprompt on"] = function() TA_SetWarlockPromptEnabled(true) end
  exactHandlers["warlock prompt on"] = function() TA_SetWarlockPromptEnabled(true) end
  exactHandlers["warlockprompt off"] = function() TA_SetWarlockPromptEnabled(false) end
  exactHandlers["warlock prompt off"] = function() TA_SetWarlockPromptEnabled(false) end
  exactHandlers["warlockprompt status"] = function() TA_ReportWarlockPromptStatus() end
  exactHandlers["warlock prompt status"] = function() TA_ReportWarlockPromptStatus() end
  exactHandlers["warlockprompt set"] = function() AddLine("system", "Usage: warlockprompt set <manapct|taphpfloor> <value>") end
  exactHandlers["warlock prompt set"] = function() AddLine("system", "Usage: warlockprompt set <manapct|taphpfloor> <value>") end

  exactHandlers["warriorprompt"] = function() TA_ReportWarriorActionPrompt(true) end
  exactHandlers["warrior prompt"] = function() TA_ReportWarriorActionPrompt(true) end
  exactHandlers["warriorprompt on"] = function() TA_SetWarriorPromptEnabled(true) end
  exactHandlers["warrior prompt on"] = function() TA_SetWarriorPromptEnabled(true) end
  exactHandlers["warriorprompt off"] = function() TA_SetWarriorPromptEnabled(false) end
  exactHandlers["warrior prompt off"] = function() TA_SetWarriorPromptEnabled(false) end
  exactHandlers["warriorprompt status"] = function() TA_ReportWarriorPromptStatus() end
  exactHandlers["warrior prompt status"] = function() TA_ReportWarriorPromptStatus() end
  exactHandlers["warriorprompt set"] = function() AddLine("system", "Usage: warriorprompt set <rage|rendrefresh> <value>") end
  exactHandlers["warrior prompt set"] = function() AddLine("system", "Usage: warriorprompt set <rage|rendrefresh> <value>") end

  exactHandlers["ml status"] = function() TA_ReportMLStatus() end
  exactHandlers["ml recommend"] = function() TA_RecommendWithML(false) end
  exactHandlers["ml recommend explain"] = function() TA_RecommendWithML(true) end
  exactHandlers["ml xp"] = function() TA_RecommendXPWithML(false) end
  exactHandlers["ml xp explain"] = function() TA_RecommendXPWithML(true) end
  exactHandlers["ml xp mode"] = function() TA_ReportMLXPMode() end
  exactHandlers["ml xp defaults"] = function() TA_ResetMLXPConfigDefaults() end
  exactHandlers["ml xp rates"] = function() TA_ReportMLXPRateStatus() end
  exactHandlers["ml xp rates reset"] = function() TA_ResetMLXPRateModel() end
  exactHandlers["ml xp set"] = function() AddLine("system", "Usage: ml xp set <key> <value> (use 'ml xp explain' for key list)") end
  exactHandlers["ml xp warrior preset"] = function() AddLine("system", "Usage: ml xp warrior preset <arms|fury>") end
  exactHandlers["ml xp warrior weapon"] = function() AddLine("system", "Usage: ml xp warrior weapon <auto|slow-2h|fast-2h|one-hand|dual-wield>") end
  exactHandlers["ml model sample"] = function() TA_LoadSampleMLModel() end
  exactHandlers["ml model clear"] = function() TA_ClearMLModel() end
  exactHandlers["ml log on"] = function() TA_SetMLLogging(true) end
  exactHandlers["ml log off"] = function() TA_SetMLLogging(false) end
  exactHandlers["ml log clear"] = function() TA_ClearMLLogs() end
  exactHandlers["ml export"] = function() TA_ExportMLLogs(20) end

  addPatternHandler("^sealdps%s+live%s+target%s+(%d+)$", function(level) TA_SetSealLiveNumber("targetLevel", level, 1, 63, "targetLevel") end)
  addPatternHandler("^sealdps%s+live%s+cd%s+([%d%.]+)$", function(seconds) TA_SetSealLiveNumber("judgementCD", seconds, 6, 10, "judgementCD") end)
  addPatternHandler("^sealdps%s+live%s+socppm%s+([%d%.]+)$", function(ppm) TA_SetSealLiveNumber("socPPM", ppm, 4, 12, "socPPM") end)
  addPatternHandler("^sealdps%s+live%s+window%s+([%d%.]+)$", function(seconds) TA_SetSealLiveHybridWindow(seconds) end)
  addPatternHandler("^sealdps%s+live%s+resealgcd%s+([%d%.]+)$", function(seconds) TA_SetSealLiveResealGCD(seconds) end)
  addPatternHandler("^sealdps%s+live%s+hybrid%s+([%d%.]+)$", function(seconds) TA_ReportLiveSealHybridComparison(seconds) end)
  addPatternHandler("^sealdps%s+live%s+behind%s+(%a+)$", function(flag) TA_SetSealLiveBehind(flag) end)
  addPatternHandler("^warlockdps%s+mode%s+([%a%-]+)$", function(mode) TA_SetWarlockMode(mode) end)
  addPatternHandler("^warlockdps%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarlockDpsConfigValue(k, v) end)
  addPatternHandler("^warlockdps%s+reset$", function() TA_ResetWarlockDpsConfigDefaults() end)
  addPatternHandler("^warlockdps%s+mapping$", function() TA_ReportWarlockSheetMapping() end)
  addPatternHandler("^warlockprompt%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarlockPromptValue(k, v) end)
  addPatternHandler("^warlock%s+prompt%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarlockPromptValue(k, v) end)
  addPatternHandler("^warriorprompt%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarriorPromptValue(k, v) end)
  addPatternHandler("^warrior%s+prompt%s+set%s+([%a]+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetWarriorPromptValue(k, v) end)
  addPatternHandler("^ml%s+export%s+(%d+)$", function(n) TA_ExportMLLogs(n) end)
  addPatternHandler("^ml%s+log%s+max%s+(%d+)$", function(n) TA_SetMLMaxLogs(n) end)
  addPatternHandler("^ml%s+xp%s+set%s+(%a+)%s+([%-]?[%d%.]+)$", function(k, v) TA_SetMLXPConfigValue(k, v) end)
  addPatternHandler("^ml%s+xp%s+mode%s+([%a%-]+)$", function(mode) TA_SetMLXPMode(mode) end)
  addPatternHandler("^ml%s+xp%s+warrior%s+preset%s+([%a%-]+)$", function(name) TA_ApplyWarriorPreset(name) end)
  addPatternHandler("^ml%s+xp%s+warrior%s+weapon%s+([%a%-]+)$", function(name) TA_ApplyWarriorWeaponProfile(name) end)
  addPatternHandler("^sealdps%s+(%d+)$", function(level) TA_ReportSealDpsComparison(tonumber(level)) end)
  addPatternHandler("^sealdps%s+set%s+(%d+)%s+([%-]?[%d%.]+)%s+([%-]?[%d%.]+)$", function(level, sor, soc) TA_SetSealDpsModelRow(level, sor, soc) end)
  addPatternHandler("^sealdps%s+import%s+(.+)$", function(payload) TA_ImportSealDpsModel(payload) end)

  TA.warlockMLCommandHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterWarlockMLCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
