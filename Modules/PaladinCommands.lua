function TA_RegisterPaladinCommandHandlers(exactHandlers, addPatternHandler)
  exactHandlers["weapondance"] = function() TA_BuildWeaponDanceReport() end
  exactHandlers["sordance"]    = function() TA_BuildWeaponDanceReport() end

  exactHandlers["swingtimer"]          = function() TA_SetSwingDanceHint("status") end
  exactHandlers["swingtimer on"]       = function() TA_SetSwingDanceHint("on") end
  exactHandlers["swingtimer off"]      = function() TA_SetSwingDanceHint("off") end
  exactHandlers["swingtimer status"]   = function() TA_SetSwingDanceHint("status") end

  addPatternHandler("^swingtimer%s+(.+)$", function(args) TA_SetSwingDanceHint(args) end)
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterPaladinCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
