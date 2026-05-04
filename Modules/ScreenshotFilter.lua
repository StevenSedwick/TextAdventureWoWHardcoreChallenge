-- ScreenshotFilter.lua
-- Manages line-limit setting for the panel buffer plus chat-filter that suppresses the
-- 'Screenshot saved' system spam (and an optional UIErrorsFrame/RaidNotice hook).
-- Extracted from textadventurer.lua. TA_ScreenshotChatFilter is module-local; the rest
-- are global. AddLine, TA, panel are referenced by name (resolved at call time).

function TA_SetLineLimit(limit, silent)
  local minLimit = 100
  local maxLimit = 2000

  if limit == nil then
    AddLine("system", string.format("Text log line limit: %d", TA.lineLimit or 400))
    AddLine("system", string.format("Usage: loglimit <n> (range %d-%d)", minLimit, maxLimit))
    return
  end

  local n = math.floor(tonumber(limit) or 0)
  if n < minLimit then n = minLimit end
  if n > maxLimit then n = maxLimit end

  TA.lineLimit = n
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.lineLimit = n

  while #TA.lines > TA.lineLimit do
    table.remove(TA.lines, 1)
  end

  if panel and panel.text then
    if panel.text.SetMaxLines then
      panel.text:SetMaxLines(TA.lineLimit)
    end
    panel.text:Clear()
    for i = 1, #TA.lines do
      local line = TA.lines[i]
      if line and line.text then
        panel.text:AddMessage(line.text, line.r or 1, line.g or 1, line.b or 1)
      end
    end
    panel.text:ScrollToBottom()
  end

  if not silent then
    AddLine("system", string.format("Text log line limit set to %d.", TA.lineLimit))
  end
end

-- Suppress "Screenshot captured as..." chat spam.
if TA.hideScreenshotMessage == nil then TA.hideScreenshotMessage = true end
TA._screenshotFilterInstalled = false

local function TA_ScreenshotChatFilter(_, _, msg)
  if not TA.hideScreenshotMessage then return false end
  if type(msg) ~= "string" then return false end
  -- SCREENSHOT_SUCCESS = "Screenshot captured as %s"; SCREENSHOT_FAILURE = "Screenshot failed."
  if msg:find("Screenshot captured as", 1, true)
    or msg:find("Screenshot failed", 1, true) then
    return true
  end
  if SCREENSHOT_SUCCESS then
    local pat = "^" .. SCREENSHOT_SUCCESS:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$"
    if msg:match(pat) then return true end
  end
  if SCREENSHOT_FAILURE and msg == SCREENSHOT_FAILURE then return true end
  return false
end

function TA_InstallScreenshotFilter()
  if not TA._screenshotChatFilterInstalled and ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", TA_ScreenshotChatFilter)
    TA._screenshotChatFilterInstalled = true
  end
  -- Suppress the on-screen yellow "Screenshot captured as..." UIErrorsFrame popup.
  if UIErrorsFrame and UIErrorsFrame.AddMessage and not TA._uiErrorsOriginalAddMessage then
    TA._uiErrorsOriginalAddMessage = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(self, msg, ...)
      if TA.debugScreenshotFilter and type(msg) == "string" then
        print("[TA-SS] UIErrors:", msg)
      end
      if TA.hideScreenshotMessage and type(msg) == "string"
        and (msg:lower():find("screenshot", 1, true)) then
        return
      end
      return TA._uiErrorsOriginalAddMessage(self, msg, ...)
    end
  end
  if UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage and not TA._uiErrorsOriginalAddExternal then
    TA._uiErrorsOriginalAddExternal = UIErrorsFrame.AddExternalErrorMessage
    UIErrorsFrame.AddExternalErrorMessage = function(self, msg, ...)
      if TA.debugScreenshotFilter and type(msg) == "string" then
        print("[TA-SS] UIErrors-Ext:", msg)
      end
      if TA.hideScreenshotMessage and type(msg) == "string"
        and (msg:lower():find("screenshot", 1, true)) then
        return
      end
      return TA._uiErrorsOriginalAddExternal(self, msg, ...)
    end
  end
  -- Some screenshot text may be raised via RaidNotice / RaidWarning frames; cover those too.
  for _, frameName in ipairs({ "RaidNotice_AddMessage" }) do
    local orig = _G[frameName]
    if type(orig) == "function" and not TA["_orig_" .. frameName] then
      TA["_orig_" .. frameName] = orig
      _G[frameName] = function(noticeFrame, textString, ...)
        if TA.hideScreenshotMessage and type(textString) == "string"
          and (textString:find("Screenshot captured as", 1, true)
            or textString:find("Screenshot failed", 1, true)) then
          return
        end
        return TA["_orig_" .. frameName](noticeFrame, textString, ...)
      end
    end
  end
  -- Override the FrameXML screenshot event handler if it's a global function (Classic).
  if type(Screenshot_OnEvent) == "function" and not TA._origScreenshotOnEvent then
    TA._origScreenshotOnEvent = Screenshot_OnEvent
    Screenshot_OnEvent = function(self, event, ...)
      if TA.hideScreenshotMessage
        and (event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED") then
        return
      end
      return TA._origScreenshotOnEvent(self, event, ...)
    end
  end
  -- Last-resort: unregister the screenshot events from any frame that listens for them.
  -- The popup may be drawn directly by an engine-side handler bound to these events.
  if EnumerateFrames then
    local f = EnumerateFrames()
    while f do
      if f.IsEventRegistered and f.UnregisterEvent then
        local ok1 = pcall(function() return f:IsEventRegistered("SCREENSHOT_SUCCEEDED") end)
        if ok1 then
          if f:IsEventRegistered("SCREENSHOT_SUCCEEDED") then
            f:UnregisterEvent("SCREENSHOT_SUCCEEDED")
            if TA.debugScreenshotFilter then
              print("[TA-SS] unregistered SCREENSHOT_SUCCEEDED from", f:GetName() or tostring(f))
            end
          end
          if f:IsEventRegistered("SCREENSHOT_FAILED") then
            f:UnregisterEvent("SCREENSHOT_FAILED")
            if TA.debugScreenshotFilter then
              print("[TA-SS] unregistered SCREENSHOT_FAILED from", f:GetName() or tostring(f))
            end
          end
        end
      end
      f = EnumerateFrames(f)
    end
  end
  TA._screenshotFilterInstalled = true
end

-- Try installing right now in case UIErrorsFrame already exists at file-load time.
if pcall(TA_InstallScreenshotFilter) then end

function TA_SetHideScreenshotMessage(enabled, silent)
  if enabled == nil then
    AddLine("system", string.format("Screenshot message: %s",
      TA.hideScreenshotMessage and "HIDDEN" or "shown"))
    AddLine("system", "Usage: hidescreenshot on|off")
    return
  end
  TA.hideScreenshotMessage = enabled and true or false
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.hideScreenshotMessage = TA.hideScreenshotMessage
  TA_InstallScreenshotFilter()
  if not silent then
    AddLine("system", string.format("Screenshot 'captured' message %s.",
      TA.hideScreenshotMessage and "hidden" or "shown"))
  end
end
