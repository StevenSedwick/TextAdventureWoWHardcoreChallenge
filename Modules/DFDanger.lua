if not TA then
  return
end

DFDanger = DFDanger or {}
local D = DFDanger

D.enabled = true
D.debug = false
D.updateInterval = 0.35
D.warningCooldown = 4.0
D.lastEvalAt = 0
D.lastPrintAt = 0
D.lastPrintedSeverity = 0
D.lastPrintedHazardKey = nil
D.lastEvaluation = nil
D.history = D.history or {}
D.ZoneIndex = D.ZoneIndex or {}
D.ticker = D.ticker or nil
D.eventFrame = D.eventFrame or nil
D.suppressReason = nil
D.lastSuppressed = false
D.lastZoneSeen = nil

local SEVERITY_RANK = {
  none = 0,
  low = 1,
  medium = 2,
  high = 3,
  immediate = 4,
}

local HAZARD_DEFAULT_SYMBOL = {
  cliff = "X",
  elevator_gap = "O",
  bridge_edge = "=",
  lethal_edge = "X",
}

D.DangerAnchors = D.DangerAnchors or {
  {
    zone = "Thunder Bluff",
    name = "Lift_1",
    x = 0.4429,
    y = 0.5975,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Lift_2",
    x = 0.3772,
    y = 0.5078,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Lift_3",
    x = 0.3775,
    y = 0.6260,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Lift_4",
    x = 0.4961,
    y = 0.3632,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Lift_5",
    x = 0.4613,
    y = 0.4243,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Lift_6",
    x = 0.4423,
    y = 0.3998,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Lift_7",
    x = 0.4199,
    y = 0.3462,
    radius = 0.025,
    hazardType = "elevator_gap",
    dropDirection = 180,
    mapSymbol = "O",
    color = "red",
    warningText = "You sense an elevator gap nearby.",
  },
  {
    zone = "Thunder Bluff",
    name = "Bridge_1",
    x = 0.4315,
    y = 0.3929,
    radius = 0.022,
    hazardType = "bridge_edge",
    dropDirection = 90,
    mapSymbol = "=",
    color = "yellow",
    warningText = "The bridge edge feels unsafe.",
  },
  {
    zone = "Thunder Bluff",
    name = "Bridge_2",
    x = 0.5058,
    y = 0.3710,
    radius = 0.022,
    hazardType = "bridge_edge",
    dropDirection = 90,
    mapSymbol = "=",
    color = "yellow",
    warningText = "The bridge edge feels unsafe.",
  },
  {
    zone = "Thunder Bluff",
    name = "Bridge_3",
    x = 0.5845,
    y = 0.4737,
    radius = 0.022,
    hazardType = "bridge_edge",
    dropDirection = 90,
    mapSymbol = "=",
    color = "yellow",
    warningText = "The bridge edge feels unsafe.",
  },
  {
    zone = "Thunder Bluff",
    name = "Bridge_4",
    x = 0.5818,
    y = 0.5571,
    radius = 0.022,
    hazardType = "bridge_edge",
    dropDirection = 90,
    mapSymbol = "=",
    color = "yellow",
    warningText = "The bridge edge feels unsafe.",
  },
  {
    zone = "Thunder Bluff",
    name = "Bridge_5",
    x = 0.3659,
    y = 0.5091,
    radius = 0.022,
    hazardType = "bridge_edge",
    dropDirection = 90,
    mapSymbol = "=",
    color = "yellow",
    warningText = "The bridge edge feels unsafe.",
  },
  {
    zone = "Thunder Bluff",
    name = "Bridge_6",
    x = 0.4478,
    y = 0.6165,
    radius = 0.022,
    hazardType = "bridge_edge",
    dropDirection = 90,
    mapSymbol = "=",
    color = "yellow",
    warningText = "The bridge edge feels unsafe.",
  },
}

local function Clamp(n, lo, hi)
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function SafeLower(s)
  return tostring(s or ""):lower()
end

function D:GetPlayerMapPosition()
  local zone = (GetZoneText and GetZoneText()) or ""
  local mapID, _, _, x, y = nil, nil, nil, nil, nil

  if C_Map and C_Map.GetBestMapForUnit then
    mapID = C_Map.GetBestMapForUnit("player")
    if mapID and C_Map.GetPlayerMapPosition then
      local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
      if okPos and pos then
        if type(pos) == "table" then
          x = tonumber(pos.x)
          y = tonumber(pos.y)
        elseif pos.GetXY then
          local okXY, px, py = pcall(pos.GetXY, pos)
          if okXY then
            x = tonumber(px)
            y = tonumber(py)
          end
        end
      end
    end
  end

  if (not x or not y) and GetPlayerMapCell then
    local okCell, mID, _, _, px, py = pcall(GetPlayerMapCell)
    if okCell then
      mapID = mapID or mID
      x = tonumber(x) or tonumber(px)
      y = tonumber(y) or tonumber(py)
    end
  end

  if not x or not y then
    return nil, nil, nil
  end
  return zone, x, y, mapID
end

function D:GetPlayerFacingDegrees()
  if not GetPlayerFacing then
    return nil
  end
  local ok, facing = pcall(GetPlayerFacing)
  if not ok or type(facing) ~= "number" then
    return nil
  end
  return self:NormalizeAngle(math.deg(facing))
end

function D:Distance2D(x1, y1, x2, y2)
  local dx = (tonumber(x2) or 0) - (tonumber(x1) or 0)
  local dy = (tonumber(y2) or 0) - (tonumber(y1) or 0)
  return math.sqrt((dx * dx) + (dy * dy))
end

function D:NormalizeAngle(angle)
  local a = tonumber(angle)
  if not a then
    return 0
  end
  a = a % 360
  if a < 0 then
    a = a + 360
  end
  return a
end

function D:SmallestAngleDiff(a, b)
  local aa = self:NormalizeAngle(a)
  local bb = self:NormalizeAngle(b)
  local diff = math.abs(aa - bb)
  if diff > 180 then
    diff = 360 - diff
  end
  return diff
end

function D:GetDangerDirection(playerFacing, angleToHazard)
  local pf = tonumber(playerFacing)
  local ah = tonumber(angleToHazard)
  if not pf or not ah then
    return "nearby"
  end

  local delta = self:NormalizeAngle(ah - pf)
  if delta > 180 then
    delta = delta - 360
  end

  local absDelta = math.abs(delta)
  if absDelta <= 30 then
    return "ahead"
  end
  if absDelta >= 150 then
    return "behind"
  end
  if delta > 0 then
    return "left"
  end
  return "right"
end

function D:GetAngleToHazardDegrees(playerX, playerY, hazardX, hazardY)
  local dx = (hazardX or 0) - (playerX or 0)
  local dy = (hazardY or 0) - (playerY or 0)
  if math.abs(dx) < 1e-9 and math.abs(dy) < 1e-9 then
    return nil
  end

  -- WoW map percent coordinates: x grows east, y grows south.
  -- For DF direction labels we use: 0=N, 90=W, 180=S, 270=E.
  local angle = math.deg(math.atan2(-dx, -dy))
  return self:NormalizeAngle(angle)
end

function D:IsMovingTowardHazard(hazard)
  local h = self.history
  if #h < 2 then
    return false, nil
  end

  local prev = h[#h - 1]
  local cur = h[#h]
  if not prev or not cur then
    return false, nil
  end

  local dt = (tonumber(cur.t) or 0) - (tonumber(prev.t) or 0)
  if dt <= 0 or dt > 2.0 then
    return false, nil
  end

  local prevDist = self:Distance2D(prev.x, prev.y, hazard.x, hazard.y)
  local curDist = self:Distance2D(cur.x, cur.y, hazard.x, hazard.y)
  local delta = prevDist - curDist
  return delta > 0.0006, delta
end

function D:PushHistory(x, y)
  local now = GetTime and GetTime() or 0
  local history = self.history
  local n = #history
  if n >= 6 then
    for i = 1, n - 1 do
      history[i] = history[i + 1]
    end
    history[n] = { x = x, y = y, t = now }
  else
    history[n + 1] = { x = x, y = y, t = now }
  end
end

function D:ResetHistory()
  self.history = {}
end

function D:GetWarningText(severity, direction, hazard)
  local dir = direction or "nearby"
  local custom = tostring((hazard and hazard.warningText) or "")
  if severity == "immediate" then
    return "STOP. You may be moving toward a lethal drop."
  end
  if severity == "high" then
    return "Careful. The ground may fall away ahead."
  end
  if severity == "medium" then
    return "Open air lies to your " .. dir .. "."
  end
  if custom ~= "" then
    return custom
  end
  return "You are near a dangerous drop."
end

function D:ChooseOverlaySymbol(hazard, severity, uncertain)
  local defaultSymbol = HAZARD_DEFAULT_SYMBOL[hazard.hazardType] or "X"
  local base = tostring(hazard.mapSymbol or defaultSymbol)

  if severity == "immediate" then
    return "!", "red"
  end
  if severity == "high" then
    return "!", "yellow"
  end
  if uncertain then
    return "?", "yellow"
  end
  return base, tostring(hazard.color or "red")
end

function D:EvaluateDanger()
  if not self.enabled then
    self.lastEvaluation = nil
    return nil, "none", "nearby", nil
  end

  local zone, x, y, mapID = self:GetPlayerMapPosition()
  local facing = self:GetPlayerFacingDegrees()
  if not x or not y then
    self.lastEvaluation = nil
    return nil, "none", "nearby", nil
  end

  self:PushHistory(x, y)

  local best = nil
  local zoneKey = SafeLower(zone)
  local list = self.ZoneIndex and self.ZoneIndex[zoneKey] or nil
  if not list then
    list = self.DangerAnchors
  end
  for i = 1, #list do
    local h = list[i]
    local sameZone = (list == self.DangerAnchors) and (SafeLower(h.zone) == zoneKey) or true
    if sameZone then
      local dist = self:Distance2D(x, y, h.x, h.y)
      local radius = tonumber(h.radius) or 0
      local inside = dist <= radius

      if inside then
        local angleToHazard = self:GetAngleToHazardDegrees(x, y, h.x, h.y)
        local dropDirection = tonumber(h.dropDirection)
        local towardAngle = dropDirection or angleToHazard
        local angleDiff = nil
        local facingToward = false
        if towardAngle and facing ~= nil then
          angleDiff = self:SmallestAngleDiff(facing, towardAngle)
          facingToward = angleDiff <= 45
        end

        local movingToward, moveDelta = self:IsMovingTowardHazard(h)
        local direction = self:GetDangerDirection(facing, towardAngle or angleToHazard)

        local severity = "low"
        if facingToward and movingToward then
          severity = "immediate"
        elseif facingToward then
          severity = "high"
        elseif movingToward then
          severity = "medium"
        elseif dist <= (radius * 0.45) then
          severity = "medium"
        end

        local uncertain = (not towardAngle) or (facing == nil)
        if uncertain and SEVERITY_RANK[severity] < SEVERITY_RANK.medium then
          severity = "medium"
        end

        local text = self:GetWarningText(severity, direction, h)
        local score = (SEVERITY_RANK[severity] * 10) + (1 - Clamp(dist / math.max(radius, 0.0001), 0, 1))

        if (not best) or (score > best.score) then
          local symbol, color = self:ChooseOverlaySymbol(h, severity, uncertain)
          best = {
            hazard = h,
            zone = zone,
            mapID = mapID,
            playerX = x,
            playerY = y,
            playerFacing = facing,
            distance = dist,
            radius = radius,
            angleToHazard = angleToHazard,
            angleDiff = angleDiff,
            facingToward = facingToward,
            movingToward = movingToward,
            moveDelta = moveDelta,
            direction = direction,
            severity = severity,
            warningText = text,
            uncertain = uncertain,
            mapSymbol = symbol,
            color = color,
            score = score,
          }
        end
      end
    end
  end

  self.lastEvaluation = best
  if not best then
    return nil, "none", "nearby", nil
  end
  return best.hazard, best.severity, best.direction, best.warningText, best
end

function D:RenderHazardSymbol(symbol, color)
  local s = tostring(symbol or "X")
  local c = SafeLower(color)
  if c == "red" then
    return "|cffff2020" .. s .. "|r"
  end
  if c == "yellow" then
    return "|cffffff40" .. s .. "|r"
  end
  if c == "orange" then
    return "|cffffa040" .. s .. "|r"
  end
  return "|cffffffff" .. s .. "|r"
end

function D:WorldToDFCell(anchorX, anchorY, playerX, playerY, yardsPerCell)
  return self:MapToDFCell(anchorX, anchorY, playerX, playerY, yardsPerCell or 5)
end

local YPP_CACHE = {}
function D:GetYardsPerPercent()
  local mapID = nil
  if C_Map and C_Map.GetBestMapForUnit then
    local okID, id = pcall(C_Map.GetBestMapForUnit, "player")
    if okID then mapID = id end
  end
  if mapID and YPP_CACHE[mapID] then
    return YPP_CACHE[mapID]
  end
  if mapID and C_Map and C_Map.GetWorldPosFromMapPos then
    local makeVec = CreateVector2D or function(x, y) return { x = x, y = y } end
    local ok1, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.0, 0.5))
    local ok2, p2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(1.0, 0.5))
    if ok1 and ok2 and p1 and p2 then
      ---@diagnostic disable-next-line: undefined-field
      local x1 = tonumber(p1.x) or tonumber(p1[1]) or 0
      ---@diagnostic disable-next-line: undefined-field
      local y1 = tonumber(p1.y) or tonumber(p1[2]) or 0
      ---@diagnostic disable-next-line: undefined-field
      local x2 = tonumber(p2.x) or tonumber(p2[1]) or 0
      ---@diagnostic disable-next-line: undefined-field
      local y2 = tonumber(p2.y) or tonumber(p2[2]) or 0
      local width = math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
      if width > 0 then
        YPP_CACHE[mapID] = width
        return width
      end
    end
  end
  if TA_GetQuestRouterStore then
    local ok, store = pcall(TA_GetQuestRouterStore)
    if ok and type(store) == "table" then
      local ypp = tonumber(store.yardsPerPercent)
      if ypp and ypp > 0 then
        return ypp
      end
    end
  end
  return 1000
end

function D:MapToDFCell(anchorX, anchorY, playerX, playerY, yardsPerCell)
  if not anchorX or not anchorY or not playerX or not playerY then
    return nil, nil
  end

  local ypp = self:GetYardsPerPercent()
  local dxYards = (anchorX - playerX) * ypp
  local dyYards = (playerY - anchorY) * ypp

  local cx = dxYards >= 0 and math.floor((dxYards / yardsPerCell) + 0.5) or math.ceil((dxYards / yardsPerCell) - 0.5)
  local cy = dyYards >= 0 and math.floor((dyYards / yardsPerCell) + 0.5) or math.ceil((dyYards / yardsPerCell) - 0.5)
  return cx, cy
end

function D:GetHazardsForMapCells(context)
  local overlays = {}
  if not self.enabled then
    return overlays
  end

  local zone = context and context.zone
  local mapID = context and context.mapID
  local playerX = context and context.playerX
  local playerY = context and context.playerY
  local innerRadius = (context and context.innerRadius) or 10
  local yardsPerCell = (context and context.yardsPerCell) or 5

  local _, _, _, _, eval = self:EvaluateDanger()

  for i = 1, #self.DangerAnchors do
    local h = self.DangerAnchors[i]
    if SafeLower(h.zone) == SafeLower(zone) then
      local cx, cy = self:MapToDFCell(h.x, h.y, playerX, playerY, yardsPerCell)
      if cx and cy and math.abs(cx) <= innerRadius and math.abs(cy) <= innerRadius then
        local dist = self:Distance2D(playerX, playerY, h.x, h.y)
        local radius = tonumber(h.radius) or 0
        local inside = dist <= radius
        local uncertain = false
        local severity = "low"
        if inside and eval and eval.hazard == h then
          severity = eval.severity or "low"
          uncertain = eval.uncertain and true or false
        elseif inside then
          severity = "low"
          uncertain = true
        end

        local symbol, color = self:ChooseOverlaySymbol(h, severity, uncertain)
        overlays[#overlays + 1] = {
          x = cx,
          y = cy,
          mapID = mapID,
          name = h.name,
          hazardType = h.hazardType,
          symbol = symbol,
          color = color,
          inside = inside,
          severity = severity,
          rendered = self:RenderHazardSymbol(symbol, color),
        }
      end
    end
  end

  return overlays
end

function D:AddHazardOverlayToMap(grid, context)
  if type(grid) ~= "table" then
    return
  end
  local overlays = self:GetHazardsForMapCells(context)
  for i = 1, #overlays do
    local o = overlays[i]
    if grid[o.y] and grid[o.y][o.x] then
      local existing = grid[o.y][o.x]
      if existing == "." or existing == "-" or existing == "=" then
        grid[o.y][o.x] = o.rendered
      elseif o.severity == "immediate" and existing ~= "P" and existing ~= "@" then
        grid[o.y][o.x] = o.rendered
      end
    end
  end
end

function D:FormatWarningLine(eval)
  local h = eval and eval.hazard
  if not h then
    return nil
  end
  local d = eval.direction or "nearby"
  local sev = string.upper(eval.severity or "low")
  local name = tostring(h.name or "danger")
  return string.format("[DF-DANGER %s] %s (%s, %s).", sev, tostring(eval.warningText or "You are near a dangerous drop."), name, d)
end

function D:PrintWarning(eval)
  if not eval or not eval.hazard then
    return
  end

  local now = GetTime and GetTime() or 0
  local key = tostring(eval.hazard.zone) .. ":" .. tostring(eval.hazard.name)
  local rank = SEVERITY_RANK[eval.severity or "low"] or 1
  local shouldPrint = false

  if self.lastPrintedHazardKey ~= key then
    shouldPrint = true
  elseif rank > (self.lastPrintedSeverity or 0) then
    shouldPrint = true
  elseif (now - (self.lastPrintAt or 0)) >= (self.warningCooldown or 4) then
    shouldPrint = true
  end

  if not shouldPrint then
    return
  end

  self.lastPrintAt = now
  self.lastPrintedSeverity = rank
  self.lastPrintedHazardKey = key

  local line = self:FormatWarningLine(eval)
  if not line then
    return
  end

  if AddLine then
    AddLine("system", line)
  elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(line)
  end
end

function D:DebugPrint(eval)
  if not self.debug then
    return
  end

  local zone, x, y = self:GetPlayerMapPosition()
  local facing = self:GetPlayerFacingDegrees()
  if AddLine then
    AddLine("system", string.format("[DFDanger debug] zone=%s x=%.4f y=%.4f facing=%s", tostring(zone or "?"), tonumber(x) or -1, tonumber(y) or -1, tostring(facing or "?")))
  end

  if eval and eval.hazard and AddLine then
    AddLine(
      "system",
      string.format(
        "[DFDanger debug] nearest=%s dist=%.4f radius=%.4f angleDiff=%s severity=%s movingToward=%s",
        tostring(eval.hazard.name or "?"),
        tonumber(eval.distance) or -1,
        tonumber(eval.radius) or -1,
        tostring(eval.angleDiff and string.format("%.1f", eval.angleDiff) or "?"),
        tostring(eval.severity or "none"),
        tostring(eval.movingToward and "yes" or "no")
      )
    )
  end
end

function D:IsSuppressed()
  if UnitOnTaxi and UnitOnTaxi("player") then
    self.suppressReason = "taxi"
    return true
  end
  if IsInInstance then
    local ok, inInstance = pcall(IsInInstance)
    if ok and inInstance then
      self.suppressReason = "instance"
      return true
    end
  end
  self.suppressReason = nil
  return false
end

function D:ResetState(reason)
  self.lastEvaluation = nil
  self.lastEvalAt = 0
  self.lastPrintAt = 0
  self.lastPrintedSeverity = 0
  self.lastPrintedHazardKey = nil
  self:ResetHistory()
  if self.debug and AddLine then
    AddLine("system", "[DFDanger] state reset (" .. tostring(reason or "manual") .. ").")
  end
end

function D:RebuildZoneIndex()
  local idx = {}
  for i = 1, #self.DangerAnchors do
    local h = self.DangerAnchors[i]
    local key = SafeLower(h.zone)
    local bucket = idx[key]
    if not bucket then
      bucket = {}
      idx[key] = bucket
    end
    bucket[#bucket + 1] = h
  end
  self.ZoneIndex = idx
end

function D:Tick()
  if not self.enabled then
    return
  end
  local suppressed = self:IsSuppressed()
  if suppressed then
    if not self.lastSuppressed then
      self:ResetState(self.suppressReason or "suppressed")
      self.lastSuppressed = true
    end
    return
  end
  if self.lastSuppressed then
    self.lastSuppressed = false
    self:ResetState("resumed")
  end

  local zoneNow = (GetZoneText and GetZoneText()) or ""
  if self.lastZoneSeen and self.lastZoneSeen ~= zoneNow then
    self:ResetState("zone change tick")
  end
  self.lastZoneSeen = zoneNow

  local now = GetTime and GetTime() or 0
  if (now - (self.lastEvalAt or 0)) < (self.updateInterval or 0.35) then
    return
  end
  self.lastEvalAt = now

  local _, severity, _, _, eval = self:EvaluateDanger()
  if not eval then
    self.lastPrintedHazardKey = nil
    self.lastPrintedSeverity = 0
  elseif severity ~= "none" then
    self:PrintWarning(eval)
  end
  self:DebugPrint(eval)
end

function D:EnsureTicker()
  if self.ticker then return end
  if C_Timer and C_Timer.NewTicker then
    self.ticker = C_Timer.NewTicker(self.updateInterval or 0.35, function()
      local ok, err = pcall(function() D:Tick() end)
      if not ok and D.debug and AddLine then
        AddLine("system", "[DFDanger] tick error: " .. tostring(err))
      end
    end)
  end
end

function D:EnsureEventFrame()
  if self.eventFrame then return end
  if not CreateFrame then return end
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("ZONE_CHANGED")
  f:RegisterEvent("ZONE_CHANGED_INDOORS")
  f:RegisterEvent("PLAYER_CONTROL_LOST")
  f:RegisterEvent("PLAYER_CONTROL_GAINED")
  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
      D:RebuildZoneIndex()
      D:EnsureTicker()
    elseif event == "PLAYER_ENTERING_WORLD" then
      D:ResetState(event)
      D:RebuildZoneIndex()
      D:EnsureTicker()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
      D:ResetState(event)
    elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
      D:ResetState(event)
    end
  end)
  self.eventFrame = f
end

local function PersistFlags()
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfDangerEnabled = D.enabled and true or false
  TextAdventurerDB.dfDangerDebug = D.debug and true or false
end

local function Trim(s)
  return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function SplitBy(str, sep)
  local out = {}
  local s = tostring(str or "")
  local p = tostring(sep or "")
  if p == "" then
    out[1] = s
    return out
  end
  local start = 1
  while true do
    local i, j = string.find(s, p, start, true)
    if not i then
      table.insert(out, string.sub(s, start))
      break
    end
    table.insert(out, string.sub(s, start, i - 1))
    start = j + 1
  end
  return out
end

local function ClampRadius(radius)
  local r = tonumber(radius) or 0.03
  if r < 0.005 then r = 0.005 end
  if r > 0.2 then r = 0.2 end
  return r
end

function D:PersistAnchors()
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfDangerAnchors = {}
  for i = 1, #self.DangerAnchors do
    local h = self.DangerAnchors[i]
    TextAdventurerDB.dfDangerAnchors[i] = {
      zone = tostring(h.zone or "Unknown"),
      name = tostring(h.name or ("Hazard " .. tostring(i))),
      x = tonumber(h.x) or 0,
      y = tonumber(h.y) or 0,
      radius = tonumber(h.radius) or 0.03,
      hazardType = tostring(h.hazardType or "cliff"),
      dropDirection = tonumber(h.dropDirection) or 0,
      mapSymbol = tostring(h.mapSymbol or (HAZARD_DEFAULT_SYMBOL[h.hazardType] or "X")),
      color = tostring(h.color or "red"),
      warningText = tostring(h.warningText or "You are near a dangerous drop."),
    }
  end
end

local function LoadFlags()
  TextAdventurerDB = TextAdventurerDB or {}
  if TextAdventurerDB.dfDangerEnabled == nil then
    TextAdventurerDB.dfDangerEnabled = true
  end
  D.enabled = TextAdventurerDB.dfDangerEnabled and true or false
  D.debug = TextAdventurerDB.dfDangerDebug and true or false

  if type(TextAdventurerDB.dfDangerAnchors) == "table" and #TextAdventurerDB.dfDangerAnchors > 0 then
    D.DangerAnchors = {}
    for i = 1, #TextAdventurerDB.dfDangerAnchors do
      local h = TextAdventurerDB.dfDangerAnchors[i]
      D.DangerAnchors[i] = {
        zone = tostring(h.zone or "Unknown"),
        name = tostring(h.name or ("Hazard " .. tostring(i))),
        x = tonumber(h.x) or 0,
        y = tonumber(h.y) or 0,
        radius = tonumber(h.radius) or 0.03,
        hazardType = tostring(h.hazardType or "cliff"),
        dropDirection = tonumber(h.dropDirection) or 0,
        mapSymbol = tostring(h.mapSymbol or (HAZARD_DEFAULT_SYMBOL[h.hazardType] or "X")),
        color = tostring(h.color or "red"),
        warningText = tostring(h.warningText or "You are near a dangerous drop."),
      }
    end
  end
end

function D:ListAnchors(zoneFilter)
  local zf = SafeLower(zoneFilter)
  AddLine("system", "DFDanger anchors:")
  for i = 1, #self.DangerAnchors do
    local h = self.DangerAnchors[i]
    if zf == "" or SafeLower(h.zone) == zf then
      AddLine(
        "system",
        string.format(
          "  [%d] %s | zone=%s type=%s x=%.4f y=%.4f r=%.4f dir=%s",
          i,
          tostring(h.name or "?"),
          tostring(h.zone or "?"),
          tostring(h.hazardType or "?"),
          tonumber(h.x) or 0,
          tonumber(h.y) or 0,
          tonumber(h.radius) or 0,
          tostring(h.dropDirection or "?")
        )
      )
    end
  end
end

function D:AddPointHere(name, hazardType, radius)
  local zone, x, y = self:GetPlayerMapPosition()
  if not x or not y then
    AddLine("system", "DFDanger addpoint failed: map position unavailable.")
    return
  end

  local r = ClampRadius(radius)

  local hType = tostring(hazardType or "cliff")
  local symbol = HAZARD_DEFAULT_SYMBOL[hType] or "X"
  local point = {
    zone = zone or "Unknown",
    name = tostring(name or "New hazard"),
    x = x,
    y = y,
    radius = r,
    hazardType = hType,
    dropDirection = self:GetPlayerFacingDegrees() or 0,
    mapSymbol = symbol,
    color = (hType == "bridge_edge") and "yellow" or "red",
    warningText = "You are near a dangerous drop.",
  }

  table.insert(self.DangerAnchors, point)
  self:RebuildZoneIndex()
  self:PersistAnchors()
  AddLine(
    "system",
    string.format(
      "DFDanger point added: %s (%s) zone=%s x=%.4f y=%.4f r=%.4f",
      point.name,
      point.hazardType,
      point.zone,
      point.x,
      point.y,
      point.radius
    )
  )
end

function D:AddPointXY(name, hazardType, x, y, radius, dropDirection, zone)
  local nx = tonumber(x)
  local ny = tonumber(y)
  if not nx or not ny then
    AddLine("system", "DFDanger addxy failed: x and y must be numbers.")
    return false
  end

  local hType = tostring(hazardType or "cliff")
  local symbol = HAZARD_DEFAULT_SYMBOL[hType] or "X"
  local r = ClampRadius(radius)
  local z = Trim(zone)
  if z == "" then
    z = (GetZoneText and GetZoneText()) or "Unknown"
  end

  local point = {
    zone = z,
    name = tostring(name or "Imported hazard"),
    x = nx,
    y = ny,
    radius = r,
    hazardType = hType,
    dropDirection = tonumber(dropDirection) or 0,
    mapSymbol = symbol,
    color = (hType == "bridge_edge") and "yellow" or "red",
    warningText = "You are near a dangerous drop.",
  }

  table.insert(self.DangerAnchors, point)
  self:RebuildZoneIndex()
  self:PersistAnchors()
  return true
end

function D:ClearAnchors()
  self.DangerAnchors = {}
  self.lastEvaluation = nil
  self.lastPrintedHazardKey = nil
  self.lastPrintedSeverity = 0
  self:RebuildZoneIndex()
  self:PersistAnchors()
  AddLine("system", "DFDanger anchors cleared.")
end

function D:ImportAnchorBatch(payload, replaceExisting)
  local text = Trim(payload)
  if text == "" then
    AddLine("system", "DFDanger import failed: payload is empty.")
    return
  end

  if replaceExisting then
    self.DangerAnchors = {}
  end

  local currentZone = (GetZoneText and GetZoneText()) or "Unknown"
  local chunks = SplitBy(text, ";")
  local imported = 0
  local skipped = 0

  for i = 1, #chunks do
    local chunk = Trim(chunks[i])
    if chunk ~= "" then
      local parts = SplitBy(chunk, "|")
      local name = Trim(parts[1])
      local hazardType = Trim(parts[2])
      local x = tonumber(Trim(parts[3]))
      local y = tonumber(Trim(parts[4]))
      local radius = tonumber(Trim(parts[5]))
      local dropDirection = tonumber(Trim(parts[6])) or 0
      local zone = Trim(parts[7])

      if name == "" then
        name = "Imported hazard " .. tostring(i)
      end
      if hazardType == "" then
        hazardType = "cliff"
      end
      if zone == "" then
        zone = currentZone
      end

      if x and y and radius then
        local ok = self:AddPointXY(name, hazardType, x, y, radius, dropDirection, zone)
        if ok then
          imported = imported + 1
        else
          skipped = skipped + 1
        end
      else
        skipped = skipped + 1
      end
    end
  end

  self:RebuildZoneIndex()
  self:PersistAnchors()
  AddLine("system", string.format("DFDanger import complete: %d imported, %d skipped.", imported, skipped))
end

function D:ExportAnchors(zoneFilter)
  local zf = SafeLower(zoneFilter)
  local chunks = {}
  for i = 1, #self.DangerAnchors do
    local h = self.DangerAnchors[i]
    if zf == "" or SafeLower(h.zone) == zf then
      chunks[#chunks + 1] = string.format(
        "%s|%s|%.4f|%.4f|%.4f|%d|%s",
        tostring(h.name or "Hazard"),
        tostring(h.hazardType or "cliff"),
        tonumber(h.x) or 0,
        tonumber(h.y) or 0,
        ClampRadius(h.radius),
        math.floor(tonumber(h.dropDirection) or 0),
        tostring(h.zone or "Unknown")
      )
    end
  end

  if #chunks == 0 then
    AddLine("system", "DFDanger export: no anchors matched filter.")
    return
  end

  AddLine("system", "DFDanger export payload (use with: dfdanger import <payload>):")
  AddLine("system", table.concat(chunks, ";"))
end

local TB_IMPORT_HIGH = table.concat({
  "Lift_1|elevator_gap|44.29|59.75|0.025|180|Thunder Bluff",
  "Lift_2|elevator_gap|37.72|50.78|0.025|180|Thunder Bluff",
  "Lift_3|elevator_gap|37.75|62.60|0.025|180|Thunder Bluff",
  "Lift_4|elevator_gap|49.61|36.32|0.025|180|Thunder Bluff",
  "Lift_5|elevator_gap|46.13|42.43|0.025|180|Thunder Bluff",
  "Lift_6|elevator_gap|44.23|39.98|0.025|180|Thunder Bluff",
  "Lift_7|elevator_gap|41.99|34.62|0.025|180|Thunder Bluff",
  "Bridge_1|bridge_edge|43.15|39.29|0.022|90|Thunder Bluff",
  "Bridge_2|bridge_edge|50.58|37.10|0.022|90|Thunder Bluff",
  "Bridge_3|bridge_edge|58.45|47.37|0.022|90|Thunder Bluff",
  "Bridge_4|bridge_edge|58.18|55.71|0.022|90|Thunder Bluff",
  "Bridge_5|bridge_edge|36.59|50.91|0.022|90|Thunder Bluff",
  "Bridge_6|bridge_edge|44.78|61.65|0.022|90|Thunder Bluff",
}, ";")

local TB_IMPORT_CLIFF = table.concat({
  "Cliff_1|cliff|44.47|59.87|0.030|180|Thunder Bluff",
  "Cliff_2|cliff|44.37|59.51|0.030|180|Thunder Bluff",
  "Cliff_3|cliff|37.64|50.61|0.030|180|Thunder Bluff",
  "Cliff_4|cliff|37.89|50.62|0.030|180|Thunder Bluff",
  "Cliff_5|cliff|37.83|62.38|0.030|180|Thunder Bluff",
  "Cliff_6|cliff|37.99|62.60|0.030|180|Thunder Bluff",
  "Cliff_7|cliff|49.72|36.50|0.030|180|Thunder Bluff",
  "Cliff_8|cliff|45.95|42.48|0.030|180|Thunder Bluff",
  "Cliff_9|cliff|44.01|40.01|0.030|180|Thunder Bluff",
  "Cliff_10|cliff|41.75|34.65|0.030|180|Thunder Bluff",
}, ";")

function D:ImportThunderBluffPreset(mode)
  local m = SafeLower(mode)
  self:ImportAnchorBatch(TB_IMPORT_HIGH, true)
  if m == "full" or m == "all" then
    self:ImportAnchorBatch(TB_IMPORT_CLIFF, false)
    AddLine("system", "DFDanger Thunder Bluff preset loaded (high + cliff candidates).")
    return
  end
  AddLine("system", "DFDanger Thunder Bluff preset loaded (high confidence).")
end

local function HandleDFDangerCommand(args)
  local lower = SafeLower(args):match("^%s*(.-)%s*$")
  if lower == "" or lower == "help" then
    AddLine("system", "DFDanger commands: on | off | debug | list | clear | export [zone]")
    AddLine("system", "                  addpoint <name> <hazardType> [radius]")
    AddLine("system", "                  addxy <name> <hazardType> <x> <y> [radius] [dropDir] [zone]")
    AddLine("system", "                  importtb [full]")
    AddLine("system", "                  import <name|type|x|y|radius|dropDir|zone;...>")
    AddLine("system", "Examples: /dfdanger addpoint Elevator Gap elevator_gap 0.03")
    AddLine("system", "          /dfdanger addxy Lift SW elevator_gap 37.72 50.78 0.025 180")
    AddLine("system", "          /dfdanger import Lift A|elevator_gap|44.29|59.75|0.025|180|Thunder Bluff;Bridge NE|bridge_edge|58.18|55.71|0.022|90|Thunder Bluff")
    return
  end

  if lower == "on" then
    D.enabled = true
    PersistFlags()
    AddLine("system", "DFDanger enabled.")
    return
  end

  if lower == "off" then
    D.enabled = false
    PersistFlags()
    AddLine("system", "DFDanger disabled.")
    return
  end

  if lower == "debug" then
    D.debug = not D.debug
    PersistFlags()
    AddLine("system", "DFDanger debug " .. (D.debug and "enabled" or "disabled") .. ".")
    return
  end

  if lower == "list" then
    local zone = GetZoneText and GetZoneText() or ""
    D:ListAnchors(zone)
    return
  end

  if lower == "clear" then
    D:ClearAnchors()
    return
  end

  local tbMode = args:match("^%s*importtb%s*(.-)%s*$")
  if tbMode ~= nil then
    D:ImportThunderBluffPreset(tbMode)
    return
  end

  local exportZone = args:match("^%s*export%s*(.-)%s*$")
  if exportZone ~= nil then
    D:ExportAnchors(exportZone)
    return
  end

  local payload = args:match("^%s*import%s+(.+)%s*$")
  if payload then
    D:ImportAnchorBatch(payload, true)
    return
  end

  local appendPayload = args:match("^%s*append%s+(.+)%s*$")
  if appendPayload then
    D:ImportAnchorBatch(appendPayload, false)
    return
  end

  local nameXY, hazardTypeXY, x, y, radius, dropDirection, zone = args:match("^%s*addxy%s+(.+)%s+([%w_%-]+)%s+([%d%.]+)%s+([%d%.]+)%s*([%d%.%-]*)%s*([%d%.%-]*)%s*(.-)%s*$")
  if nameXY and hazardTypeXY and x and y then
    D:AddPointXY(nameXY, hazardTypeXY, x, y, radius, dropDirection, zone)
    AddLine("system", string.format("DFDanger addxy: %s (%s) @ %.4f, %.4f", nameXY, hazardTypeXY, tonumber(x) or 0, tonumber(y) or 0))
    return
  end

  local name, hazardType, radius = args:match("^%s*addpoint%s+(.+)%s+([%w_%-]+)%s+([%d%.]+)%s*$")
  if name and hazardType and radius then
    D:AddPointHere(name, hazardType, radius)
    return
  end

  local nameNoRadius, hazardTypeNoRadius = args:match("^%s*addpoint%s+(.+)%s+([%w_%-]+)%s*$")
  if nameNoRadius and hazardTypeNoRadius then
    D:AddPointHere(nameNoRadius, hazardTypeNoRadius, 0.03)
    return
  end

  AddLine("system", "Usage: dfdanger help")
end

function TA_RegisterDFDangerCommandHandlers(exactHandlers, addPatternHandler)
  if TA.dfDangerCommandHandlersRegistered then
    return
  end

  LoadFlags()

  exactHandlers["dfdanger"] = function() HandleDFDangerCommand("help") end
  exactHandlers["dfdanger help"] = function() HandleDFDangerCommand("help") end
  exactHandlers["dfdanger on"] = function() HandleDFDangerCommand("on") end
  exactHandlers["dfdanger off"] = function() HandleDFDangerCommand("off") end
  exactHandlers["dfdanger debug"] = function() HandleDFDangerCommand("debug") end
  exactHandlers["dfdanger list"] = function() HandleDFDangerCommand("list") end
  exactHandlers["dfdanger clear"] = function() HandleDFDangerCommand("clear") end
  exactHandlers["dfdanger export"] = function() HandleDFDangerCommand("export") end
  exactHandlers["dfdanger importtb"] = function() HandleDFDangerCommand("importtb") end

  addPatternHandler("^dfdanger%s+addpoint%s+(.+)%s+([%w_%-]+)$", function(name, hazardType)
    D:AddPointHere(name, hazardType, 0.03)
  end)

  addPatternHandler("^dfdanger%s+addpoint%s+(.+)%s+([%w_%-]+)%s+([%d%.]+)$", function(name, hazardType, radius)
    D:AddPointHere(name, hazardType, radius)
  end)

  addPatternHandler("^dfdanger%s+addxy%s+(.+)%s+([%w_%-]+)%s+([%d%.]+)%s+([%d%.]+)$", function(name, hazardType, x, y)
    D:AddPointXY(name, hazardType, x, y, 0.03, 0, nil)
  end)

  addPatternHandler("^dfdanger%s+import%s+(.+)$", function(payload)
    D:ImportAnchorBatch(payload, true)
  end)

  addPatternHandler("^dfdanger%s+append%s+(.+)$", function(payload)
    D:ImportAnchorBatch(payload, false)
  end)

  TA.dfDangerCommandHandlersRegistered = true
end

local function HandleSlashDFDanger(msg)
  HandleDFDangerCommand(msg or "")
end

if not SLASH_DFDANGER1 then
  SLASH_DFDANGER1 = "/dfdanger"
  SlashCmdList.DFDANGER = HandleSlashDFDanger
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler and TA_RegisterDFDangerCommandHandlers then
  TA_RegisterDFDangerCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end

LoadFlags()
D:RebuildZoneIndex()
D:EnsureEventFrame()
D:EnsureTicker()
