-- Modules/Awareness.lua
-- Nearby-unit + target awareness for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * BuildNearbyLine - format hostile/neutral/friendly nearby lists.
--   * GetNearbyUnitsSummary - poll C_NamePlate + UnitPosition for visible units.
--   * CheckAwareness - emit narration when nearby/target state changes.
--   * TA_RequestAwarenessRefresh - throttled awareness refresh entry point
--     called by combat-log, target-changed and ticker handlers.
--
-- Must load AFTER textadventurer.lua and AFTER Modules/DFMode.lua (depends on
-- AddLine, TA_CompassDir, TA_TryInteractDistance, TA_RelativeBearing,
-- TA_NarrateBearing from main file, and TA_GetEffectiveDFYardsPerCell from
-- DFMode). See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 8962-9078 ----
local function BuildNearbyLine(kind, units)
  if #units == 0 then return nil end
  local parts = {}
  local yardsPerCell = TA_GetEffectiveDFYardsPerCell()
  for _, u in ipairs(units) do
    local label = u.isTarget and ("[T]" .. u.name) or u.name
    if u.dist then
      local cells = math.max(1, math.floor(u.dist / yardsPerCell + 0.5))
      local cellWord = cells == 1 and "cell" or "cells"
      local approxMark = u.distApprox and "~" or ""
      if u.dir then
        parts[#parts + 1] = label .. " (" .. approxMark .. cells .. " " .. cellWord .. " " .. u.dir .. ")"
      else
        parts[#parts + 1] = label .. " (" .. approxMark .. cells .. " " .. cellWord .. " away)"
      end
    else
      parts[#parts + 1] = label
    end
  end
  return string.format("%s nearby: %s", kind, table.concat(parts, ", "))
end

local function GetNearbyUnitsSummary()
  local seen = {}
  local hostiles, neutrals, friendlies = {}, {}, {}
  local nameplates = C_NamePlate.GetNamePlates()
  local playerX, playerY = UnitPosition("player")
  for _, frame in ipairs(nameplates) do
    local unit = frame.namePlateUnitToken
    if unit and UnitExists(unit) then
      local name = UnitName(unit)
      if name and not seen[name] then
        seen[name] = true
        local dist, dir, distApprox = nil, nil, false
        if playerX and playerY then
          local ux, uy = UnitPosition(unit)
          if ux and uy then
            local dx, dy = ux - playerX, uy - playerY
            dist = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
            dir = TA_CompassDir(dx, dy)
          end
        end
        -- Fallback: CheckInteractDistance gives bracketed range when UnitPosition is unavailable
        if not dist and CheckInteractDistance then
          if TA_TryInteractDistance(unit, 1) then dist = 3      -- ~0 cells (right next to you)
          elseif TA_TryInteractDistance(unit, 2) then dist = 9  -- ~1-2 cells
          elseif TA_TryInteractDistance(unit, 3) then dist = 24 -- ~4 cells
          else dist = 48 end                                    -- ~8 cells
          distApprox = true
        end
        local entry = { name = name, dist = dist, dir = dir, distApprox = distApprox, isTarget = UnitIsUnit(unit, "target") }
        if UnitCanAttack("player", unit) then
          table.insert(hostiles, entry)
        else
          local reaction = UnitReaction(unit, "player") or 4
          if reaction >= 5 then table.insert(friendlies, entry) else table.insert(neutrals, entry) end
        end
      end
    end
  end
  local function sortByName(a, b) return a.name < b.name end
  table.sort(hostiles, sortByName)
  table.sort(neutrals, sortByName)
  table.sort(friendlies, sortByName)
  local function nameList(t) local n = {} for _, u in ipairs(t) do n[#n + 1] = u.name end return n end
  return {
    hostile = BuildNearbyLine("Hostile", hostiles),
    neutral = BuildNearbyLine("Neutral", neutrals),
    friendly = BuildNearbyLine("Friendly", friendlies),
    signature = table.concat({ table.concat(nameList(hostiles), ","), table.concat(nameList(neutrals), ","), table.concat(nameList(friendlies), ",") }, "|"),
  }
end

local function CheckAwareness()
  local info = GetNearbyUnitsSummary()
  local signature = info.signature
  if signature == "||" then signature = "none" end
  if signature ~= TA.lastNearbySignature then
    if signature == "none" then
      AddLine("nearby", "You sense no visible creatures nearby.")
    else
      if info.hostile then AddLine("hostile", info.hostile) end
      if info.neutral then AddLine("neutral", info.neutral) end
      if info.friendly then AddLine("friendly", info.friendly) end
    end
    TA.lastNearbySignature = signature
  end
  -- Bearing narration: only emit when the target changes or its
  -- distance-band/clock-face moves, to avoid per-tick spam.
  if UnitExists("target") and not UnitIsDead("target") then
    local b = TA_RelativeBearing("target")
    if b then
      local guid = UnitGUID("target") or "?"
      local distBucket = math.floor((b.distance or 0) / 5)
      local clockKey = b.clock or "rc"
      local bucket = guid .. ":" .. tostring(clockKey) .. ":" .. distBucket
      if bucket ~= TA.lastTargetBearingBucket then
        TA_NarrateBearing("target")
        TA.lastTargetBearingBucket = bucket
      end
    end
  else
    TA.lastTargetBearingBucket = nil
  end
end

function TA_RequestAwarenessRefresh(force)
  TA.awarenessDirty = true
  local now = GetTime()
  local minInterval = tonumber(TA.awarenessEventMinInterval) or 0.20
  if not force and (now - (TA.awarenessLastRunAt or 0)) < minInterval then
    return
  end
  CheckAwareness()
  TA.awarenessLastRunAt = now
  TA.awarenessDirty = false
end

