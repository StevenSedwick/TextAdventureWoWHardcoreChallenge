---
description: "Review ASCIIMUD data collection and how collected world data is translated into the Text Adventurer HUD"
name: "ASCIIMUD Data HUD Review"
argument-hint: "Optional focus, e.g. terrain compiler, look telemetry, DF HUD symbols, accessibility labels"
agent: "agent"
model: "Claude Opus 4.7 (copilot)"
---

You are reviewing the Text Adventurer WoW Classic Era addon, with a focus on ASCIIMUD: the ASCII-MUD-style world/HUD experience built from collected terrain, telemetry, labels, and in-game state. Use Claude 4.7 for this review. If the prompt runner does not automatically select Claude 4.7 from frontmatter, switch to Claude 4.7 manually before continuing.

Primary goals:

1. Evaluate whether the data currently collected is sufficient for a useful ASCIIMUD HUD.
2. Identify improvements to the data schema, collection workflow, compiler output, and runtime translation layer.
3. Review how terrain, markers, telemetry, labels, exploration state, mobs, targets, and player orientation become HUD symbols, colors, text, and tactical hints.
4. Recommend safer next steps that improve usefulness without violating WoW Classic Era addon constraints.

Start with these files and areas:

- [README](../../README.md) for feature intent and command surface.
- [textadventurer.lua](../../textadventurer.lua), especially:
  - terrain loading and indexing around `TA_GetLoadedTerrainData`, `TA_GetTerrainChunkIndex`, `TA_BuildTerrainMarkerDensity`, and terrain lookup helpers
  - map/cell/world conversion around `GetMapWorldDimensions`, `GetCellGridForMap`, `ComputeCellForPosition`, and `TA_GetEffectiveDFYardsPerCell`
  - ASCIIMUD/DF HUD rendering around `BuildDFModeDisplay`, `TA_UpdateDFMode`, mark rendering, unit placement, rotation, and cached display state
  - `/look` and accessibility data paths if present in this file
- [Modules/AccessibilityCommands.lua](../../Modules/AccessibilityCommands.lua) for `/ta look telemetry`, `/ta look export`, labels, and data-collection commands.
- [Modules/NavigationCommands.lua](../../Modules/NavigationCommands.lua) for map, DF, HUD, copy/export, and user-facing navigation commands.
- [Modules/HelpTopics.lua](../../Modules/HelpTopics.lua) and [Modules/Commands.lua](../../Modules/Commands.lua) only as needed to confirm user-facing command names and debug surfaces.
- [tools/terrain_compiler/README.md](../../tools/terrain_compiler/README.md) and the compiler implementation only as needed to understand generated terrain schema.
- [tools/look_accessibility/training/README.txt](../../tools/look_accessibility/training/README.txt) and related scripts only as needed to understand telemetry, screenshots, labels, and model output.
- [TerrainData_Azeroth.lua](../../TerrainData_Azeroth.lua) only sample small sections if needed to confirm output shape; do not read the whole file unless necessary.

Context and constraints:

- This is a WoW Classic Era addon. Do not recommend gameplay automation, protected frame manipulation in combat, prohibited input automation, or retail-only APIs.
- The HUD should serve accessibility, situational awareness, and exploration. It should not play the game for the player.
- Runtime data must stay lightweight enough for Classic Era addon performance limits.
- Prefer improvements that make collected data more consistent, inspectable, and testable before recommending large rewrites.
- Separate what can be proven statically from what needs in-game sampling or profiling.
- Treat ASCIIMUD output as user-facing UI: symbol choice, color meaning, copyable ASCII, and spoken/readable text all matter.

Review questions:

1. Data being collected:
   - What world, terrain, camera, player, target, nearby-unit, label, screenshot, and exploration fields are currently collected?
   - Which important ASCIIMUD HUD concepts are missing or under-specified, such as roads, water, slopes, buildings, doors, caves, obstacles, cliffs, hostile density, interactables, vendors, quest objectives, safe paths, or line-of-sight blockers?
   - Are position, map ID, zone key, facing, pitch, zoom, cell size, and timestamp represented consistently enough to join telemetry, screenshots, terrain chunks, and HUD output?
   - Are labels normalized enough for training, debugging, and future expansion?

2. Data quality and schema:
   - Are collected rows reproducible and traceable back to zone/map/tile/chunk/cell?
   - Should samples include confidence, source, version, collection method, viewport/HUD settings, or addon/compiler schema version?
   - Are there fields that should be derived at compile time instead of calculated every HUD tick?
   - Are there fields that should stay runtime-only because they depend on live game state?

3. Translation into HUD:
   - How does terrain data become ASCIIMUD symbols, colors, density, warnings, and descriptive text?
   - Are symbol priorities clear when terrain, water, slope, markers, mobs, target, player, marks, and exploration state overlap?
   - Are rotation and world-to-screen conventions correct and explainable?
   - Does the HUD preserve enough context for blind/low-vision use when copied as plain ASCII or read by screen readers?
   - Are there better symbol sets, legends, or compact metadata lines that would make the HUD easier to interpret?

4. Collection workflow improvements:
   - How can `/ta look telemetry`, labels, screenshot capture, video-frame collection, and terrain compiler output be made easier to correlate?
   - What small command additions or export formats would reduce manual mistakes?
   - Would JSONL, CSV schema changes, deterministic sample IDs, or embedded schema/version fields improve the pipeline?
   - What validation should run before accepting a sample?

5. Runtime and performance:
   - What data should be cached, chunk-indexed, pre-binned, or pre-rendered?
   - Which improvements risk increasing DF/ASCIIMUD tick cost, memory, string churn, or saved-variable bloat?
   - What can be debug-rendered on demand instead of every tick?

Expected output:

1. **Executive summary**: the biggest gaps between collected data and useful ASCIIMUD HUD output.
2. **Current pipeline map**: concise flow from external extraction/training data to in-game HUD rendering.
3. **Data inventory**: table of current fields/sources, what they support in the HUD, and limitations.
4. **Missing data recommendations**: ranked list of new fields or derived features, with why each matters.
5. **HUD translation findings**: symbol priority, accessibility, rotation, terrain/marker/unit mapping, and copy/export concerns.
6. **Schema and workflow proposal**: concrete changes to telemetry/export rows, compiler output, labels, or validation.
7. **Low-risk patch candidates**: small Lua/Python changes or pseudocode, but do not apply changes unless explicitly asked.
8. **Validation checklist**: in-game and offline checks to confirm data quality, HUD correctness, and performance.

If an observation is uncertain, label it clearly as a hypothesis and say what measurement or sample would confirm it.
