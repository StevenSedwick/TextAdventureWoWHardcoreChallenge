---
description: "Review Text Adventurer DF mode performance, frame-rate impact, movement feel, world scale, and cell-size math"
name: "DF Mode Performance Review"
argument-hint: "Optional focus, e.g. terrain sampling, ticker cadence, cell sizing, movement feel"
agent: "agent"
model: "Claude Opus 4.7 (copilot)"
---

You are reviewing the Text Adventurer WoW Classic Era addon, with a narrow focus on DF mode performance and the math behind its grid scale. Use Claude 4.7 for this review. If the prompt runner does not automatically select Claude 4.7 from frontmatter, switch to Claude 4.7 manually before continuing.

Primary goals:

1. Identify why DF mode may pull down frame rate and which code paths are most likely responsible.
2. Recommend safer optimizations that preserve the current user experience and Classic Era addon constraints.
3. Review the math for cell size, movement feel, DF grid size, world-size conversion, target/unit placement, rotation, and mark rendering.
4. Propose a more intuitive default fit, if one exists, for:
   - yards per cell
   - DF mode grid size / radius
   - ticker cadence
   - player lookahead / hysteresis
   - world-map cell sizing

Start with these files and areas:

- [README](../../README.md) for feature intent and DF mode commands.
- [textadventurer.lua](../../textadventurer.lua), especially:
  - defaults around `TA.cellSizeMode`, `TA.cellSizeYards`, `TA.dfModeGridSize`, `TA.dfModeLookaheadSeconds`, `TA.dfModeHysteresisEnterPct`, and `TA.tickerIntervals`
  - `GetMapWorldDimensions`, `GetCellGridForMap`, `ComputeCellForPosition`, `SetCellSizeYards`, and `TA_ReportCellYardsCalibration`
  - `BuildDFModeDisplay`
  - `TA_UpdateDFMode`
  - `TA_GetEffectiveDFYardsPerCell`
  - `TA_GetProjectedDFPlayerWorldPosition`
  - runtime tickers in `TA_EnsureRuntimeTickers`
  - performance commands around `TA_ReportFPS`, `TA_SetTickerProfile`, and performance mode
- [Modules/DFDanger.lua](../../Modules/DFDanger.lua) for passive hazard work done during DF updates.
- [TerrainData_Azeroth.lua](../../TerrainData_Azeroth.lua) only as needed to understand terrain lookup cost and data shape; do not read the whole file unless necessary.
- [Modules/Commands.lua](../../Modules/Commands.lua) and [Modules/HelpTopics.lua](../../Modules/HelpTopics.lua) only as needed to confirm command surface and user-facing defaults.

Context and constraints:

- This is a WoW Classic Era addon. Avoid recommendations that require forbidden automation, protected frame manipulation in combat, or retail-only APIs.
- Prefer low-risk optimizations over rewrites.
- Do not silently remove safety or tactical information from DF mode.
- Treat user perception as important: DF mode should feel stable, responsive, and intuitive while moving.
- Call out any recommendations that need in-game profiling because they cannot be proven statically.

Review questions:

1. Performance / frame-rate pull:
   - What work happens every DF tick?
   - Is the DF ticker cadence too aggressive for the amount of terrain, unit, rotation, string, color, or font-string work?
   - Can any terrain sampling, trigonometry, string construction, color formatting, unit collection, or DFDanger work be cached, amortized, skipped, or made dirty-state driven?
   - Are there redundant calculations inside nested grid loops?
   - Are `GetText`/`SetText` updates already minimized enough, or is the display string generation itself the bigger cost?
   - Should different DF view modes use different tick rates or different render radii?

2. Math / scale:
   - Does `1 DF grid cell = yardsPerCell yards` map cleanly across world coordinates, map percent coordinates, marks, target placement, and terrain lookup?
   - Is the default `30` yard world-map cell size intuitive for marked places, and is the DF display's effective cell size intuitive for combat navigation?
   - Is `dfModeGridSize = 35` a good default once each rendered row is visually two characters wide per column?
   - Does `innerRadius = ceil(radius * 1.45)` make sense for smooth rotation, or should it vary by rotation mode?
   - Are lookahead and hysteresis values making movement feel responsive without causing jitter or incorrect mark/unit alignment?
   - Are axis conventions clear and correct for WoW Classic `UnitPosition`, map-space Y, north/east, and screen-space rotation?

3. Better fit:
   - Recommend candidate presets such as "performance", "balanced", and "full", with suggested values for grid size, terrain radius, DF ticker interval, nearby cache interval, yards per DF cell, lookahead, and hysteresis.
   - Explain the perceptual tradeoff for each preset.
   - If one preset should become the default, justify it.

Expected output:

1. **Executive summary**: the most likely causes of frame-rate pull and the best overall direction.
2. **Hot spots**: ranked list of specific functions/loops/settings with evidence from the code.
3. **Math findings**: issues or confirmations for cell size, movement, world size, rotation, and mark/unit placement.
4. **Recommended defaults**: a compact table of current value, proposed value, why it feels better, and risk.
5. **Optimization plan**: staged changes from safest to riskiest.
6. **Patch candidates**: concrete Lua-level suggestions or small diffs/pseudocode, but do not apply changes unless explicitly asked.
7. **Profiling checklist**: in-game commands or measurements to confirm the hypothesis before and after changes.

If an observation is uncertain, label it clearly as a hypothesis and say what measurement would confirm it.
