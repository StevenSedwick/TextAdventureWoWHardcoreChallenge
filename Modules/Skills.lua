-- Skills.lua
-- Skill snapshot, category labels, and skill-level reporting.
-- Extracted from textadventurer.lua. All three functions are global; AddLine and TA are
-- referenced by name (resolved at call time).

function TA_BuildSkillSnapshot()
  local snapshot = {}
  if not GetNumSkillLines or not GetSkillLineInfo then
    return snapshot
  end

  local count = GetNumSkillLines() or 0
  for i = 1, count do
    local skillName, isHeader, _, skillRank, _, skillModifier, skillMaxRank = GetSkillLineInfo(i)
    if skillName and skillName ~= "" and not isHeader and tonumber(skillMaxRank or 0) > 0 then
      snapshot[skillName] = {
        rank = tonumber(skillRank) or 0,
        max = tonumber(skillMaxRank) or 0,
        modifier = tonumber(skillModifier) or 0,
      }
    end
  end
  return snapshot
end

function TA_GetSkillCategory(name)
  if not name then return "other" end
  local lower = string.lower(name)
  local WEAPON_SKILLS = {
    axes = true, swords = true, maces = true, daggers = true, staves = true,
    polearms = true, bows = true, guns = true, crossbows = true, fist = true,
    thrown = true, unarmed = true,
  }
  WEAPON_SKILLS["two-handed swords"] = true
  WEAPON_SKILLS["two-handed maces"] = true
  WEAPON_SKILLS["two-handed axes"] = true
  local PROF_SKILLS = {
    alchemy = true, blacksmithing = true, enchanting = true, engineering = true,
    herbalism = true, mining = true, skinning = true, tailoring = true,
    leatherworking = true, cooking = true, fishing = true, firstaid = true,
  }
  PROF_SKILLS["first aid"] = true
  local SECONDARY_SKILLS = {
    cooking = true, fishing = true, firstaid = true,
  }
  SECONDARY_SKILLS["first aid"] = true

  if WEAPON_SKILLS[lower] or lower:find("two%-handed") then return "weapon" end
  if lower == "defense" or lower == "defence" then return "defense" end
  if SECONDARY_SKILLS[lower] then return "secondary" end
  if PROF_SKILLS[lower] then return "profession" end
  return "other"
end

function TA_ReportSkillLevels(force, filter)
  filter = (filter or "all"):lower()
  local current = TA_BuildSkillSnapshot()
  if not next(current) then
    if force then
      AddLine("system", "Skill API unavailable or no skill lines found.")
    end
    TA.skillSnapshot = current
    return
  end

  if force then
    local names = {}
    for name in pairs(current) do
      local cat = TA_GetSkillCategory(name)
      if filter == "all"
        or (filter == "weapon" and cat == "weapon")
        or (filter == "weapons" and cat == "weapon")
        or (filter == "profession" and cat == "profession")
        or (filter == "professions" and cat == "profession")
        or (filter == "secondary" and cat == "secondary")
        or (filter == "defense" and cat == "defense") then
        table.insert(names, name)
      end
    end
    table.sort(names)
    AddLine("status", string.format("Skills tracked (%s): %d", filter, #names))
    for i = 1, #names do
      local name = names[i]
      local row = current[name]
      local modText = (row.modifier and row.modifier ~= 0) and string.format(" (%+d)", row.modifier) or ""
      AddLine("status", string.format("  %s: %d/%d%s [%s]", name, row.rank or 0, row.max or 0, modText, TA_GetSkillCategory(name)))
    end
    TA.skillSnapshot = current
    return
  end

  local previous = TA.skillSnapshot or {}
  for name, now in pairs(current) do
    local before = previous[name]
    if not before then
      AddLine("status", string.format("Skill learned: %s (%d/%d)", name, now.rank or 0, now.max or 0))
    elseif (now.rank or 0) ~= (before.rank or 0) or (now.max or 0) ~= (before.max or 0) or (now.modifier or 0) ~= (before.modifier or 0) then
      AddLine("status", string.format("Skill update: %s %d/%d -> %d/%d", name, before.rank or 0, before.max or 0, now.rank or 0, now.max or 0))
    end
  end
  TA.skillSnapshot = current
end
