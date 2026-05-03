function TA_AcceptResurrect()
  if AcceptResurrect then
    AcceptResurrect()
    AddLine("status", "You accept the resurrection.")
  else
    AddLine("system", "No resurrection is being offered.")
  end
end

function TA_DeclineResurrect()
  if DeclineResurrect then
    DeclineResurrect()
    AddLine("status", "You decline the resurrection.")
  else
    AddLine("system", "No resurrection is being offered.")
  end
end

function TA_ReleaseSpirit()
  if RepopMe then
    RepopMe()
    AddLine("status", "You release your spirit toward the graveyard.")
  end
end

function TA_RetrieveCorpse()
  if RetrieveCorpse then
    local ok = RetrieveCorpse()
    if ok then
      AddLine("status", "Your spirit returns to your body.")
    else
      AddLine("system", "You must be near your corpse to retrieve it.")
    end
  end
end

function TA_AcceptBinder()
  if ConfirmBinder then
    ConfirmBinder()
    AddLine("quest", "You make this place your home.")
  else
    AddLine("system", "No innkeeper bind prompt is open.")
  end
end

function TA_AcceptDuel()
  if AcceptDuel then
    AcceptDuel()
    AddLine("playerCombat", "You accept the duel.")
  else
    AddLine("system", "No duel has been challenged.")
  end
end

function TA_DeclineDuel()
  if CancelDuel then
    CancelDuel()
    AddLine("playerCombat", "You decline the duel.")
  end
end

function TA_AcceptGroupInvite()
  if AcceptGroup then
    AcceptGroup()
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    AddLine("chat", "You join the group.")
  end
end

function TA_DeclineGroupInvite()
  if DeclineGroup then
    DeclineGroup()
    if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
    AddLine("chat", "You decline the group invite.")
  end
end

function TA_ConfirmReady(isReady)
  if ConfirmReadyCheck then
    ConfirmReadyCheck(isReady and true or false)
    AddLine("chat", isReady and "You signal ready." or "You signal not ready.")
  end
end

function TA_RequestPlayedTime()
  if RequestTimePlayed then
    RequestTimePlayed()
  end
end

function TA_RegisterSocialPromptHandlers(exactHandlers, addPatternHandler)
  if TA.socialPromptHandlersRegistered then return end

  exactHandlers["accept rez"] = function() TA_AcceptResurrect() end
  exactHandlers["accept rezz"] = function() TA_AcceptResurrect() end
  exactHandlers["decline rez"] = function() TA_DeclineResurrect() end
  exactHandlers["decline rezz"] = function() TA_DeclineResurrect() end
  exactHandlers["release"] = function() TA_ReleaseSpirit() end
  exactHandlers["retrieve"] = function() TA_RetrieveCorpse() end
  exactHandlers["bind"] = function() TA_AcceptBinder() end
  exactHandlers["accept duel"] = function() TA_AcceptDuel() end
  exactHandlers["decline duel"] = function() TA_DeclineDuel() end
  exactHandlers["accept group"] = function() TA_AcceptGroupInvite() end
  exactHandlers["decline group"] = function() TA_DeclineGroupInvite() end
  exactHandlers["accept party"] = function() TA_AcceptGroupInvite() end
  exactHandlers["decline party"] = function() TA_DeclineGroupInvite() end
  exactHandlers["ready"] = function() TA_ConfirmReady(true) end
  exactHandlers["notready"] = function() TA_ConfirmReady(false) end
  exactHandlers["not ready"] = function() TA_ConfirmReady(false) end
  exactHandlers["played"] = function() TA_RequestPlayedTime() end
  exactHandlers["timeplayed"] = function() TA_RequestPlayedTime() end

  TA.socialPromptHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterSocialPromptHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
