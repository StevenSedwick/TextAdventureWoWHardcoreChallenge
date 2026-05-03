-- Modules/Terrain.lua
-- Terrain context, classification, and heat-color helpers for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * Terrain data loaders: TA_GetLoadedTerrainData, TA_GetTerrainChunkIndex,
--     TA_TerrainStatsFromGrid, TA_TerrainMaxFromGrid, TA_TerrainSampleFromGrid,
--     TA_BuildTerrainMarkerDensity (file-local helpers).
--   * Public terrain queries: TA_GetTerrainContextAtWorldPos,
--     TA_GetTerrainContextAtMapPos, TA_GetTerrainGlyph,
--     TA_ClassifyStandingTerrain.
--   * Color/heat utilities: TA_Clamp01, TA_ColorLerp, TA_HeatToRGB,
--     TA_ColorizeCellByHeat, TA_TerrainHeatFromContext.
--
-- Must load AFTER textadventurer.lua and BEFORE modules that consume these
-- helpers (Modules/DFMode.lua, Modules/NavigationCommands.lua). See
-- TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 9968-10513 ----
function TA_GetLoadedTerrainData()
  local data = rawget(_G, "TextAdventurerTerrainData")
  if type(data) ~= "table" then
    return nil
  end
  if type(data.chunks) ~= "table" then
    return nil
  end
  return data
end

local function TA_GetTerrainChunkIndex(data)
  if not data then
    return nil
  end
  if type(data._chunkIndex) == "table" then
    return data._chunkIndex
  end

  local index = {}
  for i = 1, #data.chunks do
    local c = data.chunks[i]
    if type(c) == "table" and type(c.tile) == "table" and type(c.chunk) == "table" then
      local tx = tonumber(c.tile[1])
      local ty = tonumber(c.tile[2])
      local cx = tonumber(c.chunk[1])
      local cy = tonumber(c.chunk[2])
      if tx and ty and cx and cy then
        index[string.format("%d:%d:%d:%d", tx, ty, cx, cy)] = c
      end
    end
  end

  data._chunkIndex = index
  return index
end

local function TA_TerrainStatsFromGrid(grid)
  if type(grid) ~= "table" then
    return nil
  end
  local sum = 0
  local count = 0
  for y = 1, #grid do
    local row = grid[y]
    if type(row) == "table" then
      for x = 1, #row do
        local v = tonumber(row[x])
        if v then
          sum = sum + v
          count = count + 1
        end
      end
    end
  end
  if count <= 0 then
    return nil
  end
  return sum / count
end

local function TA_TerrainMaxFromGrid(grid)
  if type(grid) ~= "table" then
    return nil
  end
  local maxV = nil
  for y = 1, #grid do
    local row = grid[y]
    if type(row) == "table" then
      for x = 1, #row do
        local v = tonumber(row[x])
        if v and (maxV == nil or v > maxV) then
          maxV = v
        end
      end
    end
  end
  return maxV
end

local function TA_TerrainSampleFromGrid(grid, fx, fy)
  if type(grid) ~= "table" or #grid <= 0 then
    return nil
  end

  local height = #grid
  local width = 0
  for y = 1, height do
    local row = grid[y]
    if type(row) == "table" and #row > width then
      width = #row
    end
  end
  if width <= 0 then
    return nil
  end

  local xNorm = tonumber(fx) or 0
  local yNorm = tonumber(fy) or 0
  if xNorm < 0 then xNorm = 0 elseif xNorm > 1 then xNorm = 1 end
  if yNorm < 0 then yNorm = 0 elseif yNorm > 1 then yNorm = 1 end

  local gx = xNorm * (width - 1) + 1
  local gy = yNorm * (height - 1) + 1
  local x0 = math.floor(gx)
  local y0 = math.floor(gy)
  local x1 = math.min(width, x0 + 1)
  local y1 = math.min(height, y0 + 1)
  if x0 < 1 then x0 = 1 end
  if y0 < 1 then y0 = 1 end

  local tx = gx - x0
  local ty = gy - y0

  local function getCell(ix, iy)
    local row = grid[iy]
    if type(row) ~= "table" then
      return nil
    end
    return tonumber(row[ix])
  end

  local v00 = getCell(x0, y0)
  local v10 = getCell(x1, y0) or v00
  local v01 = getCell(x0, y1) or v00
  local v11 = getCell(x1, y1) or v10 or v01 or v00
  if not v00 then
    return nil
  end

  local top = v00 + (v10 - v00) * tx
  local bottom = v01 + (v11 - v01) * tx
  return top + (bottom - top) * ty
end

local function TA_BuildTerrainMarkerDensity(data, index)
  if not data or type(index) ~= "table" then
    return {}
  end
  if type(data._markerDensityByChunk) == "table" then
    return data._markerDensityByChunk
  end

  local markers = data.markers
  if type(markers) ~= "table" or #markers == 0 then
    data._markerDensityByChunk = {}
    return data._markerDensityByChunk
  end

  local ADT_TILE_SIZE = 1600 / 3
  local ADT_HALF = 32 * ADT_TILE_SIZE

  local function worldToChunkKey(wx, wy)
    if type(wx) ~= "number" or type(wy) ~= "number" then
      return nil
    end
    local rawTileX = (wx + ADT_HALF) / ADT_TILE_SIZE
    local rawTileY = (ADT_HALF - wy) / ADT_TILE_SIZE
    if rawTileX < 0 or rawTileX >= 64 or rawTileY < 0 or rawTileY >= 64 then
      return nil
    end

    local tx = math.floor(rawTileX)
    local ty = math.floor(rawTileY)
    local cx = math.floor((rawTileX - tx) * 16)
    local cy = math.floor((rawTileY - ty) * 16)
    if cx < 0 or cx > 15 or cy < 0 or cy > 15 then
      return nil
    end
    return string.format("%d:%d:%d:%d", tx, ty, cx, cy)
  end

  local transforms = {
    { name = "xy_centered", fn = function(a, b, c) return a, b end },
    { name = "yx_centered", fn = function(a, b, c) return b, a end },
    { name = "xz_centered", fn = function(a, b, c) return a, c end },
    { name = "yz_centered", fn = function(a, b, c) return b, c end },
    { name = "xy_shifted",  fn = function(a, b, c) return a - ADT_HALF, ADT_HALF - b end },
    { name = "yx_shifted",  fn = function(a, b, c) return b - ADT_HALF, ADT_HALF - a end },
    { name = "xz_shifted",  fn = function(a, b, c) return a - ADT_HALF, ADT_HALF - c end },
    { name = "yz_shifted",  fn = function(a, b, c) return b - ADT_HALF, ADT_HALF - c end },
  }

  local sampleCount = math.min(#markers, 1500)
  local best = nil
  for i = 1, #transforms do
    local t = transforms[i]
    local score = 0
    local mapped = 0
    for mIdx = 1, sampleCount do
      local m = markers[mIdx]
      if type(m) == "table" and type(m.pos) == "table" then
        local a = tonumber(m.pos[1])
        local b = tonumber(m.pos[2])
        local c = tonumber(m.pos[3])
        if a and b and c then
          local wx, wy = t.fn(a, b, c)
          local key = worldToChunkKey(wx, wy)
          if key then
            mapped = mapped + 1
            if index[key] then
              score = score + 1
            end
          end
        end
      end
    end
    if (not best) or score > best.score or (score == best.score and mapped > best.mapped) then
      best = { transform = t, score = score, mapped = mapped }
    end
  end

  local density = {}
  if not best or best.score <= 0 then
    data._markerDensityByChunk = density
    data._markerDensityTransform = best and best.transform and best.transform.name or "none"
    return density
  end

  data._markerDensityTransform = best.transform.name
  for i = 1, #markers do
    local m = markers[i]
    if type(m) == "table" and type(m.pos) == "table" then
      local a = tonumber(m.pos[1])
      local b = tonumber(m.pos[2])
      local c = tonumber(m.pos[3])
      if a and b and c then
        local wx, wy = best.transform.fn(a, b, c)
        local key = worldToChunkKey(wx, wy)
        if key and index[key] then
          local w = (m.kind == "wmo") and 2 or 1
          density[key] = (density[key] or 0) + w
        end
      end
    end
  end

  data._markerDensityByChunk = density
  return density
end

function TA_GetTerrainContextAtWorldPos(posX, posY, preferredMode)
  if type(posX) ~= "number" or type(posY) ~= "number" then
    return nil
  end

  local data = TA_GetLoadedTerrainData()
  if not data then
    return nil
  end

  local index = TA_GetTerrainChunkIndex(data)
  if type(index) ~= "table" then
    return nil
  end

  local ADT_TILE_SIZE = 1600 / 3          -- 533.333... yards per tile
  local ADT_HALF = 32 * ADT_TILE_SIZE     -- 17066.666... yards to world center

  local function buildLookup(worldX, worldY, mode)
    local rawTileX = (worldX + ADT_HALF) / ADT_TILE_SIZE
    local rawTileY = (ADT_HALF - worldY) / ADT_TILE_SIZE

    local tileX = math.floor(rawTileX)
    local tileY = math.floor(rawTileY)
    local chunkPosX = (rawTileX - tileX) * 16
    local chunkPosY = (rawTileY - tileY) * 16
    local chunkX = math.floor(chunkPosX)
    local chunkY = math.floor(chunkPosY)
    local localX = chunkPosX - chunkX
    local localY = chunkPosY - chunkY

    tileX = math.max(0, math.min(63, tileX))
    tileY = math.max(0, math.min(63, tileY))
    chunkX = math.max(0, math.min(15, chunkX))
    chunkY = math.max(0, math.min(15, chunkY))
    if localX < 0 then localX = 0 elseif localX > 1 then localX = 1 end
    if localY < 0 then localY = 0 elseif localY > 1 then localY = 1 end

    local key = string.format("%d:%d:%d:%d", tileX, tileY, chunkX, chunkY)
    return {
      mode = mode,
      tileX = tileX,
      tileY = tileY,
      chunkX = chunkX,
      chunkY = chunkY,
      localX = localX,
      localY = localY,
      key = key,
      chunk = index[key],
    }
  end

  local lookup = nil
  if preferredMode == "xy" then
    lookup = buildLookup(posX, posY, "xy")
  elseif preferredMode == "yx" then
    lookup = buildLookup(posY, posX, "yx")
  else
    lookup = buildLookup(posX, posY, "xy")
    if not lookup.chunk then
      local swapped = buildLookup(posY, posX, "yx")
      if swapped.chunk then
        lookup = swapped
      end
    end
  end

  local chunk = lookup.chunk
  local markerDensity = TA_BuildTerrainMarkerDensity(data, index)
  local selected = chunk and { lookup.tileX, lookup.tileY, lookup.chunkX, lookup.chunkY } or nil
  local mapBounds = (type(data.mapBounds) == "table") and data.mapBounds or nil

  local inCompiledTileBounds = nil
  if mapBounds and type(mapBounds.tileMin) == "table" and type(mapBounds.tileMax) == "table" then
    local minTx = tonumber(mapBounds.tileMin[1])
    local minTy = tonumber(mapBounds.tileMin[2])
    local maxTx = tonumber(mapBounds.tileMax[1])
    local maxTy = tonumber(mapBounds.tileMax[2])
    if minTx and minTy and maxTx and maxTy then
      inCompiledTileBounds = (lookup.tileX >= minTx and lookup.tileX <= maxTx and lookup.tileY >= minTy and lookup.tileY <= maxTy)
    end
  end

  if not chunk or not selected then
    return {
      loaded = true,
      chunk = nil,
      tileX = lookup.tileX,
      tileY = lookup.tileY,
      chunkX = lookup.chunkX,
      chunkY = lookup.chunkY,
      lookupMode = lookup.mode,
      inCompiledTileBounds = inCompiledTileBounds,
      mapBounds = mapBounds,
      resolved = false,
    }
  end

  local sampledHeight = TA_TerrainSampleFromGrid(chunk.heights, lookup.localX, lookup.localY)
  local sampledSlope = TA_TerrainSampleFromGrid(chunk.slope, lookup.localX, lookup.localY)

  return {
    loaded = true,
    chunk = chunk,
    tileX = selected[1],
    tileY = selected[2],
    chunkX = selected[3],
    chunkY = selected[4],
    lookupMode = lookup.mode,
    inCompiledTileBounds = inCompiledTileBounds,
    mapBounds = mapBounds,
    resolved = true,
    hasWater = chunk.hasWater and true or false,
    obstacleCount = markerDensity[lookup.key] or 0,
    texture = chunk.texture,
    avgHeight = sampledHeight or TA_TerrainStatsFromGrid(chunk.heights),
    avgSlope = sampledSlope or TA_TerrainStatsFromGrid(chunk.slope),
    maxSlope = TA_TerrainMaxFromGrid(chunk.slope),
  }

end

function TA_GetTerrainContextAtMapPos(mapX, mapY)
  -- mapX/mapY are zone-relative fractions; ignore them.
  -- Use UnitPosition for raw world coordinates to derive ADT tile indices.
  -- WoW ADT grid: 64x64 tiles, each 533.333... yards.
  -- tileX increases west→east (same direction as WoW posX, which increases east).
  -- tileY increases north→south (opposite to WoW posY, which increases north).
  local posX, posY = UnitPosition("player")
  if type(posX) ~= "number" or type(posY) ~= "number" then
    return nil
  end
  return TA_GetTerrainContextAtWorldPos(posX, posY)
end

function TA_GetTerrainGlyph(terrain, referenceHeight, referenceSlope, forwardBias, distCells, localHeightBaseline, localSlopeBaseline, localSlopeRelief, localHeightRelief)
  if type(terrain) ~= "table" or not terrain.resolved then
    return "."
  end

  -- Focus: detect deadly drop hazards only, ignore rolling hills.
  -- Show: water, deadly drops (V), obstacles, else ignore.

  if terrain.hasWater then
    return "~"
  end

  local obstacleCount = tonumber(terrain.obstacleCount) or 0
  if obstacleCount >= 4 then return "#" end
  if obstacleCount >= 2 then return "X" end
  if obstacleCount >= 1 then return "+" end

  -- Check for deadly drop differences only.
  -- Anchor to player reference height for stability while moving.
  local height = tonumber(terrain.avgHeight)
  local baselineHeight = tonumber(referenceHeight)
  if baselineHeight == nil then baselineHeight = tonumber(localHeightBaseline) end
  if baselineHeight and height then
    local deltaHeight = height - baselineHeight
    local dist = tonumber(distCells) or 1
    local forward = tonumber(forwardBias) or 0
    local localDeltaHeight = nil
    local localRelief = tonumber(localHeightRelief) or 0
    if localHeightBaseline ~= nil then
      local localBaseline = tonumber(localHeightBaseline)
      if localBaseline ~= nil then
        localDeltaHeight = height - localBaseline
      end
    end
    if dist < 1 then dist = 1 end
    local gradePerCell = deltaHeight / dist

    -- Safety filter: ignore impossible near-field deltas caused by bad chunk
    -- samples or coordinate mismatches.
    if math.abs(deltaHeight) > 300 then
      return "."
    end

    -- Fall-risk focus: only render cliffs that are close enough to matter.
    if dist > 5 then
      return "."
    end

    -- Suppress side/back jitter; prioritize hazards in travel/front arc.
    if forward < 0 then
      return "."
    end

    -- Deadly drop: strict requirements to avoid false positives on fields.
    local localDropPass = true
    if localDeltaHeight ~= nil then
      localDropPass = localDeltaHeight <= -4
    end
    if deltaHeight <= -10 and gradePerCell <= -1.6 and localDropPass and localRelief >= 2.5 then
      return "V"
    end
  end

  -- Ignore everything else (rolling hills, small slopes, textures, etc)
  return "."

end

local function GetEntitySymbol(unit)
  if unit.class then
    local classLower = unit.class:sub(1, 1):lower()
    return classLower
  end
  return "?"
end

function TA_ClassifyStandingTerrain(terrain, localSlopeBaseline)
  if type(terrain) ~= "table" or not terrain.resolved then
    return nil, nil
  end

  if terrain.hasWater then
    return "Ground: waterline", "WATER"
  end

  local slope = tonumber(terrain.avgSlope) or 0
  local maxSlope = tonumber(terrain.maxSlope) or slope
  local baseline = tonumber(localSlopeBaseline)
  local slopeDelta = baseline and (slope - baseline) or 0

  if maxSlope >= 18 or (slope >= 13 and slopeDelta >= 1.8) then
    return "Ground: mountain face", "MTN"
  end
  if maxSlope >= 15 or (slope >= 10 and slopeDelta >= 1.1) then
    return "Ground: steep hillside", "STEEP"
  end
  if maxSlope >= 11 or slope >= 7 then
    return "Ground: rolling hills", "HILL"
  end
  return "Ground: mostly flat", "FLAT"
end

function TA_Clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

function TA_ColorLerp(a, b, t)
  local s = 1 - t
  return (a[1] * s) + (b[1] * t), (a[2] * s) + (b[2] * t), (a[3] * s) + (b[3] * t)
end

function TA_HeatToRGB(heat)
  local t = TA_Clamp01(tonumber(heat) or 0)
  local stops = {
    { 0.00, { 0.22, 0.52, 1.00 } }, -- blue
    { 0.33, { 0.20, 0.90, 0.42 } }, -- green
    { 0.66, { 0.98, 0.83, 0.20 } }, -- yellow
    { 1.00, { 1.00, 0.33, 0.18 } }, -- red
  }

  for i = 1, #stops - 1 do
    local lo = stops[i]
    local hi = stops[i + 1]
    if t <= hi[1] then
      local span = hi[1] - lo[1]
      local localT = span > 0 and ((t - lo[1]) / span) or 0
      return TA_ColorLerp(lo[2], hi[2], localT)
    end
  end

  local last = stops[#stops][2]
  return last[1], last[2], last[3]
end

function TA_ColorizeCellByHeat(cell, heat)
  if type(cell) ~= "string" or cell == "" then
    return cell
  end
  local r, g, b = TA_HeatToRGB(heat)
  return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), cell)
end

function TA_TerrainHeatFromContext(terrain, slopeRelief, heightRelief)
  if type(terrain) ~= "table" or not terrain.resolved then
    return 0
  end
  if terrain.hasWater then
    return 0.08
  end

  local avgSlope = tonumber(terrain.avgSlope) or 0
  local maxSlope = tonumber(terrain.maxSlope) or avgSlope
  local reliefSlope = tonumber(slopeRelief) or 0
  local reliefHeight = tonumber(heightRelief) or 0

  -- Use average slope + local relief as primary signals. Max-slope spikes are
  -- only used as excess over average so one outlier does not saturate all cells.
  local avgNorm = TA_Clamp01(avgSlope / 22.0)
  local spikeExcess = math.max(0, maxSlope - avgSlope)
  local spikeNorm = TA_Clamp01(spikeExcess / 14.0)
  local reliefNorm = TA_Clamp01(reliefSlope / 10.0)
  local verticalNorm = TA_Clamp01(reliefHeight / 20.0)

  local raw = (avgNorm * 0.50) + (spikeNorm * 0.20) + (reliefNorm * 0.20) + (verticalNorm * 0.10)
  -- Slightly compress the top-end so hills and mid-slopes retain distinct hues.
  local heat = raw ^ 1.2
  return TA_Clamp01(heat)
end

