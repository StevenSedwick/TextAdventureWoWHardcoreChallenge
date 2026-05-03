-- Modules/TrainerAndRecipes.lua
-- Trainer-window inspection and purchase, profession recipe browsing,
-- and target-range narration.
--
-- Exported globals (already true globals in textadventurer.lua):
--   * ReportTrainerServices       -- list trainer offerings + cost/rank
--   * TrainServiceByIndex         -- buy trainer service N
--   * TrainAllAvailableServices   -- buy every available trainer skill
--   * TA_ReportRecipeDetails      -- detail a single TradeSkill recipe
--   * TA_ReportProfessionRecipes  -- list current TradeSkill recipes
--   * ReportRange                 -- narrate distance to current target
--
-- All six were already plain globals; their redundant _G.X = X mirror
-- lines in textadventurer.lua are removed.
--
-- Depends on: AddLine, FormatMoney, the Blizzard trainer/tradeskill
-- APIs (GetNumTrainerServices, GetTrainerServiceInfo, BuyTrainerService,
-- GetTradeSkillInfo, ...), C_Map.GetBestMapForUnit/GetPlayerMapPosition/
-- GetMapInfo, UnitExists, UnitName, GetItemInfo, GetSpellInfo, etc.
--

function ReportTrainerServices()
  local function TA_GetTrainerServiceNumAbilityReqCompat(serviceIndex)
    if not GetTrainerServiceNumAbilityReq then
      return 0
    end

    local ok, value = pcall(GetTrainerServiceNumAbilityReq, serviceIndex)
    if ok and tonumber(value) then
      return math.max(0, math.floor(tonumber(value) or 0))
    end

    ok, value = pcall(GetTrainerServiceNumAbilityReq)
    if ok and tonumber(value) then
      return math.max(0, math.floor(tonumber(value) or 0))
    end

    return 0
  end

  local function TA_GetTrainerServiceAbilityReqCompat(serviceIndex, reqIndex)
    if not GetTrainerServiceAbilityReq then
      return nil, nil
    end

    local ok, reqName, hasReq = pcall(GetTrainerServiceAbilityReq, serviceIndex, reqIndex)
    if ok then
      return reqName, hasReq
    end

    ok, reqName, hasReq = pcall(GetTrainerServiceAbilityReq, reqIndex)
    if ok then
      return reqName, hasReq
    end

    return nil, nil
  end

  if not GetNumTrainerServices or not GetTrainerServiceInfo then
    AddLine("system", "Trainer API unavailable.")
    return
  end
  local num = GetNumTrainerServices() or 0
  if num <= 0 then
    AddLine("system", "No trainer services available.")
    return
  end
  local shown = 0
  for i = 1, num do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name then
      local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
      local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
      local reqText = ""
      if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        local reqCount = TA_GetTrainerServiceNumAbilityReqCompat(i)
        local reqParts = {}
        for r = 1, reqCount do
          local reqName, hasReq = TA_GetTrainerServiceAbilityReqCompat(i, r)
          if reqName and not hasReq then table.insert(reqParts, reqName) end
        end
        if #reqParts > 0 then reqText = " | Missing: " .. table.concat(reqParts, ", ") end
      end
      AddLine("cast", string.format("[%d] %s%s | %s | Cost: %d | Level: %d%s", i, name, rank and rank ~= "" and (" (" .. rank .. ")") or "", tostring(category), cost or 0, levelReq or 0, reqText))
      shown = shown + 1
    end
  end
  if shown == 0 then AddLine("system", "Trainer window is open, but no skills were found.") end
end

function TrainServiceByIndex(index)
  if not index or index < 1 then
    AddLine("system", "Invalid trainer index.")
    return
  end
  if not BuyTrainerService or not GetTrainerServiceInfo then
    AddLine("system", "Trainer purchase API unavailable.")
    return
  end
  local name = GetTrainerServiceInfo(index)
  if not name then
    AddLine("system", string.format("No trainer service found at index %d.", index))
    return
  end
  BuyTrainerService(index)
  AddLine("quest", string.format("Attempted to train [%d] %s.", index, name))
end

function TrainAllAvailableServices()
  if not GetNumTrainerServices or not GetTrainerServiceInfo or not BuyTrainerService then
    AddLine("system", "Trainer API unavailable.")
    return
  end
  local num = GetNumTrainerServices() or 0
  local bought = 0
  for i = 1, num do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name and category == "available" then
      BuyTrainerService(i)
      AddLine("quest", string.format("Attempted to train [%d] %s%s.", i, name, rank and rank ~= "" and (" (" .. rank .. ")") or ""))
      bought = bought + 1
    end
  end
  if bought == 0 then AddLine("system", "No currently available trainer skills to buy.") end
end

function TA_ReportRecipeDetails(index)
  index = tonumber(index)
  if not index or index < 1 then
    AddLine("system", "Usage: recipeinfo <index>")
    return
  end

  if GetNumTradeSkills and GetTradeSkillInfo then
    local total = tonumber(GetNumTradeSkills()) or 0
    if total <= 0 then
      AddLine("system", "No open trade skill window.")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, numAvailable = GetTradeSkillInfo(index)
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    AddLine("cast", string.format("Recipe [%d]: %s | Available: %s", index, name, tostring(numAvailable or 0)))

    if GetTradeSkillNumMade then
      local madeMin, madeMax = GetTradeSkillNumMade(index)
      if madeMin and madeMax and madeMax > 0 then
        if madeMin == madeMax then
          AddLine("cast", string.format("Produces: %d", madeMin))
        else
          AddLine("cast", string.format("Produces: %d-%d", madeMin, madeMax))
        end
      end
    end

    if GetTradeSkillNumReagents and GetTradeSkillReagentInfo then
      local reagentCount = tonumber(GetTradeSkillNumReagents(index)) or 0
      if reagentCount > 0 then
        AddLine("cast", "Reagents:")
        for r = 1, reagentCount do
          local reagentName, _, needed, owned = GetTradeSkillReagentInfo(index, r)
          if reagentName then
            AddLine("cast", string.format("  - %s x%d (you have %d)", reagentName, tonumber(needed) or 0, tonumber(owned) or 0))
          end
        end
      end
    end

    if GetTradeSkillTools then
      local tools = GetTradeSkillTools(index)
      if tools and tools ~= "" then
        AddLine("cast", "Tools: " .. tools)
      end
    end
    return
  end

  if GetNumCrafts and GetCraftInfo then
    local total = tonumber(GetNumCrafts()) or 0
    if total <= 0 then
      AddLine("system", "No open crafting window.")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, numAvailable = GetCraftInfo(index)
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    AddLine("cast", string.format("Recipe [%d]: %s | Available: %s", index, name, tostring(numAvailable or 0)))

    if GetCraftNumReagents and GetCraftReagentInfo then
      local reagentCount = tonumber(GetCraftNumReagents(index)) or 0
      if reagentCount > 0 then
        AddLine("cast", "Reagents:")
        for r = 1, reagentCount do
          local reagentName, _, needed, owned = GetCraftReagentInfo(index, r)
          if reagentName then
            AddLine("cast", string.format("  - %s x%d (you have %d)", reagentName, tonumber(needed) or 0, tonumber(owned) or 0))
          end
        end
      end
    end

    if GetCraftDescription then
      local desc = GetCraftDescription(index)
      if desc and desc ~= "" then
        AddLine("cast", "Description: " .. desc)
      end
    end
    return
  end

  AddLine("system", "Recipe API unavailable on this client.")
end

function TA_ReportProfessionRecipes()
  if GetNumTradeSkills and GetTradeSkillInfo then
    local total = tonumber(GetNumTradeSkills()) or 0
    if total <= 0 then
      AddLine("system", "No open trade skill window.")
      return
    end

    local skillName = (GetTradeSkillLine and GetTradeSkillLine()) or "Trade Skill"
    AddLine("cast", string.format("%s recipes:", tostring(skillName)))
    local shown = 0
    for i = 1, total do
      local name, category, numAvailable = GetTradeSkillInfo(i)
      if name then
        if category == "header" then
          AddLine("cast", string.format("-- %s --", name))
        else
          AddLine("cast", string.format("[%d] %s | Available: %s", i, name, tostring(numAvailable or 0)))
          shown = shown + 1
        end
      end
    end
    if shown == 0 then
      AddLine("system", "No craftable recipes were found in this trade skill window.")
    else
      AddLine("system", "Use: recipeinfo <index> for reagent details.")
    end
    return
  end

  if GetNumCrafts and GetCraftInfo then
    local total = tonumber(GetNumCrafts()) or 0
    if total <= 0 then
      AddLine("system", "No open crafting window.")
      return
    end

    local skillName = (GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()) or "Crafting"
    AddLine("cast", string.format("%s recipes:", tostring(skillName)))
    local shown = 0
    for i = 1, total do
      local name, category, numAvailable = GetCraftInfo(i)
      if name then
        if category == "header" then
          AddLine("cast", string.format("-- %s --", name))
        else
          AddLine("cast", string.format("[%d] %s | Available: %s", i, name, tostring(numAvailable or 0)))
          shown = shown + 1
        end
      end
    end
    if shown == 0 then
      AddLine("system", "No craftable recipes were found in this crafting window.")
    else
      AddLine("system", "Use: recipeinfo <index> for reagent details.")
    end
    return
  end

  AddLine("system", "Recipe API unavailable. Open a profession window and try again.")
end

function ReportRange()
  if not UnitExists("target") then
    AddLine("system", "You have no target.")
    return
  end
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then
    AddLine("system", "Map position unavailable.")
    return
  end
  local px, py, tx, ty
  if C_Map and C_Map.GetPlayerMapPosition then
    local playerPos = C_Map.GetPlayerMapPosition(mapID, "player")
    local targetPos = C_Map.GetPlayerMapPosition(mapID, "target")
    if playerPos and targetPos then
      px, py = playerPos:GetXY()
      tx, ty = targetPos:GetXY()
    end
  elseif GetPlayerMapPosition then
    px, py = GetPlayerMapPosition("player")
    tx, ty = GetPlayerMapPosition("target")
  end
  if not px or not py or not tx or not ty then
    AddLine("system", "Could not read positions for range calculation.")
    return
  end
  if px == 0 and py == 0 and tx == 0 and ty == 0 then
    AddLine("system", "Position data incomplete.")
    return
  end
  -- Map coordinates are 0-1 fractions of the map tile.
  -- Multiply by the map's reported dimensions to get yards.
  local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local mapWidth  = mapInfo and mapInfo.width  or 0
  local mapHeight = mapInfo and mapInfo.height or 0
  local yardDist
  if mapWidth > 0 and mapHeight > 0 then
    local dx = (tx - px) * mapWidth
    local dy = (ty - py) * mapHeight
    yardDist = math.sqrt(dx * dx + dy * dy)
  else
    -- Fallback: use raw coordinate distance with a rough scale
    local dx = tx - px
    local dy = ty - py
    yardDist = math.sqrt(dx * dx + dy * dy) * 100
  end
  if not yardDist then
    AddLine("system", "Could not determine range right now.")
    return
  end
  local name = UnitName("target") or "target"
  local rangeDesc
  if yardDist < 5 then
    rangeDesc = "right next to you"
  elseif yardDist < 10 then
    rangeDesc = "very close"
  elseif yardDist < 20 then
    rangeDesc = "within melee reach"
  elseif yardDist < 35 then
    rangeDesc = "at short range"
  elseif yardDist < 60 then
    rangeDesc = "at medium range"
  else
    rangeDesc = "far away"
  end
  AddLine("target", string.format("%s is approximately %.0f yards away (%s).", name, yardDist, rangeDesc))
end
