-- Modules/MarkedCells.lua
-- Marked cells + world-map cell overlay for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * Map overlay frame helpers: GetWorldMapOverlayParent, EnsureMapCellOverlay,
--     SetOverlayRect, UpdateMapCellOverlay.
--   * Player cell lookup: GetPlayerMapCell.
--   * Marked cell store: GetMarkedCellByID, CellKey, MarkCurrentCell,
--     ListMarkedCells, ShowMarkedCellOnMap, TA_RenameMarkedCell,
--     ClearMarkedCells, DeleteMarkedCell.
--
-- Must load AFTER textadventurer.lua and CellMath.lua (depends on
-- GetCellGridForMap, GetMapAnchor, ComputeCellForPosition, GetCellBounds,
-- AddLine, NormalizePeriodicOffset). Must load BEFORE NavigationCommands.lua
-- which calls MarkCurrentCell/ListMarkedCells/etc. See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 1730-1972 ----
function GetWorldMapOverlayParent()
  if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return nil end
  return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
end

function EnsureMapCellOverlay()
  if TA.mapCellOverlay then return TA.mapCellOverlay end
  local parent = GetWorldMapOverlayParent()
  if not parent then return nil end

  local container = CreateFrame("Frame", nil, parent)
  container:SetAllPoints(parent)
  container:SetFrameStrata("HIGH")
  container:SetFrameLevel(parent:GetFrameLevel() + 20)
  container:EnableMouse(false)
  container:Hide()

  local function CreateOutline(r, g, b)
    local frame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    frame:SetBackdrop({
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 12,
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(r, g, b, 0.08)
    frame:SetBackdropBorderColor(r, g, b, 0.95)
    frame:Hide()

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    frame.label:SetTextColor(r, g, b)
    return frame
  end

  container.current = CreateOutline(0.1, 1.0, 0.2)
  container.marked = CreateOutline(1.0, 0.82, 0.2)

  TA.mapCellOverlay = container
  return container
end

function SetOverlayRect(frame, parent, minX, maxX, minY, maxY, label)
  if not frame or not parent then return end
  minX = math.max(0, math.min(1, minX))
  maxX = math.max(0, math.min(1, maxX))
  minY = math.max(0, math.min(1, minY))
  maxY = math.max(0, math.min(1, maxY))
  if maxX <= minX or maxY <= minY then
    frame:Hide()
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", minX * parent:GetWidth(), -minY * parent:GetHeight())
  frame:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", maxX * parent:GetWidth(), -maxY * parent:GetHeight())
  frame.label:SetText(label or "")
  frame:Show()
end

function GetMarkedCellByID(markID)
  if not markID then return nil end
  return TA.markedCells and TA.markedCells[markID] or nil
end

function UpdateMapCellOverlay()
  local overlayParent = GetWorldMapOverlayParent()
  local overlay = EnsureMapCellOverlay()
  if not overlay or not overlayParent or not TA.mapOverlayEnabled then
    if overlay then overlay:Hide() end
    return
  end
  if not WorldMapFrame:IsShown() then
    overlay:Hide()
    return
  end

  local currentMapID, cellX, cellY, _, _, _, _, _, gridX, gridY, offsetX, offsetY = GetPlayerMapCell()
  local displayedMapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID() or currentMapID
  local showedAnything = false

  overlay.current:Hide()
  overlay.marked:Hide()

  if currentMapID and displayedMapID and currentMapID == displayedMapID then
    local minX, maxX, minY, maxY = GetCellBounds(cellX, cellY, gridX, gridY, offsetX, offsetY)
    SetOverlayRect(overlay.current, overlayParent, minX, maxX, minY, maxY, "Current cell")
    showedAnything = true
  end

  local mark = GetMarkedCellByID(TA.activeMapMarkID)
  if mark and displayedMapID and mark.mapID == displayedMapID and mark.cellX ~= nil and mark.cellY ~= nil then
    local markGridX = ClampGridSize(tonumber(mark.gridX) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
    local markGridY = ClampGridSize(tonumber(mark.gridY) or tonumber(mark.gridSize) or GRID_SIZE_DEFAULT)
    local markOffsetX = NormalizePeriodicOffset(mark.anchorOffsetX, 1 / markGridX)
    local markOffsetY = NormalizePeriodicOffset(mark.anchorOffsetY, 1 / markGridY)
    local minX, maxX, minY, maxY = GetCellBounds(mark.cellX, mark.cellY, markGridX, markGridY, markOffsetX, markOffsetY)
    SetOverlayRect(overlay.marked, overlayParent, minX, maxX, minY, maxY, mark.name or "Marked cell")
    showedAnything = true
  end

  if showedAnything then
    overlay:Show()
  else
    overlay:Hide()
  end
end

function GetPlayerMapCell()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local gridX, gridY = GetCellGridForMap(mapID)
  local offsetX, offsetY = GetMapAnchor(mapID, gridX, gridY)
  local x, y
  if C_Map and C_Map.GetPlayerMapPosition then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      x, y = pos:GetXY()
    end
  elseif GetPlayerMapPosition then
    x, y = GetPlayerMapPosition("player")
  end
  if not x or not y then return nil end
  local cellX, cellY, inCellX, inCellY = ComputeCellForPosition(x, y, gridX, gridY, offsetX, offsetY)
  
  -- Get continent coordinates for global positioning
  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local continentID = mapInfo and mapInfo.continentID or nil
  local continentX, continentY = 0, 0
  if continentID and C_Map and C_Map.GetWorldPosFromMapPos then
    local worldPos = C_Map.GetWorldPosFromMapPos(mapID, {x = x, y = y})
    if worldPos and type(worldPos) == "table" and worldPos.x and worldPos.y then
      continentX, continentY = worldPos.x, worldPos.y
    end
  end
  
  return mapID, cellX, cellY, x, y, continentX, continentY, continentID, gridX, gridY, offsetX, offsetY, inCellX, inCellY
end

function CellKey(x, y)
  return tostring(x) .. "," .. tostring(y)
end

function MarkCurrentCell(name)
  -- Always recenter the grid anchor on the player before marking so the cell
  -- center lands on top of the player, matching the delete-and-remark behavior.
  RecenterCurrentCellAnchor(true)
  local mapID, cellX, cellY, x, y, continentX, continentY, continentID, gridX, gridY, offsetX, offsetY = GetPlayerMapCell()
  if not mapID then 
    AddLine("system", "Could not determine current location - mapID is nil.")
    return 
  end
  local zoneName = GetZoneText() or "Unknown Zone"
  
  local markID = TA.nextMarkID
  local markName = name or ("cell " .. tostring(markID))
  TA.markedCells[markID] = {
    id = markID,
    name = markName,
    zoneName = zoneName,
    mapID = mapID,
    gridSize = gridX,
    gridX = gridX,
    gridY = gridY,
    anchorOffsetX = offsetX,
    anchorOffsetY = offsetY,
    cellMode = TA.cellSizeMode or "grid",
    targetYards = tonumber(TA.cellSizeYards),
    continentID = continentID,
    cellX = cellX,
    cellY = cellY,
    x = x,
    y = y,
    continentX = continentX,
    continentY = continentY,
    timestamp = time()
  }
  TA.nextMarkID = TA.nextMarkID + 1
  TA.activeMapMarkID = markID
  TA.lastMarkedCellNotification = markID
  AddLine("system", string.format("Marked %s", markName))
  UpdateMapCellOverlay()
end

function ListMarkedCells()
  if not next(TA.markedCells) then
    AddLine("system", "No cells marked.")
    return
  end
  AddLine("system", "Marked cells:")
  for markID, mark in pairs(TA.markedCells) do
    local active = (TA.activeMapMarkID == markID) and " [shown on map]" or ""
    AddLine("system", string.format("  [%d] %s in %s%s", mark.id, mark.name, mark.zoneName, active))
  end
end

function ShowMarkedCellOnMap(markID)
  local mark = GetMarkedCellByID(markID)
  if not mark then
    AddLine("system", string.format("No marked cell found with ID %d.", tonumber(markID) or -1))
    return
  end
  TA.activeMapMarkID = mark.id
  AddLine("system", string.format("World Map will highlight marked cell [%d] %s.", mark.id, mark.name or "Unnamed"))
  UpdateMapCellOverlay()
end

function TA_RenameMarkedCell(markID, newName)
  local mark = GetMarkedCellByID(markID)
  if not mark then
    AddLine("system", string.format("No marked cell found with ID %d.", markID))
    return
  end
  local oldName = mark.name
  mark.name = newName
  TextAdventurerDB.markedCells = TA.markedCells
  AddLine("system", string.format("Renamed marked cell [%d] from '%s' to '%s'.", markID, oldName, newName))
end

function ClearMarkedCells()
  wipe(TA.markedCells)
  TA.activeMapMarkID = nil
  UpdateMapCellOverlay()
  AddLine("system", "All marked cells cleared.")
end

function DeleteMarkedCell(markID)
  local mark = GetMarkedCellByID(markID)
  if not mark then
    AddLine("system", string.format("No marked cell found with ID %d.", markID))
    return
  end
  local name = mark.name or "Unnamed"
  TA.markedCells[markID] = nil
  if TA.activeMapMarkID == markID then
    TA.activeMapMarkID = nil
  end
  if TA.lastMarkedCellNotification == markID then
    TA.lastMarkedCellNotification = nil
  end
  TextAdventurerDB.markedCells = TA.markedCells
  UpdateMapCellOverlay()
  AddLine("system", string.format("Deleted marked cell [%d] '%s'.", markID, name))
end

