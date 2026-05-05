-- Terminal.lua
-- Panel show/hide, text-mode toggle, terminal input execution, slash entry
-- routing, and command/pattern self-test harness.
--
-- Extracted from textadventurer.lua. The named WoW frames
-- TextAdventurerPanel and TextAdventurerOverlay are created in the main
-- file before any module loads, so we can safely cache them here.

local panel = _G.TextAdventurerPanel
local overlay = _G.TextAdventurerOverlay

function SyncTextModeOverlay()
  if TA.textMode then
    overlay:Show()
  else
    overlay:Hide()
  end
  TA_SyncProtectedCommandEditBoxes(TA.textMode and true or false)
  TA_UpdateCommandPreviewBox()
end

function TA_EnableTextModeInternal()
  TA.textMode = true
  panel:Show()
  panel:SetFrameStrata("TOOLTIP")
  panel:SetFrameLevel(11000)
  panel.inputBox:Show()
  SyncTextModeOverlay()
  TA_ApplyTextModeFrames()
  AddLine("system", "Text mode enabled.")
end

function TA_DisableTextModeInternal()
  TA.textMode = false
  SyncTextModeOverlay()
  panel.inputBox:Hide()
  AddLine("system", "Text mode disabled. Hidden frames may need /reload to return.")
end

local function TogglePanel()
  if panel:IsShown() then
    panel:Hide()
    SyncTextModeOverlay()
    if ChatFrame1 then ChatFrame1:Show() end
  else
    panel:Show()
    SyncTextModeOverlay()
  end
end

function TA_ClearTerminalLog()
  wipe(TA.lines)
  panel.text:Clear()
  AddLine("system", "Log cleared.")
end

function TA_ShowPanelCommand()
  panel:Show()
  SyncTextModeOverlay()
  AddLine("system", "Text Adventurer opened.")
end

function TA_HidePanelCommand()
  panel:Hide()
  SyncTextModeOverlay()
  if ChatFrame1 then ChatFrame1:Show() end
end

function TA_TogglePanelCommand()
  TogglePanel()
end

function TA_EnableTextModeCommand()
  TA_EnableTextModeInternal()
end

function TA_DisableTextModeCommand()
  TA_DisableTextModeInternal()
end

function TA_FocusTerminalInput(deferFocus)
  panel:Show()
  panel.inputBox:Show()

  local function FocusNow()
    if panel and panel.inputBox then
      panel.inputBox:SetFocus()
    end
  end

  if deferFocus and C_Timer and C_Timer.After then
    C_Timer.After(0, FocusNow)
  else
    FocusNow()
  end

  AddLine("system", "Terminal input ready.")
end

function TA_ExecuteTerminalInputLines(lines, opts)
  opts = opts or {}
  if type(lines) ~= "table" or #lines == 0 then
    return false
  end

  if opts.recordLastBlock ~= false then
    TA.lastInputBlock = {}
    for i = 1, #lines do
      TA.lastInputBlock[i] = lines[i]
    end
  end

  for i = 1, #lines do
    local line = lines[i]
    AddLine("system", "> " .. line)
    table.insert(TA.inputHistory, line)
    if #TA.inputHistory > TA.inputHistoryMax then table.remove(TA.inputHistory, 1) end
  end
  TA.inputHistoryPos = 0
  TA.inputDraft = ""

  -- Multi-line body folding: if the first line is a body-taking command
  -- (macrocreate / macroset), treat ALL subsequent lines as additional body
  -- lines so multi-line macros can be authored with Shift+Enter.
  if #lines >= 2 then
    local first = lines[1]
    local firstLower = first:lower()

    -- macrocreate <name> [body...] + subsequent body lines
    if firstLower:match("^macrocreate%s+") then
      local rest = first:match("^%S+%s+(.-)%s*$")
      if rest and rest ~= "" then
        local macroName, inlineBody
        if rest:sub(1, 1) == '"' then
          -- quoted name with optional inline body: "Name" body...
          macroName, inlineBody = rest:match('^"([^"]+)"%s*(.*)$')
        else
          -- unquoted single-token name with optional inline body
          macroName, inlineBody = rest:match("^(%S+)%s*(.*)$")
        end
        if macroName and macroName ~= "" then
          local extra = table.concat(lines, "\n", 2)
          local multiBody
          if inlineBody and inlineBody ~= "" then
            multiBody = inlineBody .. "\n" .. extra
          else
            multiBody = extra
          end
          CreateNewMacro(macroName, multiBody)
          return false
        end
      end
    end

    -- macroset <idx> [body...] + subsequent body lines
    local msIdx, msInline = first:match("^[Mm][Aa][Cc][Rr][Oo][Ss][Ee][Tt]%s+(%d+)%s*(.*)$")
    if msIdx then
      local extra = table.concat(lines, "\n", 2)
      local multiBody
      if msInline and msInline ~= "" then
        multiBody = msInline .. "\n" .. extra
      else
        multiBody = extra
      end
      SetMacroBody(tonumber(msIdx), multiBody)
      return false
    end
  end

  TA.deferTerminalRefocus = false
  for i = 1, #lines do
    TA_ProcessInputCommand(lines[i])
    if TA.deferTerminalRefocus then
      return true
    end
  end

  return false
end

function TA_RunLastInputBlock()
  if TA.isReplayingLastBlock then
    AddLine("system", "runlast is already replaying.")
    return
  end
  if type(TA.lastInputBlock) ~= "table" or #TA.lastInputBlock == 0 then
    AddLine("system", "No previous multiline block to replay.")
    return
  end

  local lines = {}
  for i = 1, #TA.lastInputBlock do
    lines[i] = TA.lastInputBlock[i]
  end

  TA.isReplayingLastBlock = true
  local ok, err = pcall(function()
    TA_ExecuteTerminalInputLines(lines, { recordLastBlock = false })
  end)
  TA.isReplayingLastBlock = false

  if not ok then
    AddLine("system", "runlast failed: " .. tostring(err))
  end
end

function TA_SendFromTerminal(msg)
  local cmd, rest = msg:match("^/(%S+)%s*(.*)$")
  if not cmd then return false end
  cmd = cmd:lower()
  local protectedSlashCommands = {
    logout = true,
    camp = true,
    quit = true,
    exit = true,
    cast = true,
    stopcasting = true,
    castsequence = true,
    use = true,
    equip = true,
    equipslot = true,
    petattack = true,
    petfollow = true,
    petpassive = true,
    petdefensive = true,
    petaggressive = true,
    startattack = true,
    stopattack = true,
    cancelaura = true,
    cancelform = true,
    click = true,
    -- Targeting (calls protected TargetUnit/AssistUnit/FocusUnit):
    target = true,
    targetexact = true,
    targetenemy = true,
    targetfriend = true,
    targetparty = true,
    targetraid = true,
    targetlasttarget = true,
    targetlastenemy = true,
    targetlastfriend = true,
    assist = true,
    focus = true,
    clearfocus = true,
    cleartarget = true,
  }
  if cmd == "s" or cmd == "say" then
    SendChatMessage(rest, "SAY")
  elseif cmd == "y" or cmd == "yell" then
    SendChatMessage(rest, "YELL")
  elseif cmd == "p" or cmd == "party" then
    SendChatMessage(rest, "PARTY")
  elseif cmd == "g" or cmd == "guild" then
    SendChatMessage(rest, "GUILD")
  elseif cmd == "raid" or cmd == "ra" then
    SendChatMessage(rest, "RAID")
  elseif cmd == "rw" then
    SendChatMessage(rest, "RAID_WARNING")
  elseif cmd == "w" or cmd == "whisper" then
    local target, textBody = rest:match("^(%S+)%s+(.+)$")
    if target and textBody then
      SendChatMessage(textBody, "WHISPER", nil, target)
    else
      AddLine("system", "Whisper format: /w Name message")
    end
  else
    -- Pass unknown slash commands (e.g., /logout) to Blizzard's chat parser.
    if ChatFrame_OpenChat then
      TA.deferTerminalRefocus = true
      local openText = msg
      if protectedSlashCommands[cmd] then
        -- Do not inject protected commands via addon code; require manual typing
        -- in the chat edit box to avoid tainting secure slash handlers.
        openText = ""
        TA.deferTerminalRefocus = false
      end
      ChatFrame_OpenChat(openText)
      if TA.textMode then
        TA_SyncProtectedCommandEditBoxes(true)
      end
      if ChatFrame1EditBox then
        ChatFrame1EditBox:Show()
        ChatFrame1EditBox:SetFocus()
        if ChatEdit_ActivateChat then
          ChatEdit_ActivateChat(ChatFrame1EditBox)
        end
      end
      TA_UpdateCommandPreviewBox()
      if protectedSlashCommands[cmd] then
        AddLine("system", "Protected command requires manual typing. Type /" .. cmd .. " in chat input, then press Enter.")
      else
        AddLine("system", "Slash command opened in chat input.")
      end
    else
      AddLine("system", "Unknown chat prefix. Use /s, /p, /g, /w, /raid, or /rw.")
    end
  end
  return true
end

function TA_ShowHelpOverview()
  if TA_Help_ShowOverview then
    TA_Help_ShowOverview()
    return
  end
  AddLine("system", "Help module is not loaded yet.")
end

function TA_ShowHelpTopic(topicArg)
  if TA_Help_ShowTopic then
    TA_Help_ShowTopic(topicArg)
    return
  end
  AddLine("system", "Help module is not loaded yet.")
  TA_ShowHelpOverview()
end

function TA_RunCommandSelfTest(modeArg)
  if not TA or not TA.EXACT_INPUT_HANDLERS then
    AddLine("system", "Self-test unavailable: command table is not ready.")
    return
  end

  local mode = tostring(modeArg or "safe"):lower()
  local denyContains = {
    "reload",
    "destroy",
    "sell",
    "delete",
    "equip",
    "train",
    "buy",
    "accept",
    "decline",
    "turnin",
    "complete",
    "macrocreate",
    "macroset",
    "macrorename",
    "autostart",
    "textmode",
    "reset defaults",
  }

  local safeAllow = {
    ["help"] = true,
    ["status"] = true,
    ["stats"] = true,
    ["skills"] = true,
    ["xp"] = true,
    ["buffs"] = true,
    ["tracking"] = true,
    ["actions"] = true,
    ["spells"] = true,
    ["macros"] = true,
    ["inventory"] = true,
    ["equipment"] = true,
    ["money"] = true,
    ["where"] = true,
    ["cell"] = true,
    ["markedcells"] = true,
    ["map"] = true,
    ["df status"] = true,
    ["performance status"] = true,
    ["settings"] = true,
  }

  local function isDenied(cmd)
    for i = 1, #denyContains do
      if string.find(cmd, denyContains[i], 1, true) then
        return true
      end
    end
    return false
  end

  local cmds = {}
  for cmd, _ in pairs(TA.EXACT_INPUT_HANDLERS) do
    if cmd ~= "selftest" and cmd ~= "selftest full" and not isDenied(cmd) then
      if mode == "full" or safeAllow[cmd] then
        table.insert(cmds, cmd)
      end
    end
  end
  table.sort(cmds)

  if #cmds == 0 then
    AddLine("system", "Self-test found no runnable commands for mode: " .. mode)
    return
  end

  AddLine("system", string.format("Self-test starting (%s): %d command(s)", mode, #cmds))

  local okCount = 0
  local failCount = 0
  local failures = {}
  for i = 1, #cmds do
    local cmd = cmds[i]
    local ok, err = pcall(function()
      TA_ProcessInputCommand(cmd)
    end)
    if ok then
      okCount = okCount + 1
    else
      failCount = failCount + 1
      table.insert(failures, { cmd = cmd, err = tostring(err) })
      AddLine("system", string.format("[FAIL] %s -> %s", cmd, tostring(err)))
    end
  end

  AddLine("system", string.format("Self-test complete: ok=%d fail=%d", okCount, failCount))
  if failCount > 0 then
    AddLine("system", string.format("--- %d failure(s) recap ---", failCount))
    for i = 1, #failures do
      AddLine("system", string.format("  [%d] %s", i, failures[i].cmd))
      AddLine("system", string.format("       %s", failures[i].err))
    end
  end
  if mode ~= "full" then
    AddLine("system", "Tip: run 'selftest full' for broader non-destructive exact-handler coverage.")
  end
end

function TA_RunPatternSelfTest(modeArg)
  if not TA_ProcessInputCommand then
    AddLine("system", "Pattern self-test unavailable: command parser is not ready.")
    return
  end

  local mode = tostring(modeArg or "safe"):lower()
  local cmdsSafe = {
    "help navigation",
    "skills weapons",
    "skill professions",
    "who tester",
    "markcell alpha",
    "cellsize 40",
    "cellcal 20 30",
    "cellyards 30",
    "showmark 1",
    "renamemark 1 alpha",
    "df size 300 600",
    "df grid 35",
    "df markradius 2",
    "route show test",
    "route list",
    "questinfo 1",
    "questroute top 3",
    "questroute weight xp 1.0",
    "choose 1",
    "rewardinfo 1",
    "set maxfps 60",
    "cvar maxfps",
    "cvarlist maxfps",
    "sealdps 30",
    "sealdps live target 30",
    "warlockdps mode shadow",
    "warlockprompt set manapct 40",
    "ml xp mode balanced",
    "ml xp set priorweight 8",
    "ml export 10",
    "ml log max 50",
    "ml xp warrior preset arms",
    "ml xp warrior weapon auto",
    "macroinfo 1",
    "macro 1",
    "train 1",
    "recipeinfo 1",
    "recipe 1",
  }

  local cmdsFull = {
    "help combat",
    "help automation",
    "bind 1 1",
    "bindmacro 1 1",
    "binditem 1 0 1",
    "moveitem 0 1 1 1",
    "buycheck 1",
    "buycheck 1 2",
    "vendorinfo 1",
    "shopinfo 1",
    "iteminfo 1",
    "restock food 5",
    "buyback 1",
    "bank",
    "spellbook all",
    "spells full",
    "map on",
    "map off",
    "df profile balanced",
    "df orientation rotating",
    "df rotation octant",
    "df cell 4",
    "df cell auto",
    "df level 2",
    "df level off",
    "df adaptive on",
    "df adaptive mode combat",
    "df adaptive thresholds 10 20 40",
    "route start test",
    "route follow test",
    "route follow off",
    "route clear test",
    "quest route top 2",
    "quest route weight proximity 1.2",
    "reward 1",
    "accept 1",
    "decline 1",
    "cvar maxfps 60",
    "warlockdps set targetlevel 30",
    "warlock prompt set taphpfloor 45",
    "ml xp set grindscale 1.0",
    "ml xp warrior preset fury",
    "ml xp warrior weapon dual-wield",
    "sealdps set 30 100 90",
    "sealdps import 30:100:90",
    "weapondance",
    "sordance",
    "swingtimer on",
    "swingtimer off",
    "swingtimer status",
    "swingtimer reaction 100",
    "macroset 1 /say test",
    "macrorename 1 test",
    "macrocreate test /say hi",
    "macrodelete 1",
    "train all",
  }

  local cmds = {}
  for i = 1, #cmdsSafe do
    table.insert(cmds, cmdsSafe[i])
  end
  if mode == "full" then
    for i = 1, #cmdsFull do
      table.insert(cmds, cmdsFull[i])
    end
  end

  AddLine("system", string.format("Pattern self-test starting (%s): %d sample command(s)", mode, #cmds))

  local okCount = 0
  local failCount = 0
  local failures = {}
  for i = 1, #cmds do
    local cmd = cmds[i]
    local ok, err = pcall(function()
      TA_ProcessInputCommand(cmd)
    end)
    if ok then
      okCount = okCount + 1
    else
      failCount = failCount + 1
      table.insert(failures, { cmd = cmd, err = tostring(err) })
      AddLine("system", string.format("[FAIL] %s -> %s", cmd, tostring(err)))
    end
  end

  AddLine("system", string.format("Pattern self-test complete: ok=%d fail=%d", okCount, failCount))
  if failCount > 0 then
    AddLine("system", string.format("--- %d failure(s) recap ---", failCount))
    for i = 1, #failures do
      AddLine("system", string.format("  [%d] %s", i, failures[i].cmd))
      AddLine("system", string.format("       %s", failures[i].err))
    end
  end
  if mode ~= "full" then
    AddLine("system", "Tip: run 'selftest patterns full' for broader curated pattern coverage.")
  end
end
