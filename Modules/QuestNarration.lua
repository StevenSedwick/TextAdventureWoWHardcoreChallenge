-- Modules/QuestNarration.lua
-- Chat-event narration, quest/gossip narration and acceptance, static-popup
-- inspection and response, plus text-mode frame hiding for TextAdventurer.
--
-- Extracted from textadventurer.lua. Owns:
--   * Chat-event router: HandleChatEvent (was local, now global so the
--     main event frame at the bottom of textadventurer.lua keeps working),
--     CleanSenderName (kept module-local), CHAT_EVENT_INFO global table.
--   * TA_GetNpcName and TA_WrapAndPrintQuestText helpers.
--   * Quest-text narrators: TA_NarrateQuestDetail, TA_NarrateQuestProgress,
--     TA_NarrateQuestReward, TA_NarrateQuestGreeting, TA_NarrateGossipText,
--     TA_ReplayLastQuestText.
--   * Quest accept/decline + narration mode/delay setters:
--     TA_AcceptQuestFromTerminal, TA_DeclineQuestFromTerminal,
--     TA_SetQuestNarrationMode, TA_SetQuestAcceptDelay.
--   * Gossip pool + chooser: TryAutoQuestFromGossip, BuildGossipOptionPool
--     (kept module-local), ReportGossipOptions, ChooseGossipOption,
--     TryAcceptQuest, TryCompleteQuest, TryGetQuestReward,
--     CompleteQuestFromTerminal, ListQuestRewards, SelectQuestReward,
--     GetQuestRewardChoice, ReportQuestRewardInfo (all promoted to true
--     globals so QuestCommands.lua and the TextAdventurer event frame
--     can reach them).
--   * Static-popup inspection/response: BuildStaticPopupList (kept
--     module-local), ReportStaticPopups, DebugVisiblePopups,
--     RespondToPopup (promoted; Commands.lua and QuestCommands.lua call
--     them by name).
--   * Text-mode frame hiding: TA.hiddenFrames table,
--     TA_ForceHideFrameByName, TA_ApplyTextModeFrames. The text-mode
--     toggles themselves (TA_EnableTextModeInternal etc.) stay in the
--     main file because they touch the panel/overlay frames.
--
-- The trailing _G.X = X mirrors at the bottom of textadventurer.lua for
-- ReportStaticPopups, DebugVisiblePopups, ReportGossipOptions,
-- ReportQuestRewardInfo, ChooseGossipOption, CompleteQuestFromTerminal,
-- ListQuestRewards, SelectQuestReward, GetQuestRewardChoice, and
-- RespondToPopup are removed since these functions are now declared
-- global at definition.
--
-- Must load AFTER textadventurer.lua and BEFORE Modules/QuestCommands.lua,
-- Modules/Commands.lua, and any module that binds these names. The .toc
-- slot is between Modules/MLXPTracker.lua and Modules/VendorInventory.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 5285-6092 ----
CHAT_EVENT_INFO = {
  CHAT_MSG_SAY={label="Say",kind="chat"}, CHAT_MSG_YELL={label="Yell",kind="chat"}, CHAT_MSG_EMOTE={label="Emote",kind="chat"}, CHAT_MSG_TEXT_EMOTE={label="TextEmote",kind="chat"}, CHAT_MSG_PARTY={label="Party",kind="chat"}, CHAT_MSG_PARTY_LEADER={label="PartyLead",kind="chat"}, CHAT_MSG_RAID={label="Raid",kind="chat"}, CHAT_MSG_RAID_LEADER={label="RaidLead",kind="chat"}, CHAT_MSG_RAID_WARNING={label="Warning",kind="chat"}, CHAT_MSG_GUILD={label="Guild",kind="chat"}, CHAT_MSG_OFFICER={label="Officer",kind="chat"}, CHAT_MSG_WHISPER={label="Whisper",kind="whisper"}, CHAT_MSG_WHISPER_INFORM={label="To",kind="whisper"}, CHAT_MSG_MONSTER_SAY={label="NPC",kind="chat"}, CHAT_MSG_MONSTER_YELL={label="NPC",kind="chat"}, CHAT_MSG_MONSTER_WHISPER={label="NPC",kind="chat"}, CHAT_MSG_CHANNEL={label="Channel",kind="chat"}, CHAT_MSG_SYSTEM={label="System",kind="system"}
}

local function CleanSenderName(sender)
  if not sender or sender == "" then return "Unknown" end
  return sender:gsub("%-.*$", "")
end

function HandleChatEvent(event, message, sender, _, _, _, _, _, _, channelName)
  if event == "CHAT_MSG_SYSTEM" then
    if TA.captureChat or TA.pendingCVarList then
      if message and message ~= "" then
        AddLine("system", message)
      end
    end
    return
  end
  if not TA.captureChat then return end
  local info = CHAT_EVENT_INFO[event]
  if not info or not message or message == "" then return end
  local name = CleanSenderName(sender)
  local prefix = info.label
  if event == "CHAT_MSG_CHANNEL" and channelName and channelName ~= "" then prefix = channelName end
  AddLine(info.kind, string.format("[%s] %s: %s", prefix, name, message))
end

function TA_GetNpcName()
  if UnitExists and UnitName and UnitExists("npc") then
    return UnitName("npc")
  end
  if UnitExists and UnitName and UnitExists("questnpc") then
    return UnitName("questnpc")
  end
  if UnitExists and UnitName and UnitExists("target") then
    return UnitName("target")
  end
  return nil
end

function TA_WrapAndPrintQuestText(kind, text)
  if type(text) ~= "string" or text == "" then return end
  local width = tonumber(TA.questTextWrapWidth) or 80
  if width < 30 then width = 30 end
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
    if paragraph == "" then
      AddLine(kind, " ")
    else
      local line = ""
      for word in paragraph:gmatch("%S+") do
        if line == "" then
          line = word
        elseif (#line + 1 + #word) <= width then
          line = line .. " " .. word
        else
          AddLine(kind, line)
          line = word
        end
      end
      if line ~= "" then AddLine(kind, line) end
    end
  end
end

function TA_NarrateQuestDetail()
  local title = (GetTitleText and GetTitleText()) or "Quest"
  local body  = (GetQuestText and GetQuestText()) or ""
  local obj   = (GetObjectiveText and GetObjectiveText()) or ""
  local npc   = TA_GetNpcName()
  TA.lastQuestNarration = { kind = "detail", title = title, body = body, objective = obj, npc = npc }
  if npc and npc ~= "" then
    AddLine("questNpc", string.format("%s offers a quest: \"%s\"", npc, title))
  else
    AddLine("questNpc", string.format("New quest offered: \"%s\"", title))
  end
  TA_WrapAndPrintQuestText("questText", body)
  if obj and obj ~= "" then
    AddLine("questNpc", "Objective:")
    TA_WrapAndPrintQuestText("questText", obj)
  end
  if TA.questNarration == "manual" or not TA.autoQuests then
    AddLine("quest", "Type 'accept' to take the quest, or 'decline' to refuse.")
  elseif TA.questNarration == "cinematic" then
    AddLine("quest", string.format("(Auto-accepting in %.1fs. Type 'decline' to cancel.)", TA.questAcceptDelay or 1.5))
  end
end

function TA_NarrateQuestProgress()
  local body = (GetProgressText and GetProgressText()) or ""
  local npc  = TA_GetNpcName()
  TA.lastQuestNarration = { kind = "progress", title = nil, body = body, npc = npc }
  if npc and npc ~= "" then
    AddLine("questNpc", string.format("%s says:", npc))
  end
  TA_WrapAndPrintQuestText("questText", body)
  if TA.questNarration == "manual" or not TA.autoQuests then
    if IsQuestCompletable and IsQuestCompletable() then
      AddLine("quest", "Type 'complete' to hand in the quest.")
    end
  end
end

function TA_NarrateQuestReward()
  local title = (GetTitleText and GetTitleText()) or "Quest"
  local body  = (GetRewardText and GetRewardText()) or ""
  local npc   = TA_GetNpcName()
  TA.lastQuestNarration = { kind = "reward", title = title, body = body, npc = npc }
  if npc and npc ~= "" then
    AddLine("questNpc", string.format("%s completes \"%s\":", npc, title))
  else
    AddLine("questNpc", string.format("Quest complete: \"%s\"", title))
  end
  TA_WrapAndPrintQuestText("questText", body)
  if GetNumQuestChoices then
    local n = GetNumQuestChoices() or 0
    if n > 1 then
      AddLine("quest", string.format("This quest offers %d reward choices. Type 'rewards' to list, then 'reward <n>' to pick.", n))
    end
  end
end

function TA_NarrateQuestGreeting()
  local body = (GetGreetingText and GetGreetingText()) or ""
  local npc  = TA_GetNpcName()
  TA.lastQuestNarration = { kind = "greeting", title = nil, body = body, npc = npc }
  if npc and npc ~= "" then
    AddLine("questNpc", string.format("%s greets you:", npc))
  end
  TA_WrapAndPrintQuestText("questText", body)
end

function TA_NarrateGossipText()
  local body = nil
  if C_GossipInfo and C_GossipInfo.GetText then body = C_GossipInfo.GetText() end
  if (not body or body == "") and GetGossipText then body = GetGossipText() end
  if not body or body == "" then return end
  local npc = TA_GetNpcName()
  TA.lastQuestNarration = { kind = "gossip", title = nil, body = body, npc = npc }
  if npc and npc ~= "" then
    AddLine("questNpc", string.format("%s says:", npc))
  end
  TA_WrapAndPrintQuestText("questText", body)
end

function TA_ReplayLastQuestText(kindFilter)
  local last = TA.lastQuestNarration
  if not last or not last.body or last.body == "" then
    AddLine("system", "No quest text in memory.")
    return
  end
  if kindFilter and last.kind ~= kindFilter then
    AddLine("system", string.format("Last quest text was a %s, not %s.", tostring(last.kind), kindFilter))
    return
  end
  if last.npc and last.npc ~= "" then
    AddLine("questNpc", string.format("%s%s:", last.npc, last.title and (" — \""..last.title.."\"") or ""))
  end
  TA_WrapAndPrintQuestText("questText", last.body)
end

function TA_AcceptQuestFromTerminal()
  if AcceptQuest then
    AcceptQuest()
    AddLine("quest", "Quest accepted.")
  else
    AddLine("system", "No quest dialogue is open.")
  end
end

function TA_DeclineQuestFromTerminal()
  if DeclineQuest then
    DeclineQuest()
    AddLine("quest", "Quest declined.")
  elseif CloseQuest then
    CloseQuest()
    AddLine("quest", "Quest dialogue closed.")
  else
    AddLine("system", "No quest dialogue is open.")
  end
end

function TA_SetQuestNarrationMode(mode)
  mode = (type(mode) == "string") and mode:lower() or ""
  if mode ~= "cinematic" and mode ~= "instant" and mode ~= "manual" then
    AddLine("system", "Usage: quest mode cinematic | instant | manual")
    AddLine("system", string.format("Current mode: %s", tostring(TA.questNarration)))
    return
  end
  TA.questNarration = mode
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.questNarration = mode
  AddLine("quest", string.format("Quest narration mode set to '%s'.", mode))
  if mode == "cinematic" then
    AddLine("quest", "Quest text will print, then auto-accept after a brief pause.")
  elseif mode == "instant" then
    AddLine("quest", "Quest text will print and the quest will be accepted immediately.")
  else
    AddLine("quest", "Quest text will print only. Type 'accept' / 'decline' / 'complete' to act.")
  end
end

function TA_SetQuestAcceptDelay(seconds)
  local s = tonumber(seconds)
  if not s or s < 0 or s > 10 then
    AddLine("system", "Usage: quest delay <seconds 0-10>")
    AddLine("system", string.format("Current delay: %.1fs", TA.questAcceptDelay or 1.5))
    return
  end
  TA.questAcceptDelay = s
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.questAcceptDelay = s
  AddLine("quest", string.format("Quest auto-accept delay set to %.1fs (cinematic mode).", s))
end

function TryAutoQuestFromGossip()
  if not TA.autoQuests then return end
  if C_GossipInfo then
    if C_GossipInfo.GetAvailableQuests and C_GossipInfo.SelectAvailableQuest then
      local available = C_GossipInfo.GetAvailableQuests()
      if available then
        for _, info in ipairs(available) do
          local optionID = info.questID or rawget(info, "optionID")
          if optionID then
            AddLine("quest", string.format("Auto-accepting quest: %s", info.title or "Unknown quest"))
            C_GossipInfo.SelectAvailableQuest(optionID)
            return
          end
        end
      end
    end
    if C_GossipInfo.GetActiveQuests and C_GossipInfo.SelectActiveQuest then
      local active = C_GossipInfo.GetActiveQuests()
      if active then
        for _, info in ipairs(active) do
          local optionID = info.questID or rawget(info, "optionID")
          if optionID and info.isComplete then
            AddLine("quest", string.format("Auto-turning in quest: %s", info.title or "Unknown quest"))
            C_GossipInfo.SelectActiveQuest(optionID)
            return
          end
        end
      end
    end
  end

  if GetNumAvailableQuests and GetAvailableTitle and SelectAvailableQuest then
    local availableCount = tonumber(GetNumAvailableQuests()) or 0
    for i = 1, availableCount do
      local title = GetAvailableTitle(i)
      if title and title ~= "" then
        AddLine("quest", string.format("Auto-accepting quest: %s", title))
        if not pcall(SelectAvailableQuest, i) then
          pcall(SelectAvailableQuest)
        end
        return
      end
    end
  end

  if GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
    local activeCount = tonumber(GetNumActiveQuests()) or 0
    for i = 1, activeCount do
      local title, isComplete = GetActiveTitle(i)
      if title and title ~= "" and isComplete then
        AddLine("quest", string.format("Auto-turning in quest: %s", title))
        if not pcall(SelectActiveQuest, i) then
          pcall(SelectActiveQuest)
        end
        return
      end
    end
  end
end

local function BuildGossipOptionPool()
  local pool = {}
  if C_GossipInfo then
    if C_GossipInfo.GetAvailableQuests then
      local available = C_GossipInfo.GetAvailableQuests() or {}
      for _, info in ipairs(available) do
        local optionID = info.questID or rawget(info, "optionID")
        if optionID then
          table.insert(pool, {
            kind = "availableQuest",
            id = optionID,
            title = info.title or "Available quest",
          })
        end
      end
    end

    if C_GossipInfo.GetActiveQuests then
      local active = C_GossipInfo.GetActiveQuests() or {}
      for _, info in ipairs(active) do
        local optionID = info.questID or rawget(info, "optionID")
        if optionID then
          table.insert(pool, {
            kind = "activeQuest",
            id = optionID,
            title = info.title or "Active quest",
            isComplete = info.isComplete and true or false,
          })
        end
      end
    end

    if C_GossipInfo.GetOptions then
      local options = C_GossipInfo.GetOptions() or {}
      for _, info in ipairs(options) do
        local optionID = info.gossipOptionID or info.optionID
        if optionID then
          table.insert(pool, {
            kind = "gossipOption",
            id = optionID,
            title = info.name or info.title or "Dialogue option",
          })
        end
      end
    end
  end

  if #pool == 0 and GetNumAvailableQuests and GetAvailableTitle then
    local availableCount = tonumber(GetNumAvailableQuests()) or 0
    for i = 1, availableCount do
      local title = GetAvailableTitle(i)
      if title and title ~= "" then
        table.insert(pool, {
          kind = "availableQuestLegacy",
          id = i,
          title = title,
        })
      end
    end
  end

  if #pool == 0 and GetNumActiveQuests and GetActiveTitle then
    local activeCount = tonumber(GetNumActiveQuests()) or 0
    for i = 1, activeCount do
      local title, isComplete = GetActiveTitle(i)
      if title and title ~= "" then
        table.insert(pool, {
          kind = "activeQuestLegacy",
          id = i,
          title = title,
          isComplete = isComplete and true or false,
        })
      end
    end
  end

  return pool
end

function ReportGossipOptions()
  local options = BuildGossipOptionPool()
  if #options == 0 then
    AddLine("quest", "No selectable dialogue options are available right now.")
    return
  end
  AddLine("quest", "Dialogue options:")
  for i = 1, #options do
    local opt = options[i]
    local prefix = "Talk"
    if opt.kind == "availableQuest" or opt.kind == "availableQuestLegacy" then
      prefix = "Quest available"
    elseif opt.kind == "activeQuest" or opt.kind == "activeQuestLegacy" then
      prefix = opt.isComplete and "Quest turn-in" or "Quest in progress"
    end
    AddLine("quest", string.format("  [%d] %s: %s", i, prefix, opt.title))
  end
  AddLine("quest", "Use 'choose <number>' to select one.")
end

function ChooseGossipOption(index)
  if not index or index < 1 then
    AddLine("system", "Usage: choose <number>")
    return
  end
  local options = BuildGossipOptionPool()
  local opt = options[index]
  if not opt then
    AddLine("system", string.format("Invalid dialogue option %d.", index))
    return
  end

  if opt.kind == "availableQuest" and C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
    C_GossipInfo.SelectAvailableQuest(opt.id)
    AddLine("quest", string.format("Selected quest offer: %s", opt.title))
  elseif opt.kind == "availableQuestLegacy" and SelectAvailableQuest then
    if not pcall(SelectAvailableQuest, opt.id) then
      pcall(SelectAvailableQuest)
    end
    AddLine("quest", string.format("Selected quest offer: %s", opt.title))
  elseif opt.kind == "activeQuest" and C_GossipInfo and C_GossipInfo.SelectActiveQuest then
    C_GossipInfo.SelectActiveQuest(opt.id)
    AddLine("quest", string.format("Selected active quest: %s", opt.title))
  elseif opt.kind == "activeQuestLegacy" and SelectActiveQuest then
    if not pcall(SelectActiveQuest, opt.id) then
      pcall(SelectActiveQuest)
    end
    AddLine("quest", string.format("Selected active quest: %s", opt.title))
  elseif opt.kind == "gossipOption" and C_GossipInfo and C_GossipInfo.SelectOption then
    C_GossipInfo.SelectOption(opt.id)
    AddLine("quest", string.format("Selected dialogue option: %s", opt.title))
  else
    AddLine("system", "That dialogue choice is unavailable in this client state.")
  end
end

function TryAcceptQuest()
  if TA.autoQuests and AcceptQuest then
    AcceptQuest()
    AddLine("quest", "Quest accepted.")
  end
end

function TryCompleteQuest()
  if TA.autoQuests and IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
    CompleteQuest()
    AddLine("quest", "Quest ready to turn in.")
  end
end

function TryGetQuestReward()
  if not TA.autoQuests or not GetQuestReward or not GetNumQuestChoices then return end
  local choices = GetNumQuestChoices() or 0
  if choices == 0 then
    GetQuestReward(1)
    AddLine("quest", "Quest turned in.")
  elseif choices == 1 then
    GetQuestReward(1)
    AddLine("quest", "Quest turned in and reward accepted.")
  else
    AddLine("quest", string.format("Quest has %d reward choices. Manual choice needed.", choices))
  end
end

function CompleteQuestFromTerminal()
  if GetNumQuestChoices and GetQuestReward then
    local numChoices = GetNumQuestChoices() or 0
    if numChoices > 0 then
      GetQuestRewardChoice(TA.selectedRewardIndex or 1)
      return
    end
  end
  if not IsQuestCompletable or not IsQuestCompletable() then
    AddLine("quest", "No quest is ready to complete.")
    return
  end
  if not CompleteQuest then
    AddLine("system", "Quest completion API unavailable.")
    return
  end
  CompleteQuest()
  AddLine("quest", "Quest completed and dialogue progressed.")
end

function ListQuestRewards()
  if not GetNumQuestChoices or not GetQuestItemInfo then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  local numChoices = GetNumQuestChoices() or 0
  if numChoices == 0 then
    AddLine("quest", "No reward choices available (quest may auto-complete).")
    return
  end
  AddLine("quest", string.format("Quest has %d reward choice(s):", numChoices))
  for i = 1, numChoices do
    local itemName, itemTexture, itemQuality, itemLevel = GetQuestItemInfo("choice", i)
    if itemName then
      local qualityColor = itemQuality or 1
      local qualityName = ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" })[qualityColor + 1] or "Unknown"
      AddLine("quest", string.format("  [%d] %s (Quality: %s, Level: %d)", i, itemName, qualityName, itemLevel or 0))
    else
      AddLine("quest", string.format("  [%d] (reward item %d)", i, i))
    end
  end
  AddLine("quest", "Use 'select <number>' to pick, then 'complete' to turn in.")
end

function SelectQuestReward(index)
  if not GetNumQuestChoices then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  local numChoices = GetNumQuestChoices() or 0
  if numChoices == 0 then
    AddLine("quest", "No reward choices available.")
    return
  end
  if not index or index < 1 or index > numChoices then
    AddLine("system", string.format("Invalid choice %d. Quest has %d options. Use 'rewards' to list them.", index, numChoices))
    return
  end
  
  -- In WoW Classic, you select a reward by clicking on it in the quest reward frame
  -- We can simulate this by clicking the reward button
  local QuestFrame = _G["QuestFrame"]
  if QuestFrame and QuestFrame:IsVisible() then
    local RewardItemChoice = _G["QuestRewardItem_" .. index]
    if RewardItemChoice and RewardItemChoice:IsVisible() then
      RewardItemChoice:Click()
      TA.selectedRewardIndex = index
      AddLine("quest", string.format("Selected reward choice %d.", index))
      return
    end
  end
  
  -- Fallback: just report which one will be selected
  AddLine("quest", string.format("Selected reward choice %d. Type 'complete' to turn in.", index))
  TA.selectedRewardIndex = index
end

function GetQuestRewardChoice(index)
  if not GetQuestReward then
    AddLine("system", "Quest reward API unavailable.")
    return
  end
  if not index or index < 1 then
    index = TA.selectedRewardIndex or 1
  end
  local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
  if numChoices == 0 then
    GetQuestReward(1)
    AddLine("quest", "Quest turned in with no reward choice.")
  elseif index > numChoices then
    AddLine("system", string.format("Invalid reward choice %d. Quest has %d options.", index, numChoices))
  else
    GetQuestReward(index)
    AddLine("quest", string.format("Quest turned in. Reward choice %d selected.", index))
    TA.selectedRewardIndex = nil
  end
end

function ReportQuestRewardInfo(index)
  if not GetNumQuestChoices or not GetQuestItemInfo then
    AddLine("system", "Quest reward API unavailable.")
    return
  end

  local numChoices = GetNumQuestChoices() or 0
  if numChoices == 0 then
    AddLine("quest", "No reward choices available (quest may auto-complete).")
    return
  end

  index = tonumber(index)
  if not index then
    AddLine("system", "Usage: rewardinfo <index>")
    return
  end
  if index < 1 or index > numChoices then
    AddLine("system", string.format("Invalid choice %d. Quest has %d options. Use 'rewards' to list them.", index, numChoices))
    return
  end

  local itemName, _, itemQuality, itemLevel = GetQuestItemInfo("choice", index)
  local link = GetQuestItemLink and GetQuestItemLink("choice", index)
  local title = itemName or (link and link:match("%[(.-)%]")) or ("Reward " .. tostring(index))
  local qualityName = ({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" })[(itemQuality or 1) + 1] or "Unknown"

  AddLine("quest", string.format("Reward [%d]: %s", index, title))
  AddLine("quest", string.format("Quality: %s | Item level: %d", qualityName, itemLevel or 0))

  if not CreateFrame or not UIParent then
    AddLine("system", "Tooltip inspection API unavailable.")
    return
  end
  if not TA.questRewardInspectTooltip then
    TA.questRewardInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerQuestRewardInspectTooltip", UIParent, "GameTooltipTemplate")
  end

  local tip = TA.questRewardInspectTooltip
  if not tip or not tip.SetQuestItem or not tip.NumLines or not tip.GetName then
    AddLine("system", "Tooltip inspection API unavailable.")
    return
  end

  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetQuestItem("choice", index)

  local tipName = tip:GetName()
  local shown = 0
  local maxLines = 16
  for i = 2, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local leftText = left and left:GetText() or ""
    local rightText = right and right:GetText() or ""
    if leftText ~= "" or rightText ~= "" then
      local lineText = leftText
      if rightText ~= "" then
        if lineText ~= "" then
          lineText = lineText .. "  " .. rightText
        else
          lineText = rightText
        end
      end
      AddLine("quest", lineText)
      shown = shown + 1
      if shown >= maxLines then
        AddLine("quest", "(Additional reward details truncated.)")
        break
      end
    end
  end

  if shown == 0 then
    AddLine("quest", "No additional tooltip details available yet.")
  end

  tip:Hide()
end

local function BuildStaticPopupList()
  local popups = {}
  
  -- In Classic Era, dialogs are registered as StaticPopup1, StaticPopup2, etc.
  -- We need to check them by reference and identify by text content
  for i = 1, 10 do
    local frameName = "StaticPopup" .. i
    local dialog = _G[frameName]
    if dialog and dialog:IsVisible() then
      local text = ""
      if dialog.Text then
        local ok, txt = pcall(function() return dialog.Text:GetText() end)
        text = ok and txt or ""
      end
      
      local kind, title, defaultAction
      
      if text:find("home", 1, true) or text:find("Home", 1, true) then
        kind = "hearthstone"
        title = "Confirm hearthstone location"
        defaultAction = "accept"
      elseif text:find("invite", 1, true) or text:find("Invite", 1, true) then
        kind = "groupInvite"
        title = "Group invite received"
        defaultAction = "accept"
      elseif text:find("duel", 1, true) or text:find("Duel", 1, true) then
        kind = "duelRequest"
        title = "Duel request"
        defaultAction = "decline"
      elseif text:find("delete", 1, true) or text:find("Delete", 1, true) then
        kind = "deleteItem"
        title = "Confirm item deletion"
        defaultAction = "decline"
      elseif text:find("bound to you", 1, true) or text:find("become soulbound", 1, true)
          or text:find("become non%-refundable") or text:find("BIND") or text:find("soulbound") then
        -- BoE equip / refundable-loss confirmation. Default action is accept
        -- so the player can finish equipping the upgrade with /ta accept 1.
        kind = "equipBind"
        title = "Confirm bind on equip"
        defaultAction = "accept"
      end

      -- Generic fallback: surface any popup with at least one button so the
      -- user is never stuck unable to interact with a Blizzard dialog. Title
      -- previews the first ~60 chars of the dialog text.
      if not kind then
        local btn1 = _G[frameName .. "Button1"]
        if btn1 and btn1:IsShown() and text and text ~= "" then
          kind = "generic"
          title = "Dialog: " .. (text:sub(1, 60):gsub("\n", " "))
          defaultAction = "accept"
        end
      end
      
      if kind then
        local btn1Name = frameName .. "Button1"
        local btn2Name = frameName .. "Button2"
        table.insert(popups, {
          kind = kind,
          title = title,
          defaultAction = defaultAction,
          frame = dialog,
          button1 = _G[btn1Name],
          button2 = _G[btn2Name],
        })
      end
    end
  end
  
  return popups
end

function ReportStaticPopups()
  local popups = BuildStaticPopupList()
  if #popups == 0 then
    AddLine("system", "No active prompts or dialogs.")
    return
  end
  AddLine("system", "Active prompts:")
  for i = 1, #popups do
    local p = popups[i]
    AddLine("system", string.format("  [%d] %s (%s)", i, p.title, p.kind))
  end
  AddLine("system", "Use 'accept <number>' or 'decline <number>' to respond.")
end

function DebugVisiblePopups()
  AddLine("system", "=== Scanning StaticPopup1-10 ===")
  
  for i = 1, 10 do
    local frameName = "StaticPopup" .. i
    local dialog = _G[frameName]
    if dialog then
      local isVis = dialog:IsVisible()
      AddLine("system", string.format("%s: visible=%s", frameName, tostring(isVis)))
      
      if isVis then
        -- Show text
        if dialog.Text then
          local ok, txt = pcall(function() return dialog.Text:GetText() end)
          if ok then
            AddLine("system", string.format("  Text: %s", txt))
          end
        end
        
        -- Check for buttons by global name
        local btn1Name = frameName .. "Button1"
        local btn2Name = frameName .. "Button2"
        local btn1 = _G[btn1Name]
        local btn2 = _G[btn2Name]
        
        if btn1 then
          local ok, label = pcall(function() return btn1:GetText() end)
          label = ok and label or "error"
          AddLine("system", string.format("  %s: %s", btn1Name, label))
        end
        if btn2 then
          local ok, label = pcall(function() return btn2:GetText() end)
          label = ok and label or "error"
          AddLine("system", string.format("  %s: %s", btn2Name, label))
        end
      end
    end
  end
  
  AddLine("system", "=== End popup scan ===")
end

function RespondToPopup(index, action)
  if not index or index < 1 then
    AddLine("system", string.format("Usage: %s <number>", action))
    return
  end
  local popups = BuildStaticPopupList()
  local p = popups[index]
  if not p then
    AddLine("system", string.format("No prompt at index %d.", index))
    return
  end
  
  if action == "accept" then
    if p.button1 then
      p.button1:Click()
      if p.kind == "hearthstone" then
        AddLine("quest", "Hearthstone location confirmed.")
      elseif p.kind == "groupInvite" then
        AddLine("quest", "Group invite accepted.")
      elseif p.kind == "duelRequest" then
        AddLine("quest", "Duel accepted.")
      elseif p.kind == "deleteItem" then
        AddLine("loot", "Item deletion confirmed.")
      elseif p.kind == "equipBind" then
        AddLine("loot", "Equip confirmed (item is now soulbound).")
      else
        AddLine("system", string.format("Accepted: %s", p.title))
      end
    else
      AddLine("system", string.format("%s button not accessible.", p.title))
    end
  elseif action == "decline" then
    if p.button2 then
      p.button2:Click()
      if p.kind == "hearthstone" then
        AddLine("quest", "Hearthstone location declined.")
      elseif p.kind == "groupInvite" then
        AddLine("quest", "Group invite declined.")
      elseif p.kind == "duelRequest" then
        AddLine("quest", "Duel declined.")
      elseif p.kind == "deleteItem" then
        AddLine("loot", "Item deletion declined.")
      elseif p.kind == "equipBind" then
        AddLine("loot", "Equip cancelled.")
      else
        AddLine("system", string.format("Declined: %s", p.title))
      end
    else
      AddLine("system", string.format("%s decline button not accessible.", p.title))
    end
  end
end

TA.hiddenFrames = { "MinimapCluster", "MiniMapTracking", "MinimapZoneTextButton", "GameTimeFrame", "PlayerFrame", "TargetFrame", "BuffFrame", "DurabilityFrame" }

function TA_ForceHideFrameByName(name)
  local frame = _G[name]
  if frame then frame:Hide() end
end

function TA_ApplyTextModeFrames()
  for _, name in ipairs(TA.hiddenFrames or {}) do TA_ForceHideFrameByName(name) end
end

