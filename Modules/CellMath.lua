-- Modules/CellMath.lua
-- Cell / grid math + cell-size commands for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * Grid size helpers: GetGridSize, ClampGridSize, NormalizePeriodicOffset,
--     IsAnchorCompatible, GetMapWorldDimensions, GetCellGridForMap,
--     GetMapAnchor, ComputeCellForPosition, GetCellBounds.
--   * Cell anchor + reporting: RecenterCurrentCellAnchor, ReportCurrentCell.
--   * Cell-size commands: SetGridSize, SetCellSizeYards, DisableCellSizeYardsMode,
--     TA_ParseCellYardsCandidates, TA_ReportCellYardsCalibration.
--
-- Must load AFTER textadventurer.lua (which defines TA, AddLine, the
-- GRID_SIZE_*/CELL_YARDS_* constants, and the UpdateMapCellOverlay forward
-- declaration), and BEFORE modules that use these (NavigationCommands.lua,
-- MarkedCells.lua). See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- Pull in file-local constants that the main file mirrors onto _G.
local GRID_SIZE_DEFAULT = _G.GRID_SIZE_DEFAULT or 80
local GRID_SIZE_MIN = _G.GRID_SIZE_MIN or 8
local GRID_SIZE_MAX = _G.GRID_SIZE_MAX or 240
local CELL_YARDS_MIN = _G.CELL_YARDS_MIN or 5
local CELL_YARDS_MAX = _G.CELL_YARDS_MAX or 500

-- ---- moved from textadventurer.lua lines 1726-2079 ----
function GetGridSize()
  local size = tonumber(TA.gridSize) or GRID_SIZE_DEFAULT
  size = math.floor(size)
  if size < GRID_SIZE_MIN then size = GRID_SIZE_MIN end
  if size > GRID_SIZE_MAX then size = GRID_SIZE_MAX end
  return size
end

function ClampGridSize(n)
  n = math.floor(tonumber(n) or GRID_SIZE_DEFAULT)
  if n < GRID_SIZE_MIN then n = GRID_SIZE_MIN end
  if n > GRID_SIZE_MAX then n = GRID_SIZE_MAX end
  return n
end

function NormalizePeriodicOffset(offset, step)
  if not step or step <= 0 then return 0 end
  offset = tonumber(offset) or 0
  offset = offset % step
  return offset
end

function IsAnchorCompatible(anchor, gridX, gridY)
  if type(anchor) ~= "table" then return false end
  if tonumber(anchor.gridX) ~= tonumber(gridX) or tonumber(anchor.gridY) ~= tonumber(gridY) then
    return false
  end
  local anchorMode = anchor.mode == "yards" and "yards" or "grid"
  local currentMode = TA.cellSizeMode == "yards" and "yards" or "grid"
  if anchorMode ~= currentMode then
    return false
  end
  if anchorMode == "yards" then
    local anchorYards = math.floor((tonumber(anchor.targetYards) or 0) + 0.5)
    local currentYards = math.floor((tonumber(TA.cellSizeYards) or 0) + 0.5)
    return anchorYards > 0 and anchorYards == currentYards
  end
  return true
end

function GetMapWorldDimensions(mapID)
  -- Returns (widthYards, heightYards) for a zone map, measured via corner
  -- samples through C_Map.GetWorldPosFromMapPos. This is a fallback for
  -- Classic Era where C_Map.GetMapInfo does not populate width/height.
  -- Cached per mapID since these never change at runtime.
  if not mapID then return nil, nil end
  TA._mapYardsCache = TA._mapYardsCache or {}
  local cached = TA._mapYardsCache[mapID]
  if cached then return cached.width, cached.height end

  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  if mapInfo and tonumber(mapInfo.width) and tonumber(mapInfo.height) and mapInfo.width > 0 and mapInfo.height > 0 then
    TA._mapYardsCache[mapID] = { width = mapInfo.width, height = mapInfo.height }
    return mapInfo.width, mapInfo.height
  end

  if C_Map and C_Map.GetWorldPosFromMapPos then
    local makeVec = CreateVector2D or function(vx, vy) return { x = vx, y = vy } end
    -- C_Map.GetWorldPosFromMapPos returns (continentID, worldPos) -- the
    -- vector is the SECOND return value.
    local ok1, _c1, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.0, 0.5))
    local ok2, _c2, p2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(1.0, 0.5))
    local ok3, _c3, p3 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.5, 0.0))
    local ok4, _c4, p4 = pcall(C_Map.GetWorldPosFromMapPos, mapID, makeVec(0.5, 1.0))
    if ok1 and ok2 and ok3 and ok4
        and type(p1) == "table" and type(p2) == "table"
        and type(p3) == "table" and type(p4) == "table" then
      local function vx(p) return tonumber(p.x) or tonumber(p[1]) or 0 end
      local function vy(p) return tonumber(p.y) or tonumber(p[2]) or 0 end
      local widthYards = math.sqrt((vx(p2) - vx(p1))^2 + (vy(p2) - vy(p1))^2)
      local heightYards = math.sqrt((vx(p4) - vx(p3))^2 + (vy(p4) - vy(p3))^2)
      if widthYards > 0 and heightYards > 0 then
        TA._mapYardsCache[mapID] = { width = widthYards, height = heightYards }
        return widthYards, heightYards
      end
    end
  end
  return nil, nil
end

function GetCellGridForMap(mapID)
  local mode = TA.cellSizeMode == "yards" and "yards" or "grid"
  local targetYards = tonumber(TA.cellSizeYards)
  if mode == "yards" and targetYards and targetYards > 0 then
    local mapWidthYards, mapHeightYards = GetMapWorldDimensions(mapID)
    if mapWidthYards and mapHeightYards then
      local gridX = ClampGridSize(math.floor((mapWidthYards / targetYards) + 0.5))
      local gridY = ClampGridSize(math.floor((mapHeightYards / targetYards) + 0.5))
      return gridX, gridY, "yards", targetYards
    end
  end

  local gridSize = GetGridSize()
  return gridSize, gridSize, mode, targetYards
end

function GetMapAnchor(mapID, gridX, gridY)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local anchors = TA.cellAnchors or {}
  local anchor = anchors[mapID]
  if not IsAnchorCompatible(anchor, gridX, gridY) then
    return 0, 0
  end
  return NormalizePeriodicOffset(anchor.offsetX, stepX), NormalizePeriodicOffset(anchor.offsetY, stepY)
end

function ComputeCellForPosition(x, y, gridX, gridY, offsetX, offsetY)
  local shiftedX = (x - (offsetX or 0)) % 1
  local shiftedY = (y - (offsetY or 0)) % 1
  local scaledX = shiftedX * gridX
  local scaledY = shiftedY * gridY
  local cellX = math.floor(scaledX)
  local cellY = math.floor(scaledY)
  if cellX < 0 then cellX = 0 end
  if cellY < 0 then cellY = 0 end
  if cellX >= gridX then cellX = gridX - 1 end
  if cellY >= gridY then cellY = gridY - 1 end
  local inCellX = math.max(0, math.min(1, scaledX - cellX))
  local inCellY = math.max(0, math.min(1, scaledY - cellY))
  return cellX, cellY, inCellX, inCellY
end

function GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local minX = ((offsetX or 0) + (cellX * stepX)) % 1
  local maxX = minX + stepX
  local minY = ((offsetY or 0) + (cellY * stepY)) % 1
  local maxY = minY + stepY
  return minX, maxX, minY, maxY, stepX, stepY
end

function RecenterCurrentCellAnchor(silent)
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then
    if not silent then AddLine("system", "Could not center grid: map is unavailable.") end
    return false
  end
  local x, y
  if C_Map and C_Map.GetPlayerMapPosition then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      x, y = pos:GetXY()
    end
  elseif GetPlayerMapPosition then
    x, y = GetPlayerMapPosition("player")
  end
  if not x or not y then
    if not silent then AddLine("system", "Could not center grid: player position unavailable.") end
    return false
  end

  local gridX, gridY, mode, targetYards = GetCellGridForMap(mapID)
  local stepX = 1 / gridX
  local stepY = 1 / gridY
  local offsetX = NormalizePeriodicOffset(x - (0.5 * stepX), stepX)
  local offsetY = NormalizePeriodicOffset(y - (0.5 * stepY), stepY)

  TA.cellAnchors = TA.cellAnchors or {}
  TA.cellAnchors[mapID] = {
    offsetX = offsetX,
    offsetY = offsetY,
    gridX = gridX,
    gridY = gridY,
    mode = mode,
    targetYards = targetYards,
  }
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.cellAnchors = TA.cellAnchors
  TA.lastCellVizSignature = nil
  UpdateMapCellOverlay()

  if not silent then
    AddLine("system", "Cell grid anchor moved so your position is centered in the current cell.")
  end
  return true
end

function ReportCurrentCell(force)
  local mapID, cellX, cellY, x, y, _, _, _, gridX, gridY, offsetX, offsetY, inCellX, inCellY = GetPlayerMapCell()
  if not mapID then
    if force then AddLine("system", "Could not determine current cell.") end
    return
  end
  local minX, maxX, minY, maxY = GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local sizeText = "size unknown"
  if mapInfo and mapInfo.width and mapInfo.height and mapInfo.width > 0 and mapInfo.height > 0 then
    sizeText = string.format("~%.1f x %.1f yards", mapInfo.width / gridX, mapInfo.height / gridY)
  end
  local signature = string.format("%d:%d,%d:%d:%d:%s:%.6f:%.6f", mapID, cellX, cellY, gridX, gridY, TA.cellSizeMode or "grid", offsetX or 0, offsetY or 0)
  local modeText
  if TA.cellSizeMode == "yards" and tonumber(TA.cellSizeYards) then
    modeText = string.format("fixed %.0f-yard mode (%dx%d grid)", tonumber(TA.cellSizeYards), gridX, gridY)
  else
    modeText = string.format("%dx%d grid", gridX, gridY)
  end
  if force or signature ~= TA.lastCellVizSignature then
    AddLine("place", string.format("Cell %d,%d on map %d using %s (%s).", cellX, cellY, mapID, modeText, sizeText))
    AddLine("place", string.format("Bounds X %.4f-%.4f, Y %.4f-%.4f. Position in cell: %.0f%% east, %.0f%% south.", minX, maxX, minY, maxY, inCellX * 100, inCellY * 100))
    if TA.markedCells and TA.lastMarkedCellNotification and TA.markedCells[TA.lastMarkedCellNotification] and TA.markedCells[TA.lastMarkedCellNotification].mapID == mapID then
      AddLine("place", string.format("YOU ARE IN MARKED CELL [%d]: %s", TA.markedCells[TA.lastMarkedCellNotification].id or -1, TA.markedCells[TA.lastMarkedCellNotification].name or "Unnamed"))
    else
      AddLine("place", "You are not in a marked cell.")
    end
    TA.lastCellVizSignature = signature
  end
end

function SetGridSize(newSize, label)
  local n = tonumber(newSize)
  if not n then
    AddLine("system", "Usage: cellsize <number|standard|inn>")
    return
  end
  n = math.floor(n)
  if n < GRID_SIZE_MIN or n > GRID_SIZE_MAX then
    AddLine("system", string.format("Cell size must be between %d and %d.", GRID_SIZE_MIN, GRID_SIZE_MAX))
    return
  end
  TA.gridSize = n
  TA.cellSizeMode = "grid"
  TA.cellSizeYards = nil
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.gridSize = n
  TextAdventurerDB.cellSizeMode = "grid"
  TextAdventurerDB.cellSizeYards = nil
  RecenterCurrentCellAnchor(true)
  TA.lastCellVizSignature = nil
  if label and label ~= "" then
    AddLine("system", string.format("Cell grid set to %s (%dx%d).", label, n, n))
  else
    AddLine("system", string.format("Cell grid set to %dx%d.", n, n))
  end
end

function SetCellSizeYards(newYards)
  local yards = tonumber(newYards)
  if not yards then
    AddLine("system", "Usage: cellyards <yards>|off")
    return
  end
  yards = math.floor(yards + 0.5)
  if yards < CELL_YARDS_MIN or yards > CELL_YARDS_MAX then
    AddLine("system", string.format("Cell yards must be between %d and %d.", CELL_YARDS_MIN, CELL_YARDS_MAX))
    return
  end

  TA.cellSizeMode = "yards"
  TA.cellSizeYards = yards
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.cellSizeMode = "yards"
  TextAdventurerDB.cellSizeYards = yards
  RecenterCurrentCellAnchor(true)
  TA.lastCellVizSignature = nil
  AddLine("system", string.format("Cell sizing set to fixed %d-yard mode.", yards))
end

function DisableCellSizeYardsMode()
  TA.cellSizeMode = "grid"
  TA.cellSizeYards = nil
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.cellSizeMode = "grid"
  TextAdventurerDB.cellSizeYards = nil
  RecenterCurrentCellAnchor(true)
  TA.lastCellVizSignature = nil
  AddLine("system", "Fixed-yard cell mode disabled; using grid mode.")
end

function TA_ParseCellYardsCandidates(arg)
  if not arg or arg == "" then
    return nil
  end

  local values = {}
  local seen = {}
  for token in string.gmatch(arg, "[%d%.]+") do
    local yards = math.floor((tonumber(token) or 0) + 0.5)
    if yards >= CELL_YARDS_MIN and yards <= CELL_YARDS_MAX and not seen[yards] then
      seen[yards] = true
      table.insert(values, yards)
    end
  end

  if #values == 0 then
    return nil
  end

  table.sort(values)
  return values
end

function TA_ReportCellYardsCalibration(arg)
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then
    AddLine("system", "Could not calibrate cell size: map is unavailable.")
    return
  end

  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  if not mapInfo or not mapInfo.width or not mapInfo.height or mapInfo.width <= 0 or mapInfo.height <= 0 then
    AddLine("system", "Could not calibrate cell size: map dimensions are unavailable.")
    return
  end

  local candidates = TA_ParseCellYardsCandidates(arg) or CELL_YARDS_CANDIDATES
  local rows = {}
  for _, targetYards in ipairs(candidates) do
    local gridX = ClampGridSize(math.floor((mapInfo.width / targetYards) + 0.5))
    local gridY = ClampGridSize(math.floor((mapInfo.height / targetYards) + 0.5))
    local actualX = mapInfo.width / gridX
    local actualY = mapInfo.height / gridY
    local drift = math.abs(actualX - targetYards) + math.abs(actualY - targetYards)
    local skew = math.abs(actualX - actualY)
    -- Prefer candidates that stay close to target yards and keep X/Y cell dimensions similar.
    local score = drift + (skew * 0.35)

    table.insert(rows, {
      target = targetYards,
      gridX = gridX,
      gridY = gridY,
      actualX = actualX,
      actualY = actualY,
      drift = drift,
      skew = skew,
      score = score,
    })
  end

  if #rows == 0 then
    AddLine("system", "No valid cell-yard candidates to test.")
    return
  end

  table.sort(rows, function(a, b)
    if a.score == b.score then
      return a.target < b.target
    end
    return a.score < b.score
  end)

  local mapName = mapInfo.name or ("map " .. tostring(mapID))
  AddLine("system", string.format("Cell calibration on %s (%d):", mapName, mapID))
  local showCount = math.min(#rows, 6)
  for i = 1, showCount do
    local row = rows[i]
    AddLine("system", string.format("  %d yd -> %dx%d grid, actual %.1f x %.1f yd (drift %.1f, skew %.1f)", row.target, row.gridX, row.gridY, row.actualX, row.actualY, row.drift, row.skew))
  end

  local best = rows[1]
  AddLine("system", string.format("Recommended here: /ta cellyards %d", best.target))
  AddLine("system", "Use /ta cellcal <n1 n2 n3 ...> to test your own yard list.")
end

