-- Talent commands: list and spend talent points from chat.
--
-- /ta talents               -> show all 3 tabs (name, points spent, points available)
-- /ta talents <tab>         -> list talents in that tab (1-based: 1=Arms, 2=Fury, 3=Prot for warrior)
-- /ta talent <tab> <index>  -> spend one talent point in (tab, index)
--
-- All API used here is Classic Era safe: GetNumTalentTabs, GetTalentTabInfo,
-- GetNumTalents, GetTalentInfo, LearnTalent, UnitCharacterPoints.

local function TalentLine(text)
  if AddLine then AddLine("system", text) end
end

local function TA_GetUnspentTalentPoints()
  if UnitCharacterPoints then
    local pts = UnitCharacterPoints("player")
    if type(pts) == "number" then return pts end
  end
  return 0
end

local function TA_TalentTabSummary()
  if not GetNumTalentTabs or not GetTalentTabInfo then
    TalentLine("Talent API unavailable.")
    return
  end
  local numTabs = GetNumTalentTabs() or 0
  if numTabs <= 0 then
    TalentLine("No talent tabs available (under level 10?).")
    return
  end
  local unspent = TA_GetUnspentTalentPoints()
  TalentLine(string.format("Talent points unspent: %d", unspent))
  for tab = 1, numTabs do
    local name, _, pointsSpent = GetTalentTabInfo(tab)
    TalentLine(string.format("  [%d] %s - %d spent", tab, name or ("Tab " .. tab), pointsSpent or 0))
  end
  TalentLine("Use: ta talents <tab>  |  ta talent <tab> <index>")
end

local function TA_TalentTabList(tab)
  if not GetNumTalents or not GetTalentInfo or not GetTalentTabInfo then
    TalentLine("Talent API unavailable.")
    return
  end
  local numTabs = GetNumTalentTabs() or 0
  if tab < 1 or tab > numTabs then
    TalentLine(string.format("Invalid tab %d (have %d).", tab, numTabs))
    return
  end
  local tabName = GetTalentTabInfo(tab) or ("Tab " .. tab)
  local n = GetNumTalents(tab) or 0
  TalentLine(string.format("=== %s (tab %d) - %d talents ===", tabName, tab, n))
  for i = 1, n do
    local name, _, tier, column, currentRank, maxRank, _, meetsPrereq = GetTalentInfo(tab, i)
    if name then
      local lockTag = ""
      if meetsPrereq == false then lockTag = " (locked)" end
      local maxedTag = ""
      if currentRank and maxRank and currentRank >= maxRank then maxedTag = " [MAX]" end
      TalentLine(string.format(
        "  [%d] %s  rank %d/%d  tier %d col %d%s%s",
        i, name, currentRank or 0, maxRank or 0, tier or 0, column or 0, lockTag, maxedTag
      ))
    end
  end
  TalentLine(string.format("Spend: ta talent %d <index>", tab))
end

local function TA_LearnTalentPoint(tab, idx)
  if not LearnTalent or not GetTalentInfo then
    TalentLine("Talent API unavailable.")
    return
  end
  local numTabs = GetNumTalentTabs() or 0
  if tab < 1 or tab > numTabs then
    TalentLine(string.format("Invalid tab %d (have %d).", tab, numTabs))
    return
  end
  local n = GetNumTalents(tab) or 0
  if idx < 1 or idx > n then
    TalentLine(string.format("Invalid talent index %d (tab %d has %d).", idx, tab, n))
    return
  end
  local unspent = TA_GetUnspentTalentPoints()
  if unspent <= 0 then
    TalentLine("No unspent talent points available.")
    return
  end
  local name, _, _, _, currentRank, maxRank, _, meetsPrereq = GetTalentInfo(tab, idx)
  if not name then
    TalentLine("Talent info unavailable.")
    return
  end
  if currentRank and maxRank and currentRank >= maxRank then
    TalentLine(string.format("%s is already maxed (%d/%d).", name, currentRank, maxRank))
    return
  end
  if meetsPrereq == false then
    TalentLine(string.format("%s prerequisites not met.", name))
    return
  end
  LearnTalent(tab, idx)
  -- Re-read after spend.
  local _, _, _, _, newRank, newMax = GetTalentInfo(tab, idx)
  local newUnspent = TA_GetUnspentTalentPoints()
  TalentLine(string.format(
    "Spent point on %s: %d/%d (unspent: %d).",
    name, newRank or (currentRank or 0) + 1, newMax or maxRank or 0, newUnspent
  ))
end

function TA_RegisterTalentCommandHandlers(exactHandlers, addPatternHandler)
  exactHandlers["talents"] = function() TA_TalentTabSummary() end
  exactHandlers["talent"]  = function() TA_TalentTabSummary() end
  addPatternHandler("^talents%s+(%d+)$", function(t) TA_TalentTabList(tonumber(t)) end)
  addPatternHandler("^talent%s+(%d+)$",  function(t) TA_TalentTabList(tonumber(t)) end)
  addPatternHandler("^talent%s+(%d+)%s+(%d+)$", function(t, i)
    TA_LearnTalentPoint(tonumber(t), tonumber(i))
  end)
  addPatternHandler("^talents%s+(%d+)%s+(%d+)$", function(t, i)
    TA_LearnTalentPoint(tonumber(t), tonumber(i))
  end)
end

-- Self-register: Modules\Commands.lua runs before this file, so its earlier
-- attempt to call TA_RegisterTalentCommandHandlers was a no-op. Register now
-- that the handler tables already exist on TA.
if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterTalentCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
