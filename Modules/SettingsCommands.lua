function TA_RunCVarList(filter)
  if not ConsoleExec then
    AddLine("system", "Console command API unavailable.")
    return
  end

  local suffix = ""
  local f = (filter or ""):match("^%s*(.-)%s*$")
  if f ~= "" then
    suffix = " " .. f
  end

  TA.pendingCVarList = true
  AddLine("system", string.format("Running cvarlist%s...", suffix))
  ConsoleExec("cvarlist" .. suffix)
  if C_Timer and C_Timer.After then
    C_Timer.After(3.0, function()
      TA.pendingCVarList = false
    end)
  end
end

function TA_HandleSettingsInputCommand(lower, msg)
  if lower == "settings" then
    TA_ReportGameSettings()
    return true
  elseif lower == "set" then
    AddLine("system", "Usage: set <name> <value>")
    AddLine("system", "Shortcuts: autoloot, sound, sfx, music, ambience, master, graphics, spellqueue, maxfps, maxfpsbk")
    AddLine("system", "Any other name is treated as a direct CVar name.")
    return true
  elseif lower == "cvar" then
    AddLine("system", "Usage: cvar <name> [value]")
    return true
  elseif lower == "cvarlist" then
    TA_RunCVarList(nil)
    return true
  end

  local cvarFilter = msg:match("^%s*[Cc][Vv][Aa][Rr][Ll][Ii][Ss][Tt]%s+(.+)$")
  if cvarFilter then
    TA_RunCVarList(cvarFilter)
    return true
  end

  local setName, setValue = msg:match("^%s*[Ss][Ee][Tt]%s+(%S+)%s+(.+)$")
  if setName and setValue then
    TA_HandleSettingCommand(setName, setValue)
    return true
  end

  local cvarName, cvarValue = msg:match("^%s*[Cc][Vv][Aa][Rr]%s+(%S+)%s+(.+)$")
  if cvarName and cvarValue then
    TA_SetNamedCVar(cvarName, cvarValue)
    return true
  end

  cvarName = msg:match("^%s*[Cc][Vv][Aa][Rr]%s+(%S+)%s*$")
  if cvarName then
    TA_ReportNamedCVar(cvarName)
    return true
  end

  return false
end
