# Text Adventurer (WoW Classic Era Addon)

Text Adventurer is a World of Warcraft Classic Era addon focused on text-first gameplay feedback, command-driven utilities, and tactical overlays.

## Danger Warning

This addon is intentionally extreme for Hardcore challenge play.

- It is extremely dangerous and WILL eventually get your character killed.
- First-run safety mode keeps autostart OFF by default.
- Enable autostart only if you accept the risk: `/ta autostart on`

## Features

- Text event and status output.
- Slash-command interface (`/ta ...`).
- Tactical DF mode window with multiple views.
- Per-character saved variables (`TextAdventurerDB`).

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
- DF mode shortcuts:
  - `/ta dfmode`
  - `/ta df on`
  - `/ta df off`
  - `/ta df tactical|threat|exploration|combined`

## Project Notes

- TOC interface currently targets Classic Era interface `11599`.
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

## Release Warning Text

Use the following warning at the top of both your GitHub release body and your CurseForge file/project description.

### GitHub Upload Warning

`WARNING: Text Adventurer is extremely dangerous and WILL eventually get your Hardcore character killed. Use at your own risk.`

### CurseForge Upload Warning

`WARNING: This addon is extremely dangerous for Hardcore play and WILL eventually get your character killed. First-run autostart is OFF for safety.`

## License

No license file is currently defined. Add a `LICENSE` file if you plan to distribute under specific terms.
