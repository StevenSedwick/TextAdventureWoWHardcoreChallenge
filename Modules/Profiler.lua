-- Profiler.lua
-- TextAdventurer performance profiler (TA:ProfileStart/End/PrintProfiler/Enable/Disable).
-- Extracted from textadventurer.lua. Requires TA.profiler table to be initialized in main
-- before this module loads. Loaded after main per .toc.

local TA = _G.TextAdventurerFrame or _G.TA
if not TA then return end

function TA:ProfileStart(label)
  if not self.profiler.enabled then return end
  if not self.profiler.data[label] then
    self.profiler.data[label] = { count = 0, totalMs = 0, maxMs = 0, minMs = 999999 }
  end
  self.profiler.data[label].__startTime = debugprofilestop()
end

function TA:ProfileEnd(label)
  if not self.profiler.enabled then return end
  local entry = self.profiler.data[label]
  if not entry or not entry.__startTime then return end
  local elapsed = debugprofilestop() - entry.__startTime
  entry.count = entry.count + 1
  entry.totalMs = entry.totalMs + elapsed
  entry.maxMs = math.max(entry.maxMs, elapsed)
  entry.minMs = math.min(entry.minMs, elapsed)
  entry.__startTime = nil
end

function TA:PrintProfiler()
  if not self.profiler.enabled then AddLine("system", "Profiler disabled") return end
  AddLine("system", "=== TextAdventurer Performance Profile ===")
  for label, data in pairs(self.profiler.data) do
    if data.count > 0 then
      local avg = data.totalMs / data.count
      AddLine("system", string.format("%s: %.2fms avg (%.2f min, %.2f max) - %d calls", 
        label, avg, data.minMs, data.maxMs, data.count))
    end
  end
end

function TA:EnableProfiler()
  self.profiler.enabled = true
  self.profiler.data = {}
  AddLine("system", "TextAdventurer profiler enabled")
end

function TA:DisableProfiler()
  self.profiler.enabled = false
  AddLine("system", "TextAdventurer profiler disabled")
end
