-- TargetingAndWho.lua
-- DoTargetCommand (target nearest/next/corpse/<name>), TA_ReportWhoList, TA_RunWhoQuery.
-- Extracted from textadventurer.lua. All globals; references TA.dfModeCorpseContacts and
-- AddLine by name.

function DoTargetCommand(arg)
  if not arg or arg == "" then
    AddLine("system", "Usage: target nearest, target next, target corpse, or target <name>")
    return
  end
  local lower = arg:lower()
  if lower == "nearest" then
    if TargetNearestEnemy then
      TargetNearestEnemy()
      AddLine("target", "You attempt to target the nearest enemy.")
    else
      AddLine("system", "Nearest-enemy targeting unavailable.")
    end
  elseif lower == "next" then
    if TargetNearestEnemy then
      TargetNearestEnemy()
      AddLine("target", "You cycle to the next nearby enemy.")
    else
      AddLine("system", "Target cycling unavailable.")
    end
  elseif lower == "corpse" then
    -- TargetNearestEnemy() does not pick up corpses in Classic Era. Instead,
    -- use our tracked dfModeCorpseContacts list and target the closest one
    -- by name via TargetUnit. Falls back to TargetNearestEnemy(true) if we
    -- have no recent corpse contacts (some private servers do honor it).
    local now = (GetTime and GetTime()) or 0
    local px, py
    if UnitPosition then px, py = UnitPosition("player") end
    local bestName, bestDist
    for _, c in pairs(TA.dfModeCorpseContacts or {}) do
      if type(c) == "table" and c.name and c.expiresAt and c.expiresAt > now then
        local d
        if px and py and c.worldX and c.worldY then
          local dx = c.worldX - px
          local dy = c.worldY - py
          d = (dx * dx) + (dy * dy)
        else
          d = math.huge
        end
        if not bestDist or d < bestDist then
          bestDist = d
          bestName = c.name
        end
      end
    end
    if bestName and TargetUnit then
      TargetUnit(bestName)
      AddLine("target", "You attempt to target the corpse of " .. bestName .. ".")
    elseif TargetNearestEnemy then
      TargetNearestEnemy(true)
      AddLine("target", "You attempt to target the nearest corpse.")
    else
      AddLine("system", "Corpse targeting unavailable.")
    end
  else
    if TargetByName then
      TargetByName(arg, true)
      AddLine("target", "You attempt to target " .. arg .. ".")
    else
      AddLine("system", "Name targeting unavailable.")
    end
  end
end


function TA_ReportWhoList()
  local getNumWho = GetNumWhoResults or (C_FriendList and C_FriendList.GetNumWhoResults)
  local getWhoInfo = GetWhoInfo or (C_FriendList and C_FriendList.GetWhoInfo)
  if not getNumWho or not getWhoInfo then
    AddLine("system", "Who API unavailable.")
    return
  end

  local count = getNumWho() or 0
  if count <= 0 then
    AddLine("social", "No /who results to display.")
    return
  end

  local queryLabel = TA.pendingWhoQuery and (" for '" .. TA.pendingWhoQuery .. "'") or ""
  AddLine("social", string.format("/who results%s (%d):", queryLabel, count))
  local maxShown = math.min(count, 50)
  for i = 1, maxShown do
    local result1, result2, result3, result4, result5, result6 = getWhoInfo(i)
    local name, guild, level, race, className, zone
    
    -- Handle table-based API (new C_FriendList) vs multi-value return (legacy GetWhoInfo)
    if type(result1) == "table" then
      name = result1.fullName
      guild = result1.fullGuildName
      level = result1.level
      race = result1.raceStr
      className = result1.classStr
      zone = result1.area
    else
      name = result1
      guild = result2
      level = result3
      race = result4
      className = result5
      zone = result6
    end
    
    if name then
      local guildText = (guild and guild ~= "") and (" <" .. guild .. ">") or ""
      local levelText = level and tostring(level) or "?"
      local classText = className or "Unknown"
      local zoneText = zone or "Unknown zone"
      AddLine("social", string.format("[%d] %s%s - %s %s in %s", i, name, guildText, levelText, classText, zoneText))
    end
  end
  if count > maxShown then
    AddLine("social", string.format("(Showing first %d of %d results)", maxShown, count))
  end
end

function TA_RunWhoQuery(query)
  local q = (query or ""):match("^%s*(.-)%s*$")
  local sendWho = SendWho or (C_FriendList and C_FriendList.SendWho)
  if not sendWho then
    AddLine("system", "Who API unavailable.")
    return
  end
  if q == "" then
    TA_ReportWhoList()
    return
  end

  TA.pendingWhoQuery = q
  sendWho(q)
  AddLine("social", string.format("Querying /who: %s", q))
end
