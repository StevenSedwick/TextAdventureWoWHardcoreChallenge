-- Modules/DFMode.lua
-- Dwarf-Fortress-style tactical map for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * The dfModeFrame UI (frame, title, resize handle, fixed FontString rows).
--   * DF state helpers (TA_RecordDFLastKnownUnits, TA_PruneDFLastKnownUnits,
--     TA_RecordDFCorpseFromGUID, TA_PruneDFCorpseContacts).
--   * The shared render context TA._dfCtx and its helper methods.
--   * BuildDFModeDisplay (the per-tick render builder).
--   * Public API: TA_SetDFModeSize, TA_SetDFModeMarkRadius, TA_DFModeStatus,
--     TA_UpdateDFMode, TA_ToggleDFMode, TA_GetEffectiveDFYardsPerCell,
--     TA_GetProjectedDFPlayerWorldPosition.
--
-- This file must load AFTER textadventurer.lua (which defines TA and the
-- shared helpers DF code calls into) and BEFORE any module that calls the
-- DF public API (e.g. Modules/NavigationCommands.lua). See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  -- Defensive: textadventurer.lua should have created TA before this loads.
  TA = {}
  _G.TA = TA
end
TA._dfCtx = TA._dfCtx or {}

-- Constants duplicated from textadventurer.lua (kept locally for the frame
-- construction below). The originals stay in the main file because saved-
-- variable init code there still references them.
local DF_MODE_DEFAULT_WIDTH = 400
local DF_MODE_DEFAULT_HEIGHT = 600
local DF_MODE_MIN_USABLE_WIDTH = 300

-- ---- moved from textadventurer.lua lines 605-683 ----

local dfModeFrame = CreateFrame("Frame", "TextAdventurerDFModeFrame", UIParent, "BackdropTemplate")
dfModeFrame:SetSize(DF_MODE_DEFAULT_WIDTH, DF_MODE_DEFAULT_HEIGHT)
dfModeFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
dfModeFrame:SetFrameStrata("TOOLTIP")
dfModeFrame:SetFrameLevel(11000)
dfModeFrame:SetClampedToScreen(true)
if dfModeFrame.SetResizable then
  dfModeFrame:SetResizable(true)
end
if dfModeFrame.SetMinResize then
  dfModeFrame:SetMinResize(300, 200)
end
if dfModeFrame.SetMaxResize then
  dfModeFrame:SetMaxResize(1200, 1000)
end
dfModeFrame:SetMovable(true)
dfModeFrame:EnableMouse(true)
dfModeFrame:RegisterForDrag("LeftButton")
dfModeFrame:SetScript("OnDragStart", dfModeFrame.StartMoving)
dfModeFrame:SetScript("OnDragStop", dfModeFrame.StopMovingOrSizing)
dfModeFrame:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
    self:StartMoving()
  end
end)
dfModeFrame:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" then
    self:StopMovingOrSizing()
  end
end)
dfModeFrame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
dfModeFrame:SetBackdropColor(0.05, 0.08, 0.10, 0.96)
dfModeFrame:Hide()

local dfTitle = dfModeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dfTitle:SetPoint("TOPLEFT", 8, -8)
dfTitle:SetText("threat")

dfModeFrame.resizeHandle = CreateFrame("Button", nil, dfModeFrame)
dfModeFrame.resizeHandle:SetPoint("BOTTOMRIGHT", -6, 6)
dfModeFrame.resizeHandle:SetSize(16, 16)
dfModeFrame.resizeHandle:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
dfModeFrame.resizeHandle:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
dfModeFrame.resizeHandle:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
dfModeFrame.resizeHandle:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" and self:GetParent().StartSizing then
    self:GetParent():StartSizing("BOTTOMRIGHT")
  end
end)
dfModeFrame.resizeHandle:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" then
    self:GetParent():StopMovingOrSizing()
  end
end)

-- Fixed FontString rows for flicker-free in-place map updates (Dwarf Fortress style)
local dfMapContainer = CreateFrame("Frame", nil, dfModeFrame)
dfMapContainer:SetPoint("TOPLEFT", 18, -42)
dfMapContainer:SetPoint("BOTTOMRIGHT", -18, 18)

local DF_MAX_ROWS = 50
local DF_LINE_HEIGHT = 12
dfModeFrame.mapLines = {}
for i = 1, DF_MAX_ROWS do
  local fs = dfMapContainer:CreateFontString(nil, "OVERLAY")
  fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
  fs:SetPoint("TOPLEFT", 0, -(i - 1) * DF_LINE_HEIGHT)
  fs:SetJustifyH("LEFT")
  fs:SetTextColor(0.6, 1.0, 0.9)
  fs:SetText("")
  dfModeFrame.mapLines[i] = fs
end

-- Expose the frame so external init code (saved-variable handler in
-- textadventurer.lua) can show it after load.
TA._dfModeFrame = dfModeFrame

-- Returns the screen-space (x, y) of the P glyph (player center) in the DF map.
-- Uses dfMapContainer geometry: P is at horizontal center, vertically at the
-- center row (row radius+1 from the top, where radius = floor(gridSize/2)).
-- Returns nil if the frame isn't visible or positioned yet.
function TA.GetDFPlayerScreenCenter()
  if not dfModeFrame:IsShown() then return nil end
  local left  = dfMapContainer:GetLeft()
  local top   = dfMapContainer:GetTop()
  local width = dfMapContainer:GetWidth()
  if not left or not top or not width then return nil end
  local gridSize = TA.dfModeGridSize or 35
  local radius   = math.floor(gridSize / 2)
  local screenX  = left + width * 0.5
  local screenY  = top - radius * DF_LINE_HEIGHT - DF_LINE_HEIGHT * 0.5
  return screenX, screenY
end

-- ---- moved from textadventurer.lua lines 10046-10112 ----
local function TA_RecordDFLastKnownUnits(units, mapID)
  if not units or not mapID then return end
  local now = GetTime()
  local lastKnown = TA.dfModeLastKnownUnits or {}
  local function ingest(kind, list)
    for _, u in ipairs(list or {}) do
      if u and u.hasExactPos and u.worldX and u.worldY and u.guid then
        lastKnown[u.guid] = {
          guid = u.guid,
          name = u.name or "Unknown",
          kind = kind,
          mapID = mapID,
          worldX = u.worldX,
          worldY = u.worldY,
          seenAt = now,
          expiresAt = now + 30,
        }
      end
    end
  end
  ingest("hostile", units.hostile)
  ingest("neutral", units.neutral)
  ingest("friendly", units.friendly)
  TA.dfModeLastKnownUnits = lastKnown
end

local function TA_PruneDFLastKnownUnits(mapID)
  local now = GetTime()
  for key, u in pairs(TA.dfModeLastKnownUnits or {}) do
    if type(u) ~= "table" or not u.expiresAt or u.expiresAt <= now or (mapID and u.mapID and u.mapID ~= mapID) then
      TA.dfModeLastKnownUnits[key] = nil
    end
  end
end

function TA_RecordDFCorpseFromGUID(guid, name, mapID)
  if not guid then return end
  local known = TA.dfModeLastKnownUnits and TA.dfModeLastKnownUnits[guid]
  if type(known) ~= "table" then return end
  if mapID and known.mapID and known.mapID ~= mapID then return end
  if not known.worldX or not known.worldY then return end

  local now = GetTime()
  local ttl = math.max(5, tonumber(TA.dfModeCorpseTTL) or 45)
  local corpses = TA.dfModeCorpseContacts or {}
  local key = "corpse:" .. tostring(guid)
  corpses[key] = {
    key = key,
    guid = guid,
    name = name or known.name or "Unknown",
    mapID = known.mapID or mapID,
    worldX = known.worldX,
    worldY = known.worldY,
    seenAt = now,
    expiresAt = now + ttl,
  }
  TA.dfModeCorpseContacts = corpses
end

local function TA_PruneDFCorpseContacts(mapID)
  local now = GetTime()
  for key, c in pairs(TA.dfModeCorpseContacts or {}) do
    if type(c) ~= "table" or not c.expiresAt or c.expiresAt <= now or (mapID and c.mapID and c.mapID ~= mapID) then
      TA.dfModeCorpseContacts[key] = nil
    end
  end
end

-- ---- moved from textadventurer.lua lines 10661-11872 ----
-- Shared DF render context. Populated by BuildDFModeDisplay each tick and
-- read by the file-scope helpers below. Kept at file scope so the helpers do
-- not have to be re-created (with fresh upvalues) on every tick. Stored on
-- TA (rather than as a separate file-scope local) to avoid bloating the
-- chunk's local-variable count past Lua 5.1's 200-local limit. The helpers
-- use the local alias only for the duration of this declaration block; at
-- runtime the helpers look up their context as TA._dfCtx via upvalue.
TA._dfCtx = TA._dfCtx or {}
do
local dfCtx = TA._dfCtx

function dfCtx.roundNearest(n)
  if n >= 0 then
    return math.floor(n + 0.5)
  end
  return math.ceil(n - 0.5)
end

function dfCtx.octantAngle(angle)
  local step = math.pi / 4
  return math.floor((angle / step) + 0.5) * step
end

function dfCtx.distanceBucket(d)
  if d <= 8 then return 2 end
  if d <= 18 then return 4 end
  if d <= 30 then return 6 end
  return math.min(dfCtx.radius or 8, 8)
end

function dfCtx.isSameTerrainChunk(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  return (a.tileX == b.tileX) and (a.tileY == b.tileY) and (a.chunkX == b.chunkX) and (a.chunkY == b.chunkY)
end

function dfCtx.getGridDistance(x, y)
  local cache = dfCtx.gridDistanceCache
  local row = cache[y]
  if not row then
    row = {}
    cache[y] = row
  end
  local d = row[x]
  if not d then
    d = math.sqrt((x * x) + (y * y))
    row[x] = d
  end
  return d
end

function dfCtx.getTerrainCellAtOffset(wx, wy)
  local px = dfCtx.playerWorldX
  local py = dfCtx.playerWorldY
  if not px or not py then
    return nil
  end
  local terrainCache = dfCtx.terrainCache
  local yardsPerCell = dfCtx.yardsPerCell or 3
  local sampleX = px + (wx * yardsPerCell)
  local sampleY = py + (wy * yardsPerCell)
  -- Key the cache on the snapped *absolute* world cell. The terrain at a fixed
  -- world position is invariant under player motion, so this lets the cache
  -- survive walking/running indefinitely (only invalidated on map/mode/ypc
  -- changes — handled by the caller in BuildDFModeDisplay). Size is bounded
  -- by a soft cap (also enforced by the caller).
  local snapX = sampleX >= 0 and math.floor(sampleX / yardsPerCell + 0.5)
                              or  math.ceil(sampleX / yardsPerCell - 0.5)
  local snapY = sampleY >= 0 and math.floor(sampleY / yardsPerCell + 0.5)
                              or  math.ceil(sampleY / yardsPerCell - 0.5)
  local key = snapX .. ":" .. snapY
  local cached = terrainCache[key]
  if cached ~= nil then
    return cached ~= false and cached or nil
  end

  local stats = dfCtx.terrainStats
  if stats then stats.lookups = (stats.lookups or 0) + 1 end
  local terrainCell = TA_GetTerrainContextAtWorldPos(sampleX, sampleY, dfCtx.terrainLookupMode)
  terrainCache[key] = terrainCell or false
  terrainCache._count = (terrainCache._count or 0) + 1
  return terrainCell
end

function dfCtx.getLocalTerrainBaselines(wx, wy, anchorTerrainCell)
  local slopeSum = 0
  local heightSum = 0
  local count = 0
  local slopeMin, slopeMax = nil, nil
  local heightMin, heightMax = nil, nil
  for oy = -1, 1 do
    for ox = -1, 1 do
      if not (ox == 0 and oy == 0) then
        local n = dfCtx.getTerrainCellAtOffset(wx + ox, wy + oy)
        if n and n.resolved then
          if anchorTerrainCell and not dfCtx.isSameTerrainChunk(anchorTerrainCell, n) then
            -- Keep the baseline local to the same ADT chunk so nearby chunk
            -- transitions do not flatten or overstate local slope cues.
            n = nil
          end
        end
        if n and n.resolved then
          local nSlope = tonumber(n.avgSlope)
          local nHeight = tonumber(n.avgHeight)
          if nSlope ~= nil and nHeight ~= nil then
            count = count + 1
            slopeSum = slopeSum + nSlope
            heightSum = heightSum + nHeight
            if slopeMin == nil or nSlope < slopeMin then slopeMin = nSlope end
            if slopeMax == nil or nSlope > slopeMax then slopeMax = nSlope end
            if heightMin == nil or nHeight < heightMin then heightMin = nHeight end
            if heightMax == nil or nHeight > heightMax then heightMax = nHeight end
          end
        end
      end
    end
  end

  if count >= 3 then
    local slopeRelief = (slopeMax and slopeMin) and (slopeMax - slopeMin) or 0
    local heightRelief = (heightMax and heightMin) and (heightMax - heightMin) or 0
    return (heightSum / count), (slopeSum / count), slopeRelief, heightRelief
  end

  if anchorTerrainCell and anchorTerrainCell.resolved then
    -- Fallback: if there are too few same-chunk neighbors, use the anchor
    -- cell sample itself instead of averaging across other chunks.
    local aHeight = tonumber(anchorTerrainCell.avgHeight)
    local aSlope = tonumber(anchorTerrainCell.avgSlope)
    return aHeight, aSlope, 0, 0
  end

  return nil, nil, 0, 0
end

function dfCtx.getSmoothedTerrainGlyph(x, y)
  local terrainLayer = dfCtx.terrainLayer
  local raw = terrainLayer[y] and terrainLayer[y][x] or "."
  if raw ~= "A" and raw ~= "V" and raw ~= "/" and raw ~= "^" then
    return raw
  end

  local counts = { ["A"] = 0, ["V"] = 0, ["/"] = 0, ["^"] = 0 }
  for oy = -1, 1 do
    for ox = -1, 1 do
      if not (ox == 0 and oy == 0) then
        local ny = y + oy
        local nx = x + ox
        local g = terrainLayer[ny] and terrainLayer[ny][nx] or nil
        if counts[g] ~= nil then
          counts[g] = counts[g] + 1
        end
      end
    end
  end

  -- Cliff-only mode: require stronger local consensus and never propagate
  -- A/V into neighbors (prevents wave-like advancing vertical bands).
  if raw == "V" then
    if counts[raw] < 3 then
      return "."
    end
    return raw
  end
  if raw == "^" and counts["^"] < 2 and counts["/"] >= 2 then
    return "/"
  end

  local bestGlyph = raw
  local bestCount = counts[raw] or 0
  local candidates = { "^", "/" }
  for i = 1, #candidates do
    local g = candidates[i]
    local c = counts[g] or 0
    if c > bestCount then
      bestCount = c
      bestGlyph = g
    end
  end

  if bestGlyph ~= raw and bestCount >= 3 then
    return bestGlyph
  end
  return raw
end

function dfCtx.placeUnitByDistance(unit, symbol, unitType)
  if not unit or not unit.distance then return end

  local targetGUID = dfCtx.targetGUID
  local targetGlyphNear = dfCtx.targetGlyphNear
  local targetGlyphMid = dfCtx.targetGlyphMid
  local balanced = dfCtx.balanced
  local yardsPerCell = dfCtx.yardsPerCell
  local innerRadius = dfCtx.innerRadius
  local playerWorldX = dfCtx.playerWorldX
  local playerWorldY = dfCtx.playerWorldY
  local grid = dfCtx.grid
  local threatHeat = dfCtx.threatHeat

  -- Reconciliation: if this unit IS the current target, render as target glyph
  -- so a single entity does not appear as both E and T in different cells.
  local isTarget = (targetGUID and unit.guid and unit.guid == targetGUID) and true or false
  if isTarget then
    symbol = targetGlyphNear
    if balanced and unit.distance and unit.distance > 14 then
      symbol = targetGlyphMid
    end
    -- Refresh the target's world position from the live API. The unit pool
    -- is cached for ~150ms; right after Charge/Intercept/teleport this
    -- caches stale coords and renders the target at the wrong cell. The
    -- player's current target is the one cell users notice, so refresh it.
    if UnitPosition then
      local lx, ly = UnitPosition("target")
      if lx and ly then
        unit.worldX = lx
        unit.worldY = ly
        unit.hasExactPos = true
        local dxLive = lx - (playerWorldX or 0)
        local dyLive = ly - (playerWorldY or 0)
        unit.distance = math.sqrt(dxLive * dxLive + dyLive * dyLive)
      end
    end
  end

  local dist = math.floor(unit.distance / yardsPerCell)
  if dist <= 0 then dist = 1 end
  if dist <= 0 then dist = 1 end
  if dist > innerRadius then dist = innerRadius end

  local x, y
  if unit.hasExactPos and unit.worldX and unit.worldY and playerWorldX and playerWorldY then
    -- WoW Classic UnitPosition returns (posY, posX) -- the first return is
    -- NORTH and the second is EAST. CollectNearbyUnitsWithPositions stores
    -- those into worldX/worldY without renaming, so the field "worldX" is
    -- actually NORTH and "worldY" is actually EAST. Map them to the grid
    -- correctly here.
    local north = unit.worldX - playerWorldX
    local east  = -(unit.worldY - playerWorldY)  -- WoW Classic east axis is negated relative to grid +x
    x = east  >= 0 and math.floor((east  / yardsPerCell) + 0.5) or math.ceil((east  / yardsPerCell) - 0.5)
    y = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
    if isTarget and TA.dfModeDebugTarget then
      local lpx, lpy = UnitPosition("player")
      local ltx, lty = UnitPosition("target")
      DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cffff8800[TA-DBG]|r tgt=%s player(p)=(%.1f,%.1f) live(p)=(%.1f,%.1f) tgt(u)=(%.1f,%.1f) live(t)=(%.1f,%.1f) N=%.1f E=%.1f -> cell(%d,%d) ypc=%d",
        tostring(unit.name), playerWorldX, playerWorldY, lpx or 0, lpy or 0,
        unit.worldX, unit.worldY, ltx or 0, lty or 0, north, east, x, y, yardsPerCell))
    end
    if x > innerRadius then x = innerRadius end
    if x < -innerRadius then x = -innerRadius end
    if y > innerRadius then y = innerRadius end
    if y < -innerRadius then y = -innerRadius end
  else
    local nameHash = 0
    for i = 1, #(unit.name or "") do
      nameHash = nameHash + string.byte(unit.name, i)
    end
    local angle = math.rad(nameHash % 360)

    -- For the player's current target specifically, the hash angle gives a
    -- random direction that often disagrees with where the player is looking.
    -- Override with the facing vector so the target glyph appears in front of
    -- the player rather than scattered (e.g. NW when facing E).
    local facing = dfCtx.facing
    if isTarget and facing then
      angle = math.atan2(math.cos(facing), -math.sin(facing))
    end

    if balanced then
      -- Coarsen to broad sectors and distance buckets to keep awareness, not precision.
      dist = dfCtx.distanceBucket(unit.distance)
      angle = dfCtx.octantAngle(angle)
      if unitType ~= "hostile" then
        symbol = "?"
      end
    end

    x = math.floor(math.cos(angle) * dist)
    y = math.floor(math.sin(angle) * dist)
  end

  if balanced then
    if unitType ~= "hostile" then
      symbol = "?"
    end
  end

  if math.abs(x) <= innerRadius and math.abs(y) <= innerRadius and grid[y] then
    if isTarget then
      -- Target glyph always wins; record placement so standalone target
      -- block can skip and we never render duplicate E/T cells.
      if grid[y][x] ~= "P" then
        grid[y][x] = symbol
      end
      dfCtx.targetPlaced = true
      dfCtx.targetDistance = unit.distance
      dfCtx.targetDistanceExact = unit.hasExactPos and unit.distance or nil
      dfCtx.targetDistanceApprox = (not unit.hasExactPos) and unit.distance or nil
      dfCtx.targetRenderedCellDist = math.sqrt((x * x) + (y * y))
      if unitType == "hostile" then
        threatHeat[y][x] = (threatHeat[y][x] or 0) + 1
      end
    elseif grid[y][x] == "." then
      grid[y][x] = symbol
    elseif grid[y][x] ~= "P" and grid[y][x] ~= symbol then
      grid[y][x] = "*"
    end
    if (not isTarget) and unitType == "hostile" then
      threatHeat[y][x] = (threatHeat[y][x] or 0) + 1
    end
  end
end
end -- close `do` block that scoped the dfCtx alias

local function BuildDFModeDisplay()
  local dfCtx = TA._dfCtx
  local mapID, _, _, x, y, continentX, continentY, continentID = GetPlayerMapCell()
  if not mapID then
    return "ERROR: Could not determine map position."
  end

  TA.dfModeTerrainContext = TA_GetTerrainContextAtMapPos()

  local gridSize = TA.dfModeGridSize or 35
  local radius = TA.dfModeRenderRadiusOverride or math.floor(gridSize / 2)
  -- innerRadius covers all display cells after rotation. In fixed orientation no rotation
  -- happens so we can save grid allocation by using radius directly.
  local orientation = TA.dfModeOrientation or "fixed"
  local rotationMode = TA.dfModeRotationMode or "smooth"
  local innerRadiusKey = gridSize * 2 + (orientation == "fixed" and 0 or 1)
  if TA.dfModeInnerRadiusGridSize ~= innerRadiusKey then
    TA.dfModeInnerRadius = (orientation == "fixed") and radius or math.ceil(radius * 1.45)
    TA.dfModeInnerRadiusGridSize = innerRadiusKey
  end
  local innerRadius = TA.dfModeInnerRadius or math.ceil(radius * 1.45)
  -- Each DF grid cell represents this many in-game yards. Must be a whole number
  -- so mark and unit positions map cleanly: N yards = exactly N/yardsPerCell cells.
  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  local calibrationEnabled = TA.dfModeCalibrationEnabled and true or false
  local viewMode = TA.dfModeViewMode or "threat"
  local profile = TA.dfModeProfile or "full"
  local balanced = (profile ~= "full")

  -- Get facing direction
  local facing = GetPlayerFacing() or 0
  local basePlayerWorldX, basePlayerWorldY = UnitPosition("player")
  local playerWorldX, playerWorldY = TA_GetProjectedDFPlayerWorldPosition(basePlayerWorldX, basePlayerWorldY)
  local now = GetTime()
  local facingDegrees = math.floor(math.deg(facing))
  TA.dfModeNavHint = nil

  -- Hoist unit fetch + bookkeeping + target detection before the sig check.
  -- GetNearbyUnitsWithPositions returns a cached value (refreshed at most every
  -- nearbyUnitsCacheInterval=0.15–0.20s), so this is cheap.
  local units = GetNearbyUnitsWithPositions()
  TA_RecordDFLastKnownUnits(units, mapID)
  TA_PruneDFLastKnownUnits(mapID)
  TA_PruneDFCorpseContacts(mapID)

  local targetName = UnitName("target")
  local targetUnit = targetName and "target" or nil
  local targetGUID = targetUnit and UnitGUID("target") or nil

  -- Dirty-state gate: compute a cheap signature over every display-affecting
  -- variable. If identical to last tick, skip all grid/terrain/render work and
  -- return the cached display string. This eliminates ~95% of the per-tick cost
  -- when the player is stationary and the scene is unchanged.
  --
  -- Signature components:
  --   mapID, viewMode, profile, gridSize, yardsPerCell — config/zone state
  --   facingBucket (2° steps) — heading; finer would cause jitter, coarser misses turns
  --   snappedPX/PY (half-cell resolution) — player position; catches cell crossings
  --   unitCountSig + unitPosHash — catches units entering/leaving/moving
  --   targetGUID + target position (half-cell) — target enter/leave/move
  --   terrainCtxKey — catches ADT chunk transitions (standing-terrain label)
  --   hue/legend toggles, mark state
  TA._dfScratch = TA._dfScratch or {}
  local scratch = TA._dfScratch

  local terrainCtx = TA.dfModeTerrainContext
  local terrainCtxKey = (type(terrainCtx) == "table" and terrainCtx.key) or ""
  local halfCell = (yardsPerCell or 3) * 0.5
  local snappedPX = playerWorldX and math.floor(playerWorldX / halfCell + 0.5) or 0
  local snappedPY = playerWorldY and math.floor(playerWorldY / halfCell + 0.5) or 0
  local facingBucket = math.floor(facingDegrees / 2)

  local hostile  = units.hostile  or {}
  local neutral  = units.neutral  or {}
  local friendly = units.friendly or {}
  local unitCountSig = #hostile * 10000 + #neutral * 100 + #friendly
  local unitPosHash = 0
  local allPools = { hostile, neutral, friendly }
  for p = 1, 3 do
    local pool = allPools[p]
    for i = 1, #pool do
      local u = pool[i]
      if u and u.worldX and u.worldY then
        unitPosHash = (unitPosHash + math.floor(u.worldX * 3 + 0.5) * 131
                                   + math.floor(u.worldY * 3 + 0.5)) % 16777216
      end
    end
  end

  local tgSigX, tgSigY = 0, 0
  if targetGUID then
    local tx, ty = UnitPosition("target")
    if tx and ty then
      tgSigX = math.floor(tx / halfCell + 0.5)
      tgSigY = math.floor(ty / halfCell + 0.5)
    end
  end

  local markedCellSig = tostring(TA.lastMarkedCellNotification or "")
  local dfSig = string.format("%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%d|%d",
    tostring(mapID or ""), viewMode, profile,
    gridSize, math.floor(yardsPerCell or 0),
    facingBucket, snappedPX, snappedPY,
    unitCountSig, unitPosHash,
    tgSigX, tgSigY, (targetGUID and 1 or 0),
    tostring(targetGUID or ""), terrainCtxKey,
    tostring(TA.dfModeHueEnabled), tostring(TA.dfModeLegendEnabled ~= false),
    markedCellSig, (TA.dfModeRenderRadiusOverride or -1), (TA.oreNodesVersion or 0)
  )
  if scratch.dfSig == dfSig and scratch.dfSigDisplay then
    return scratch.dfSigDisplay
  end
  local grid = scratch.grid or {}
  local threatHeat = scratch.threatHeat or {}
  scratch.grid = grid
  scratch.threatHeat = threatHeat
  -- Resize if needed (grow only; shrinking is unnecessary for a steady grid size).
  for y = -innerRadius, innerRadius do
    local row = grid[y]; if not row then row = {}; grid[y] = row end
    local hrow = threatHeat[y]; if not hrow then hrow = {}; threatHeat[y] = hrow end
    for x = -innerRadius, innerRadius do
      row[x] = "."
      hrow[x] = 0
    end
  end

  -- Place ore nodes first (lowest priority — overwritten by all entities).
  if TA.dfModeOreEnabled ~= false and playerWorldX and playerWorldY then
    local oreByMap = TextAdventurerDB and TextAdventurerDB.oreNodes and TextAdventurerDB.oreNodes[mapID]
    if oreByMap then
      for _, node in ipairs(oreByMap) do
        if node.wx and node.wy then
          local north = node.wx - playerWorldX
          local east  = -(node.wy - playerWorldY)
          local gx = east  >= 0 and math.floor((east  / yardsPerCell) + 0.5) or math.ceil((east  / yardsPerCell) - 0.5)
          local gy = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
          if math.abs(gx) <= innerRadius and math.abs(gy) <= innerRadius and grid[gy] then
            if grid[gy][gx] == "." then
              grid[gy][gx] = (TA_GetOreNodeGlyph and TA_GetOreNodeGlyph(node.n)) or "$"
            end
          end
        end
      end
    end
  end

  -- Place player at center; use @ when standing inside a marked cell.
  grid[0][0] = (TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID) and "@" or "P"

  -- (units, bookkeeping, and target detection were moved before the sig check above.)
  local targetPlaced = false
  local targetDistance = nil
  local targetDistanceExact = nil
  local targetDistanceApprox = nil
  local targetRenderedCellDist = nil
  local targetUsedFallback = false
  local glyphEnemy = "|cffff4040E|r"
  local glyphFriendly = "|cffb366ffF|r"
  local targetGlyphNear = "T"
  local targetGlyphMid = "t"
  local targetHostile = targetUnit and UnitCanAttack("player", "target") and true or false
  if targetHostile then
    targetGlyphNear = "|cffff4040T|r"
    targetGlyphMid = "|cffff4040t|r"
  end

  -- Populate the file-scope DF context for the helpers hoisted out of this
  -- function. Keeping the helpers at file scope avoids re-creating closures
  -- (and their upvalue tables) on every DF tick.
  dfCtx.yardsPerCell = yardsPerCell
  dfCtx.innerRadius = innerRadius
  dfCtx.radius = radius
  dfCtx.balanced = balanced
  dfCtx.facing = facing
  dfCtx.playerWorldX = playerWorldX
  dfCtx.playerWorldY = playerWorldY
  dfCtx.grid = grid
  dfCtx.threatHeat = threatHeat
  dfCtx.targetGUID = targetGUID
  dfCtx.targetGlyphNear = targetGlyphNear
  dfCtx.targetGlyphMid = targetGlyphMid
  dfCtx.targetPlaced = false
  dfCtx.targetDistance = nil
  dfCtx.targetDistanceExact = nil
  dfCtx.targetDistanceApprox = nil
  dfCtx.targetRenderedCellDist = nil

  -- Place units
  for _, unit in ipairs(units.hostile or {}) do
    dfCtx.placeUnitByDistance(unit, glyphEnemy, "hostile")
  end
  for _, unit in ipairs(units.neutral or {}) do
    dfCtx.placeUnitByDistance(unit, "N", "neutral")
  end
  for _, unit in ipairs(units.friendly or {}) do
    dfCtx.placeUnitByDistance(unit, glyphFriendly, "friendly")
  end

  -- Copy back the placement results that the standalone target block
  -- (and downstream telemetry) read as plain locals.
  targetPlaced = dfCtx.targetPlaced
  targetDistance = dfCtx.targetDistance
  targetDistanceExact = dfCtx.targetDistanceExact
  targetDistanceApprox = dfCtx.targetDistanceApprox
  targetRenderedCellDist = dfCtx.targetRenderedCellDist

  -- Place target with near-visual emphasis in balanced mode.
  -- Skip when PlaceUnitByDistance already handled it (GUID-matched against nameplate pool).
  if targetUnit and not targetPlaced then
    if TA.dfModeDebugTarget then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[TA-DBG]|r entering standalone target block (no nameplate match)")
    end
    local tx, ty
    local playerX, playerY = playerWorldX, playerWorldY
    local targetX, targetY = nil, nil

    local targetGUID = UnitGUID("target")

    -- Always prefer LIVE UnitPosition("target") over the cached unit pool.
    -- The pool is only refreshed every nearbyUnitsCacheInterval (~150ms), so
    -- after a Charge/Intercept/Death-Grip the cached worldX/worldY still
    -- reflect the pre-teleport position. Subtracting the new player position
    -- produces a huge bogus delta that pins the target to the grid edge.
    targetX, targetY = UnitPosition("target")

    -- Cache fallback: only use stored position if live UnitPosition failed.
    if (not targetX or not targetY) and targetGUID then
      local pools = { units.hostile or {}, units.neutral or {}, units.friendly or {} }
      for i = 1, #pools do
        local pool = pools[i]
        for j = 1, #pool do
          local u = pool[j]
          if u and u.guid == targetGUID and u.hasExactPos and u.worldX and u.worldY then
            targetX, targetY = u.worldX, u.worldY
            break
          end
        end
        if targetX and targetY then break end
      end
    end

    if playerX and playerY and targetX and targetY then
      -- Same UnitPosition axis swap as PlaceUnitByDistance: first return is
      -- NORTH, second is EAST. The variables are mis-named upstream but the
      -- math here treats the deltas as their true world axes.
      local north = targetX - playerX
      local east  = -(targetY - playerY)  -- WoW Classic east axis is negated relative to grid +x
      targetDistance = math.sqrt(north * north + east * east)
      targetDistanceExact = targetDistance
      tx = east  >= 0 and math.floor((east  / yardsPerCell) + 0.5) or math.ceil((east  / yardsPerCell) - 0.5)
      ty = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
      if TA.dfModeDebugTarget then
        local lpx, lpy = UnitPosition("player")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
          "|cffff8800[TA-DBG-S]|r player(p)=(%.1f,%.1f) live(p)=(%.1f,%.1f) tgt=(%.1f,%.1f) N=%.1f E=%.1f cell(%d,%d) ypc=%d",
          playerX, playerY, lpx or 0, lpy or 0, targetX, targetY, north, east, tx, ty, yardsPerCell))
      end
    else
      targetUsedFallback = true

      -- Determine actual distance before placement
      if CheckInteractDistance then
        if TA_TryInteractDistance("target", 1) then targetDistance = 10
        elseif TA_TryInteractDistance("target", 2) then targetDistance = 11
        elseif TA_TryInteractDistance("target", 3) then targetDistance = 28
        elseif TA_TryInteractDistance("target", 4) then targetDistance = 30
        end
        targetDistanceApprox = targetDistance
      end

      -- Without exact world coords, best guess is the direction the player is
      -- looking (you almost always face what you target). Place the glyph in
      -- front of P along the facing vector at the measured distance.
      -- Previously this used a hash of the target name to pick a random angle,
      -- which scattered targets to incorrect quadrants like NW when facing E.
      local cellDist = targetDistance and math.floor(targetDistance / yardsPerCell + 0.5) or 2
      if cellDist < 1 then cellDist = 1 end
      local forwardX = -math.sin(facing or 0)  -- east component of facing
      local forwardY = math.cos(facing or 0)   -- north component of facing
      tx = math.floor((forwardX * cellDist) + 0.5)
      ty = math.floor((forwardY * cellDist) + 0.5)
      if tx == 0 and ty == 0 then ty = 1 end
    end

    if tx and ty then
      -- Track whether we had to clamp the target into the visible grid. When
      -- the target is far enough that its real position lands beyond the
      -- innerRadius edge, we still want to show it -- but pin it to the edge
      -- so the user understands "this thing is past the edge of my map".
      local clampedToEdge = false
      if tx > innerRadius then tx = innerRadius; clampedToEdge = true end
      if tx < -innerRadius then tx = -innerRadius; clampedToEdge = true end
      if ty > innerRadius then ty = innerRadius; clampedToEdge = true end
      if ty < -innerRadius then ty = -innerRadius; clampedToEdge = true end
      targetRenderedCellDist = math.sqrt((tx * tx) + (ty * ty))

      if tx == 0 and ty == 0 then
        tx = math.floor((-math.sin(facing)) + 0.5)
        ty = math.floor((math.cos(facing)) + 0.5)
        if tx == 0 and ty == 0 then tx = 1 end
        targetRenderedCellDist = math.sqrt((tx * tx) + (ty * ty))
      end

      if math.abs(tx) <= innerRadius and math.abs(ty) <= innerRadius and grid[ty] and grid[ty][tx] ~= "P" then
        local targetGlyph = targetGlyphNear
        if balanced and targetDistance and targetDistance > 14 then targetGlyph = targetGlyphMid end
        if clampedToEdge then targetGlyph = targetGlyphMid end
        grid[ty][tx] = targetGlyph
      end
    end
  end

  -- Place marked cells last so marks stay visible over other map symbols.
  local markRadius = math.floor(tonumber(TA.dfModeMarkRadius) or 0)
  local maxMarkRadius = math.floor((TA.dfModeGridSize or 35) / 2)
  local markEdgeGlyph = "|cff33ff66o|r"
  local markCenterGlyph = "|cff33ff66M|r"
  if markRadius < 0 then markRadius = 0 end
  if markRadius > maxMarkRadius then markRadius = maxMarkRadius end
  -- Scale: 1 DF grid cell = yardsPerCell yards (integer), same as unit placement.
  local defaultCellYards = tonumber(TA.cellSizeYards) or CELL_YARDS_STANDARD
  local nearestMarkDist = nil
  local nearestMarkID = nil
  local nearestMarkName = nil
  local nearestMarkMX = nil
  local nearestMarkMY = nil
  for _, mark in pairs(TA.markedCells or {}) do
    if mark.mapID == mapID and mark.cellX and mark.cellY then
      local dx_yards, dy_yards
      local markGridX = ClampGridSize(tonumber(mark.gridX) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
      local markGridY = ClampGridSize(tonumber(mark.gridY) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
      local markOffsetX = NormalizePeriodicOffset(mark.anchorOffsetX, 1 / markGridX)
      local markOffsetY = NormalizePeriodicOffset(mark.anchorOffsetY, 1 / markGridY)
      local playerCellX, playerCellY, playerInCellX, playerInCellY = ComputeCellForPosition(x, y, markGridX, markGridY, markOffsetX, markOffsetY)

      -- Keep mark math in one coordinate system (map-cell space) to avoid drift when rotating view.
      local markCenterX = mark.cellX + 0.5
      local markCenterY = mark.cellY + 0.5
      local playerPosX = playerCellX + playerInCellX
      local playerPosY = playerCellY + playerInCellY
      local markCellYards = tonumber(mark.targetYards) or defaultCellYards
      -- Per-axis cell size in yards = mapWorldYards / gridDimension. We use
      -- GetMapWorldDimensions (corner-sampled, cached) so the perimeter
      -- reflects the cell's true rectangular footprint instead of assuming a
      -- square markCellYards x markCellYards box.
      local markCellYardsX = markCellYards
      local markCellYardsY = markCellYards
      local markMapW, markMapH = GetMapWorldDimensions(mark.mapID)
      if markMapW and markMapH and markGridX > 0 and markGridY > 0 then
        markCellYardsX = markMapW / markGridX
        markCellYardsY = markMapH / markGridY
      end
      dx_yards = (markCenterX - playerPosX) * markCellYardsX
      -- Map-space Y grows southward; DF-space Y grows northward.
      dy_yards = (playerPosY - markCenterY) * markCellYardsY

      -- Units are placed relative to the SNAPPED player world position (see
      -- TA_GetProjectedDFPlayerWorldPosition), but dx_yards/dy_yards above are
      -- relative to the player's TRUE map position. Shift by the snap delta so
      -- marks share the same sub-cell frame as units; otherwise a mark sitting
      -- on the same world cell as the player/target/friendly/enemy can render
      -- one cell off and look like it "moved" that glyph.
      local snapDeltaEast = (basePlayerWorldX or 0) - (playerWorldX or 0)
      local snapDeltaNorth = (basePlayerWorldY or 0) - (playerWorldY or 0)
      local markDist = math.sqrt((dx_yards * dx_yards) + (dy_yards * dy_yards))
      local east = dx_yards + snapDeltaEast
      local north = dy_yards + snapDeltaNorth
      local mx = east >= 0 and math.floor((east / yardsPerCell) + 0.5) or math.ceil((east / yardsPerCell) - 0.5)
      local my = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)

      if nearestMarkDist == nil or markDist < nearestMarkDist then
        nearestMarkDist = markDist
        nearestMarkID = mark.id or -1
        nearestMarkName = mark.name or "Unnamed"
        nearestMarkMX = mx
        nearestMarkMY = my
      end

      local exMin, exMax, eyMin, eyMax
      if orientation == "fixed" then
        -- Fixed orientation: marked cell is axis-aligned with the DF grid.
        -- The DF renderer prints each column as 2 chars (glyph + space) but
        -- each row as 1 char tall, so a visually-square rectangle needs
        -- ~half as many columns as rows. We force ODD counts so the M is
        -- perfectly centered with equal cells on each side.
        local rowsPerSide = math.max(1, math.floor((markCellYards / yardsPerCell) + 0.5))
        local extra = markRadius or 0
        rowsPerSide = rowsPerSide + (extra * 2)
        if rowsPerSide % 2 == 0 then rowsPerSide = rowsPerSide + 1 end
        local colsPerSide = math.max(1, math.floor((rowsPerSide / 2) + 0.5))
        if colsPerSide % 2 == 0 then colsPerSide = colsPerSide + 1 end
        local halfRow = (rowsPerSide - 1) / 2
        local halfCol = (colsPerSide - 1) / 2
        exMin = mx - halfCol
        exMax = mx + halfCol
        eyMin = my - halfRow + 2  -- shift south edge up by 2 cells to match in-game yard scale
        eyMax = my + halfRow - 2  -- shift north edge down by 2 cells to match in-game yard scale
      elseif markCellYardsX > 0 and markCellYardsY > 0 then
        -- Rotating orientation: the marked cell is no longer aligned with
        -- the screen, so we have to project from yard-space and snap each
        -- edge independently to the rotated DF grid.
        local halfYardsX = (markCellYardsX * 0.5) + (markRadius * yardsPerCell)
        local halfYardsY = (markCellYardsY * 0.5) + (markRadius * yardsPerCell)
        local halfYardsLeft  = halfYardsX
        local halfYardsRight = halfYardsX
        local halfYardsSouth = halfYardsY
        local halfYardsNorth = halfYardsY
        local function SnapToCell(yards)
          if yards >= 0 then return math.floor((yards / yardsPerCell) + 0.5) end
          return math.ceil((yards / yardsPerCell) - 0.5)
        end
        exMin = SnapToCell(east  - halfYardsLeft)
        exMax = SnapToCell(east  + halfYardsRight)
        eyMin = SnapToCell(north - halfYardsSouth)
        eyMax = SnapToCell(north + halfYardsNorth)
      end
      -- Render perimeter whenever the mark's bounding box overlaps the viewport
      -- (not just when the center is in view). Loop bounds are clamped so a
      -- giant offscreen mark never iterates over invisible cells.
      if exMin and exMax and eyMin and eyMax
          and exMin <= innerRadius and exMax >= -innerRadius
          and eyMin <= innerRadius and eyMax >= -innerRadius then
        local clampedExMin = exMin < -innerRadius and -innerRadius or exMin
        local clampedExMax = exMax >  innerRadius and  innerRadius or exMax
        local clampedEyMin = eyMin < -innerRadius and -innerRadius or eyMin
        local clampedEyMax = eyMax >  innerRadius and  innerRadius or eyMax
        for ey = clampedEyMin, clampedEyMax do
          local row = grid[ey]
          if row then
            for ex = clampedExMin, clampedExMax do
              if (ex == exMin or ex == exMax or ey == eyMin or ey == eyMax)
                  and row[ex] == "." then
                row[ex] = markEdgeGlyph
              end
            end
          end
        end
      end

      -- Center glyph only renders if the mark's center cell is on screen.
      if math.abs(mx) <= innerRadius and math.abs(my) <= innerRadius
          and grid[my] and grid[my][mx] then
        local current = grid[my][mx]
        if current ~= "P" and current ~= "@" and current ~= "T" and current ~= "t" and current ~= targetGlyphNear and current ~= targetGlyphMid then
          grid[my][mx] = markCenterGlyph
        end
      end
    end
  end

  -- Quest route marker overlay: show the best suggested next-quest origin as Q.
  if TA_GetQuestRouterStore and TA_BuildQuestRouteCandidates then
    local qstore = TA_GetQuestRouterStore()
    if qstore and qstore.enabled ~= false then
      local overlay = TA.questRouteOverlay
      if overlay and overlay.mapID == mapID and overlay.dxCells and overlay.dyCells then
        local qx = overlay.dxCells >= 0 and math.floor(overlay.dxCells + 0.5) or math.ceil(overlay.dxCells - 0.5)
        local qy = overlay.dyCells >= 0 and math.floor(overlay.dyCells + 0.5) or math.ceil(overlay.dyCells - 0.5)
        if qx > innerRadius then qx = innerRadius end
        if qx < -innerRadius then qx = -innerRadius end
        if qy > innerRadius then qy = innerRadius end
        if qy < -innerRadius then qy = -innerRadius end
        if grid[qy] and grid[qy][qx] and grid[qy][qx] == "." then
          grid[qy][qx] = "Q"
        elseif grid[qy] and grid[qy][qx] and grid[qy][qx] ~= "P" and grid[qy][qx] ~= "@" then
          grid[qy][qx] = "*"
        end
      end
    end
  end

  -- DFDanger integration: lightweight hazard overlay layer for known cliff/elevator anchors.
  if DFDanger and DFDanger.enabled and DFDanger.AddHazardOverlayToMap then
    local overlayContext = {
      zone = GetZoneText and (GetZoneText() or "") or "",
      mapID = mapID,
      playerX = x,
      playerY = y,
      innerRadius = innerRadius,
      yardsPerCell = yardsPerCell,
      playerFacing = facing,
    }
    local okDangerOverlay = pcall(function()
      DFDanger:AddHazardOverlayToMap(grid, overlayContext)
    end)
    if not okDangerOverlay then
      -- Keep DF rendering resilient if danger overlay has transient errors.
    end
  end

  -- Corpse overlay: recently killed units at their last known exact position.
  for _, c in pairs(TA.dfModeCorpseContacts or {}) do
    if c and c.mapID == mapID and c.worldX and c.worldY and playerWorldX and playerWorldY and c.expiresAt and c.expiresAt > now then
      local dx_yards = c.worldX - playerWorldX
      local dy_yards = c.worldY - playerWorldY
      local east = dx_yards
      local north = dy_yards
      local cx = east >= 0 and math.floor((east / yardsPerCell) + 0.5) or math.ceil((east / yardsPerCell) - 0.5)
      local cy = north >= 0 and math.floor((north / yardsPerCell) + 0.5) or math.ceil((north / yardsPerCell) - 0.5)
      if math.abs(cx) <= innerRadius and math.abs(cy) <= innerRadius and grid[cy] and grid[cy][cx] and grid[cy][cx] == "." then
        grid[cy][cx] = "|cffb0b0b0x|r"
      end
    end
  end

  -- Build output: grid rows only, no header or footer.
  -- Reuse scratch buffers across ticks to avoid per-tick table allocations for
  -- the row cell array, the row pieces assembly, and the final lines array.
  local rowBuf    = scratch.rowBuf    or {}; scratch.rowBuf    = rowBuf
  local piecesBuf = scratch.piecesBuf or {}; scratch.piecesBuf = piecesBuf
  local linesBuf  = scratch.linesBuf  or {}; scratch.linesBuf  = linesBuf
  local linesN    = 0
  local navRotationAngle = facing
  if rotationMode == "octant" then
    local step = math.pi / 4
    navRotationAngle = math.floor((navRotationAngle / step) + 0.5) * step
  end
  local navSinA = math.sin(navRotationAngle)
  local navCosA = math.cos(navRotationAngle)

  local displayRotationAngle = 0
  if orientation == "rotating" then
    displayRotationAngle = navRotationAngle
  end
  local displaySinA = math.sin(displayRotationAngle)
  local displayCosA = math.cos(displayRotationAngle)
  local forwardX = -math.sin(facing)
  local forwardY = math.cos(facing)
  local centerTerrainHeight = TA.dfModeTerrainContext and TA.dfModeTerrainContext.avgHeight or nil
  local centerTerrainSlope = TA.dfModeTerrainContext and TA.dfModeTerrainContext.avgSlope or nil
  local terrainLookupMode = TA.dfModeTerrainContext and TA.dfModeTerrainContext.lookupMode or nil
  dfCtx.terrainLookupMode = terrainLookupMode

  if nearestMarkDist and nearestMarkMX and nearestMarkMY then
    local sx = dfCtx.roundNearest((nearestMarkMX * navCosA) + (nearestMarkMY * navSinA))
    local sy = dfCtx.roundNearest((-nearestMarkMX * navSinA) + (nearestMarkMY * navCosA))
    local vertical = ""
    local horizontal = ""
    if sy > 0 then
      vertical = "ahead"
    elseif sy < 0 then
      vertical = "behind"
    end
    if sx > 0 then
      horizontal = "right"
    elseif sx < 0 then
      horizontal = "left"
    end
    local relDir
    if vertical ~= "" and horizontal ~= "" then
      relDir = vertical .. "-" .. horizontal
    elseif vertical ~= "" then
      relDir = vertical
    elseif horizontal ~= "" then
      relDir = horizontal
    else
      relDir = "on top of you"
    end
    local approachIndicator = ""
    local prevDist = (TA.dfModeLastNearestMarkID == nearestMarkID) and TA.dfModeLastNearestMarkDist or nil
    if prevDist then
      local delta = nearestMarkDist - prevDist
      if delta < -1 then
        approachIndicator = " >>>"
      elseif delta > 1 then
        approachIndicator = " <<<"
      else
        approachIndicator = " ---"
      end
    end
    TA.dfModeLastNearestMarkID = nearestMarkID
    TA.dfModeLastNearestMarkDist = nearestMarkDist
    TA.dfModeNavHint = nil
  end

  local terrainStats = {
    samples = 0,
    lookups = 0,
    resolved = 0,
    unresolved = 0,
    painted = 0,
    blocked = 0,
    noGlyph = 0,
    heatMin = nil,
    heatMax = nil,
    compared = 0,
    ignoredOutlier = 0,
    deltaMin = nil,
    deltaMax = nil,
    cliffDrops = 0,
  }
  -- Persistent terrain cache: TA_GetTerrainContextAtWorldPos is the single biggest cost in
  -- BuildDFModeDisplay. Cache it across DF builds, keyed inside the lookup helper by the
  -- snapped *absolute* world cell, so the cache survives player movement (terrain is
  -- world-anchored, not player-anchored). Wipe only when map / lookup mode / yards-per-cell
  -- changes -- those genuinely invalidate every entry. Bound size with a soft cap so a long
  -- session walking across a continent does not grow the cache unboundedly.
  local terrainCacheKey = string.format("%s:%s:%d", tostring(mapID or "?"), tostring(terrainLookupMode or "?"), math.floor(yardsPerCell or 0))
  local terrainCacheSizeCap = 30000
  if TA._dfTerrainCacheKey ~= terrainCacheKey
      or (TA._dfTerrainCache and (TA._dfTerrainCache._count or 0) > terrainCacheSizeCap) then
    TA._dfTerrainCache = {}
    TA._dfTerrainCacheKey = terrainCacheKey
  end
  local terrainCache = TA._dfTerrainCache
  -- Persistent grid distance cache: getGridDistance(x,y) is a pure function of
  -- (x,y) integer offsets in [-radius, radius]. The values are identical every
  -- tick as long as `radius` is unchanged, so allocate once per radius and
  -- reuse across ticks. Avoids ~(2*radius+1)^2 sqrt + table-grow operations
  -- on the warm-up tick after each rebuild.
  local gridDistCacheBundle = scratch.gridDist
  if (not gridDistCacheBundle) or gridDistCacheBundle.radius ~= radius then
    gridDistCacheBundle = { radius = radius, cache = {} }
    scratch.gridDist = gridDistCacheBundle
  end
  local gridDistanceCache = gridDistCacheBundle.cache
  dfCtx.terrainCache = terrainCache
  dfCtx.gridDistanceCache = gridDistanceCache
  dfCtx.terrainStats = terrainStats
  -- (terrainLookupMode populated above; playerWorldX/Y/yardsPerCell already
  -- set when the unit-placement context was prepared.)

  -- Keep terrain warnings closer to the player in threat mode.
  local terrainRenderRadius = radius
  if viewMode == "threat" then
    terrainRenderRadius = math.max(6, math.floor(radius * 0.6))
  end

  local showTerrainView = (viewMode == "threat" or viewMode == "combined")
  scratch.terrainLayer = scratch.terrainLayer or {}
  scratch.terrainHeatLayer = scratch.terrainHeatLayer or {}
  scratch.rotWX = scratch.rotWX or {}
  scratch.rotWY = scratch.rotWY or {}
  local terrainLayer = scratch.terrainLayer
  local terrainHeatLayer = scratch.terrainHeatLayer
  -- Cache rotated world coords per (y,x) so the render pass below can reuse
  -- them instead of recomputing the same rotation/round per cell.
  local rotWX = scratch.rotWX
  local rotWY = scratch.rotWY
  dfCtx.terrainLayer = terrainLayer

  -- Pass 1: sample terrain glyphs for each display cell so we can smooth noisy
  -- one-off spikes without requerying terrain on the render pass.
  for y = radius, -radius, -1 do
    local tlrow = terrainLayer[y]; if not tlrow then tlrow = {}; terrainLayer[y] = tlrow end
    local throw = terrainHeatLayer[y]; if not throw then throw = {}; terrainHeatLayer[y] = throw end
    local wxrow = rotWX[y]; if not wxrow then wxrow = {}; rotWX[y] = wxrow end
    local wyrow = rotWY[y]; if not wyrow then wyrow = {}; rotWY[y] = wyrow end
    for x = -radius, radius do
      terrainStats.samples = terrainStats.samples + 1

      local wx = dfCtx.roundNearest((x * displayCosA) - (y * displaySinA))
      local wy = dfCtx.roundNearest((x * displaySinA) + (y * displayCosA))
      wxrow[x] = wx
      wyrow[x] = wy
      local dist = dfCtx.getGridDistance(x, y)

      local baseCell = "."
      if math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius and grid[wy] and grid[wy][wx] then
        baseCell = grid[wy][wx]
      end

      local glyph = "."
      local heat = 0
      if showTerrainView then
        if baseCell ~= "." then
          terrainStats.blocked = terrainStats.blocked + 1
        elseif dist > terrainRenderRadius then
          -- Intentionally skip far-edge terrain in threat mode to avoid
          -- warnings appearing only at the outer border.
        elseif playerWorldX and playerWorldY then
          local terrainCell = dfCtx.getTerrainCellAtOffset(wx, wy)
          if terrainCell and terrainCell.resolved then
            terrainStats.resolved = terrainStats.resolved + 1
          else
            terrainStats.unresolved = terrainStats.unresolved + 1
          end

          local forwardBias = 0
          if dist > 0 then
            forwardBias = ((wx * forwardX) + (wy * forwardY)) / dist
          end
          local localHeightBaseline, localSlopeBaseline, localSlopeRelief, localHeightRelief = dfCtx.getLocalTerrainBaselines(wx, wy, terrainCell)
          heat = TA_TerrainHeatFromContext(terrainCell, localSlopeRelief, localHeightRelief)
          if terrainStats.heatMin == nil or heat < terrainStats.heatMin then terrainStats.heatMin = heat end
          if terrainStats.heatMax == nil or heat > terrainStats.heatMax then terrainStats.heatMax = heat end
          local sampleHeight = terrainCell and tonumber(terrainCell.avgHeight) or nil
          local baselineHeight = tonumber(localHeightBaseline)
          if baselineHeight == nil then baselineHeight = centerTerrainHeight end
          if baselineHeight and sampleHeight then
            local deltaHeight = sampleHeight - baselineHeight
            if math.abs(deltaHeight) > 300 then
              terrainStats.ignoredOutlier = terrainStats.ignoredOutlier + 1
            else
              terrainStats.compared = terrainStats.compared + 1
              if terrainStats.deltaMin == nil or deltaHeight < terrainStats.deltaMin then terrainStats.deltaMin = deltaHeight end
              if terrainStats.deltaMax == nil or deltaHeight > terrainStats.deltaMax then terrainStats.deltaMax = deltaHeight end
              local gradeDist = dist
              if gradeDist < 1 then gradeDist = 1 end
              local gradePerCell = deltaHeight / gradeDist
              local localRelief = tonumber(localHeightRelief) or 0
              local localDeltaHeight = nil
              if localHeightBaseline ~= nil then
                local localBaseline = tonumber(localHeightBaseline)
                if localBaseline ~= nil then
                  localDeltaHeight = sampleHeight - localBaseline
                end
              end
              local localDropPass = true
              if localDeltaHeight ~= nil then
                localDropPass = localDeltaHeight <= -4
              end
              if dist <= 5 and forwardBias >= 0 and deltaHeight <= -10 and gradePerCell <= -1.6 and localDropPass and localRelief >= 2.5 then
                terrainStats.cliffDrops = terrainStats.cliffDrops + 1
              end
            end
          end
          glyph = TA_GetTerrainGlyph(
            terrainCell,
            centerTerrainHeight,
            centerTerrainSlope,
            forwardBias,
            dist,
            localHeightBaseline,
            localSlopeBaseline,
            localSlopeRelief,
            localHeightRelief
          )
          if glyph ~= "." then
            terrainStats.painted = terrainStats.painted + 1
          else
            terrainStats.noGlyph = terrainStats.noGlyph + 1
          end
        end
      end

      terrainLayer[y][x] = glyph
      terrainHeatLayer[y][x] = heat
    end
  end

  local centerLocalSlope = nil
  if playerWorldX and playerWorldY then
    local centerTerrainCell = dfCtx.getTerrainCellAtOffset(0, 0)
    local _, localSlope = dfCtx.getLocalTerrainBaselines(0, 0, centerTerrainCell)
    centerLocalSlope = localSlope
  end
  local standingLabel, standingShort = TA_ClassifyStandingTerrain(TA.dfModeTerrainContext, centerLocalSlope)
  TA.dfModeTerrainStandingLabel = standingLabel
  TA.dfModeTerrainStandingShort = standingShort

  -- Loop-invariant: viewMode does not change inside the render loop.
  local showThreat = (viewMode == "threat" or viewMode == "combined")
  local showExploration = (viewMode == "exploration" or viewMode == "combined")
  local showRange = (viewMode == "tactical" or viewMode == "combined")
  local showTerrain = showTerrainView

  for y = radius, -radius, -1 do
    local rowN = 0
    local wxrow = rotWX[y]
    local wyrow = rotWY[y]
    for x = -radius, radius do
      -- Reuse rotated world coords computed during pass 1 above.
      local wx = wxrow[x]
      local wy = wyrow[x]

      -- Hoist bounds check: used by grid, threat, and exploration lookups.
      local inBounds = math.abs(wx) <= innerRadius and math.abs(wy) <= innerRadius
      -- Hoist per-wy row lookups used by two separate branches below.
      local threatRow  = inBounds and threatHeat[wy]
      local recentRow  = inBounds and TA.dfModeRecentCells[wy]

      local cell = "."
      if inBounds and grid[wy] and grid[wy][wx] then
        cell = grid[wy][wx]
      end

      if showTerrain and cell == "." then
        local glyph = dfCtx.getSmoothedTerrainGlyph(x, y)
        if glyph and glyph ~= "." then
          if TA.dfModeHueEnabled then
            if glyph == "V" or glyph == "A" then
              cell = glyph
            else
              local heat = (terrainHeatLayer[y] and terrainHeatLayer[y][x]) or 0
              cell = TA_ColorizeCellByHeat(glyph, heat)
            end
          else
            cell = glyph
          end
        end
      end

      -- Only adorn "background" cells. Mark glyphs (|c..|r), entities (P/@/T/t/Q/*),
      -- and any multi-char/colored cell must NOT receive a prepend, otherwise that
      -- cell becomes visually wider than its neighbors and breaks row alignment
      -- (this is what made horizontal mark edges look like they had extra spacing).
      local adornable = (cell == "." or (#cell == 1
        and cell ~= "P" and cell ~= "@" and cell ~= "T" and cell ~= "t"
        and cell ~= "Q" and cell ~= "*" and cell ~= "M"))

      if showThreat and adornable then
        local threatVal = threatRow and (threatRow[wx] or 0) or 0
        if threatVal >= 3 then cell = "!" .. cell
        elseif threatVal >= 2 then cell = "~" .. cell
        end
      end

      if showExploration and adornable and recentRow and recentRow[wx] then
        cell = "+" .. cell
      end

      if showRange then
        local distSq = (x * x) + (y * y)
        local ring2 = (distSq >= 2.25 and distSq < 6.25)
        local ring4 = (distSq >= 12.25 and distSq < 20.25)
        local ring6 = (distSq >= 30.25 and distSq < 42.25)
        if (ring2 or ring4 or ring6) and cell == "." then
          cell = "-"
        end
      end

      rowN = rowN + 1
      rowBuf[rowN] = cell
    end

    -- Horizontal mark-edge rows: when 3+ consecutive cells are the (unadorned)
    -- mark edge glyph, drop the spaces between just those cells so they read as a
    -- continuous "ooooo" segment instead of "o o o o o" (which over-stretches
    -- the rectangle horizontally relative to its vertical sides).
    local piecesN = 0
    local i = 1
    while i <= rowN do
      local cell = rowBuf[i]
      if cell == markEdgeGlyph then
        local j = i
        while j <= rowN and rowBuf[j] == markEdgeGlyph do j = j + 1 end
        local runLen = j - i
        if runLen >= 3 then
          if piecesN > 0 then piecesN = piecesN + 1; piecesBuf[piecesN] = " " end
          for k = i, j - 1 do piecesN = piecesN + 1; piecesBuf[piecesN] = rowBuf[k] end
          i = j
        else
          if piecesN > 0 then piecesN = piecesN + 1; piecesBuf[piecesN] = " " end
          piecesN = piecesN + 1; piecesBuf[piecesN] = cell
          i = i + 1
        end
      else
        if piecesN > 0 then piecesN = piecesN + 1; piecesBuf[piecesN] = " " end
        piecesN = piecesN + 1; piecesBuf[piecesN] = cell
        i = i + 1
      end
    end
    linesN = linesN + 1
    linesBuf[linesN] = table.concat(piecesBuf, "", 1, piecesN)
  end

  TA.dfModeTerrainRenderStats = terrainStats
  local display = table.concat(linesBuf, "\n", 1, linesN)
  -- Stash the raw rendered grid (no color codes stripped) so /ta df copy
  -- can show it in a copyable popup for debugging perimeter rendering.
  TA.dfModeLastRawDisplay = display

  if viewMode == "threat" or viewMode == "combined" then
    local legendEnabled = (TA.dfModeLegendEnabled ~= false)
    local legend = {
      "",
      "Legend: P player  E enemy  T/t target  M mark  * contested  $ ore node",
      "Threat: ! high  ~ medium  . empty  x corpse",
      "Terrain: V drop hazard  X/# obstacles",
    }
    if TA.dfModeHueEnabled then
      table.insert(legend, "Terrain hue: blue low  green medium  yellow high  red extreme")
    end
    if standingLabel then
      table.insert(legend, standingLabel)
    end
    if calibrationEnabled then
      local radiusYards = radius * yardsPerCell
      local ring2 = 2 * yardsPerCell
      local ring4 = 4 * yardsPerCell
      local ring6 = 6 * yardsPerCell
      table.insert(legend, string.format("Cal: grid=%dx%d radius=%d cells (~%d yd) cell=%d yd", gridSize, gridSize, radius, radiusYards, yardsPerCell))
      table.insert(legend, string.format("Cal: rings 2/4/6 cells => ~%d/%d/%d yd", ring2, ring4, ring6))
      if centerTerrainHeight and terrainStats.compared > 0 and terrainStats.deltaMin and terrainStats.deltaMax then
        table.insert(legend, string.format("Cal terrain: centerH=%.1f dH[min/max]=%.1f/%.1f yd compared=%d ignored=%d", centerTerrainHeight, terrainStats.deltaMin, terrainStats.deltaMax, terrainStats.compared, terrainStats.ignoredOutlier))
        table.insert(legend, string.format("Cal terrain: cliff cells V=%d (rule: dH<=-10 & grade<=-1.6 & localDrop<=-4 & relief>=2.5 & dist<=5 & forward>=0)", terrainStats.cliffDrops))
      elseif centerTerrainHeight then
        table.insert(legend, string.format("Cal terrain: centerH=%.1f (no comparable terrain samples, ignored=%d)", centerTerrainHeight, terrainStats.ignoredOutlier))
      else
        table.insert(legend, "Cal terrain: center terrain unresolved")
      end
      if targetUnit and targetRenderedCellDist then
        local renderedYards = targetRenderedCellDist * yardsPerCell
        if targetDistanceExact then
          local expectedCells = targetDistanceExact / yardsPerCell
          local cellError = targetRenderedCellDist - expectedCells
          local yardError = renderedYards - targetDistanceExact
          table.insert(legend, string.format("Cal target: exact=%.1f yd expected=%.2f cells rendered=%.2f cells (err %.2f cells / %.1f yd)", targetDistanceExact, expectedCells, targetRenderedCellDist, cellError, yardError))
        elseif targetDistanceApprox then
          local expectedCells = targetDistanceApprox / yardsPerCell
          local cellError = targetRenderedCellDist - expectedCells
          local yardError = renderedYards - targetDistanceApprox
          table.insert(legend, string.format("Cal target: approx~%.1f yd expected~%.2f cells rendered=%.2f cells (err %.2f cells / %.1f yd)", targetDistanceApprox, expectedCells, targetRenderedCellDist, cellError, yardError))
        elseif targetUsedFallback then
          table.insert(legend, string.format("Cal target: fallback placement rendered=%.2f cells (~%.1f yd), no distance estimate", targetRenderedCellDist, renderedYards))
        else
          table.insert(legend, string.format("Cal target: rendered=%.2f cells (~%.1f yd), no distance source", targetRenderedCellDist, renderedYards))
        end
      elseif targetUnit then
        table.insert(legend, "Cal target: target selected but not rendered (off-grid or unresolved position)")
      else
        table.insert(legend, "Cal target: no target selected")
      end
    end
    if legendEnabled then
      display = display .. "\n" .. table.concat(legend, "\n")
    end
  end

  scratch.dfSig = dfSig
  scratch.dfSigDisplay = display
  return display
end

-- ---- moved from textadventurer.lua lines 11874-12169 ----
function TA_SetDFModeSize(width, height, silent)
  local minW, minH = 100, 200
  local maxW, maxH = 1200, 1000

  if not width or not height then
    local currentW, currentH = dfModeFrame:GetSize()
    AddLine("system", "DF window size: " .. math.floor(currentW) .. "x" .. math.floor(currentH))
    AddLine("system", "Usage: /ta df size <width> <height> (range " .. minW .. "-" .. maxW .. " x " .. minH .. "-" .. maxH .. ")")
    return
  end

  local w = math.floor(tonumber(width) or 0)
  local h = math.floor(tonumber(height) or 0)
  if w <= 0 or h <= 0 then
    AddLine("system", "Invalid DF size. Usage: /ta df size <width> <height>")
    return
  end

  if w < minW then w = minW end
  if h < minH then h = minH end
  if w > maxW then w = maxW end
  if h > maxH then h = maxH end

  dfModeFrame:SetSize(w, h)
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfModeWidth = w
  TextAdventurerDB.dfModeHeight = h

  if not silent then
    AddLine("system", "DF window size set to " .. w .. "x" .. h)
  end
  if TA.dfModeEnabled then
    TA.dfModeLastUpdate = 0
    TA_UpdateDFMode()
  end
end

function TA_SetDFModeMarkRadius(radius, silent)
  local minR = 0
  local maxR = math.floor((TA.dfModeGridSize or 35) / 2)

  if radius == nil then
    local current = tonumber(TA.dfModeMarkRadius) or 0
    AddLine("system", "DF mark radius: " .. math.floor(current) .. " cell(s)")
    AddLine("system", "Usage: /ta df markradius <0-" .. maxR .. ">")
    return
  end

  local r = math.floor(tonumber(radius) or -1)
  if r < minR or r > maxR then
    AddLine("system", "Invalid DF mark radius. Use a value from " .. minR .. " to " .. maxR)
    return
  end

  TA.dfModeMarkRadius = r
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfModeMarkRadius = r

  if not silent then
    AddLine("system", "DF mark radius set to " .. r .. " cell(s)")
  end
  if TA.dfModeEnabled then
    TA.dfModeLastUpdate = 0
    TA_UpdateDFMode()
  end
end

function TA_DFModeStatus()
  if not TA.dfModeEnabled then
    AddLine("system", "DF Mode is not active. Use /ta dfmode to enable it.")
    return
  end

  local profile = TA.dfModeProfile or "full"
  local balanced = (profile ~= "full")
  local viewMode = TA.dfModeViewMode or "threat"

  local facing = GetPlayerFacing() or 0
  local facingDegrees = math.floor(math.deg(facing))
  local dirStr = "?"
  if facingDegrees >= 315 or facingDegrees < 45 then dirStr = "N"
  elseif facingDegrees >= 45 and facingDegrees < 135 then dirStr = "W"
  elseif facingDegrees >= 135 and facingDegrees < 225 then dirStr = "S"
  elseif facingDegrees >= 225 and facingDegrees < 315 then dirStr = "E"
  end

  local mapID, cellX, cellY, px, py = GetPlayerMapCell()
  local zoneName = GetZoneText() or "Unknown"
  local units = GetNearbyUnitsWithPositions() or { hostile = {}, neutral = {}, friendly = {} }

  local totalHostile = #(units.hostile or {})
  local totalNeutral = #(units.neutral or {})
  local totalFriendly = #(units.friendly or {})

  AddLine("system", "=== DF MODE STATUS ===")
  AddLine("system", "View: " .. viewMode:upper() .. "  |  Profile: " .. profile:upper())
  local cellText = ""
  if mapID and cellX ~= nil and cellY ~= nil then
    cellText = string.format("  |  Cell: [%s,%s]", tostring(cellX), tostring(cellY))
  elseif mapID then
    cellText = "  |  Cell: [unknown]"
  end
  AddLine("system", "Zone: " .. zoneName .. cellText)
  AddLine("system", "Facing: " .. dirStr .. " (" .. facingDegrees .. " deg)")
  AddLine("system", "Legend overlay: " .. ((TA.dfModeLegendEnabled ~= false) and "ON" or "OFF") .. " (use /ta df legend on|off)")
  if TA.dfModeLegendEnabled ~= false then
    AddLine("system", "Legend: P=Player  E=Enemy  T/t=Target  M=Mark  *=Contested")
    AddLine("system", "Threat: !=high  ~=medium  .=empty  x=corpse")
    AddLine("system", "Terrain: ^=steep  /=incline  A/V=up/down  X/#=obstacles")
  end
  AddLine("system", "Terrain hue: " .. (TA.dfModeHueEnabled and "ON" or "OFF") .. " (use /ta df hue on|off)")
  AddLine("system", "DF calibration: " .. (TA.dfModeCalibrationEnabled and "ON" or "OFF") .. " (use /ta df calibrate on|off)")
  AddLine("system", "Mark radius: " .. (tonumber(TA.dfModeMarkRadius) or 0) .. " cell(s)")
  AddLine("system", "Orientation: " .. ((TA.dfModeOrientation or "fixed"):upper()))
  AddLine("system", "Rotation mode: " .. ((TA.dfModeRotationMode or "smooth"):upper()))
  local terrain = nil
  local terrainOk, terrainOrErr = pcall(TA_GetTerrainContextAtMapPos)
  if terrainOk then
    terrain = terrainOrErr
  else
    AddLine("system", "Terrain: lookup error: " .. tostring(terrainOrErr))
  end

  if not terrain then
    AddLine("system", "Terrain: no compiled terrain data loaded")
  elseif not terrain.resolved then
    AddLine("system", string.format("Terrain: loaded but no chunk match near tile/chunk %d:%d / %d:%d (mode %s)", terrain.tileX or -1, terrain.tileY or -1, terrain.chunkX or -1, terrain.chunkY or -1, tostring(terrain.lookupMode or "?")))
    if terrain.inCompiledTileBounds == false then
      local b = terrain.mapBounds
      if b and b.tileMin and b.tileMax then
        AddLine("system", string.format("Terrain coverage: outside compiled tile bounds (%d:%d to %d:%d). Export and compile this zone.", tonumber(b.tileMin[1]) or -1, tonumber(b.tileMin[2]) or -1, tonumber(b.tileMax[1]) or -1, tonumber(b.tileMax[2]) or -1))
      else
        AddLine("system", "Terrain coverage: outside compiled tile bounds. Export and compile this zone.")
      end
    else
      AddLine("system", "Terrain coverage: tile is inside compiled bounds, but this chunk is missing from the dataset.")
    end
  else
    local water = terrain.hasWater and "yes" or "no"
    local texture = tostring(terrain.texture or "unknown")
    local height = terrain.avgHeight and string.format("%.1f", terrain.avgHeight) or "?"
    local slope = terrain.avgSlope and string.format("%.2f", terrain.avgSlope) or "?"
    local maxSlope = terrain.maxSlope and string.format("%.2f", terrain.maxSlope) or "?"
    AddLine("system", string.format("Terrain: tile/chunk %d:%d / %d:%d  water=%s  texture=%s  height~%s  slope~%s (max %s, mode %s)", terrain.tileX or -1, terrain.tileY or -1, terrain.chunkX or -1, terrain.chunkY or -1, water, texture, height, slope, maxSlope, tostring(terrain.lookupMode or "?")))
  end
  local standingLabel = TA.dfModeTerrainStandingLabel
  if not standingLabel and terrain and terrain.resolved then
    standingLabel = select(1, TA_ClassifyStandingTerrain(terrain, nil))
  end
  if standingLabel then
    AddLine("system", standingLabel)
  end
  local tr = TA.dfModeTerrainRenderStats
  if type(tr) == "table" then
    AddLine("system", string.format("Terrain render: samples=%d lookups=%d resolved=%d painted=%d blocked=%d no-glyph=%d unresolved=%d", tr.samples or 0, tr.lookups or 0, tr.resolved or 0, tr.painted or 0, tr.blocked or 0, tr.noGlyph or 0, tr.unresolved or 0))
    if tr.heatMin ~= nil and tr.heatMax ~= nil then
      AddLine("system", string.format("Terrain hue range: min=%.2f max=%.2f", tonumber(tr.heatMin) or 0, tonumber(tr.heatMax) or 0))
    end
  end
  if TA.dfModeNavHint and TA.dfModeNavHint ~= "" then
    AddLine("system", "Navigation hint: " .. TA.dfModeNavHint)
  end
  if TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID then
    AddLine("system", "Marked cell occupancy: IN [" .. (TA.markedCells[TA.lastMarkedCellNotification].id or -1) .. "] " .. (TA.markedCells[TA.lastMarkedCellNotification].name or "Unnamed"))
  else
    AddLine("system", "Marked cell occupancy: not in a marked cell")
  end
  AddLine("system", "        ~=2 threats on cell  !=3+ threats on cell")

  if totalHostile > 0 then
    if balanced then
      local near, mid, far = 0, 0, 0
      for _, u in ipairs(units.hostile or {}) do
        local d = u.distance or 999
        if d <= 10 then near = near + 1
        elseif d <= 25 then mid = mid + 1
        else far = far + 1
        end
      end
      AddLine("system", "[THREAT] Hostiles: " .. totalHostile .. "  (Near: " .. near .. "  Mid: " .. mid .. "  Far: " .. far .. ")")
    else
      AddLine("system", "[!!! THREAT !!!] " .. totalHostile .. " hostile unit(s)!")
      for i = 1, math.min(6, totalHostile) do
        local unit = units.hostile[i]
        if unit then
          local health = "?"
          if unit.maxHealth and unit.maxHealth > 0 then
            health = math.floor((unit.health or 0) / unit.maxHealth * 100) .. "%"
          end
          local dist = math.floor(unit.distance or 0) .. "yd"
          local level = unit.level or "?"
          AddLine("system", "  [" .. i .. "] " .. (unit.name or "?") .. " Lvl" .. level .. " HP:" .. health .. " (" .. dist .. ")")
        end
      end
      if totalHostile > 6 then
        AddLine("system", "  ... and " .. (totalHostile - 6) .. " more hostile!")
      end
    end
  end

  local targetName = UnitName("target")
  if targetName then
    local playerX, playerY = UnitPosition("player")
    local targetX, targetY = UnitPosition("target")
    if playerX and targetX then
      local dx = targetX - playerX
      local dy = targetY - playerY
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= 14 then AddLine("system", "Target: " .. targetName .. " (near, " .. math.floor(d) .. "yd)")
      elseif d <= 30 then AddLine("system", "Target: " .. targetName .. " (mid-range, " .. math.floor(d) .. "yd)")
      else AddLine("system", "Target: " .. targetName .. " (far, " .. math.floor(d) .. "yd)")
      end
    else
      AddLine("system", "Target: " .. targetName .. " (detected)")
    end
  end

  if totalNeutral > 0 then AddLine("system", "Neutral: " .. totalNeutral .. " nearby") end
  if totalFriendly > 0 then AddLine("system", "Friendly: " .. totalFriendly .. " nearby") end
  if totalHostile == 0 and totalNeutral == 0 and totalFriendly == 0 then
    AddLine("system", "All clear - no units detected nearby")
  end
end

function TA_UpdateDFMode()
  if not TA.dfModeEnabled or not dfModeFrame:IsShown() then
    return
  end
  
  local now = GetTime()
  local dfInterval = tonumber(TA.tickerIntervals and TA.tickerIntervals.df) or 0.1
  if now - TA.dfModeLastUpdate < dfInterval then
    return  -- Update at most every configured DF ticker interval.
  end
  TA.dfModeLastUpdate = now

  -- DFDanger integration: evaluate passive warnings on a slower internal cadence.
  if DFDanger and DFDanger.Tick then
    pcall(function()
      DFDanger:Tick()
    end)
  end
  
  local display = BuildDFModeDisplay()
  local mapLines = dfModeFrame.mapLines
  local i = 1
  if display then
    for line in display:gmatch("[^\n]+") do
      if mapLines[i] then
        if mapLines[i]:GetText() ~= line then
          mapLines[i]:SetText(line)
        end
        i = i + 1
      end
    end
  else
    if mapLines[1] and mapLines[1]:GetText() ~= "Error generating tactical map." then
      mapLines[1]:SetText("Error generating tactical map.")
    end
    i = 2
  end
  -- Blank out any rows below the current map
  for j = i, #mapLines do
    if mapLines[j]:GetText() ~= "" then
      mapLines[j]:SetText("")
    end
  end
  local viewMode = TA.dfModeViewMode or "threat"
  local terrain = TA.dfModeTerrainContext
  if terrain and terrain.resolved then
    local waterFlag = terrain.hasWater and "W" or "D"
    dfTitle:SetText(string.format("%s | %s", viewMode, waterFlag))
  else
    dfTitle:SetText(viewMode)
  end
end

function TA_ToggleDFMode()
  TA.dfModeEnabled = not TA.dfModeEnabled
  if TA.dfModeEnabled then
    TA.dfModeViewMode = "threat"
    dfModeFrame:Show()
    TA.dfModeLastUpdate = 0  -- Reset timer to force immediate update
    TA_UpdateDFMode()
    AddLine("system", "DF Mode tactical map enabled.")
  else
    dfModeFrame:Hide()
    AddLine("system", "DF Mode tactical map disabled.")
  end
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.dfModeEnabled = TA.dfModeEnabled
  TextAdventurerDB.dfModeProfile = TA.dfModeProfile
  local currentW, currentH = dfModeFrame:GetSize()
  TextAdventurerDB.dfModeWidth = math.floor(currentW)
  TextAdventurerDB.dfModeHeight = math.floor(currentH)
end

-- ---- moved from textadventurer.lua lines 12451-12528 ----
local DF_YARDS_PER_CELL = 3
function TA_GetEffectiveDFYardsPerCell()
  local yards = tonumber(TA.dfModeYardsPerCell)
  if not yards then
    -- Keep DF tactical map at its own scale; do not inherit world cell-yard sizing.
    yards = tonumber(DF_YARDS_PER_CELL) or 3
  end
  yards = math.floor(yards + 0.5)
  if yards < 3 then yards = 3 end
  if yards > 100 then yards = 100 end
  return yards
end

function TA_GetProjectedDFPlayerWorldPosition(playerWorldX, playerWorldY)
  if not playerWorldX or not playerWorldY then
    playerWorldX, playerWorldY = UnitPosition("player")
  end
  if not playerWorldX or not playerWorldY then
    return nil, nil
  end

  local speed = tonumber(GetUnitSpeed("player")) or 0
  if speed <= 0 then
    return playerWorldX, playerWorldY
  end

  local facing = GetPlayerFacing()
  if not facing then
    return playerWorldX, playerWorldY
  end

  local lookaheadSeconds = tonumber(TA.dfModeLookaheadSeconds) or 0
  local projectedWorldX = playerWorldX
  local projectedWorldY = playerWorldY
  if lookaheadSeconds > 0 then
    -- Lookahead cap: max half a cell so projection cannot leap past the snap zone.
    local lookaheadCap = 0.5 * (TA_GetEffectiveDFYardsPerCell() or 3)
    local lookaheadYards = math.min(speed * lookaheadSeconds, lookaheadCap)
    local forwardX = -math.sin(facing)
    local forwardY = math.cos(facing)
    projectedWorldX = projectedWorldX + (forwardX * lookaheadYards)
    projectedWorldY = projectedWorldY + (forwardY * lookaheadYards)
  end

  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  if not yardsPerCell or yardsPerCell <= 0 then
    return projectedWorldX, projectedWorldY
  end

  local threshold = tonumber(TA.dfModeHysteresisEnterPct) or 0.38
  if threshold < 0.05 then threshold = 0.05 end
  if threshold > 0.49 then threshold = 0.49 end

  local function RoundNearest(n)
    if n >= 0 then
      return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
  end

  local function SnapAxis(rawCell, stateKey)
    local snappedCell = tonumber(TA[stateKey])
    if not snappedCell or math.abs(rawCell - snappedCell) > 2 then
      snappedCell = RoundNearest(rawCell)
    else
      while (rawCell - snappedCell) >= threshold do
        snappedCell = snappedCell + 1
      end
      while (rawCell - snappedCell) <= -threshold do
        snappedCell = snappedCell - 1
      end
    end
    TA[stateKey] = snappedCell
    return snappedCell * yardsPerCell
  end

  return SnapAxis(projectedWorldX / yardsPerCell, "dfModeAnchorCellX"), SnapAxis(projectedWorldY / yardsPerCell, "dfModeAnchorCellY")
end

