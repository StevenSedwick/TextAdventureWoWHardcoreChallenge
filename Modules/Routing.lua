-- Modules/Routing.lua
-- Named-route recording, display, following, and cell-change callback.
--
-- Extracted from textadventurer.lua. Owns:
--   * TA_RouteDirection        -- (dx,dy) -> compass string
--   * TA_RouteGetTable         -- returns SavedVariables route table
--   * TA_RouteStart            -- begin recording a named route
--   * TA_RouteStop             -- stop recording
--   * TA_RouteList             -- list all saved routes
--   * TA_RouteShow             -- print waypoints of a named route
--   * TA_RouteClear            -- delete a named route
--   * TA_RouteFollow           -- begin following a named route
--   * TA_RouteFollowOff        -- stop following
--   * TA_RouteOnCellChanged    -- per-cell callback (called from the
--                                 main ticker / cell-change detector)
--
-- All were already true globals. No _G mirror lines to remove.
--
-- Depends on shared globals: AddLine, CellKey, GetPlayerMapCell,
-- TA (for routeRecordingName, routeFollowName, routeFollowIndex,
-- routeLastGuidedCell), TextAdventurerDB.
--
-- NavigationCommands.lua calls TA_RouteStop, TA_RouteList,
-- TA_RouteFollowOff, TA_RouteStart, TA_RouteShow, TA_RouteClear,
-- TA_RouteFollow directly.
--
-- Loads after textadventurer.lua and before Modules/NavigationCommands.lua.
-- .toc slot: between Modules/QuestRouter.lua and Modules/Awareness.lua
-- (or anywhere before NavigationCommands.lua).

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 2950-3192 ----
function TA_RouteDirection(dx, dy)
  if dx == 0 and dy == 0 then return "here" end
  local horiz = ""
  local vert = ""
  -- Map-space Y increases downward on the map: +dy is south, -dy is north.
  if dy < 0 then vert = "north" elseif dy > 0 then vert = "south" end
  if dx > 0 then horiz = "east" elseif dx < 0 then horiz = "west" end
  if vert ~= "" and horiz ~= "" then
    return vert .. "-" .. horiz
  end
  return vert ~= "" and vert or horiz
end

function TA_RouteGetTable()
  TextAdventurerDB = TextAdventurerDB or {}
  TextAdventurerDB.routes = TextAdventurerDB.routes or {}
  return TextAdventurerDB.routes
end

function TA_RouteStart(name)
  local routeName = (name or ""):match("^%s*(.-)%s*$")
  if routeName == "" then
    AddLine("system", "Usage: route start <name>")
    return
  end
  local mapID, cellX, cellY = GetPlayerMapCell()
  if not mapID then
    AddLine("system", "Could not determine current cell for route recording.")
    return
  end
  local routeKey = routeName:lower()
  local routes = TA_RouteGetTable()
  routes[routeKey] = {
    name = routeName,
    mapID = mapID,
    cells = { CellKey(cellX, cellY) },
    createdAt = time(),
  }
  TA.routeRecordingName = routeKey
  TA.routeFollowName = nil
  TA.routeFollowIndex = nil
  TA.routeLastGuidedCell = nil
  AddLine("place", string.format("Route recording started: %s", routeName))
end

function TA_RouteStop()
  if not TA.routeRecordingName then
    AddLine("system", "No active route recording.")
    return
  end
  local routes = TA_RouteGetTable()
  local route = routes[TA.routeRecordingName]
  local name = (route and route.name) or TA.routeRecordingName
  local steps = route and route.cells and #route.cells or 0
  TA.routeRecordingName = nil
  AddLine("place", string.format("Route recording stopped: %s (%d cell(s)).", name, steps))
end

function TA_RouteList()
  local routes = TA_RouteGetTable()
  local count = 0
  for _ in pairs(routes) do count = count + 1 end
  if count == 0 then
    AddLine("system", "No saved routes yet.")
    return
  end
  AddLine("place", string.format("Saved routes (%d):", count))
  for key, route in pairs(routes) do
    local tag = ""
    if TA.routeRecordingName == key then tag = " [recording]" end
    if TA.routeFollowName == key then tag = tag .. " [following]" end
    AddLine("place", string.format("  %s - %d cells%s", route.name or key, route.cells and #route.cells or 0, tag))
  end
end

function TA_RouteShow(name)
  local routeKey = (name or ""):match("^%s*(.-)%s*$"):lower()
  if routeKey == "" then
    AddLine("system", "Usage: route show <name>")
    return
  end
  local routes = TA_RouteGetTable()
  local route = routes[routeKey]
  if not route then
    AddLine("system", string.format("No route named '%s'.", name or ""))
    return
  end
  local total = route.cells and #route.cells or 0
  AddLine("place", string.format("Route %s: %d cell(s).", route.name or routeKey, total))
  if total <= 1 then
    AddLine("place", "  Route has only a start point.")
    return
  end
  local shown = 0
  local maxShown = 10
  for i = 1, total - 1 do
    local x1, y1 = route.cells[i]:match("^(-?%d+),(-?%d+)$")
    local x2, y2 = route.cells[i + 1]:match("^(-?%d+),(-?%d+)$")
    if x1 and y1 and x2 and y2 then
      local dir = TA_RouteDirection(tonumber(x2) - tonumber(x1), tonumber(y2) - tonumber(y1))
      AddLine("place", string.format("  %d -> %d: %s", i, i + 1, dir))
      shown = shown + 1
      if shown >= maxShown then
        AddLine("place", string.format("  ... (%d more segment(s))", (total - 1) - shown))
        break
      end
    end
  end
end

function TA_RouteClear(name)
  local routeKey = (name or ""):match("^%s*(.-)%s*$"):lower()
  if routeKey == "" then
    AddLine("system", "Usage: route clear <name>")
    return
  end
  local routes = TA_RouteGetTable()
  if not routes[routeKey] then
    AddLine("system", string.format("No route named '%s'.", name or ""))
    return
  end
  local routeName = routes[routeKey].name or routeKey
  routes[routeKey] = nil
  if TA.routeRecordingName == routeKey then
    TA.routeRecordingName = nil
  end
  if TA.routeFollowName == routeKey then
    TA.routeFollowName = nil
    TA.routeFollowIndex = nil
    TA.routeLastGuidedCell = nil
  end
  AddLine("place", string.format("Route cleared: %s", routeName))
end

function TA_RouteFollow(name)
  local routeKey = (name or ""):match("^%s*(.-)%s*$"):lower()
  if routeKey == "" then
    AddLine("system", "Usage: route follow <name>")
    return
  end
  local routes = TA_RouteGetTable()
  local route = routes[routeKey]
  if not route then
    AddLine("system", string.format("No route named '%s'.", name or ""))
    return
  end
  TA.routeFollowName = routeKey
  TA.routeFollowIndex = 1
  TA.routeLastGuidedCell = nil
  AddLine("place", string.format("Now following route: %s", route.name or routeKey))
end

function TA_RouteFollowOff()
  if not TA.routeFollowName then
    AddLine("system", "No route is currently being followed.")
    return
  end
  local routeKey = TA.routeFollowName
  local route = TA_RouteGetTable()[routeKey]
  TA.routeFollowName = nil
  TA.routeFollowIndex = nil
  TA.routeLastGuidedCell = nil
  AddLine("place", string.format("Stopped following route: %s", (route and route.name) or routeKey))
end

function TA_RouteOnCellChanged(mapID, cellX, cellY)
  local routes = TA_RouteGetTable()
  local currentCell = CellKey(cellX, cellY)

  if TA.routeRecordingName then
    local route = routes[TA.routeRecordingName]
    if route and route.mapID == mapID and route.cells then
      local last = route.cells[#route.cells]
      if last ~= currentCell then
        table.insert(route.cells, currentCell)
      end
    end
  end

  if not TA.routeFollowName then
    return
  end

  local route = routes[TA.routeFollowName]
  if not route or not route.cells or #route.cells == 0 then
    TA.routeFollowName = nil
    TA.routeFollowIndex = nil
    TA.routeLastGuidedCell = nil
    return
  end
  if route.mapID and route.mapID ~= mapID then
    if TA.routeLastGuidedCell ~= "map-mismatch" then
      AddLine("system", "Route follow paused: you are on a different map.")
      TA.routeLastGuidedCell = "map-mismatch"
    end
    return
  end

  if TA.routeLastGuidedCell == currentCell then
    return
  end
  TA.routeLastGuidedCell = currentCell

  local total = #route.cells
  local idx = nil
  for i = 1, total do
    if route.cells[i] == currentCell then
      idx = i
      break
    end
  end

  if idx then
    TA.routeFollowIndex = idx
    if idx >= total then
      AddLine("place", string.format("Route %s complete.", route.name or TA.routeFollowName))
      TA.routeFollowName = nil
      TA.routeFollowIndex = nil
      return
    end
    local nx, ny = route.cells[idx + 1]:match("^(-?%d+),(-?%d+)$")
    if nx and ny then
      local dir = TA_RouteDirection(tonumber(nx) - cellX, tonumber(ny) - cellY)
      AddLine("place", string.format("Route %s [%d/%d]: go %s.", route.name or TA.routeFollowName, idx, total, dir))
    end
    return
  end

  local bestI, bestDist = nil, nil
  for i = 1, total do
    local rx, ry = route.cells[i]:match("^(-?%d+),(-?%d+)$")
    if rx and ry then
      local dist = math.abs(tonumber(rx) - cellX) + math.abs(tonumber(ry) - cellY)
      if not bestDist or dist < bestDist then
        bestDist = dist
        bestI = i
      end
    end
  end
  if bestI and bestDist ~= nil then
    AddLine("place", string.format("Off route '%s'. Nearest step: %d (about %d cell(s) away).", route.name or TA.routeFollowName, bestI, bestDist))
  end
end

