-- Modules/Breath.lua
-- Vague-percentage warnings for the BREATH (underwater) and EXHAUSTION
-- (deep-water fatigue) mirror timers. We do NOT show seconds remaining --
-- only fixed percentage milestones (75/50/25/5).

local TA = _G.TA
if not TA then return end

local THRESHOLDS = { 0.75, 0.50, 0.25, 0.05 }

-- Color per remaining-percent bucket. Severity ramps with urgency.
local function colorFor(pct)
  if pct >= 75 then return "|cffffff66" end -- yellow
  if pct >= 50 then return "|cffffcc33" end -- gold
  if pct >= 25 then return "|cffff8800" end -- orange
  return "|cffff2222"                       -- red
end

local LABELS = {
  BREATH     = "Breath",
  EXHAUSTION = "Fatigue",
}

-- Per-timer state: { timers = {C_Timer handles}, maxMs = number }
local active = {}

local function cancelTimers(state)
  if not state or not state.timers then return end
  for _, t in ipairs(state.timers) do
    if t and t.Cancel then t:Cancel() end
  end
  state.timers = {}
end

local function fireWarning(kind, pct)
  if not AddLine then return end
  local label = LABELS[kind] or kind
  local color = colorFor(pct)
  if pct <= 5 then
    -- Attention-grabbing line: bracketed, all caps, repeated, red.
    AddLine("system", string.format(
      "%s>>> %s CRITICAL: %d%% <<< SURFACE NOW! <<<|r", color, string.upper(label), pct))
  else
    AddLine("system", string.format("%s%s: %d%% remaining.|r", color, label, pct))
  end
end

local function scheduleWarnings(kind, remainingMs, maxMs)
  if not C_Timer or not C_Timer.NewTimer then return end
  local state = active[kind] or { timers = {} }
  active[kind] = state
  cancelTimers(state)
  state.maxMs = maxMs

  if not maxMs or maxMs <= 0 or not remainingMs or remainingMs <= 0 then return end
  local totalSec   = maxMs / 1000
  local elapsedSec = (maxMs - remainingMs) / 1000

  for _, frac in ipairs(THRESHOLDS) do
    -- fireAt = seconds from start when this frac of breath remains
    local fireAt = totalSec * (1 - frac)
    local delay  = fireAt - elapsedSec
    if delay > 0.05 then
      local pct = math.floor(frac * 100 + 0.5)
      table.insert(state.timers, C_Timer.NewTimer(delay, function()
        fireWarning(kind, pct)
      end))
    end
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MIRROR_TIMER_START")
f:RegisterEvent("MIRROR_TIMER_PAUSE")
f:RegisterEvent("MIRROR_TIMER_STOP")
f:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
  if event == "MIRROR_TIMER_START" then
    -- arg1=timer, arg2=value (remaining ms), arg3=maxvalue (ms)
    if LABELS[arg1] then
      scheduleWarnings(arg1, arg2, arg3)
    end
  elseif event == "MIRROR_TIMER_PAUSE" then
    -- arg1=timer, arg2=remaining ms (paused). Cancel pending warnings;
    -- a fresh START will re-fire when the timer resumes/restarts.
    if LABELS[arg1] and active[arg1] then
      cancelTimers(active[arg1])
    end
  elseif event == "MIRROR_TIMER_STOP" then
    if LABELS[arg1] and active[arg1] then
      cancelTimers(active[arg1])
    end
  end
end)
