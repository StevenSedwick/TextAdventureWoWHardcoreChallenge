# Text Adventurer (WoW Classic Era Addon)

Text Adventurer is a text-first command console for WoW Classic Era that combines real-time character telemetry, command-driven utilities, tactical navigation overlays, and theorycraft helpers in one addon.

## Danger Warning

This addon is intentionally extreme for Hardcore challenge play.

- It is extremely dangerous and WILL eventually get your character killed.
- First-run safety mode keeps autostart OFF by default.
- Enable autostart only if you accept the risk: `/ta autostart on`

## Core Features

- Text-first command console with timestamped output and low-friction slash commands (`/ta ...`).
- Multiline command input (Shift+Enter), comment lines (`# ...`), and block replay (`runlast`, `rerun`).
- Command autocomplete with Tab cycling.
- Character telemetry for health, resources, stats, gear, actions, bars, cooldowns, and economic signals.
- Tactical DF mode panel with threat, exploration, and combined views.
- Per-character persistence using `TextAdventurerDB`.

## Combat and Theorycraft Features

- Warlock DPS model backed by extracted spreadsheet data.
- Warrior prompt tools for combat decision support.
- Paladin seal DPS commands for quick comparison and assumptions checks.
- Live command set for assumptions, configuration, and model inspection.

## Command Utility Features

- Navigation and exploration helpers.
- Quest and social command groups.
- Macro and recipe command helpers.
- Help system with topic-based command discovery (`/ta help <topic>`).

## Tutorial

For a guided walkthrough of the terminal, command groups, and a
suggested first session, see [`TUTORIAL.md`](TUTORIAL.md).

## Install

1. Copy this folder into your AddOns directory:
   - `World of Warcraft/_classic_era_/Interface/AddOns/TextAdventurer`
2. Make sure these files exist in the addon folder:
   - `TextAdventurer.toc`
   - `textadventurer.lua`
3. Launch WoW Classic Era and enable the addon on the character select screen.

## Usage

- Open help:
  - `/ta help`
- Terminal input mode:
  - `/ta input`
- Multiline and replay:
  - Type multiple lines with Shift+Enter
  - Use `runlast` or `rerun` to replay last block
- DF mode shortcuts:
  - `/ta dfmode`
  - `/ta df on`
  - `/ta df off`
  - `/ta df tactical|threat|exploration|combined`
- Warlock spreadsheet-backed model:
  - `/ta warlockdps`
  - `/ta warlockdps assumptions`
  - `/ta warlockdps mapping`
  - `/ta warlockdps reset`
  - `/ta warlockdps set <key> <value>`
- Warrior and Paladin helpers:
  - `/ta warriorprompt`
  - `/ta warriorprompt status`
  - `/ta sealdps`
  - `/ta sealdps list`

## Project Notes

- TOC interface currently targets Classic Era interface `11508`.
- Core metadata is in `TextAdventurer.toc`.
- Primary implementation is in `textadventurer.lua`.

## Development

- Repo: `https://github.com/StevenSedwick/TextAdventureWoWHardcoreChallenge`
- Standard workflow:

```bash
git add .
git commit -m "Describe your change"
git push
```

## Warlock Spreadsheet Flow

- Spreadsheet source: `release/Zephans_Warlock_Simulation.xlsx`
- Extracted formula inventory: `release/warlock_formula_inventory.txt`
- Generated addon data: `WarlockSheetData.lua`
- Regeneration task: `Generate Warlock Sheet Data`

The Warlock live model now uses generated sheet snapshots for its baseline multipliers and exposes the mapping in-game with `/ta warlockdps mapping`.

## Release Warning Text

Use the following warning at the top of both your GitHub release body and your CurseForge file/project description.

### GitHub Upload Warning

`WARNING: Text Adventurer is extremely dangerous and WILL eventually get your Hardcore character killed. Use at your own risk.`

### CurseForge Upload Warning

`WARNING: This addon is extremely dangerous for Hardcore play and WILL eventually get your character killed. First-run autostart is OFF for safety.`

## CurseForge Project Description (Copy/Paste)

Text Adventurer is a command-first utility addon for WoW Classic Era. It gives you a terminal-style interface for gameplay telemetry, tactical overlays, and theorycraft commands without depending on heavy UI workflows.

Highlights:

- Text-first command console with timestamped output
- Multiline command input, comments, and replay (`runlast` / `rerun`)
- Tab autocomplete for faster command discovery
- Character, gear, action bar, and economy reporting commands
- Tactical DF mode overlays (threat, exploration, combined)
- Warlock spreadsheet-backed DPS model
- Warrior prompt and Paladin seal DPS helper commands
- Per-character saved settings and data

WARNING: This addon is extremely dangerous for Hardcore play and WILL eventually get your character killed. First-run autostart is OFF for safety.

## License

No license file is currently defined. Add a `LICENSE` file if you plan to distribute under specific terms.
