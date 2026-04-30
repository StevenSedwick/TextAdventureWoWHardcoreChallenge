function TA_RegisterSocialCommandHandlers(exactHandlers, addPatternHandler)
  if TA.socialCommandHandlersRegistered then
    return
  end

  exactHandlers["chat on"] = function()
    TA.captureChat = true
    AddLine("chat", "Chat capture enabled.")
  end
  exactHandlers["chat off"] = function()
    TA.captureChat = false
    AddLine("chat", "Chat capture disabled.")
  end

  addPatternHandler("^target%s+(.+)$", function(arg) DoTargetCommand(arg) end)

  TA.socialCommandHandlersRegistered = true
end

function TA_HandleSocialInputCommand(lower, msg)
  if lower == "who" then
    TA_ReportWhoList()
    return true
  end

  local whoQuery = msg:match("^%s*[Ww][Hh][Oo]%s+(.+)$")
  if whoQuery then
    TA_RunWhoQuery(whoQuery)
    return true
  end

  return false
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterSocialCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
