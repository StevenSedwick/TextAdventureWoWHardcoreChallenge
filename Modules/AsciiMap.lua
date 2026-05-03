-- Modules/AsciiMap.lua
-- Interact-distance helper, nearby-unit position collection + cache,
-- and the ASCII minimap renderer.
--
-- Extracted from textadventurer.lua. Owns:
--   * TA_TryInteractDistance          -- safe pcall wrapper around
--                                        CheckInteractDistance
--   * CollectNearbyUnitsWithPositions -- snapshot all nameplate units
--                                        with world coords + distances
--   * GetNearbyUnitsWithPositions     -- cached wrapper; refreshes at
--                                        most once per 100-200 ms
--   * TA_ReportAsciiMap               -- "map" command: 7x7 ASCII cell
--                                        grid around player
--
-- All were already true globals (no local function prefix). No _G
-- mirror lines existed; none needed to be removed.
--
-- Depends on shared globals: AddLine, TA (recentCells, markedCells,
-- asciiMapEnabled, lastAsciiMapSignature, lastNearbyUnits,
-- nearbyUnitsCacheAt, nearbyUnitsCacheInterval),
-- GetPlayerMapCell, CellKey, ComputeCellForPosition, GetExplorationData.
--
-- Called from: Modules/Awareness.lua, Modules/DFMode.lua,
-- Modules/TargetPositioning.lua (TA_TryInteractDistance);
-- Modules/DFMode.lua, Modules/Awareness.lua
-- (GetNearbyUnitsWithPositions); Modules/NavigationCommands.lua
-- (TA_ReportAsciiMap); textadventurer.lua tickers
-- (TA_ReportAsciiMap, GetNearbyUnitsWithPositions).
--
-- Loads after textadventurer.lua and before Modules/DFMode.lua,
-- Modules/Awareness.lua, and Modules/NavigationCommands.lua.
-- .toc slot: between Modules/TargetPositioning.lua and
-- Modules/CellMath.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2952-3117 ----
function TA_TryInteractDistance(unit, checkType)
  if not unit or not CheckInteractDistance then
    return false
  end
  -- This API can be protected in combat when execution is tainted.
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  local ok, result = pcall(CheckInteractDistance, unit, checkType)
  return ok and result or false
end

function CollectNearbyUnitsWithPositions()
  local units = { hostile = {}, neutral = {}, friendly = {} }
  local nameplates = C_NamePlate.GetNamePlates()
  if not nameplates then return units end
  local playerX, playerY = UnitPosition("player")
  
  for _, frame in ipairs(nameplates) do
    local unit = frame.namePlateUnitToken
    if unit and UnitExists(unit) then
      local name = UnitName(unit)
      if name then
        local reaction = UnitReaction(unit, "player") or 4
        local canAttack = UnitCanAttack("player", unit)
        local unitType = "neutral"
        
        if canAttack then
          unitType = "hostile"
        elseif reaction >= 5 then
          unitType = "friendly"
        end
        
        -- Get distance estimate -- prefer exact world-position math (works at
        -- any range and is accurate to <1 yard). Fall back to interact-distance
        -- buckets when positions are unavailable. Fall back to "far" only when
        -- both methods fail. Previously CheckInteractDistance ran first and
        -- locked very-close units to 5 yards even when exact pos would have
        -- said 0.3, which propagated into clamped grid placement.
        local unitX, unitY = UnitPosition(unit)
        local distance = 0
        if unitX and unitY and playerX and playerY then
          local dx = unitX - playerX
          local dy = unitY - playerY
          distance = math.sqrt(dx*dx + dy*dy)
        elseif CheckInteractDistance then
          for i = 1, 4 do
            if TA_TryInteractDistance(unit, i) then
              distance = i * 5
              break
            end
          end
        end
        if distance == 0 and not (unitX and unitY and playerX and playerY) then
          distance = 50  -- assume far if we truly cannot measure
        end
        
        table.insert(units[unitType], {
          name = name,
          distance = distance,
          level = UnitLevel(unit),
          class = UnitClass(unit),
          health = UnitHealth(unit),
          maxHealth = UnitHealthMax(unit),
          unit = unit,
          guid = UnitGUID(unit),
          worldX = unitX,
          worldY = unitY,
          hasExactPos = unitX and unitY and playerX and playerY,
        })
      end
    end
  end
  
  return units
end

  function GetNearbyUnitsWithPositions(forceRefresh)
    if not GetTime then
      return CollectNearbyUnitsWithPositions()
    end

    local now = GetTime()
    local refreshInterval = tonumber(TA.nearbyUnitsCacheInterval) or 0.15
    if refreshInterval < 0.1 then refreshInterval = 0.1 end
    if refreshInterval > 0.2 then refreshInterval = 0.2 end

    local hasCached = (type(TA.lastNearbyUnits) == "table") and (type(TA.nearbyUnitsCacheAt) == "number")
    if hasCached and not forceRefresh and (now - TA.nearbyUnitsCacheAt) < refreshInterval then
      return TA.lastNearbyUnits
    end

    local units = CollectNearbyUnitsWithPositions()
    TA.lastNearbyUnits = units
    TA.nearbyUnitsCacheAt = now
    return units
  end





function TA_ReportAsciiMap(force, ignoreToggle)
  if not ignoreToggle and not TA.asciiMapEnabled then
    return
  end


  local mapID, cellX, cellY, _, _, _, _, _, gridX, gridY, offsetX, offsetY = GetPlayerMapCell()
  if not mapID then
    if force then AddLine("system", "Could not determine current cell for map.") end
    return
  end

  local signature = tostring(mapID) .. ":" .. tostring(cellX) .. "," .. tostring(cellY)
  if not force and signature == TA.lastAsciiMapSignature then
    return
  end
  TA.lastAsciiMapSignature = signature

  local data = GetExplorationData(mapID)
  local recentLookup = {}
  for i = 1, #TA.recentCells do
    local key = TA.recentCells[i]
    local keyMap, keyCell = key:match("^(%d+):(.+)$")
    if tonumber(keyMap) == mapID and keyCell then
      recentLookup[keyCell] = true
    end
  end

  local markLookup = {}
  for _, mark in pairs(TA.markedCells) do
    if mark.mapID == mapID and mark.x and mark.y then
      local mCellX, mCellY = ComputeCellForPosition(mark.x, mark.y, gridX, gridY, offsetX, offsetY)
      markLookup[CellKey(mCellX, mCellY)] = true
    elseif mark.mapID == mapID and mark.cellX ~= nil and mark.cellY ~= nil then
      markLookup[CellKey(mark.cellX, mark.cellY)] = true
    end
  end

  local radius = 3
  local span = (radius * 2) + 1
  AddLine("place", string.format("ASCII map (%dx%d), centered on [%d,%d]:", span, span, cellX, cellY))

  for y = cellY + radius, cellY - radius, -1 do
    local row = {}
    for x = cellX - radius, cellX + radius do
      local glyph = "."
      if x == cellX and y == cellY then
        glyph = "P"
      else
        local key = CellKey(x, y)
        if markLookup[key] then
          glyph = "M"
        elseif recentLookup[key] then
          glyph = "+"
        elseif data.visited and data.visited[key] then
          glyph = "#"
        end
      end
      table.insert(row, glyph)
    end
    AddLine("place", "  " .. table.concat(row, " "))
  end
  AddLine("place", "Legend: P=you M=mark +=recent #=visited .=unknown")
end

