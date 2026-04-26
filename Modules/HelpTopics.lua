function TA_Help_ShowOverview()
  AddLine("system", "Text Adventurer help topics:")
  AddLine("system", "  combat - damage, stats, range, spacing")
  AddLine("system", "  navigation - cells, marks, map overlay")
  AddLine("system", "  quests - quest, gossip, trainer flows")
  AddLine("system", "  automation - auto behaviors and text mode")
  AddLine("system", "  economy - bags, gear, vendor, buying/selling")
  AddLine("system", "  social - chat and targeting shortcuts")
  AddLine("system", "  advanced - macros, bindings, diagnostics")
  AddLine("system", "All commands support both: <command> (terminal) and /ta <command> (chat).")
  AddLine("system", "Type: help <topic>. Example: help navigation")
end

function TA_Help_ShowTopic(topicArg)
  local raw = (topicArg or ""):match("^%s*(.-)%s*$"):lower()
  if raw == "" or raw == "all" or raw == "commands" or raw == "topics" then
    TA_Help_ShowOverview()
    return
  end

  local key = raw
  if raw == "dps" or raw == "battle" then key = "combat" end
  if raw == "nav" or raw == "cells" or raw == "map" then key = "navigation" end
  if raw == "quest" or raw == "npc" then key = "quests" end
  if raw == "auto" then key = "automation" end
  if raw == "inventory" or raw == "vendor" then key = "economy" end
  if raw == "chat" then key = "social" end
  if raw == "macros" then key = "advanced" end

  if key == "combat" then
    AddLine("system", "Help: Combat & Stats")
    AddLine("system", "  status - health and current resource summary.")
    AddLine("system", "  stats - full character stat breakdown.")
    AddLine("system", "  skills - current skill line levels (weapon/profession/defense).")
    AddLine("system", "  skills weapons|professions|secondary|defense - filtered skill views.")
    AddLine("system", "  dps - fight DPS, session DPS, and weapon DPS.")
    AddLine("system", "  dps reset - clear recorded DPS history.")
    AddLine("system", "  weapondps - main-hand and off-hand auto-attack DPS.")
    AddLine("system", "  sealdps - compare spreadsheet model DPS for SoR vs SoC.")
    AddLine("system", "  sealdps <level> - evaluate model at a specific level.")
    AddLine("system", "  sealdps set <lvl> <sor> <soc> - save one spreadsheet row.")
    AddLine("system", "  sealdps import <lvl:sor:soc,...> - bulk import spreadsheet rows.")
    AddLine("system", "  sealdps list / sealdps clear - inspect or wipe model rows.")
    AddLine("system", "  sealdps live - compute live SoR vs SoC from current character stats.")
    AddLine("system", "  sealdps live hybrid [seconds] - test JoC opener then SoR loop vs pure SoR.")
    AddLine("system", "  sealdps assumptions - view/tune live model assumptions.")
    AddLine("system", "  warlockdps - spreadsheet-backed Warlock live DPS estimate.")
    AddLine("system", "  warlockdps mode <shadow|fire> - switch Warlock model lane.")
    AddLine("system", "  warlockdps set <key> <value> - tune direct/DoT/pet/mana knobs.")
    AddLine("system", "  warlockdps assumptions|mapping|reset - inspect sheet linkage or restore defaults.")
    AddLine("system", "  warlockprompt - single next-action prompt for current target.")
    AddLine("system", "  warlockprompt on/off/status - auto-prompt control while in combat.")
    AddLine("system", "  warlockprompt set <manapct|taphpfloor> <value> - prompt tuning.")
    AddLine("system", "  ml recommend[/explain] - tree model strategy recommendation.")
    AddLine("system", "  ml xp[/explain] - XP/hour recommendation blending grinding and questing source models.")
    AddLine("system", "  ml xp mode [balanced|grind-first|quest-first] - switch leveling strategy mode.")
    AddLine("system", "  ml xp set <key> <value> - tune XP optimizer.")
    AddLine("system", "  ml xp defaults - reset XP optimizer tuning.")
    AddLine("system", "  ml xp rates - show learned grind/quest XP/hour rates and confidence.")
    AddLine("system", "  ml xp rates reset - clear learned grind/quest source rates.")
    AddLine("system", "  ml xp warrior preset <arms|fury> - load common Warrior tuning.")
    AddLine("system", "  ml xp warrior weapon <auto|slow-2h|fast-2h|one-hand|dual-wield> - tune Warrior weapon profile.")
    AddLine("system", "  ml model sample/clear - load or clear built-in ML model.")
    AddLine("system", "  ml log on/off/status/clear/max <n> - manage feature logs.")
    AddLine("system", "  ml export [n] - print recent fight logs as CSV rows.")
    AddLine("system", "  range - approximate distance to your target.")
    AddLine("system", "  fps/framerate - show current FPS in chat output.")
    AddLine("system", "  behind/backstab - positional check for rear attacks.")
    AddLine("system", "  marka, markb, spacing - geometric pull spacing estimate.")
    return
  end

  if key == "navigation" then
    AddLine("system", "Help: Navigation & Cells")
    AddLine("system", "  where - current zone/subzone and facing.")
    AddLine("system", "  markcell [name] - mark your current location cell.")
    AddLine("system", "  markedcells/listmarks - list saved cell marks.")
    AddLine("system", "  renamemark/renamecell <id> <name> - rename a marked cell.")
    AddLine("system", "  showmark <id> - highlight one mark on world map overlay.")
    AddLine("system", "  deletemark <id> - delete a specific marked cell.")
    AddLine("system", "  clearmarks - delete all saved marks.")
    AddLine("system", "  cell - current cell bounds and position-in-cell.")
    AddLine("system", "  cellsize <n|standard|inn> - grid-based cell sizing.")
    AddLine("system", "  cellyards <yards|off> - fixed-distance sizing across maps.")
    AddLine("system", "  cellcal [yards list] - test and recommend yard sizes for this map.")
    AddLine("system", "  cellanchor - recenter current grid on where you stand.")
    AddLine("system", "  cellmap on/off - world map cell overlay toggle.")
    AddLine("system", "  map - print an ASCII local map.")
    AddLine("system", "  map on/off - auto-print ASCII map on cell changes.")
    AddLine("system", "  dfmode/df [on/off] - toggle Dwarf Fortress tactical map window.")
    AddLine("system", "  df tactical/threat/exploration/combined - switch DF mode view.")
    AddLine("system", "  df hybrid or df all - alias for combined view.")
    AddLine("system", "  df profile balanced|full - balanced is fuzzier, full is precise.")
    AddLine("system", "  df orientation fixed|rotating - fixed keeps map north-up (default), rotating follows heading.")
    AddLine("system", "  df rotation smooth|octant - smooth turns freely; octant keeps geometry squarer.")
    AddLine("system", "  df square on/off - alias for octant/smooth rotation.")
    AddLine("system", "  df size <width> <height> - set DF window size by command.")
    AddLine("system", "  df grid <n> - set DF grid cell count (odd number 5-99).")
    AddLine("system", "  df markradius <0-max> - set how far mark edges extend from M.")
    AddLine("system", "  df status - print zone, facing, legend, and threat summary to chat.")
    AddLine("system", "  df sonar - show sonar settings and active contact count.")
    AddLine("system", "  df sonar ping [seconds] - temporarily amplify exact-contact sonar echoes (1-20s).")
    AddLine("system", "  df sonar ttl <seconds> - keep sonar echoes longer after contact (1-60s).")
    AddLine("system", "  df sonar clear - clear remembered sonar echoes immediately.")
    AddLine("system", "  route start <name>, route stop - record your movement path.")
    AddLine("system", "  route list/show/clear <name> - manage saved routes.")
    AddLine("system", "  route follow <name>, route follow off - text navigation prompts.")
    AddLine("system", "  explore - exploration memory and recent path output.")
    return
  end

  if key == "quests" then
    AddLine("system", "Help: Quests & NPC")
    AddLine("system", "  quests - quest log summary.")
    AddLine("system", "  questinfo <index or name> - detailed quest info.")
    AddLine("system", "  questroute - ranked recommendation for your next quest objective.")
    AddLine("system", "  questroute top <n> - show more ranked route suggestions.")
    AddLine("system", "  questroute explain - include score factors for each suggestion.")
    AddLine("system", "  questroute weights - print current route scoring weights.")
    AddLine("system", "  questroute weight <key> <value> - tune one route scoring weight.")
    AddLine("system", "  questroute on/off - enable or disable route recommendation output.")
    AddLine("system", "  questroute mark - place waypoint marker on top recommendation.")
    AddLine("system", "  questroute debug - dump candidate source/debug data for troubleshooting.")
    AddLine("system", "  gossip, choose <n> - navigate gossip without mouse.")
    AddLine("system", "  complete/turnin - complete active quest interaction.")
    AddLine("system", "  rewards, select <n>, reward <n> - choose turn-in rewards.")
    AddLine("system", "  rewardinfo <n> - inspect stats/details for one reward.")
    AddLine("system", "  prompts, accept <n>, decline <n> - handle popup dialogs.")
    AddLine("system", "  trainer, train <n>, train all - trainer service commands.")
    AddLine("system", "  recipes, recipeinfo <n> - list profession recipes and inspect reagents.")
    return
  end

  if key == "automation" then
    AddLine("system", "Help: Automation")
    AddLine("system", "  autoquests on/off - automatic quest handling.")
    AddLine("system", "  chat on/off - narration of chat traffic.")
    AddLine("system", "  autostart on/off - auto-enable on login.")
    AddLine("system", "  settings - view common game settings.")
    AddLine("system", "  set <name> <value> - shortcuts + direct CVar set.")
    AddLine("system", "  cvar <name> - read any CVar value.")
    AddLine("system", "  cvar <name> <value> - set any CVar value.")
    AddLine("system", "  cvarlist [filter] - print console CVar list to terminal.")
    AddLine("system", "  performance on/off/status - reduce UI rendering cost and tune ticker rates.")
    AddLine("system", "  textmode on/off - immersive black-screen text mode.")
    return
  end

  if key == "economy" then
    AddLine("system", "Help: Inventory & Economy")
    AddLine("system", "  inventory/bags - bag contents and free space.")
    AddLine("system", "  lootpreview - inspect corpse loot slots before taking items.")
    AddLine("system", "  gear/equipment - equipped items summary.")
    AddLine("system", "  equip <item name> - equip an item by name.")
    AddLine("system", "  equip <bag> <slot> - equip a specific bag item.")
    AddLine("system", "  money/gold/coins - show your current currency.")
    AddLine("system", "  readitem - read an open readable item, or readitem <bag> <slot>.")
    AddLine("system", "  vendor/shop - vendor inventory overview.")
    AddLine("system", "  vendorinfo <n> - inspect vendor item details before buying.")
    AddLine("system", "  buycheck <n> [qty] - check affordability before buying.")
    AddLine("system", "  buy <n> [qty] - purchase vendor items.")
    AddLine("system", "  buyback - list sold items available for buyback.")
    AddLine("system", "  buyback <index> - buy back a sold item by index.")
    AddLine("system", "  sell <bag> <slot> - sell an item from bag slot.")
    AddLine("system", "  destroy <bag> <slot> - destroy an item from bag slot.")
    AddLine("system", "  selljunk - sell all gray-quality bag items to vendor.")
    AddLine("system", "  restock <item name> <count> - buy items from vendor up to target count.")
    AddLine("system", "  repair - repair equipped gear at current vendor.")
    AddLine("system", "  repair guild - repair using guild funds if available.")
    AddLine("system", "  repairstatus - show repair cost and affordability.")
    return
  end

  if key == "social" then
    AddLine("system", "Help: Chat & Social")
    AddLine("system", "  Use slash chat in text input: /s, /p, /g, /w, /raid, /rw.")
    AddLine("system", "  who <query> - run /who and print results in the text log.")
    AddLine("system", "  who - show the current /who result list.")
    AddLine("system", "  target nearest/next/corpse/<name> - targeting shortcuts.")
    AddLine("system", "  input (or just /ta) - focus terminal input quickly.")
    AddLine("system", "  clear - clear the addon text log.")
    return
  end

  if key == "advanced" then
    AddLine("system", "Help: Advanced & Diagnostics")
    AddLine("system", "  actions/bars - action bar slot report.")
    AddLine("system", "  spells/spellbook - spellbook summary.")
    AddLine("system", "  macros - list all macros.")
    AddLine("system", "  macro <index|name> - run a macro by index or name.")
    AddLine("system", "  macroinfo <index> - inspect macro body and details.")
    AddLine("system", "  macroset <index> <body> - update macro body.")
    AddLine("system", "  macrorename <index> <name> - rename a macro.")
    AddLine("system", "  macrocreate <name> <body> - create new macro.")
    AddLine("system", "  macrodelete <index> - delete a macro.")
    AddLine("system", "  bind <slot> <spellbook idx> - put spellbook spell on action bar.")
    AddLine("system", "  bindmacro <slot> <macro idx> - put macro on action bar.")
    AddLine("system", "  binditem <slot> <bag> <slot> - put bag item on action bar.")
    AddLine("system", "  debug/debugpopups - show popup dialog diagnostics.")
    AddLine("system", "  settings - view current game cvars/settings.")
    AddLine("system", "  set <name> <value> - quick-set game settings by name.")
    AddLine("system", "  cvar <name> - read a specific cvar value.")
    AddLine("system", "  cvar <name> <value> - set a specific cvar value.")
    AddLine("system", "  cvarlist [filter] - print full console cvar list to terminal.")
    AddLine("system", "  textmode on/off - toggle immersive black-screen text mode.")
    AddLine("system", "  autostart on/off - auto-load addon on login.")
    AddLine("system", "  input - focus text input quickly (same as /ta input).")
    AddLine("system", "  hide/show/toggle - hide/show the text panel.")
    AddLine("system", "  clear - clear the addon text log.")
    return
  end

  AddLine("system", string.format("Unknown help topic '%s'.", topicArg or ""))
  TA_Help_ShowOverview()
end
