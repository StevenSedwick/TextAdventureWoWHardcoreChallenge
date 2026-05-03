function TA_FormatMoneyString(copper)
  copper = tonumber(copper) or 0
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local parts = {}
  if g > 0 then table.insert(parts, g .. "g") end
  if s > 0 or g > 0 then table.insert(parts, s .. "s") end
  table.insert(parts, c .. "c")
  return table.concat(parts, " ")
end

function TA_ReportMailInbox()
  if not GetInboxNumItems then
    AddLine("system", "Mail API unavailable. Open a mailbox first.")
    return
  end
  local n = GetInboxNumItems() or 0
  if n == 0 then
    AddLine("loot", "Your mailbox is empty.")
    return
  end
  AddLine("loot", string.format("Mailbox: %d letter(s).", n))
  for i = 1, n do
    local _, _, sender, subject, money, _, daysLeft, hasItem, _, _, _, _, isGM = GetInboxHeaderInfo(i)
    sender = sender or "Unknown"
    subject = subject or "(no subject)"
    local extras = {}
    if money and money > 0 then table.insert(extras, TA_FormatMoneyString(money)) end
    if hasItem and hasItem > 0 then table.insert(extras, hasItem .. " item(s)") end
    if isGM then table.insert(extras, "GM") end
    local suffix = (#extras > 0) and (" [" .. table.concat(extras, ", ") .. "]") or ""
    local days = (type(daysLeft) == "number") and string.format(" (%.1fd left)", daysLeft) or ""
    AddLine("loot", string.format("  %d. %s — %s%s%s", i, sender, subject, suffix, days))
  end
  AddLine("system", "Type 'mail read <n>', 'mail take <n>', 'mail money <n>', 'mail delete <n>', or 'mail send <name> <subject> <body>'.")
end

function TA_ReadMail(index)
  index = tonumber(index)
  if not index or not GetInboxText then
    AddLine("system", "Usage: mail read <n>")
    return
  end
  local n = GetInboxNumItems and (GetInboxNumItems() or 0) or 0
  if index < 1 or index > n then
    AddLine("system", string.format("No letter at slot %d (you have %d).", index, n))
    return
  end
  local _, _, sender, subject, money, _, daysLeft, hasItem = GetInboxHeaderInfo(index)
  local body = GetInboxText(index) or ""
  AddLine("questNpc", string.format("Letter from %s — \"%s\"", sender or "Unknown", subject or "(no subject)"))
  TA_WrapAndPrintQuestText("questText", body)
  if money and money > 0 then
    AddLine("loot", string.format("Enclosed: %s", TA_FormatMoneyString(money)))
  end
  if hasItem and hasItem > 0 then
    AddLine("loot", string.format("Attachments: %d item(s). Use 'mail take %d' to claim.", hasItem, index))
    if GetInboxItemLink then
      for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local link = GetInboxItemLink(index, a)
        if link then AddLine("loot", string.format("  attach %d: %s", a, link)) end
      end
    end
  end
end

function TA_TakeMailMoney(index)
  index = tonumber(index)
  if not index or not TakeInboxMoney then
    AddLine("system", "Usage: mail money <n>")
    return
  end
  TakeInboxMoney(index)
  AddLine("loot", string.format("Took money from letter %d.", index))
end

function TA_TakeMailItems(index)
  index = tonumber(index)
  if not index or not TakeInboxItem then
    AddLine("system", "Usage: mail take <n>")
    return
  end
  local _, _, _, _, money, _, _, hasItem = GetInboxHeaderInfo(index)
  if money and money > 0 and TakeInboxMoney then TakeInboxMoney(index) end
  local count = (hasItem and hasItem > 0) and hasItem or 0
  for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
    if GetInboxItemLink and GetInboxItemLink(index, a) then
      TakeInboxItem(index, a)
    end
  end
  AddLine("loot", string.format("Claimed letter %d (%d attachment(s)).", index, count))
end

function TA_DeleteMail(index)
  index = tonumber(index)
  if not index or not DeleteInboxItem then
    AddLine("system", "Usage: mail delete <n>")
    return
  end
  DeleteInboxItem(index)
  AddLine("loot", string.format("Deleted letter %d.", index))
end

function TA_SendMail(recipient, subject, body)
  if not SendMail or not ClearSendMail then
    AddLine("system", "Mail send API unavailable. Open a mailbox first.")
    return
  end
  if not recipient or recipient == "" or not subject or subject == "" then
    AddLine("system", "Usage: mail send <name> <subject> <body>")
    return
  end
  ClearSendMail()
  SendMail(recipient, subject, body or "")
  AddLine("quest", string.format("Letter sent to %s: \"%s\"", recipient, subject))
end

function TA_RegisterMailCommandHandlers(exactHandlers, addPatternHandler)
  if TA.mailCommandHandlersRegistered then return end

  exactHandlers["mail"] = function() TA_ReportMailInbox() end
  exactHandlers["mailbox"] = function() TA_ReportMailInbox() end
  exactHandlers["inbox"] = function() TA_ReportMailInbox() end

  addPatternHandler("^mail%s+read%s+(%d+)$", function(n) TA_ReadMail(tonumber(n)) end)
  addPatternHandler("^mail%s+take%s+(%d+)$", function(n) TA_TakeMailItems(tonumber(n)) end)
  addPatternHandler("^mail%s+money%s+(%d+)$", function(n) TA_TakeMailMoney(tonumber(n)) end)
  addPatternHandler("^mail%s+delete%s+(%d+)$", function(n) TA_DeleteMail(tonumber(n)) end)
  addPatternHandler("^mail%s+send%s+(%S+)%s+(%S+)%s+(.+)$", function(name, subj, body)
    TA_SendMail(name, subj, body)
  end)
  addPatternHandler("^mail%s+send%s+(%S+)%s+(.+)$", function(name, subj)
    TA_SendMail(name, subj, "")
  end)

  TA.mailCommandHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterMailCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
