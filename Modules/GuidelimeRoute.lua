--[[
GuidelimeRoute.lua

Bridge between TextAdventurer and the Guidelime addon. Exposes the next N
active guide steps and lets the player advance ("skip") the current step or
roll back ("back") the most recently completed/skipped step, all surfaced
through the /ta route slash command family.

Requires a one-line patch to Guidelime/Guidelime.lua that exports `addon`
to `Guidelime.addon`. Apply via `tools/patch-guidelime.ps1`. If the patch is
missing, this module degrades gracefully and prints a one-time hint.

Public API:
  TA_GuidelimeAvailable()           -> bool (patch + currentGuide present)
  TA_GuidelimeStatusLine()          -> string (single-line status, never nil)
  TA_GuidelimeNextSteps(n)          -> array of {index, text, coords, kinds}
  TA_GuidelimeAdvance()             -> advance: skip current active steps
  TA_GuidelimeBack()                -> rollback most recent completed/skipped
  TA_ReportGuidelimeRoute(n)        -> print next n (default 3) to terminal
  TA_GuidelimeRouteAdvance()        -> advance + report
  TA_GuidelimeRouteBack()           -> back + report
]]

local NAGGED = false

local function nagOnce()
    if NAGGED then return end
    NAGGED = true
    local fn = _G.AddLine or function(_, t) print("|cffffaa00ASCIIMUD|r " .. t) end
    fn("system", "Guidelime bridge missing. Run tools\\patch-guidelime.ps1 then /reload.")
end

local function getCG()
    local G = _G.Guidelime
    if not G or not G.addon then return nil end
    return G.addon.CG
end

function TA_GuidelimeAvailable()
    local CG = getCG()
    return CG ~= nil and CG.currentGuide ~= nil and CG.currentGuide.steps ~= nil
       and #CG.currentGuide.steps > 0
end

local function stepIsCandidate(step)
    if not step then return false end
    if step.completed then return false end
    if step.skip then return false end
    if step.available == false then return false end
    return true
end

local function trim(s, n)
    if not s then return "" end
    s = tostring(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|T[^|]*|t", "")
    s = s:gsub("\n", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if n and #s > n then s = s:sub(1, n - 1) .. "..." end
    return s
end

local function summarizeStep(step)
    local parts = {}
    local kinds = {}
    local coords
    for _, el in ipairs(step.elements or {}) do
        if el.text and el.text ~= "" then
            table.insert(parts, el.text)
        end
        if el.t then kinds[el.t] = (kinds[el.t] or 0) + 1 end
        if not coords and el.x and el.y and el.mapID then
            coords = {x = el.x, y = el.y, mapID = el.mapID}
        end
    end
    local text = trim(table.concat(parts, " "), 140)
    if text == "" then text = "(no text)" end
    return {
        index = step.index,
        line  = step.line,
        text  = text,
        coords = coords,
        kinds = kinds,
        active = step.active and true or false,
        manual = step.manual and true or false,
    }
end

function TA_GuidelimeNextSteps(n)
    n = n or 3
    local CG = getCG()
    if not CG or not CG.currentGuide or not CG.currentGuide.steps then
        return {}
    end
    local steps = CG.currentGuide.steps
    local startIndex = CG.currentGuide.firstActiveIndex or 1
    local out = {}
    for i = startIndex, #steps do
        local s = steps[i]
        if stepIsCandidate(s) then
            table.insert(out, summarizeStep(s))
            if #out >= n then break end
        end
    end
    return out
end

function TA_GuidelimeStatusLine()
    local CG = getCG()
    if not CG then nagOnce(); return "Guidelime not connected (patch missing)." end
    if not CG.currentGuide or not CG.currentGuide.steps or #CG.currentGuide.steps == 0 then
        return "Guidelime: no guide loaded."
    end
    local total = #CG.currentGuide.steps
    local done = 0
    if GuidelimeDataChar and GuidelimeDataChar.completedSteps then
        for _, v in pairs(GuidelimeDataChar.completedSteps) do
            if v then done = done + 1 end
        end
    end
    local name = CG.currentGuide.name or "?"
    return string.format("Guidelime: %s [%d / %d]", name, done, total)
end

function TA_GuidelimeAdvance()
    local CG = getCG()
    if not CG or not CG.skipCurrentSteps then return false, "Guidelime not connected." end
    if not CG.currentGuide or CG.currentGuide.firstActiveIndex == nil then
        return false, "No active step to advance past."
    end
    CG.skipCurrentSteps()
    return true, "Advanced past current step."
end

function TA_GuidelimeBack()
    local CG = getCG()
    if not CG or not CG.setStepSkip or not CG.currentGuide then
        return false, "Guidelime not connected."
    end
    local steps = CG.currentGuide.steps or {}
    local guideName = CG.currentGuide.name
    local skipMap = (GuidelimeDataChar and GuidelimeDataChar.guideSkip
        and GuidelimeDataChar.guideSkip[guideName]) or {}
    local doneMap = (GuidelimeDataChar and GuidelimeDataChar.completedSteps) or {}
    local target
    for i = #steps, 1, -1 do
        if skipMap[i] or doneMap[i] then target = i; break end
    end
    if not target then return false, "Nothing to roll back." end
    if skipMap[target] then
        CG.setStepSkip(false, target, target)
    else
        doneMap[target] = false
        if CG.updateSteps then CG.updateSteps({target}) end
    end
    return true, string.format("Rolled back step #%d.", target)
end

local function emit(kind, msg)
    local fn = _G.AddLine or function(_, t) print(t) end
    fn(kind, msg)
end

function TA_ReportGuidelimeRoute(n)
    if not TA_GuidelimeAvailable() then
        if not _G.Guidelime or not _G.Guidelime.addon then nagOnce() end
        emit("system", TA_GuidelimeStatusLine())
        return
    end
    emit("quest", TA_GuidelimeStatusLine())
    local steps = TA_GuidelimeNextSteps(n or 3)
    if #steps == 0 then
        emit("system", "No upcoming Guidelime steps found.")
        return
    end
    for i, s in ipairs(steps) do
        local prefix = (i == 1) and ">" or " "
        local coordStr = ""
        if s.coords and s.coords.mapID then
            coordStr = string.format(" [%.1f,%.1f m=%d]", s.coords.x or 0, s.coords.y or 0, s.coords.mapID)
        end
        emit("quest", string.format("%s %d. %s%s", prefix, s.index, s.text, coordStr))
    end
    emit("system", "/ta route skip = advance, /ta route back = undo")
end

function TA_GuidelimeRouteAdvance()
    local ok, msg = TA_GuidelimeAdvance()
    emit(ok and "quest" or "system", "Route: " .. msg)
    if ok then TA_ReportGuidelimeRoute(3) end
end

function TA_GuidelimeRouteBack()
    local ok, msg = TA_GuidelimeBack()
    emit(ok and "quest" or "system", "Route: " .. msg)
    if ok then TA_ReportGuidelimeRoute(3) end
end
