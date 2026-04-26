---@diagnostic disable: undefined-global

function TA_RegisterMacroRecipeCommandHandlers(exactHandlers, addPatternHandler)
  if TA.macroRecipeCommandHandlersRegistered then
    return
  end

  exactHandlers["macros"] = function() ReportMacros() end
  exactHandlers["trainer"] = function() ReportTrainerServices() end
  exactHandlers["train list"] = function() ReportTrainerServices() end
  exactHandlers["recipes"] = function() TA_ReportProfessionRecipes() end
  exactHandlers["recipe"] = function() TA_ReportProfessionRecipes() end
  exactHandlers["recipeinfo"] = function() AddLine("system", "Usage: recipeinfo <index>") end

  addPatternHandler("^macroinfo%s+(%d+)$", function(idx) ShowMacroInfo(tonumber(idx)) end)
  addPatternHandler("^macro%s+(%d+)$", function(idx) CastMacroByIndex(tonumber(idx)) end)
  addPatternHandler("^macroset%s+(%d+)%s+(.+)$", function(idx, body) SetMacroBody(tonumber(idx), body) end)
  addPatternHandler("^macrorename%s+(.+)$", function(rest)
    local idx, newName = ParseRenameArgs(rest)
    RenameMacro(idx, newName)
  end)
  addPatternHandler("^macrocreate%s+(.+)$", function(rest)
    local name, body = ParseNameAndBodyArgs(rest)
    CreateNewMacro(name, body)
  end)
  addPatternHandler("^macrodelete%s+(%d+)$", function(idx) DeleteMacroByIndex(tonumber(idx)) end)
  addPatternHandler("^macro%s+(.+)$", function(name) CastMacroByName(name) end)
  addPatternHandler("^train%s+all$", function() TrainAllAvailableServices() end)
  addPatternHandler("^train%s+(%d+)$", function(idx) TrainServiceByIndex(tonumber(idx)) end)
  addPatternHandler("^recipeinfo%s+(%d+)$", function(idx) TA_ReportRecipeDetails(tonumber(idx)) end)
  addPatternHandler("^recipe%s+(%d+)$", function(idx) TA_ReportRecipeDetails(tonumber(idx)) end)

  TA.macroRecipeCommandHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterMacroRecipeCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
