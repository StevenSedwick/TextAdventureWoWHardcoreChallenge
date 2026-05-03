-- Spellbook, spell info, action bar lookup, and trainer commands.
--
-- Two clearly-separated worlds:
--   KNOWN spells (your spellbook):
--     /ta spellbook                  - list all spell tabs and their spell counts
--     /ta spellbook <tab>            - list spells in tab N (1-based)
--     /ta spell <name>               - show full details for a known spell
--     /ta find <text>                - search YOUR spellbook + action bars
--
--   UNKNOWN spells (trainer window must be open):
--     /ta trainer                    - list all trainer services with status
--     /ta trainer available          - only ranks you can buy now
--     /ta trainer unavailable        - too high level / unmet requirements
--     /ta trainer known              - already learned (skip them)
--     /ta findtrainer <text>         - search current trainer service list
--
-- Spell tooltip text (description/range/cast) is read by anchoring an offscreen
-- GameTooltip and walking its text lines.

local function L(text) if AddLine then AddLine("system", text) end end
local function LC(text) if AddLine then AddLine("cast", text) end end

-- -------------------------------------------------------------------------
-- Tooltip scanner (covers spells + spellbook items + actions + trainer)
-- -------------------------------------------------------------------------

local TA_SPELL_TIP_NAME = "TextAdventurerSpellScanTooltip"
local function GetScanTooltip()
  local tip = _G[TA_SPELL_TIP_NAME]
  if not tip then
    tip = CreateFrame("GameTooltip", TA_SPELL_TIP_NAME, UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  tip:ClearLines()
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  return tip
end

local function ReadTooltipLines(tip)
  local lines = {}
  local n = tip:NumLines() or 0
  for i = 1, n do
    local left = _G[TA_SPELL_TIP_NAME .. "TextLeft" .. i]
    local right = _G[TA_SPELL_TIP_NAME .. "TextRight" .. i]
    local lt = (left and left:GetText()) or ""
    local rt = (right and right:GetText()) or ""
    if lt ~= "" or rt ~= "" then
      if rt ~= "" and lt ~= "" then
        lines[#lines + 1] = lt .. "  " .. rt
      else
        lines[#lines + 1] = lt ~= "" and lt or rt
      end
    end
  end
  return lines
end

-- -------------------------------------------------------------------------
-- Cooldown / cost formatting
-- -------------------------------------------------------------------------

local function FormatCooldown(start, duration, enabled)
  if not start or not duration or duration <= 1.5 or (enabled or 0) ~= 1 or start == 0 then
    return "ready"
  end
  local remain = (start + duration) - GetTime()
  if remain <= 0 then return "ready" end
  if remain >= 60 then
    return string.format("%dm%ds", math.floor(remain / 60), math.floor(remain % 60))
  end
  return string.format("%.1fs", remain)
end

local function FormatRange(minR, maxR)
  if not maxR or maxR == 0 then return "melee" end
  if minR and minR > 0 then
    return string.format("%d-%dyd", math.floor(minR), math.floor(maxR))
  end
  return string.format("%dyd", math.floor(maxR))
end

local function FormatCastTime(castMs)
  if not castMs or castMs <= 0 then return "instant" end
  return string.format("%.1fs cast", castMs / 1000)
end

-- -------------------------------------------------------------------------
-- Spellbook listing
-- -------------------------------------------------------------------------

local function TA_SpellbookSummary()
  if not GetNumSpellTabs or not GetSpellTabInfo then
    L("Spellbook API unavailable.")
    return
  end
  local nTabs = GetNumSpellTabs() or 0
  if nTabs <= 0 then
    L("Your spellbook is empty.")
    return
  end
  L(string.format("=== Spellbook: %d tab(s) ===", nTabs))
  for tab = 1, nTabs do
    local name, _, offset, numSpells = GetSpellTabInfo(tab)
    L(string.format("  [%d] %s - %d spell(s)", tab, name or ("Tab " .. tab), numSpells or 0))
  end
  L("Use: ta spellbook <tab> | ta spell <name> | ta find <text> | ta spellbook all")
end

local function TA_SpellbookListTab(tab)
  if not GetNumSpellTabs or not GetSpellTabInfo or not GetSpellBookItemName then
    L("Spellbook API unavailable.")
    return
  end
  local nTabs = GetNumSpellTabs() or 0
  if not tab or tab < 1 or tab > nTabs then
    L(string.format("Invalid tab %s (have %d).", tostring(tab), nTabs))
    return
  end
  local tabName, _, offset, numSpells = GetSpellTabInfo(tab)
  L(string.format("=== %s (tab %d, %d spells) ===", tabName or ("Tab " .. tab), tab, numSpells or 0))
  for i = 1, (numSpells or 0) do
    local idx = offset + i
    local name, rank = GetSpellBookItemName(idx, "spell")
    if name then
      local _, spellID = GetSpellBookItemInfo(idx, "spell")
      local cdText = "ready"
      if GetSpellCooldown then
        local s, d, en = GetSpellCooldown(idx, "spell")
        cdText = FormatCooldown(s, d, en)
      end
      local rankText = (rank and rank ~= "") and (" " .. rank) or ""
      local idText = spellID and (" id=" .. spellID) or ""
      LC(string.format("  [%d] %s%s%s  (%s)", idx, name, rankText, idText, cdText))
    end
  end
  L("Use: ta spell <name>  for full details.")
end

-- -------------------------------------------------------------------------
-- Spell details (known spell)
-- -------------------------------------------------------------------------

local function TA_SpellInfo(query)
  if not GetSpellInfo then
    L("GetSpellInfo unavailable.")
    return
  end
  local lookup = tonumber(query) or query
  local name, _, _, castTime, minRange, maxRange, spellID = GetSpellInfo(lookup)
  if not name then
    L(string.format("No spell found for '%s'. Try ta find %s", tostring(query), tostring(query)))
    return
  end

  -- IsSpellKnown takes a spellID in Classic.
  local known = false
  if IsSpellKnown and spellID then
    known = IsSpellKnown(spellID) and true or false
  elseif IsPlayerSpell and spellID then
    known = IsPlayerSpell(spellID) and true or false
  end

  L(string.format("=== %s%s ===", name, known and "" or "  (not in your spellbook)"))
  L(string.format("  spellID=%s  %s  %s", tostring(spellID or "?"),
    FormatCastTime(castTime), FormatRange(minRange, maxRange)))

  if GetSpellCooldown and spellID then
    local s, d, en = GetSpellCooldown(spellID)
    local cdText = FormatCooldown(s, d, en)
    L(string.format("  cooldown: %s", cdText))
  end

  if IsUsableSpell then
    local usable, noMana = IsUsableSpell(name)
    if usable then
      L("  status: usable now")
    elseif noMana then
      L("  status: out of mana/rage/energy")
    else
      L("  status: not usable (target/range/state)")
    end
  end

  -- Tooltip description -- preferred path is SetSpellByID for accuracy.
  local tip = GetScanTooltip()
  local ok = false
  if spellID and tip.SetSpellByID then
    ok = pcall(function() tip:SetSpellByID(spellID) end)
  end
  if not ok and tip.SetSpell then
    pcall(function() tip:SetSpell(name) end)
  end
  local lines = ReadTooltipLines(tip)
  if #lines > 0 then
    L("  --- tooltip ---")
    for i = 1, math.min(#lines, 12) do
      LC("  " .. lines[i])
    end
    if #lines > 12 then
      L(string.format("  (+%d more lines)", #lines - 12))
    end
  end
  tip:Hide()
end

-- -------------------------------------------------------------------------
-- Find: search known spellbook + action bars + macros
-- -------------------------------------------------------------------------

local function TA_FindKnown(query)
  if not query or query == "" then
    L("Usage: ta find <text>")
    return
  end
  local q = query:lower()
  local hits = 0

  -- Spellbook
  if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    local nTabs = GetNumSpellTabs() or 0
    for tab = 1, nTabs do
      local _, _, offset, numSpells = GetSpellTabInfo(tab)
      for i = 1, (numSpells or 0) do
        local idx = offset + i
        local name, rank = GetSpellBookItemName(idx, "spell")
        if name and name:lower():find(q, 1, true) then
          local _, spellID = GetSpellBookItemInfo(idx, "spell")
          local rankText = (rank and rank ~= "") and (" " .. rank) or ""
          LC(string.format("  spellbook[%d]: %s%s  id=%s  (ta spell %s)",
            idx, name, rankText, tostring(spellID or "?"), name))
          hits = hits + 1
        end
      end
    end
  end

  -- Action bars
  if GetActionInfo then
    for slot = 1, 120 do
      local actionType, id = GetActionInfo(slot)
      if actionType and id then
        local label
        if actionType == "spell" then
          label = GetSpellInfo and GetSpellInfo(id) or ("spell " .. id)
        elseif actionType == "item" then
          label = (GetItemInfo and GetItemInfo(id)) or ("item " .. id)
        elseif actionType == "macro" then
          label = (GetMacroInfo and GetMacroInfo(id)) or ("macro " .. id)
        else
          label = tostring(actionType) .. " " .. tostring(id)
        end
        if label and label:lower():find(q, 1, true) then
          LC(string.format("  action slot %d: %s (%s %s)", slot, label, actionType, tostring(id)))
          hits = hits + 1
        end
      end
    end
  end

  -- Macros
  if GetNumMacros and GetMacroInfo then
    local nm = GetNumMacros() or 0
    for i = 1, nm do
      local name = GetMacroInfo(i)
      if name and name:lower():find(q, 1, true) then
        LC(string.format("  macro[%d]: %s", i, name))
        hits = hits + 1
      end
    end
  end

  if hits == 0 then
    L(string.format("No matches for '%s' in your spellbook, action bars, or macros.", query))
    L("To search trainer offerings, open a trainer and use: ta findtrainer " .. query)
  else
    L(string.format("Found %d match(es) for '%s'.", hits, query))
  end
end

-- -------------------------------------------------------------------------
-- Trainer (unknown spells you could learn)
-- -------------------------------------------------------------------------

-- Trainer services use a filter: GetTrainerServiceTypeFilter("available"),
-- ("unavailable"), ("used"). Not all UI builds expose set/get of the same
-- name, so we read all three categories without changing the user's filter.
local function TA_ScanTrainer()
  if not GetNumTrainerServices then
    return nil, "Trainer API unavailable."
  end
  local count = GetNumTrainerServices() or 0
  if count <= 0 then
    return nil, "No trainer window is open."
  end
  local services = {}
  for i = 1, count do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name then
      local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
      local skillLine, skillRank = nil, nil
      if GetTrainerServiceSkillLine then
        skillLine, skillRank = GetTrainerServiceSkillLine(i)
      end
      services[#services + 1] = {
        index = i,
        name = name,
        rank = rank or "",
        category = category or "available", -- "available" / "unavailable" / "used"
        cost = cost,
        skillLine = skillLine,
        skillReq = skillRank,
      }
    end
  end
  return services, nil
end

local function FormatCopper(c)
  c = tonumber(c) or 0
  if c <= 0 then return "free" end
  local g = math.floor(c / 10000)
  local s = math.floor((c % 10000) / 100)
  local cp = c % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if cp > 0 or #parts == 0 then parts[#parts + 1] = cp .. "c" end
  return table.concat(parts, " ")
end

local CATEGORY_LABEL = {
  available = "BUY",
  unavailable = "lockd",
  used = "known",
}

local function TA_TrainerList(filter)
  local services, err = TA_ScanTrainer()
  if not services then L(err) return end
  filter = filter and filter:lower() or nil
  if filter and not (filter == "available" or filter == "unavailable" or filter == "known" or filter == "used") then
    L("Filter must be: available | unavailable | known")
    return
  end
  -- Map the user-friendly "known" to the internal "used" category.
  if filter == "known" then filter = "used" end

  local shown = 0
  L(string.format("=== Trainer: %d service(s)%s ===", #services, filter and (" [" .. filter .. "]") or ""))
  for _, s in ipairs(services) do
    if (not filter) or s.category == filter then
      local tag = CATEGORY_LABEL[s.category] or s.category
      local rankText = (s.rank ~= "") and (" " .. s.rank) or ""
      local skillText = ""
      if s.skillLine then
        skillText = string.format("  needs %s %s", s.skillLine, tostring(s.skillReq or "?"))
      end
      LC(string.format("  [%d] %-5s %s%s  cost %s%s",
        s.index, tag, s.name, rankText, FormatCopper(s.cost), skillText))
      shown = shown + 1
    end
  end
  if shown == 0 then
    L("No services match that filter.")
  else
    L("Open the trainer to learn; this addon does not auto-purchase.")
  end
end

local function TA_FindTrainer(query)
  if not query or query == "" then
    L("Usage: ta findtrainer <text>  (trainer window must be open)")
    return
  end
  local services, err = TA_ScanTrainer()
  if not services then L(err) return end
  local q = query:lower()
  local hits = 0
  L(string.format("=== Trainer search: '%s' ===", query))
  for _, s in ipairs(services) do
    if s.name:lower():find(q, 1, true) then
      local tag = CATEGORY_LABEL[s.category] or s.category
      local rankText = (s.rank ~= "") and (" " .. s.rank) or ""
      LC(string.format("  [%d] %-5s %s%s  cost %s",
        s.index, tag, s.name, rankText, FormatCopper(s.cost)))
      hits = hits + 1
    end
  end
  if hits == 0 then
    L("No trainer services match.")
  end
end

-- -------------------------------------------------------------------------
-- Registration
-- -------------------------------------------------------------------------

function TA_RegisterSpellbookCommandHandlers(exactHandlers, addPatternHandler)
  exactHandlers["spellbook"] = function() TA_SpellbookSummary() end
  exactHandlers["book"]      = function() TA_SpellbookSummary() end
  exactHandlers["spells"]    = function() TA_SpellbookSummary() end

  -- Legacy full-dump view (lists every spell across all tabs in one printout, plus pets).
  local function LegacyDump()
    if _G.ReportSpellbook then
      _G.ReportSpellbook()
    else
      L("Legacy spellbook view unavailable.")
    end
  end
  exactHandlers["spellbook all"]  = LegacyDump
  exactHandlers["book all"]       = LegacyDump
  exactHandlers["spells all"]     = LegacyDump
  exactHandlers["spellbook full"] = LegacyDump
  exactHandlers["spells full"]    = LegacyDump

  exactHandlers["trainer"]              = function() TA_TrainerList(nil) end
  exactHandlers["trainer available"]    = function() TA_TrainerList("available") end
  exactHandlers["trainer unavailable"]  = function() TA_TrainerList("unavailable") end
  exactHandlers["trainer known"]        = function() TA_TrainerList("known") end
  exactHandlers["trainer used"]         = function() TA_TrainerList("used") end

  addPatternHandler("^spellbook%s+(%d+)$", function(t) TA_SpellbookListTab(tonumber(t)) end)
  addPatternHandler("^book%s+(%d+)$",      function(t) TA_SpellbookListTab(tonumber(t)) end)
  addPatternHandler("^spells%s+(%d+)$",    function(t) TA_SpellbookListTab(tonumber(t)) end)

  addPatternHandler("^spell%s+(.+)$",  function(q) TA_SpellInfo(q) end)
  addPatternHandler("^find%s+(.+)$",   function(q) TA_FindKnown(q) end)
  addPatternHandler("^findtrainer%s+(.+)$", function(q) TA_FindTrainer(q) end)
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterSpellbookCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
