-- Modules/TargetPositioning.lua
-- Cardinal-direction helpers, unit-cell-distance estimation, target
-- reporting, player/target facing analysis, mark-A/B spacing, and
-- related geometric utilities.
--
-- Extracted from textadventurer.lua. Owns:
--   * TA_CardinalFromEastNorth   -- cardinal from (east, north) delta
--   * TA_GetUnitCellsAway        -- cells + direction to an arbitrary unit
--   * CheckTarget                -- UNIT_TARGET dispatcher helper
--   * FacingToCardinal           -- radians -> compass string
--   * SpeedCategory              -- speed -> "still"/"walking"/"running"/"fast"
--   * GetFacingDegrees           -- player facing in degrees
--   * GetTargetFacingDegrees     -- target facing in degrees
--   * AngleDiff                  -- absolute angle difference (0-180)
--   * EstimateSpacing            -- geometry: angle -> estimated yards
--   * DescribeSpacing            -- text + risk label for a spacing estimate
--   * ReportTargetPositioning    -- "behind" / "backstab" command handler
--   * MarkFacingA / MarkFacingB  -- "marka" / "markb" command handlers
--   * ReportSpacingEstimate      -- "spacing" command handler
--
-- All were already true globals (no local function prefix). The _G.X = X
-- mirror lines for ReportSpacingEstimate, ReportTargetPositioning,
-- MarkFacingA, and MarkFacingB are removed from textadventurer.lua.
-- SPACING_ASSUMED_RANGE (previously a file-local at line 206 of the main
-- file, only referenced within this range) is relocated here.
--
-- Depends on shared globals: AddLine, TA (for activeCasts, markA/B,
-- lastTargetGUID/Name/HealthBucket), TA_TryInteractDistance,
-- TA_GetEffectiveDFYardsPerCell, ReportTargetCondition (CombatNarration).
--
-- Loads after textadventurer.lua and Modules/CombatNarration.lua and
-- before Modules/Commands.lua.
-- .toc slot: between Modules/CombatNarration.lua and Modules/CellMath.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

local SPACING_ASSUMED_RANGE = 25   -- assumed melee/near-range distance in yards

-- ---- moved from textadventurer.lua lines 1267-1527 ----

function TA_CardinalFromEastNorth(east, north)
  if not east or not north then return nil end
  local eps = 0.01
  local hasEast = math.abs(east) > eps
  local hasNorth = math.abs(north) > eps
  if not hasEast and not hasNorth then
    return "here"
  end
  if hasNorth and hasEast then
    if north > 0 then
      return east > 0 and "northeast" or "northwest"
    end
    return east > 0 and "southeast" or "southwest"
  end
  if hasNorth then
    return north > 0 and "north" or "south"
  end
  return east > 0 and "east" or "west"
end

function TA_GetUnitCellsAway(unit)
  if not unit or not UnitExists(unit) then
    return nil, false
  end

  local yardsPerCell = TA_GetEffectiveDFYardsPerCell and TA_GetEffectiveDFYardsPerCell() or 3
  if yardsPerCell <= 0 then yardsPerCell = 3 end

  local px, py = UnitPosition("player")
  local ux, uy = UnitPosition(unit)
  if px and py and ux and uy then
    local dx = ux - px
    local dy = uy - py
    local east = dx
    local north = dy
    local distYards = math.sqrt((east * east) + (north * north))
    local cells = math.max(1, math.floor((distYards / yardsPerCell) + 0.5))
    local direction = TA_CardinalFromEastNorth(east, north)
    return cells, false, direction
  end

  if CheckInteractDistance then
    local approxYards = nil
    if TA_TryInteractDistance and TA_TryInteractDistance(unit, 1) then approxYards = 3
    elseif TA_TryInteractDistance and TA_TryInteractDistance(unit, 2) then approxYards = 9
    elseif TA_TryInteractDistance and TA_TryInteractDistance(unit, 3) then approxYards = 24
    elseif TA_TryInteractDistance and TA_TryInteractDistance(unit, 4) then approxYards = 30
    end
    if approxYards then
      local cells = math.max(1, math.floor((approxYards / yardsPerCell) + 0.5))
      return cells, true, nil
    end
  end

  return nil, false, nil
end

function CheckTarget()
  if not UnitExists("target") then
    if TA.lastTargetGUID then
      AddLine("target", "You clear your target.")
      TA.lastTargetGUID = nil
      TA.lastTargetName = nil
      TA.lastTargetHealthBucket = nil
    end
    return
  end
  local guid = UnitGUID("target")
  local name = UnitName("target") or "Unknown"
  local level = UnitLevel("target")
  local dead = UnitIsDeadOrGhost("target")
  local reaction = UnitCanAttack("player", "target") and "hostile" or "neutral/friendly"
  if guid ~= TA.lastTargetGUID then
    if dead then
      AddLine("corpse", string.format("You target the corpse of %s.", name))
      TA.lastTargetHealthBucket = nil
    else
      local cellsAway, isApprox, direction = TA_GetUnitCellsAway("target")
      if cellsAway then
        local approxPrefix = isApprox and "~" or ""
        local cellWord = cellsAway == 1 and "cell" or "cells"
        local where = direction and direction ~= "here" and (" " .. direction) or ""
        AddLine("target", string.format("You target %s (level %s, %s, %s%d %s%s away).", name, level > 0 and level or "??", reaction, approxPrefix, cellsAway, cellWord, where))
      else
        AddLine("target", string.format("You target %s (level %s, %s).", name, level > 0 and level or "??", reaction))
      end
      TA.lastTargetHealthBucket = nil
      ReportTargetCondition(true)
    end
    TA.lastTargetGUID = guid
    TA.lastTargetName = name
  end
end

function FacingToCardinal(facing)
  if not facing then return nil end
  local deg = math.deg(facing) % 360
  -- WoW Classic facing uses 0°=north, 90°=west, 180°=south, 270°=east.
  if deg < 22.5 then return "north" end
  if deg < 67.5 then return "northwest" end
  if deg < 112.5 then return "west" end
  if deg < 157.5 then return "southwest" end
  if deg < 202.5 then return "south" end
  if deg < 247.5 then return "southeast" end
  if deg < 292.5 then return "east" end
  if deg < 337.5 then return "northeast" end
  return "north"
end

function SpeedCategory(speed)
  speed = speed or 0
  if speed <= 0 then return "still" end
  if speed < 7.5 then return "walking" end
  if speed < 13.5 then return "running" end
  return "fast"
end

function GetFacingDegrees()
  local f = GetPlayerFacing()
  if not f then return nil end
  return math.deg(f) % 360
end

function GetTargetFacingDegrees()
  if not UnitExists("target") or UnitIsDeadOrGhost("target") then return nil end
  if not UnitFacing then return nil end
  local f = UnitFacing("target")
  if not f then return nil end
  return math.deg(f) % 360
end

function AngleDiff(a, b)
  local diff = math.abs(a - b)
  if diff > 180 then diff = 360 - diff end
  return diff
end

function EstimateSpacing(angleDeg)
  local radians = math.rad(angleDeg / 2)
  return 2 * SPACING_ASSUMED_RANGE * math.sin(radians)
end

function DescribeSpacing(angle, distance)
  if angle < 15 or distance < 7 then
    return "tightly clustered", "high"
  elseif angle < 30 or distance < 13 then
    return "moderately separated", "medium"
  else
    return "widely separated", "lower"
  end
end

function ReportTargetPositioning()
  if not UnitExists("target") then
    AddLine("system", "No target selected.")
    return
  end
  if UnitIsDeadOrGhost("target") then
    AddLine("system", "Target is dead.")
    return
  end

  local playerFacing = GetFacingDegrees()
  if not playerFacing then
    AddLine("system", "Could not read your facing.")
    return
  end

  local targetFacing = GetTargetFacingDegrees()
  local targetFacingPlayer = nil
  local playerFacingTarget = nil
  if UnitIsFacing then
    targetFacingPlayer = UnitIsFacing("target", "player")
    playerFacingTarget = UnitIsFacing("player", "target")
  end

  if not targetFacing and targetFacingPlayer == nil then
    if UnitIsFacing then
      AddLine("system", "Could not determine target facing from this client.")
    else
      AddLine("system", "Target-facing information is not available in this client, so backstab cannot be determined.")
    end
    return
  end

  if targetFacing then
    local relative = AngleDiff(playerFacing, targetFacing)
    local facingText
    if relative < 30 then
      facingText = "Target is facing you."
    elseif relative < 150 then
      facingText = "Target is facing sideways to you."
    else
      facingText = "Target is facing away from you."
    end
    AddLine("system", string.format("%s facing: %.0fÂ°, you facing: %.0fÂ°, relative heading: %.0fÂ°.", UnitName("target") or "Target", targetFacing, playerFacing, relative))
    AddLine("system", facingText)
    if relative > 150 then
      AddLine("system", "Rear attack likely possible if you are in melee range.")
    else
      AddLine("system", "You are not behind the target.")
    end
  else
    -- Use facing checks when exact target facing angle is unavailable.
    local facingText
    if targetFacingPlayer and playerFacingTarget then
      facingText = "You and the target are facing each other. You are not behind them."
    elseif targetFacingPlayer and not playerFacingTarget then
      facingText = "The target is facing you, but you are not facing them directly."
    elseif not targetFacingPlayer and playerFacingTarget then
      facingText = "The target is not facing you and you are facing them. You are likely behind them."
    else
      facingText = "Neither of you is directly facing the other. You may be to the side or behind the target."
    end
    AddLine("system", string.format("You facing target: %s, target facing you: %s.", tostring(playerFacingTarget), tostring(targetFacingPlayer)))
    AddLine("system", facingText)
    if not targetFacingPlayer and playerFacingTarget then
      AddLine("system", "Rear attack likely possible if you are in melee range.")
    else
      AddLine("system", "You are not clearly behind the target.")
    end
  end
end

function MarkFacingA()
  local facing = GetFacingDegrees()
  if not facing then AddLine("system", "Could not read facing."); return end
  TA.markA = {
    facing = facing,
    target = UnitName("target") or "unknown target",
    reaction = UnitCanAttack("player", "target") and "hostile" or "non-hostile",
  }
  AddLine("system", string.format("Marked A at %.1fÂ° toward %s.", facing, TA.markA.target))
end

function MarkFacingB()
  local facing = GetFacingDegrees()
  if not facing then AddLine("system", "Could not read facing."); return end
  TA.markB = {
    facing = facing,
    target = UnitName("target") or "unknown target",
    reaction = UnitCanAttack("player", "target") and "hostile" or "non-hostile",
  }
  AddLine("system", string.format("Marked B at %.1fÂ° toward %s.", facing, TA.markB.target))
end

function ReportSpacingEstimate()
  if not TA.markA or not TA.markB then
    AddLine("system", "You must mark both directions first with marka and markb.")
    return
  end
  local angle = AngleDiff(TA.markA.facing, TA.markB.facing)
  local dist = EstimateSpacing(angle)
  local desc, risk = DescribeSpacing(angle, dist)
  AddLine("system", string.format("Angle between marks: %.1fÂ°", angle))
  AddLine("system", string.format("Estimated spacing at %.0f-yard range: %.1f yards", SPACING_ASSUMED_RANGE, dist))
  AddLine("system", string.format("%s and %s appear %s. Pull risk is %s.", TA.markA.target, TA.markB.target, desc, risk))
  AddLine("system", "This is a geometric estimate, not a guaranteed safe-pull measurement.")
end


