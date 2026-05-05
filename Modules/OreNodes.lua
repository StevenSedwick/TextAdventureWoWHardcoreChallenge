-- Modules/OreNodes.lua
-- Records ore node positions when the player hovers them in the world.
-- Detected via GameTooltip text (the yellow name above the node).
-- Renders as colored $ glyphs on the DF mode map.
-- Commands: /ta ore, /ta ore clear, /ta ore clearall

local TA = _G.TA
if not TA then return end

-- Classic Era harvestable node names -> color code.
-- UnitPosition returns world coords; axes match DFMode's playerWorldX/Y convention.
local ORE_NODE_COLORS = {
  ["Copper Vein"]        = "|cffb87333",
  ["Tin Vein"]           = "|cffbbbbbb",
  ["Silver Vein"]        = "|cffdddddd",
  ["Iron Deposit"]       = "|cff8b6914",
  ["Gold Vein"]          = "|cffd4a017",
  ["Mithril Deposit"]    = "|cff7799cc",
  ["Truesilver Deposit"] = "|cff00ddee",
  ["Dark Iron Deposit"]  = "|cffaa3311",
  ["Small Thorium Vein"] = "|cff9966bb",
  ["Rich Thorium Vein"]  = "|cffcc88ff",
}

local ORE_GLYPH = "$"
local MAX_NODES_PER_MAP = 200
local DEDUP_YARDS = 20  -- skip recording if same type exists within this range

-- Runtime debug flag (off by default). When on, recordOreNode and the minimap
-- cursor math print verbose diagnostics so we can verify that the coordinates
-- recorded from minimap blips line up with what DFMode renders.
local oreDebug = false
local function dprint(fmt, ...)
  if not oreDebug then return end
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
  if AddLine then AddLine("system", "[ore] " .. msg) end
end
function TA_OreDebugEnabled() return oreDebug end

function TA_GetOreNodeGlyph(nodeType)
  local color = ORE_NODE_COLORS[nodeType]
  if color then
    return color .. ORE_GLYPH .. "|r"
  end
  return ORE_GLYPH
end

local function recordOreNode(nodeType, wx, wy)
  local fromCursor = (wx ~= nil and wy ~= nil)
  if not wx or not wy then
    wx, wy = UnitPosition("player")
  end
  if not wx or not wy then return end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then return end

  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.oreNodes = TextAdventurerDB.oreNodes or {}
  local byMap = TextAdventurerDB.oreNodes[mapID]
  if not byMap then
    byMap = {}
    TextAdventurerDB.oreNodes[mapID] = byMap
  end

  for _, node in ipairs(byMap) do
    if node.n == nodeType then
      local dx = node.wx - wx
      local dy = node.wy - wy
      if (dx * dx + dy * dy) <= (DEDUP_YARDS * DEDUP_YARDS) then
        if oreDebug then
          local dist = math.sqrt(dx * dx + dy * dy)
          dprint("dedup %s @(%.1f,%.1f) - existing within %.1f yd of (%.1f,%.1f)",
            nodeType, wx, wy, dist, node.wx, node.wy)
        end
        return
      end
    end
  end

  if #byMap >= MAX_NODES_PER_MAP then
    table.remove(byMap, 1)
  end

  table.insert(byMap, { n = nodeType, wx = wx, wy = wy })
  TA.oreNodesVersion = (TA.oreNodesVersion or 0) + 1
  if oreDebug then
    local px, py = UnitPosition("player")
    if px and py then
      local north = wx - px
      local east  = -(wy - py)
      local dist  = math.sqrt(north * north + east * east)
      dprint("REC %s src=%s map=%s node=(%.1f,%.1f) player=(%.1f,%.1f) delta(N=%.1f,E=%.1f) dist=%.1f yd",
        nodeType, fromCursor and "cursor" or "self", tostring(mapID),
        wx, wy, px, py, north, east, dist)
    else
      dprint("REC %s src=%s map=%s node=(%.1f,%.1f) (no player pos)",
        nodeType, fromCursor and "cursor" or "self", tostring(mapID), wx, wy)
    end
  end
end

-- Classic Era minimap zoom radii in yards (zoom level 0..5).
local MINIMAP_RADIUS_OUTDOOR = { [0] = 233.3, [1] = 200, [2] = 166.6, [3] = 133.3, [4] = 100, [5] = 66.6 }
local MINIMAP_RADIUS_INDOOR  = { [0] = 150,   [1] = 120, [2] = 90,    [3] = 75,    [4] = 60,  [5] = 45 }

-- Compute the world position of whatever the cursor is pointing at on the minimap.
-- Returns (worldX, worldY) or nil if computation fails.
local function ComputeMinimapCursorWorldPosition()
  local mcx, mcy = Minimap:GetCenter()
  if not mcx then return nil end
  local cx, cy = GetCursorPosition()
  if not cx then return nil end
  local scale = Minimap:GetEffectiveScale()
  if scale and scale > 0 then
    cx = cx / scale
    cy = cy / scale
  end

  local dxPx = cx - mcx  -- east+
  local dyPx = cy - mcy  -- north+
  local mw = Minimap:GetWidth()
  if not mw or mw <= 0 then return nil end
  local radiusPx = mw * 0.5

  local zoom = Minimap:GetZoom() or 0
  local _, instType = IsInInstance()
  local radii = (instType == "none") and MINIMAP_RADIUS_OUTDOOR or MINIMAP_RADIUS_INDOOR
  local yardsRadius = radii[zoom] or 100
  local yardsPerPx = yardsRadius / radiusPx

  local east  = dxPx * yardsPerPx
  local north = dyPx * yardsPerPx

  -- If the minimap rotates with the player (CVar rotateMinimap=1), our minimap
  -- offsets are in player-facing space, not north-up. Rotate them by player
  -- facing so they become world-axis offsets.
  local rotateOn = GetCVar and GetCVar("rotateMinimap") == "1"
  if rotateOn then
    -- When the minimap rotates, screen-up = player forward direction.
    -- WoW facing F: 0=north, pi/2=west (CCW). Forward in (north,east) is
    -- (cos F, -sin F); right (90 CW of forward) is (sin F, cos F).
    -- World offset = dyPx*forward + dxPx*right, using east=dxPx north=dyPx.
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local cosF = math.cos(facing)
    local sinF = math.sin(facing)
    local north2 = north * cosF + east * sinF
    local east2  = east  * cosF - north * sinF
    east, north = east2, north2
  end

  local px, py = UnitPosition("player")
  if not px or not py then return nil end
  -- Player worldX is NORTH, worldY is EAST-negated (see DFMode.lua axis notes).
  local nodeWX = px + north
  local nodeWY = py - east
  if oreDebug then
    dprint("cursor: dPx=(%.1f,%.1f) mw=%.1f r=%.1f zoom=%d yd/px=%.3f rot(N=%.1f,E=%.1f) rotOn=%s facing=%.2f -> world(%.1f,%.1f) player=(%.1f,%.1f)",
      dxPx, dyPx, mw, radiusPx, zoom, yardsPerPx, north, east,
      tostring(rotateOn), (GetPlayerFacing and GetPlayerFacing() or 0),
      nodeWX, nodeWY, px, py)
  end
  return nodeWX, nodeWY
end

-- Hook GameTooltip to detect when the player mouses over an ore node.
GameTooltip:HookScript("OnShow", function()
  local textFrame = _G["GameTooltipTextLeft1"]
  local text = textFrame and textFrame:GetText()
  if not text then return end
  if not ORE_NODE_COLORS[text] then return end

  -- If the tooltip owner is the Minimap, the cursor is on a minimap blip;
  -- compute the blip's world position from the cursor offset rather than
  -- recording the player's own position.
  local owner = GameTooltip:GetOwner()
  if owner == Minimap then
    local wx, wy = ComputeMinimapCursorWorldPosition()
    if wx and wy then
      recordOreNode(text, wx, wy)
      return
    end
  end
  recordOreNode(text)
end)

-- ---- Minimap inset toggle ----
-- The black overlay covers the minimap, so blip tooltips can't fire while DF
-- mode is up. /ta minimap raises the minimap above the overlay (and dims +
-- shrinks it) so the player can hover blips, then restores it on toggle off.

local minimapInset = { active = false, saved = nil }

-- Standard minimap chrome frames in Classic Era. We hide these when the
-- inset is active so only the round map face shows, then restore them on
-- toggle off. Names that don't exist on this client are silently skipped.
local MINIMAP_CHROME_FRAMES = {
  "MinimapCluster",
  "MinimapBorder",
  "MinimapBorderTop",
  "MinimapZoomIn",
  "MinimapZoomOut",
  "MinimapNorthTag",
  "MinimapToggleButton",
  "MiniMapWorldMapButton",
  "GameTimeFrame",
  "MiniMapTracking",
  "MiniMapTrackingFrame",
  "MiniMapTrackingButton",
  "MiniMapMailFrame",
  "MiniMapMailIcon",
  "MiniMapBattlefieldFrame",
  "MiniMapVoiceChatFrame",
  "MiniMapInstanceDifficulty",
  "TimeManagerClockButton",
  "MiniMapLFGFrame",
  "LFGMinimapFrame",
  "LFGMinimapFrameButton",
  "MiniMapPing",
}

local DEFAULT_MINIMAP_INSET_ALPHA = 0
local DEFAULT_MINIMAP_INSET_SCALE = 1.0
local LOCKED_MINIMAP_ZOOM = 0  -- furthest out (largest yard radius)

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function getInsetAlpha()
  -- Locked: players cannot change this (would let them see the world).
  return DEFAULT_MINIMAP_INSET_ALPHA
end

local function getInsetScale()
  -- Locked: scale is fixed at 1.0 so blip-to-yard math stays predictable.
  return DEFAULT_MINIMAP_INSET_SCALE
end

local PLAYER_ARROW_BLANK = "Interface\\AddOns\\TextAdventurer\\Textures\\Blank"
local PLAYER_ARROW_DEFAULT = "Interface\\Minimap\\MinimapArrow"

local function hidePlayerArrow()
  if minimapInset.savedPlayerTexture == nil then
    minimapInset.savedPlayerTexture = PLAYER_ARROW_DEFAULT
  end
  if Minimap.SetPlayerTexture then
    -- Empty string blanks the texture on Era; fall back to a blank file
    -- if the API rejects empty strings on this client.
    local ok = pcall(Minimap.SetPlayerTexture, Minimap, "")
    if not ok then
      pcall(Minimap.SetPlayerTexture, Minimap, PLAYER_ARROW_BLANK)
    end
  end
end

local function restorePlayerArrow()
  if Minimap.SetPlayerTexture then
    pcall(Minimap.SetPlayerTexture, Minimap,
      minimapInset.savedPlayerTexture or PLAYER_ARROW_DEFAULT)
  end
  minimapInset.savedPlayerTexture = nil
end

local function captureMinimapState()
  if minimapInset.saved then return end
  local s = {}
  s.parent = Minimap:GetParent()
  s.strata = Minimap:GetFrameStrata()
  s.level  = Minimap:GetFrameLevel()
  s.scale  = Minimap:GetScale()
  s.alpha  = Minimap:GetAlpha()
  s.shown  = Minimap:IsShown()
  s.zoom   = Minimap:GetZoom()
  s.numPoints = Minimap:GetNumPoints()
  s.points = {}
  for i = 1, s.numPoints do
    s.points[i] = { Minimap:GetPoint(i) }
  end
  minimapInset.saved = s
end

local function applyInsetPosition()
  Minimap:ClearAllPoints()
  local pos = TextAdventurerDB and TextAdventurerDB.minimapInsetPos
  if type(pos) == "table" and pos.point then
    Minimap:SetPoint(pos.point, UIParent, pos.relPoint or pos.point,
      tonumber(pos.x) or 0, tonumber(pos.y) or 0)
  else
    Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -16)
  end
end

local function persistInsetPosition()
  local point, _, relPoint, x, y = Minimap:GetPoint(1)
  if not point then return end
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.minimapInsetPos = {
    point = point, relPoint = relPoint, x = x, y = y,
  }
end

local dragHooked = false
local function ensureDragHooked()
  if dragHooked then return end
  dragHooked = true
  Minimap:SetMovable(true)
  Minimap:HookScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and minimapInset.active then
      self:StartMoving()
      self.taIsDragging = true
    end
  end)
  Minimap:HookScript("OnMouseUp", function(self, button)
    if self.taIsDragging then
      self:StopMovingOrSizing()
      self.taIsDragging = false
      persistInsetPosition()
    end
  end)
end

local function hideMinimapChrome()
  local saved = {}
  for _, name in ipairs(MINIMAP_CHROME_FRAMES) do
    local f = _G[name]
    if f and f.IsShown and f.Hide then
      saved[name] = f:IsShown()
      f:Hide()
    end
  end
  minimapInset.savedChrome = saved
end

local function restoreMinimapChrome()
  local saved = minimapInset.savedChrome
  if not saved then return end
  for name, wasShown in pairs(saved) do
    local f = _G[name]
    if f and wasShown and f.Show then f:Show() end
  end
  minimapInset.savedChrome = nil
end

-- Hide all child frames of Minimap (addon icons like BugSack, LibDBIcon
-- buttons, etc.). We snapshot their shown state and restore on toggle off.
local function hideMinimapChildren()
  local savedChildren = {}
  for _, child in ipairs({ Minimap:GetChildren() }) do
    if child and child.IsShown and child:IsShown() then
      child:Hide()
      savedChildren[#savedChildren + 1] = child
    end
  end
  minimapInset.savedChildren = savedChildren
end

local function restoreMinimapChildren()
  local saved = minimapInset.savedChildren
  if not saved then return end
  for _, child in ipairs(saved) do
    if child and child.Show then child:Show() end
  end
  minimapInset.savedChildren = nil
end

local function lockMinimapZoom()
  if Minimap.SetZoom then pcall(Minimap.SetZoom, Minimap, LOCKED_MINIMAP_ZOOM) end
end

-- Re-blank the player arrow texture (other addons or events can reset it).
local function reblankPlayerArrow()
  if Minimap.SetPlayerTexture then
    local ok = pcall(Minimap.SetPlayerTexture, Minimap, "")
    if not ok then
      pcall(Minimap.SetPlayerTexture, Minimap, PLAYER_ARROW_BLANK)
    end
  end
end

local lockWatchdog
local function ensureLockWatchdog()
  if lockWatchdog then return end
  lockWatchdog = CreateFrame("Frame")
  lockWatchdog:RegisterEvent("MINIMAP_UPDATE_ZOOM")
  lockWatchdog:RegisterEvent("MINIMAP_UPDATE_TRACKING")
  lockWatchdog:RegisterEvent("CVAR_UPDATE")
  lockWatchdog:SetScript("OnEvent", function()
    if minimapInset.active then
      lockMinimapZoom()
      reblankPlayerArrow()
    end
  end)
  -- Throttled OnUpdate as belt-and-suspenders against silent overrides.
  local accum = 0
  lockWatchdog:SetScript("OnUpdate", function(self, elapsed)
    if not minimapInset.active then return end
    accum = accum + elapsed
    if accum < 1 then return end
    accum = 0
    if (Minimap:GetZoom() or 0) ~= LOCKED_MINIMAP_ZOOM then lockMinimapZoom() end
    reblankPlayerArrow()
  end)
end

local function applyMinimapInset()
  captureMinimapState()
  ensureDragHooked()
  ensureLockWatchdog()
  -- Reparent off MinimapCluster so the performance-mode auto-hide on the
  -- cluster (and its hidden state) doesn't suppress us.
  Minimap:SetParent(UIParent)
  Minimap:SetFrameStrata("TOOLTIP")
  Minimap:SetFrameLevel(20000)
  Minimap:SetScale(getInsetScale())
  Minimap:SetAlpha(getInsetAlpha())
  Minimap:SetMovable(true)
  Minimap:SetClampedToScreen(true)
  applyInsetPosition()
  hideMinimapChrome()
  hideMinimapChildren()
  hidePlayerArrow()
  lockMinimapZoom()
  Minimap:Show()
  minimapInset.active = true
end

local function restoreMinimap()
  local s = minimapInset.saved
  if not s then
    minimapInset.active = false
    return
  end
  if s.parent then Minimap:SetParent(s.parent) end
  Minimap:SetFrameStrata(s.strata or "BACKGROUND")
  Minimap:SetFrameLevel(s.level or 1)
  Minimap:SetScale(s.scale or 1)
  Minimap:SetAlpha(s.alpha or 1)
  if s.points and #s.points > 0 then
    Minimap:ClearAllPoints()
    for _, p in ipairs(s.points) do
      Minimap:SetPoint(unpack(p))
    end
  end
  if s.shown then Minimap:Show() else Minimap:Hide() end
  if s.zoom and Minimap.SetZoom then pcall(Minimap.SetZoom, Minimap, s.zoom) end
  restoreMinimapChrome()
  restoreMinimapChildren()
  restorePlayerArrow()
  minimapInset.saved = nil
  minimapInset.active = false
end

function TA_ToggleMinimapInset(force)
  local target
  if force == "on" then target = true
  elseif force == "off" then target = false
  else target = not minimapInset.active end
  if target then applyMinimapInset() else restoreMinimap() end
  return minimapInset.active
end

function TA_SetMinimapInsetAlpha(value)
  local v = tonumber(value)
  if not v then return nil end
  v = clamp(v, 0.05, 1)
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.minimapInsetAlpha = v
  if minimapInset.active then Minimap:SetAlpha(v) end
  return v
end

function TA_SetMinimapInsetScale(value)
  local v = tonumber(value)
  if not v then return nil end
  v = clamp(v, 0.3, 1.5)
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.minimapInsetScale = v
  if minimapInset.active then Minimap:SetScale(v) end
  return v
end

function TA_MinimapInsetReapplyPosition()
  if minimapInset.active then applyInsetPosition() end
end

-- ---- Command handler ----

function TA_OreNodeCommand(args)
  local cmd = (args or ""):match("^%s*(%S*)%s*$") or ""
  cmd = cmd:lower()

  if cmd == "clear" or cmd == "reset" then
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if TextAdventurerDB and TextAdventurerDB.oreNodes and mapID then
      local removed = TextAdventurerDB.oreNodes[mapID] and #TextAdventurerDB.oreNodes[mapID] or 0
      TextAdventurerDB.oreNodes[mapID] = {}
      TA.oreNodesVersion = (TA.oreNodesVersion or 0) + 1
      AddLine("system", string.format("Cleared %d ore node(s) for this map.", removed))
    else
      AddLine("system", "No ore nodes to clear.")
    end

  elseif cmd == "clearall" then
    local total = 0
    if TextAdventurerDB and TextAdventurerDB.oreNodes then
      for _, nodes in pairs(TextAdventurerDB.oreNodes) do
        total = total + #nodes
      end
      TextAdventurerDB.oreNodes = {}
      TA.oreNodesVersion = (TA.oreNodesVersion or 0) + 1
    end
    AddLine("system", string.format("Cleared all ore nodes (%d total).", total))

  elseif cmd == "debug" then
    oreDebug = not oreDebug
    AddLine("system", "Ore debug " .. (oreDebug and "ON" or "OFF") .. ". Hover blips and watch chat.")
    if oreDebug then
      local px, py = UnitPosition("player")
      local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
      local facing = GetPlayerFacing and GetPlayerFacing() or 0
      local rotOn = GetCVar and GetCVar("rotateMinimap") == "1"
      AddLine("system", string.format("[ore] state: player=(%s,%s) map=%s facing=%.2f rad rotateMinimap=%s zoom=%s",
        px and string.format("%.1f", px) or "?",
        py and string.format("%.1f", py) or "?",
        tostring(mapID), facing, tostring(rotOn),
        tostring(Minimap:GetZoom())))
    end

  elseif cmd == "list" or cmd == "" then
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local nodes = TextAdventurerDB and TextAdventurerDB.oreNodes and mapID and TextAdventurerDB.oreNodes[mapID]
    if not nodes or #nodes == 0 then
      AddLine("system", "No ore nodes recorded for this map. Hover ore veins to record them.")
      return
    end
    AddLine("system", string.format("Ore nodes on this map: %d (max %d)", #nodes, MAX_NODES_PER_MAP))
    for i, node in ipairs(nodes) do
      AddLine("system", string.format("  %d. %s (%.0f, %.0f)", i, node.n, node.wx or 0, node.wy or 0))
    end

  else
    AddLine("system", "Usage: ore [list|clear|reset|clearall|debug]")
    AddLine("system", "  ore list       - show recorded nodes on current map")
    AddLine("system", "  ore clear      - clear nodes for current map")
    AddLine("system", "  ore reset      - alias for ore clear")
    AddLine("system", "  ore clearall   - clear all saved nodes")
    AddLine("system", "  ore debug      - toggle verbose coord logging on hover")
  end
end

-- Register commands via the standard TA handler tables.
function TA_RegisterOreNodeCommandHandlers(exactHandlers, addPattern)
  exactHandlers["ore"] = function() TA_OreNodeCommand("") end
  addPattern("^ore%s+(.+)$", function(args) TA_OreNodeCommand(args) end)

  exactHandlers["minimap"] = function()
    local on = TA_ToggleMinimapInset()
    AddLine("system", on
      and "Minimap inset ON. Shift+drag to move. Hover ore blips to record. /ta minimap to hide."
      or  "Minimap inset OFF.")
  end
  exactHandlers["minimap on"]  = function() TA_ToggleMinimapInset("on");  AddLine("system", "Minimap inset ON. Shift+drag to move.") end
  exactHandlers["minimap off"] = function() TA_ToggleMinimapInset("off"); AddLine("system", "Minimap inset OFF.") end
  exactHandlers["minimap reset"] = function()
    if TextAdventurerDB then TextAdventurerDB.minimapInsetPos = nil end
    if TA_MinimapInsetReapplyPosition then TA_MinimapInsetReapplyPosition() end
    AddLine("system", "Minimap inset position reset to top-right.")
  end
  addPattern("^minimap%s+alpha%s+([%d%.]+)$", function(arg)
    AddLine("system", string.format("Minimap inset alpha is locked at %.2f for the challenge.", DEFAULT_MINIMAP_INSET_ALPHA))
  end)
  addPattern("^minimap%s+scale%s+([%d%.]+)$", function(arg)
    AddLine("system", string.format("Minimap inset scale is locked at %.2f for the challenge.", DEFAULT_MINIMAP_INSET_SCALE))
  end)
end
