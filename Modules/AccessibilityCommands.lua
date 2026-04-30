if not TA then
  return
end

local function TA_GetLookState()
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.accessibilityLook = TextAdventurerDB.accessibilityLook or {
    description = "",
    updatedAt = 0,
    selectedLabels = {},
  }
  if type(TextAdventurerDB.accessibilityLook.selectedLabels) ~= "table" then
    TextAdventurerDB.accessibilityLook.selectedLabels = {}
  end
  return TextAdventurerDB.accessibilityLook
end

local LOOK_LABEL_PRESETS = {
  town = { "terrain_road", "building_inn", "enemy_none" },
  road = { "terrain_road", "obstacle_tree" },
  forest = { "terrain_forest", "obstacle_tree" },
  cliff = { "terrain_cliff", "obstacle_rocks" },
  combat = { "enemy_wolf" },
  safe = { "enemy_none" },
}

local function TA_GetSelectedLookLabels()
  local state = TA_GetLookState()
  local labels = {}
  for i = 1, #state.selectedLabels do
    local label = tostring(state.selectedLabels[i] or "")
    label = label:match("^%s*(.-)%s*$")
    if label ~= "" then
      table.insert(labels, label)
    end
  end
  table.sort(labels)
  return labels
end

local function TA_SetSelectedLookLabels(labels)
  local state = TA_GetLookState()
  state.selectedLabels = {}
  local seen = {}
  for i = 1, #labels do
    local label = tostring(labels[i] or "")
    label = label:match("^%s*(.-)%s*$")
    if label ~= "" and not seen[label] then
      seen[label] = true
      table.insert(state.selectedLabels, label)
    end
  end
  table.sort(state.selectedLabels)
end

local function TA_AddSelectedLookLabel(label)
  local labels = TA_GetSelectedLookLabels()
  table.insert(labels, label)
  TA_SetSelectedLookLabels(labels)
end

local function TA_RemoveSelectedLookLabel(label)
  local labels = TA_GetSelectedLookLabels()
  local filtered = {}
  for i = 1, #labels do
    if labels[i] ~= label then
      table.insert(filtered, labels[i])
    end
  end
  TA_SetSelectedLookLabels(filtered)
end

local function TA_PrintSelectedLookLabels()
  local labels = TA_GetSelectedLookLabels()
  if #labels == 0 then
    AddLine("system", "Look labels: (none selected)")
    AddLine("system", "Use: look labels add <tag> or look labels preset <name>")
    return
  end
  AddLine("system", "Look labels: " .. table.concat(labels, ";"))
end

local function TA_SetLookDescription(description)
  local state = TA_GetLookState()
  state.description = description or ""
  state.updatedAt = time() or 0
end

local function TA_FormatSecondsAgo(updatedAt)
  if not updatedAt or updatedAt <= 0 then
    return "never"
  end
  local now = time() or 0
  local delta = now - updatedAt
  if delta < 0 then
    delta = 0
  end
  if delta < 60 then
    return string.format("%ds ago", delta)
  end
  local minutes = math.floor(delta / 60)
  if minutes < 60 then
    return string.format("%dm ago", minutes)
  end
  local hours = math.floor(minutes / 60)
  return string.format("%dh ago", hours)
end

local function TA_PrintLookDescription()
  local state = TA_GetLookState()
  local text = (state.description or ""):match("^%s*(.-)%s*$")
  if text == "" then
    AddLine("system", "No /look description cached yet.")
    AddLine("system", "Use external vision tool, then paste: /look set <description>")
    return
  end
  AddLine("system", "Look: " .. text)
  AddLine("system", "Look cache updated: " .. TA_FormatSecondsAgo(state.updatedAt))
end

local function TA_ShowLookStatus()
  local state = TA_GetLookState()
  local hasDescription = (state.description or ""):match("%S") ~= nil
  AddLine("system", "Accessibility look bridge status:")
  AddLine("system", "  description cached: " .. (hasDescription and "yes" or "no"))
  AddLine("system", "  last update: " .. TA_FormatSecondsAgo(state.updatedAt))
  AddLine("system", "  capture trigger: external hotkey (recommended Ctrl+Shift+L)")
  AddLine("system", "  safety: read-only scene description, no gameplay automation")
end

local function TA_ShowPythonBridgeStatus()
  AddLine("system", "Python bridge probe (WoW addon sandbox):")
  AddLine("system", "  in-addon Python runtime: unavailable")
  AddLine("system", "  direct process launch from addon Lua: unavailable")
  AddLine("system", "  direct pixel capture from addon Lua: unavailable")
  AddLine("system", "  local companion service: supported (outside WoW)")
  AddLine("system", "Use external service + '/look set <description>' to bridge results.")
end

local function TA_ShowPythonBridgeHowTo()
  AddLine("system", "Python bridge quick flow:")
  AddLine("system", "  1) Run local capture/model service in terminal.")
  AddLine("system", "  2) Trigger capture hotkey (recommended Ctrl+Shift+L).")
  AddLine("system", "  3) Copy output command: /look set <description>.")
  AddLine("system", "  4) Paste into WoW chat or terminal.")
  AddLine("system", "Safety: no movement, targeting, casting, or decision automation.")
end

local function TA_GetLookTelemetrySnapshot()
  local zone = GetZoneText and (GetZoneText() or "") or ""
  local subzone = GetSubZoneText and (GetSubZoneText() or "") or ""

  local mapID = nil
  if C_Map and C_Map.GetBestMapForUnit then
    mapID = C_Map.GetBestMapForUnit("player")
  end

  local x, y = nil, nil
  if mapID and C_Map and C_Map.GetPlayerMapPosition then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      if type(pos) == "table" then
        x = pos.x
        y = pos.y
      elseif pos.GetXY then
        x, y = pos:GetXY()
      end
    end
  end

  local facing = GetPlayerFacing and GetPlayerFacing() or nil
  local zoom = GetCameraZoom and GetCameraZoom() or nil
  local pitch = GetCameraPitch and GetCameraPitch() or nil

  return {
    zone = zone,
    subzone = subzone,
    mapID = mapID,
    x = x,
    y = y,
    facing = facing,
    pitch = pitch,
    zoom = zoom,
    ts = time() or 0,
  }
end

local function TA_PrintLookTelemetry()
  local t = TA_GetLookTelemetrySnapshot()
  local labels = TA_GetSelectedLookLabels()
  local labelsJoined = table.concat(labels, ";")
  local line = string.format(
    "LOOK_TELEMETRY zone=%s subzone=%s map=%s x=%s y=%s facing=%s pitch=%s zoom=%s ts=%s labels=%s",
    tostring(t.zone or ""),
    tostring(t.subzone or ""),
    tostring(t.mapID or ""),
    tostring(t.x or ""),
    tostring(t.y or ""),
    tostring(t.facing or ""),
    tostring(t.pitch or ""),
    tostring(t.zoom or ""),
    tostring(t.ts or ""),
    tostring(labelsJoined)
  )
  AddLine("system", "Look telemetry export:")
  AddLine("system", line)
end

function TA_RegisterAccessibilityCommandHandlers(exactHandlers, addPatternHandler)
  if TA.accessibilityCommandHandlersRegistered then
    return
  end

  exactHandlers["look"] = function()
    AddLine("system", "Accessibility /look is read-only scene description.")
    AddLine("system", "Trigger local capture hotkey, then store text with: look set <description>")
    TA_PrintLookDescription()
  end

  exactHandlers["look last"] = function()
    TA_PrintLookDescription()
  end

  exactHandlers["look clear"] = function()
    TA_SetLookDescription("")
    AddLine("system", "Cleared cached /look description.")
  end

  exactHandlers["look status"] = function()
    TA_ShowLookStatus()
    TA_PrintSelectedLookLabels()
  end

  exactHandlers["look telemetry"] = function()
    TA_PrintLookTelemetry()
  end

  exactHandlers["look export"] = function()
    TA_PrintLookTelemetry()
  end

  exactHandlers["look labels"] = function()
    TA_PrintSelectedLookLabels()
  end

  exactHandlers["look labels clear"] = function()
    TA_SetSelectedLookLabels({})
    AddLine("system", "Cleared selected look labels.")
  end

  exactHandlers["py"] = function()
    AddLine("system", "Python probe command for accessibility bridge.")
    AddLine("system", "Try: py status, py howto, py limits")
    TA_ShowPythonBridgeStatus()
  end

  exactHandlers["python"] = function()
    TA_ShowPythonBridgeStatus()
  end

  exactHandlers["py status"] = function()
    TA_ShowPythonBridgeStatus()
  end

  exactHandlers["py limits"] = function()
    TA_ShowPythonBridgeStatus()
  end

  exactHandlers["py howto"] = function()
    TA_ShowPythonBridgeHowTo()
  end

  addPatternHandler("^look%s+set%s+(.+)$", function(text)
    local trimmed = (text or ""):match("^%s*(.-)%s*$")
    if trimmed == "" then
      AddLine("system", "Usage: look set <description>")
      return
    end
    TA_SetLookDescription(trimmed)
    AddLine("system", "Updated /look description.")
    TA_PrintLookDescription()
  end)

  addPatternHandler("^look%s+last$", function()
    TA_PrintLookDescription()
  end)

  addPatternHandler("^look%s+status$", function()
    TA_ShowLookStatus()
  end)

  addPatternHandler("^look%s+clear$", function()
    TA_SetLookDescription("")
    AddLine("system", "Cleared cached /look description.")
  end)

  addPatternHandler("^look%s+telemetry$", function()
    TA_PrintLookTelemetry()
  end)

  addPatternHandler("^look%s+export$", function()
    TA_PrintLookTelemetry()
  end)

  addPatternHandler("^look%s+labels%s+add%s+([%w_%-]+)$", function(label)
    local clean = tostring(label or ""):lower()
    if clean == "" then
      AddLine("system", "Usage: look labels add <tag>")
      return
    end
    TA_AddSelectedLookLabel(clean)
    TA_PrintSelectedLookLabels()
  end)

  addPatternHandler("^look%s+labels%s+remove%s+([%w_%-]+)$", function(label)
    local clean = tostring(label or ""):lower()
    if clean == "" then
      AddLine("system", "Usage: look labels remove <tag>")
      return
    end
    TA_RemoveSelectedLookLabel(clean)
    TA_PrintSelectedLookLabels()
  end)

  addPatternHandler("^look%s+labels%s+clear$", function()
    TA_SetSelectedLookLabels({})
    AddLine("system", "Cleared selected look labels.")
  end)

  addPatternHandler("^look%s+labels%s+preset%s+([%w_%-]+)$", function(name)
    local key = tostring(name or ""):lower()
    local preset = LOOK_LABEL_PRESETS[key]
    if not preset then
      AddLine("system", "Unknown label preset. Available: town, road, forest, cliff, combat, safe")
      return
    end
    TA_SetSelectedLookLabels(preset)
    AddLine("system", "Applied look label preset: " .. key)
    TA_PrintSelectedLookLabels()
  end)

  addPatternHandler("^py%s+status$", function()
    TA_ShowPythonBridgeStatus()
  end)

  addPatternHandler("^py%s+limits$", function()
    TA_ShowPythonBridgeStatus()
  end)

  addPatternHandler("^py%s+howto$", function()
    TA_ShowPythonBridgeHowTo()
  end)

  if SlashCmdList then
    SLASH_TEXTADVENTURERLOOK1 = "/look"
    rawset(SlashCmdList, "TEXTADVENTURERLOOK", function(msg)
      local trimmed = (msg or ""):match("^%s*(.-)%s*$")
      if trimmed == "" then
        TA_ProcessInputCommand("look")
      else
        TA_ProcessInputCommand("look " .. trimmed)
      end
    end)
  end

  TA.accessibilityCommandHandlersRegistered = true
end

-- Register immediately when command tables already exist (live TOC may load this after Commands.lua).
if TA_RegisterAccessibilityCommandHandlers and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterAccessibilityCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
