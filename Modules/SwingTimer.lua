-- Modules/SwingTimer.lua
-- Swing-timer tracking and the weapon-swap "dance hint" overlay.
--
-- Exported globals:
--   * ResetSwingTimer          -- (promoted) reset timer on SWING_DAMAGE
--   * CheckSwingTimer          -- (promoted) poll swing state each tick
--   * TA_RecordSwingReaction   -- record hint->swing latency sample
--   * TA_ReportSwingDanceLog   -- print recent reaction-time samples
--   * TA_ResetSwingDanceLog    -- clear the reaction log
--   * TA_SetSwingDanceHint     -- "swingtimer" command dispatcher
--
-- ResetSwingTimer and CheckSwingTimer are promoted from
-- forward-declared file-locals to true globals so the movement
-- ticker and combat event handlers in textadventurer.lua can call
-- them after load. Their _G mirror line is removed.
--
-- Depends on: AddLine, TA (swingReadyAt, lastSwingState,
-- swingDanceHintEnabled, swingDanceReactionBuffer, swingDanceLog,
-- swingDanceLogMax, lastSwingHintAt), GetTime, UnitAttackSpeed,
-- GetNetStats.
--

local ResetSwingTimer
local CheckSwingTimer
function ResetSwingTimer()
  local mainSpeed = UnitAttackSpeed("player")
  if not mainSpeed or mainSpeed <= 0 then return end
  TA.swingReadyAt = GetTime() + mainSpeed
  TA.lastSwingState = "waiting"
  AddLine("playerCombat", "You ready your next strike.")
end


function CheckSwingTimer()
  if not TA.swingReadyAt or TA.swingReadyAt == 0 then return end
  local remain = TA.swingReadyAt - GetTime()
  if TA.swingDanceHintEnabled then
    local lagSec = 0
    if GetNetStats then
      lagSec = (tonumber(select(4, GetNetStats())) or 0) / 1000
    end
    local reactionBuf = tonumber(TA.swingDanceReactionBuffer) or 0.05
    local hintThreshold = lagSec + reactionBuf
    if remain > -0.1 and remain <= hintThreshold and TA.lastSwingState ~= "hintnow" then
      AddLine("swingDance", "Your hands glow bright. SWING YOUR WEAPON NOW!")
      TA.lastSwingState = "hintnow"
      TA.lastSwingHintAt = GetTime()
      return
    end
  end
  if remain <= 0 and TA.lastSwingState ~= "ready" and TA.lastSwingState ~= "hintnow" then
    AddLine("playerCombat", "Your next strike is ready.")
    TA.lastSwingState = "ready"
  elseif remain > 0 and remain <= 0.3 and TA.lastSwingState ~= "soon" and not TA.swingDanceHintEnabled then
    AddLine("playerCombat", "Your strike is about to land again.")
    TA.lastSwingState = "soon"
  end
end

function TA_RecordSwingReaction()
  local hintAt = TA.lastSwingHintAt
  if not hintAt then return end
  local now = GetTime()
  local delta = now - hintAt
  TA.lastSwingHintAt = nil
  if delta < 0 or delta > 5 then return end
  TA.swingDanceLog = TA.swingDanceLog or {}
  table.insert(TA.swingDanceLog, 1, { delta = delta, at = now })
  local maxN = tonumber(TA.swingDanceLogMax) or 20
  while #TA.swingDanceLog > maxN do
    table.remove(TA.swingDanceLog)
  end
end

function TA_ReportSwingDanceLog(n)
  n = tonumber(n) or 5
  if n < 1 then n = 1 end
  if n > 20 then n = 20 end
  local log = TA.swingDanceLog
  if not log or #log == 0 then
    AddLine("system", "No swing reaction samples yet. Enable 'swingtimer on' and weapon-swap to collect data.")
    return
  end
  local count = math.min(n, #log)
  local sum, best, worst = 0, math.huge, -math.huge
  AddLine("swingDance", string.format("Last %d swing reaction(s) (time from SWING NOW prompt to actual swing):", count))
  for i = 1, count do
    local entry = log[i]
    local ms = entry.delta * 1000
    local ago = GetTime() - entry.at
    sum = sum + ms
    if ms < best then best = ms end
    if ms > worst then worst = ms end
    AddLine("swingDance", string.format("  %d. %.0f ms  (%.0fs ago)", i, ms, ago))
  end
  local avg = sum / count
  AddLine("swingDance", string.format("Avg: %.0f ms | Best: %.0f ms | Worst: %.0f ms", avg, best, worst))
  if GetNetStats then
    local lagMs = tonumber(select(4, GetNetStats())) or 0
    local buf = (tonumber(TA.swingDanceReactionBuffer) or 0.05) * 1000
    AddLine("system", string.format("Lead time given: latency %d ms + buffer %.0f ms = %.0f ms before swing.", lagMs, buf, lagMs + buf))
  end
end

function TA_ResetSwingDanceLog()
  TA.swingDanceLog = {}
  TA.lastSwingHintAt = nil
  AddLine("system", "Swing reaction log cleared.")
end

function TA_SetSwingDanceHint(args)
  args = (args or ""):match("^%s*(.-)%s*$")
  local cmd = (args:match("^(%S+)") or ""):lower()
  if cmd == "on" then
    TA.swingDanceHintEnabled = true
    AddLine("system", "Swing dance hint enabled. Fires before each swing at latency + reaction buffer.")
  elseif cmd == "off" then
    TA.swingDanceHintEnabled = false
    AddLine("system", "Swing dance hint disabled.")
  elseif cmd == "status" then
    local lagSec = 0
    if GetNetStats then
      lagSec = (tonumber(select(4, GetNetStats())) or 0) / 1000
    end
    local buf = tonumber(TA.swingDanceReactionBuffer) or 0.05
    AddLine("system", string.format(
      "Swing hint: %s | Latency: %d ms | Reaction buffer: %d ms | Fires at: %d ms before swing.",
      TA.swingDanceHintEnabled and "ON" or "OFF",
      math.floor(lagSec * 1000),
      math.floor(buf * 1000),
      math.floor((lagSec + buf) * 1000)
    ))
  elseif cmd == "reaction" then
    local ms = tonumber(args:match("%S+%s+(%d+)"))
    if not ms then
      AddLine("system", "Usage: swingtimer reaction <ms>  (e.g. swingtimer reaction 100)")
      return
    end
    TA.swingDanceReactionBuffer = ms / 1000
    AddLine("system", string.format("Reaction buffer set to %d ms.", ms))
  elseif cmd == "log" then
    local sub = (args:match("^%S+%s+(%S+)") or ""):lower()
    if sub == "reset" or sub == "clear" then
      TA_ResetSwingDanceLog()
    else
      local n = tonumber(args:match("%S+%s+(%d+)"))
      TA_ReportSwingDanceLog(n or 5)
    end
  else
    AddLine("system", "Usage: swingtimer on|off|status|reaction <ms>|log [n]|log reset")
  end
end
_G.TA_SetSwingDanceHint = TA_SetSwingDanceHint
