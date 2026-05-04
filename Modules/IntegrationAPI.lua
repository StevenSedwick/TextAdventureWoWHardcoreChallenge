-- IntegrationAPI.lua
-- External integration: _G.TextAdventurerAPI surface, TA_EmitExternal callback dispatch,
-- /tastream slash command, and the chat-log streaming pipe (STREAM_SENTINEL).
-- Extracted from textadventurer.lua. TA_EmitExternal, TA_GetIntegrationStateSnapshot,
-- TA_PublishPublicAPI are global so main-file event handlers can call them. The do/end
-- streaming block keeps its own internal locals.

local TA_API_VERSION = "1.0.0"
local TAExternalCallbacks = {}

function TA_EmitExternal(eventName, payload)
  local listeners = TAExternalCallbacks[eventName]
  if not listeners then return end
  for i = #listeners, 1, -1 do
    local cb = listeners[i]
    if type(cb) == "function" then
      local ok = pcall(cb, payload)
      if not ok then
        table.remove(listeners, i)
      end
    else
      table.remove(listeners, i)
    end
  end
end

function TA_GetIntegrationStateSnapshot()
  local panelShown = panel and panel.IsShown and panel:IsShown() or false
  return {
    version = TA_API_VERSION,
    addonLoaded = true,
    panelVisible = panelShown and true or false,
    textModeEnabled = TA.textMode and true or false,
    dfModeEnabled = TA.dfModeEnabled and true or false,
    dfModeView = TA.dfModeViewMode or "threat",
    performanceModeEnabled = TA.performanceModeEnabled and true or false,
  }
end

function TA_PublishPublicAPI()
  local api = _G.TextAdventurerAPI
  if type(api) ~= "table" then
    api = {}
    _G.TextAdventurerAPI = api
  end

  api.apiVersion = TA_API_VERSION

  function api.GetVersion()
    return TA_API_VERSION
  end

  function api.GetState()
    return TA_GetIntegrationStateSnapshot()
  end

  function api.ExecuteCommand(commandText)
    if type(TA_ProcessInputCommand) ~= "function" then
      return false, "TA_ProcessInputCommand unavailable"
    end
    local ok, err = pcall(TA_ProcessInputCommand, tostring(commandText or ""))
    if not ok then
      return false, tostring(err)
    end
    TA_EmitExternal("COMMAND_EXECUTED", { command = tostring(commandText or "") })
    return true
  end

  function api.SendSlash(slashText)
    if type(TA_SendFromTerminal) ~= "function" then
      return false, "TA_SendFromTerminal unavailable"
    end
    local ok, result = pcall(TA_SendFromTerminal, tostring(slashText or ""))
    if not ok then
      return false, tostring(result)
    end
    TA_EmitExternal("SLASH_SENT", { slash = tostring(slashText or ""), handled = result and true or false })
    return true, result and true or false
  end

  function api.RegisterCallback(eventName, callbackFn)
    if type(eventName) ~= "string" or eventName == "" then
      return false, "eventName must be non-empty string"
    end
    if type(callbackFn) ~= "function" then
      return false, "callbackFn must be function"
    end
    local bucket = TAExternalCallbacks[eventName]
    if not bucket then
      bucket = {}
      TAExternalCallbacks[eventName] = bucket
    end
    bucket[#bucket + 1] = callbackFn
    return true
  end

  function api.UnregisterCallback(eventName, callbackFn)
    local bucket = TAExternalCallbacks[eventName]
    if not bucket or type(callbackFn) ~= "function" then
      return false
    end
    for i = #bucket, 1, -1 do
      if bucket[i] == callbackFn then
        table.remove(bucket, i)
        return true
      end
    end
    return false
  end
end

TA_PublishPublicAPI()

-- ============================================================
-- External streaming (TA_Stream)
-- Wrapped in `do ... end` so its locals don't count against the file-chunk's
-- 200-local cap. Cross-block reads (AddLine, PLAYER_TARGET_CHANGED) use
-- TA._streamEnabled instead of a file-scope local.
-- ============================================================
TA._streamEnabled = false
do
  local STREAM_SENTINEL = "##TA##"
  local streamFrame = nil
  local streamSeq = 0

  local function ta_json_escape(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return s
  end
  local function ta_json_encode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
      if v ~= v or v == math.huge or v == -math.huge then return "null" end
      return string.format("%.6g", v)
    end
    if t == "string" then return '"' .. ta_json_escape(v) .. '"' end
    if t == "table" then
      local n = #v
      local isArray = n > 0
      if isArray then
        for k in pairs(v) do
          if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
            isArray = false; break
          end
        end
      end
      local parts = {}
      if isArray then
        for i = 1, n do parts[#parts+1] = ta_json_encode(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
      else
        for k, val in pairs(v) do
          parts[#parts+1] = '"' .. ta_json_escape(k) .. '":' .. ta_json_encode(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
      end
    end
    return "null"
  end

  local function TA_StreamEnsureFrame()
    if streamFrame then return streamFrame end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
      local name = GetChatWindowInfo and select(1, GetChatWindowInfo(i))
      if name == "TAStream" then
        streamFrame = _G["ChatFrame" .. i]
        break
      end
    end
    if not streamFrame and FCF_OpenNewWindow then
      streamFrame = FCF_OpenNewWindow("TAStream")
      if streamFrame then
        streamFrame:UnregisterAllEvents()
        if FCF_SetWindowAlpha then FCF_SetWindowAlpha(streamFrame, 0) end
        streamFrame:SetAlpha(0)
        streamFrame:Hide()
        local tab = _G[streamFrame:GetName() .. "Tab"]
        if tab then tab:Hide(); tab:SetAlpha(0) end
      end
    end
    return streamFrame
  end

  local function TA_StreamWrite(eventName, payload)
    if not TA._streamEnabled then return end
    local f = TA_StreamEnsureFrame()
    if not f then return end
    streamSeq = streamSeq + 1
    f:AddMessage(STREAM_SENTINEL .. ta_json_encode({
      seq = streamSeq, t = GetTime(), ev = eventName, p = payload,
    }))
  end

  local STREAM_EVENTS = { "LINE", "TARGET", "READY", "COMBAT_ENTER", "COMBAT_LEAVE", "DEATH", "COMMAND_EXECUTED", "SLASH_SENT" }
  local function TA_StreamAttachListeners()
    for _, ev in ipairs(STREAM_EVENTS) do
      local bucket = TAExternalCallbacks[ev]
      if not bucket then bucket = {}; TAExternalCallbacks[ev] = bucket end
      local marker = "_taStream_" .. ev
      if not bucket[marker] then
        local evName = ev
        local fn = function(payload) TA_StreamWrite(evName, payload) end
        bucket[#bucket + 1] = fn
        bucket[marker] = true
      end
    end
  end

  function TA_StreamEnable(on)
    if on == nil then on = not TA._streamEnabled end
    if on then
      TA_StreamEnsureFrame()
      TA_StreamAttachListeners()
      if ConsoleExec then ConsoleExec("LoggingChat 1") end
      TA._streamEnabled = true
      AddLine("system", "Stream ON. Tail Logs/WoWChatLog.txt for lines beginning with '" .. STREAM_SENTINEL .. "'.")
      TA_StreamWrite("STREAM_START", { version = TA_API_VERSION, time = time() })
    else
      TA_StreamWrite("STREAM_STOP", { time = time() })
      TA._streamEnabled = false
      if ConsoleExec then ConsoleExec("LoggingChat 0") end
      AddLine("system", "Stream OFF. LoggingChat disabled.")
    end
  end

  function TA_StreamStatus()
    return TA._streamEnabled, streamSeq
  end

  SLASH_TASTREAM1 = "/tastream"
  SlashCmdList["TASTREAM"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "off" or msg == "0" or msg == "false" then
      TA_StreamEnable(false)
    elseif msg == "on" or msg == "1" or msg == "true" or msg == "" then
      TA_StreamEnable(true)
    elseif msg == "test" then
      if not TA._streamEnabled then TA_StreamEnable(true) end
      TA_EmitExternal("LINE", { kind = "system", text = "stream test ping" })
      AddLine("system", "Sent test ping to stream.")
    elseif msg == "status" then
      local on, n = TA_StreamStatus()
      AddLine("system", string.format("Stream: %s, seq=%d", on and "ON" or "OFF", n or 0))
    else
      AddLine("system", "Usage: /tastream [on|off|test|status]")
    end
  end
end

-- Publish API now that this module is loaded (was at file scope in main).
TA_PublishPublicAPI()
