-- Modules/MovementAndBearing.lua
-- Fall heuristic, wall-block heuristic, relative-bearing to unit,
-- bearing narration, movement/facing state reporting, and the 8-dir
-- compass helper.
--
-- Extracted from textadventurer.lua. Owns:
--   * CheckFallState      -- (promoted) falling-start/stop detection
--   * CheckWallHeuristic  -- (promoted) movement-blocked detection
--   * TA_GetRangeCheck    -- (module-local) lazy LibRangeCheck handle
--   * TA_RelativeBearing  -- bearing in degrees to a unit token
--   * TA_NarrateBearing   -- AddLine wrapper for bearing
--   * CheckMovement       -- (promoted) speed/facing change narration
--   * TA_CompassDir       -- (dx,dy) -> 8-dir compass string
--
-- CheckFallState, CheckWallHeuristic, and CheckMovement are promoted
-- from local to global because the movement ticker in textadventurer.lua
-- calls all three directly.
-- TA_GetRangeCheck stays module-local (only used by TA_RelativeBearing).
-- TA_RelativeBearing, TA_NarrateBearing, and TA_CompassDir were already
-- true globals. No _G mirror lines needed to be removed.
--
-- Depends on: AddLine, TA (lastFalling, fallStartTime, blockedStreak,
-- lastWallWarningAt, lastPositionX/Y, lastMoving, lastFacingBucket,
-- lastSpeedCategory, lastNearbyUnits),
-- FacingToCardinal, SpeedCategory (TargetPositioning.lua),
-- ReportLocation (main file), ReportExplorationMemory, ReportPathMemory
-- (SettingsAndPerformance.lua), WALL_WARNING_COOLDOWN (main file local).
--
-- Called from: textadventurer.lua movement ticker (CheckFallState,
-- CheckWallHeuristic, CheckMovement); Modules/Awareness.lua
-- (TA_CompassDir, TA_RelativeBearing, TA_NarrateBearing).
--
-- Loads after textadventurer.lua, TargetPositioning.lua, and
-- SettingsAndPerformance.lua and before Modules/Awareness.lua.
-- .toc slot: between Modules/AsciiMap.lua and Modules/CellMath.lua.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

local WALL_WARNING_COOLDOWN = 2.5

-- ---- moved from textadventurer.lua lines 2952-3166 ----

function CheckFallState()
  local falling = IsFalling()
  if falling and not TA.lastFalling then
    TA.lastFalling = true
    TA.fallStartTime = GetTime()
    AddLine("trace", "WARNING: sudden drop.")
    AddLine("trace", "You are falling.")
  elseif not falling and TA.lastFalling then
    TA.lastFalling = false
    local duration = GetTime() - TA.fallStartTime
    if duration > 1.2 then
      AddLine("trace", "You fall a long distance and hit the ground hard.")
    elseif duration > 0.5 then
      AddLine("trace", "You drop down to a lower level.")
    else
      AddLine("trace", "You regain stable footing.")
    end
  end
end

function CheckWallHeuristic()
  local now = GetTime()
  local mapID, _, _, x, y = GetPlayerMapCell()
  if not mapID or not x or not y then return end
  local speed = GetUnitSpeed("player") or 0
  if speed < 6 or IsFalling() then
    TA.blockedStreak = 0
    return
  end
  if not TA.lastPositionX or not TA.lastPositionY then
    TA.lastPositionX = x
    TA.lastPositionY = y
    return
  end
  local dx = x - TA.lastPositionX
  local dy = y - TA.lastPositionY
  local distSq = dx * dx + dy * dy
  if distSq < 0.00000015 then
    TA.blockedStreak = (TA.blockedStreak or 0) + 1
  else
    TA.blockedStreak = 0
  end
  if TA.blockedStreak >= 8 and (now - (TA.lastWallWarningAt or 0)) > WALL_WARNING_COOLDOWN then
    AddLine("trace", "Your path seems blocked.")
    TA.lastWallWarningAt = now
    TA.blockedStreak = 0
  end
end

-- Positional awareness without protected APIs.
-- UnitPosition only returns coordinates for player/pet/group members in
-- Classic Era; for arbitrary mobs we fall back to the nameplate-derived
-- cache (TA.lastNearbyUnits) populated by CollectNearbyUnitsWithPositions,
-- and finally to LibRangeCheck-3.0 for a range-bucket distance (no bearing).
-- Axis convention follows the rest of the addon (see ~10174):
--   first return  = world NORTH (Y)
--   second return = needs negation for EAST
-- GetPlayerFacing: 0 = north, increases CCW (90deg = west).
local function TA_GetRangeCheck()
  if TA._rangeCheck ~= nil then return TA._rangeCheck or nil end
  local ok, lib = pcall(function() return LibStub and LibStub("LibRangeCheck-3.0", true) end)
  TA._rangeCheck = (ok and lib) or false
  return TA._rangeCheck or nil
end

function TA_RelativeBearing(unitToken)
  if not unitToken then return nil end
  if not UnitExists(unitToken) then return nil end
  local pa, pb = UnitPosition("player")

  local ua, ub
  if pa and pb then
    ua, ub = UnitPosition(unitToken)
    if not (ua and ub) then
      local guid = UnitGUID(unitToken)
      if guid and TA.lastNearbyUnits then
        for _, bucket in pairs(TA.lastNearbyUnits) do
          if type(bucket) == "table" then
            for i = 1, #bucket do
              local u = bucket[i]
              if u and u.guid == guid and u.hasExactPos and u.worldX and u.worldY then
                ua, ub = u.worldX, u.worldY
                break
              end
            end
          end
          if ua and ub then break end
        end
      end
    end
  end

  if pa and pb and ua and ub then
    local dn = ua - pa
    local de = pb - ub
    local dist = math.sqrt(dn * dn + de * de)
    if dist < 0.01 then
      return { distance = 0, bearingRad = 0, bearingDeg = 0, clock = 12, forward = 0, strafe = 0, behind = false, source = "exact" }
    end
    local f = GetPlayerFacing() or 0
    local sinf, cosf = math.sin(f), math.cos(f)
    local forward = de * (-sinf) + dn * cosf
    local strafe  = de *  cosf  + dn * sinf
    local bodyAng = math.atan2(strafe, forward)
    local deg = (bodyAng * 180 / math.pi) % 360
    local clock = math.floor(deg / 30 + 0.5)
    if clock <= 0 or clock >= 12 then clock = 12 end
    return {
      distance   = dist,
      bearingRad = bodyAng,
      bearingDeg = deg,
      clock      = clock,
      forward    = forward,
      strafe     = strafe,
      behind     = forward < 0,
      source     = "exact",
    }
  end

  -- Fall back to LibRangeCheck-3.0 for a distance bucket. No bearing info.
  local rc = TA_GetRangeCheck()
  if rc then
    local minR, maxR = rc:GetRange(unitToken)
    if minR then
      local mid = maxR and ((minR + maxR) * 0.5) or minR
      return {
        distance    = mid,
        distanceMin = minR,
        distanceMax = maxR,
        clock       = nil,
        forward     = nil,
        strafe      = nil,
        behind      = nil,
        source      = "rangecheck",
      }
    end
  end
  return nil
end

-- Narrate the relative bearing to the current target (or any unit) as a
-- terse text-adventure line. Cheap; safe to call from CheckTarget or a
-- throttled awareness tick.
function TA_NarrateBearing(unitToken, label)
  local b = TA_RelativeBearing(unitToken or "target")
  if not b then return end
  local who = label or (UnitName(unitToken or "target")) or "target"
  if b.clock then
    AddLine("trace", string.format(
      "%s is %.1fyd at your %d o'clock (%s%.1fyd fwd, %s%.1fyd %s).",
      who, b.distance, b.clock,
      b.forward >= 0 and "+" or "", b.forward,
      b.strafe  >= 0 and "+" or "", math.abs(b.strafe),
      b.strafe >= 0 and "right" or "left"
    ))
  else
    if b.distanceMax then
      AddLine("trace", string.format("%s is %.0f-%.0fyd away (range-check, no bearing).", who, b.distanceMin or 0, b.distanceMax))
    else
      AddLine("trace", string.format("%s is more than %.0fyd away (range-check, no bearing).", who, b.distanceMin or b.distance or 0))
    end
  end
end

function CheckMovement()
  local speed = GetUnitSpeed("player") or 0
  local movingNow = speed > 0
  local facing = GetPlayerFacing()
  local facingLabel = FacingToCardinal(facing)
  local speedLabel = SpeedCategory(speed)
  if movingNow ~= TA.lastMoving then
    if movingNow then
      AddLine("trace", "TRACE: PLAYER_STARTED_MOVING")
      AddLine("trace", string.format("You begin moving %s.", facingLabel or "forward"))
    else
      AddLine("trace", "TRACE: PLAYER_STOPPED_MOVING")
      AddLine("trace", "You come to a stop.")
      ReportLocation(false)
      ReportExplorationMemory(false)
      ReportPathMemory(false)
    end
    TA.lastMoving = movingNow
  end
  if movingNow and facingLabel and facingLabel ~= TA.lastFacingBucket then
    AddLine("trace", string.format("TRACE: PLAYER_FACING %s", facingLabel))
    AddLine("trace", string.format("You turn toward the %s.", facingLabel))
    TA.lastFacingBucket = facingLabel
  elseif not movingNow then
    TA.lastFacingBucket = facingLabel
  end
  if speedLabel ~= TA.lastSpeedCategory then
    if speedLabel == "walking" then
      AddLine("trace", string.format("TRACE: PLAYER_SPEED %.2f", speed))
      AddLine("trace", "You are walking.")
    elseif speedLabel == "running" then
      AddLine("trace", string.format("TRACE: PLAYER_SPEED %.2f", speed))
      AddLine("trace", "You are running.")
    elseif speedLabel == "fast" then
      AddLine("trace", string.format("TRACE: PLAYER_SPEED %.2f", speed))
      AddLine("trace", "You move at high speed.")
    end
    TA.lastSpeedCategory = speedLabel
  end
end

-- Returns an 8-direction compass string (N/NE/E/SE/S/SW/W/NW) from map-space dx/dy.
-- In map-space, +dx is east and +dy is south, so convert to east/north before atan2.
function TA_CompassDir(dx, dy)
  local east = dx
  local north = -dy
  local deg = math.deg(math.atan2(north, east)) % 360
  local dirs = { "E", "NE", "N", "NW", "W", "SW", "S", "SE" }
  return dirs[math.floor((deg + 22.5) / 45) % 8 + 1]
end

