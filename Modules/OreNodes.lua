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

function TA_GetOreNodeGlyph(nodeType)
  local color = ORE_NODE_COLORS[nodeType]
  if color then
    return color .. ORE_GLYPH .. "|r"
  end
  return ORE_GLYPH
end

local function recordOreNode(nodeType)
  local wx, wy = UnitPosition("player")
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

  -- Skip if same node type already recorded within DEDUP_YARDS.
  for _, node in ipairs(byMap) do
    if node.n == nodeType then
      local dx = node.wx - wx
      local dy = node.wy - wy
      if (dx * dx + dy * dy) <= (DEDUP_YARDS * DEDUP_YARDS) then
        return
      end
    end
  end

  if #byMap >= MAX_NODES_PER_MAP then
    table.remove(byMap, 1)
  end

  table.insert(byMap, { n = nodeType, wx = wx, wy = wy })
  TA.oreNodesVersion = (TA.oreNodesVersion or 0) + 1
end

-- Hook GameTooltip to detect when the player mouses over an ore node.
GameTooltip:HookScript("OnShow", function()
  local textFrame = _G["GameTooltipTextLeft1"]
  local text = textFrame and textFrame:GetText()
  if not text then return end
  if ORE_NODE_COLORS[text] then
    recordOreNode(text)
  end
end)

-- ---- Command handler ----

function TA_OreNodeCommand(args)
  local cmd = (args or ""):match("^%s*(%S*)%s*$") or ""
  cmd = cmd:lower()

  if cmd == "clear" then
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
    AddLine("system", "Usage: ore [list|clear|clearall]")
    AddLine("system", "  ore list    - show recorded nodes on current map")
    AddLine("system", "  ore clear   - clear nodes for current map")
    AddLine("system", "  ore clearall - clear all saved nodes")
  end
end

-- Register commands via the standard TA handler tables.
function TA_RegisterOreNodeCommandHandlers(exactHandlers, addPattern)
  exactHandlers["ore"] = function() TA_OreNodeCommand("") end
  addPattern("^ore%s+(.+)$", function(args) TA_OreNodeCommand(args) end)
end
