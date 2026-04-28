---@diagnostic disable: undefined-global

local PROFESSION_NAME_BY_KEY = {
  alchemy = "Alchemy",
  alch = "Alchemy",
  blacksmithing = "Blacksmithing",
  blacksmith = "Blacksmithing",
  bs = "Blacksmithing",
  enchanting = "Enchanting",
  enchant = "Enchanting",
  eng = "Engineering",
  engineering = "Engineering",
  herbalism = "Herbalism",
  herb = "Herbalism",
  leatherworking = "Leatherworking",
  lw = "Leatherworking",
  mining = "Mining",
  skinning = "Skinning",
  tailoring = "Tailoring",
  tailor = "Tailoring",
  cooking = "Cooking",
  firstaid = "First Aid",
  ["first aid"] = "First Aid",
  fishing = "Fishing",
  lockpicking = "Lockpicking",
  poisons = "Poisons",
}

local PROFESSION_DISPLAY_LIST = {
  "Alchemy",
  "Blacksmithing",
  "Enchanting",
  "Engineering",
  "Herbalism",
  "Leatherworking",
  "Mining",
  "Skinning",
  "Tailoring",
  "Cooking",
  "First Aid",
  "Fishing",
}

local function TA_NormalizeProfessionKey(raw)
  local input = tostring(raw or "")
  input = input:lower()
  input = input:gsub("[%p]", " ")
  input = input:gsub("%s+", " ")
  input = input:match("^%s*(.-)%s*$") or ""
  return input, input:gsub("%s+", "")
end

local function TA_ResolveProfessionName(raw)
  local spaced, compact = TA_NormalizeProfessionKey(raw)
  if spaced == "" then
    return nil
  end

  local direct = PROFESSION_NAME_BY_KEY[spaced] or PROFESSION_NAME_BY_KEY[compact]
  if direct then
    return direct
  end

  for key, value in pairs(PROFESSION_NAME_BY_KEY) do
    if key:find(spaced, 1, true) or key:find(compact, 1, true) then
      return value
    end
  end
  return nil
end

local function TA_OpenProfessionByCommandName(rawProfession)
  local spellName = TA_ResolveProfessionName(rawProfession)
  if not spellName then
    AddLine("system", "Usage: recipes <profession>")
    AddLine("system", "Known professions: " .. table.concat(PROFESSION_DISPLAY_LIST, ", "))
    return
  end
  -- Opening professions through CastSpellByName can trigger protected-action taint.
  AddLine("system", string.format("Open %s manually from your spellbook/trade skills, then run recipes list.", spellName))
end

local function TA_CraftRecipeIndex(index, count)
  index = tonumber(index)
  local qty = tonumber(count) or 1
  if not index or index < 1 then
    AddLine("system", "Usage: craft <index> <count>")
    return
  end
  if qty < 1 then
    AddLine("system", "Craft count must be at least 1.")
    return
  end

  if GetNumTradeSkills and GetTradeSkillInfo then
    local total = tonumber(GetNumTradeSkills()) or 0
    if total <= 0 then
      AddLine("system", "No open trade skill window. Use: recipes <profession>")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, available = GetTradeSkillInfo(index)
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    if (tonumber(available) or 0) <= 0 then
      AddLine("system", string.format("%s is not currently craftable.", name))
      return
    end
    if not DoTradeSkill then
      AddLine("system", "TradeSkill craft API unavailable.")
      return
    end

    DoTradeSkill(index, qty)
    AddLine("quest", string.format("Attempted craft: [%d] %s x%d.", index, name, qty))
    return
  end

  if GetNumCrafts and GetCraftInfo then
    local total = tonumber(GetNumCrafts()) or 0
    if total <= 0 then
      AddLine("system", "No open crafting window. Use: recipes <profession>")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, available = GetCraftInfo(index)
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    if (tonumber(available) or 0) <= 0 then
      AddLine("system", string.format("%s is not currently craftable.", name))
      return
    end
    if not DoCraft then
      AddLine("system", "Craft API unavailable.")
      return
    end

    DoCraft(index, qty)
    AddLine("quest", string.format("Attempted craft: [%d] %s x%d.", index, name, qty))
    return
  end

  AddLine("system", "Recipe API unavailable. Open a profession window and try again.")
end

local function TA_CraftAllByIndex(index)
  index = tonumber(index)
  if not index or index < 1 then
    AddLine("system", "Usage: craftall <index>")
    return
  end

  if GetNumTradeSkills and GetTradeSkillInfo then
    local total = tonumber(GetNumTradeSkills()) or 0
    if total <= 0 then
      AddLine("system", "No open trade skill window. Use: recipes <profession>")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, available = GetTradeSkillInfo(index)
    local maxCraft = tonumber(available) or 0
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    if maxCraft <= 0 then
      AddLine("system", string.format("%s is not currently craftable.", name))
      return
    end
    if not DoTradeSkill then
      AddLine("system", "TradeSkill craft API unavailable.")
      return
    end

    DoTradeSkill(index, maxCraft)
    AddLine("quest", string.format("Attempted craftall: [%d] %s x%d.", index, name, maxCraft))
    return
  end

  if GetNumCrafts and GetCraftInfo then
    local total = tonumber(GetNumCrafts()) or 0
    if total <= 0 then
      AddLine("system", "No open crafting window. Use: recipes <profession>")
      return
    end
    if index > total then
      AddLine("system", string.format("No recipe found at index %d.", index))
      return
    end

    local name, category, available = GetCraftInfo(index)
    local maxCraft = tonumber(available) or 0
    if not name or category == "header" then
      AddLine("system", "That row is a category header. Pick a recipe index.")
      return
    end
    if maxCraft <= 0 then
      AddLine("system", string.format("%s is not currently craftable.", name))
      return
    end
    if not DoCraft then
      AddLine("system", "Craft API unavailable.")
      return
    end

    DoCraft(index, maxCraft)
    AddLine("quest", string.format("Attempted craftall: [%d] %s x%d.", index, name, maxCraft))
    return
  end

  AddLine("system", "Recipe API unavailable. Open a profession window and try again.")
end

function TA_RegisterMacroRecipeCommandHandlers(exactHandlers, addPatternHandler)
  if TA.macroRecipeCommandHandlersRegistered then
    return
  end

  exactHandlers["macros"] = function() ReportMacros() end
  exactHandlers["trainer"] = function() ReportTrainerServices() end
  exactHandlers["train list"] = function() ReportTrainerServices() end
  exactHandlers["recipes"] = function() TA_ReportProfessionRecipes() end
  exactHandlers["recipe"] = function() TA_ReportProfessionRecipes() end
  exactHandlers["recipeinfo"] = function() TA_ReportProfessionRecipes() end
  exactHandlers["craft"] = function() AddLine("system", "Usage: craft <index> <count>") end
  exactHandlers["craftall"] = function() AddLine("system", "Usage: craftall <index>") end

  addPatternHandler("^macroinfo%s+(%d+)$", function(idx) ShowMacroInfo(tonumber(idx)) end)
  addPatternHandler("^macro%s+(%d+)$", function(idx) CastMacroByIndex(tonumber(idx)) end)
  addPatternHandler("^macroset%s+(%d+)%s+(.+)$", function(idx, body) SetMacroBody(tonumber(idx), body) end)
  addPatternHandler("^macrorename%s+(.+)$", function(rest)
    local idx, newName = ParseRenameArgs(rest)
    RenameMacro(idx, newName)
  end)
  addPatternHandler("^macrocreate%s+(.+)$", function(rest)
    local name, body = ParseNameAndBodyArgs(rest)
    CreateNewMacro(name, body)
  end)
  addPatternHandler("^macrodelete%s+(%d+)$", function(idx) DeleteMacroByIndex(tonumber(idx)) end)
  addPatternHandler("^macro%s+(.+)$", function(name) CastMacroByName(name) end)
  addPatternHandler("^train%s+all$", function() TrainAllAvailableServices() end)
  addPatternHandler("^train%s+(%d+)$", function(idx) TrainServiceByIndex(tonumber(idx)) end)
  addPatternHandler("^recipes%s+(.+)$", function(profession) TA_OpenProfessionByCommandName(profession) end)
  addPatternHandler("^recipeinfo%s+(%d+)$", function(idx) TA_ReportRecipeDetails(tonumber(idx)) end)
  addPatternHandler("^recipe%s+(%d+)$", function(idx) TA_ReportRecipeDetails(tonumber(idx)) end)
  addPatternHandler("^craft%s+(%d+)%s+(%d+)$", function(idx, qty) TA_CraftRecipeIndex(idx, qty) end)
  addPatternHandler("^craft%s+(%d+)$", function(idx) TA_CraftRecipeIndex(idx, 1) end)
  addPatternHandler("^craftall%s+(%d+)$", function(idx) TA_CraftAllByIndex(idx) end)

  TA.macroRecipeCommandHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterMacroRecipeCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
