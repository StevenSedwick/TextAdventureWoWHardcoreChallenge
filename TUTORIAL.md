# Text Adventurer Tutorial

A walkthrough of the Text Adventurer console for WoW Classic Era. This
tutorial covers what the addon does, how to operate the terminal, and the
command groups you will rely on most often.

> **Hardcore warning.** Text Adventurer is intentionally extreme for
> Hardcore Challenge play. It will eventually get your character killed.
> Read every section below before turning anything on.

---

## 1. What Text Adventurer Is

Text Adventurer is a text-first command console. Instead of clicking
through windows, you type short commands into a terminal and read the
results in a scrolling log. It is built for players who want to:

- Drive WoW Classic Era from a keyboard-only, text-style interface.
- Read the world through descriptions, telemetry, and tactical overlays
  rather than the standard UI.
- Use theorycraft helpers (Warlock DPS model, Warrior/Paladin prompts,
  Seal of Righteousness comparisons) without leaving the keyboard.
- Run a self-imposed Hardcore Challenge that pushes against normal play
  conventions.

It is not a combat bot. Every action in combat is still your decision,
your keypress, and your responsibility.

---

## 2. Install and First Launch

1. Copy the `TextAdventurer` folder into your AddOns directory:
   `World of Warcraft/_classic_era_/Interface/AddOns/TextAdventurer`
2. Verify the folder contains `TextAdventurer.toc` and `textadventurer.lua`.
3. Launch WoW Classic Era. On the character select screen, click
   `AddOns` and make sure Text Adventurer is enabled.
4. Log in. The first time you run the addon you will see a red warning
   in chat:

   ```
   [Text Adventurer WARNING] Autostart is OFF.
   Use /ta autostart on to enable auto-open on login.
   ```

   This is the **first-run safety mode**. The addon does not auto-open
   its window until you opt in. Leave it off until you have read the
   tutorial.

---

## 3. The Terminal

Open the terminal:

```
/ta
```

Or focus the input box explicitly:

```
/ta input
```

You can type commands two ways:

- In the terminal input box: just type `status`.
- In the chat window: type `/ta status`.

Both forms are equivalent. The rest of this tutorial uses the `/ta`
form because it works whether the terminal is open or not.

Useful terminal controls:

- `Shift+Enter` writes a second line in the same submission.
- Lines starting with `#` are comments and are ignored.
- `runlast`, `run last`, or `rerun` replays the last submitted block.
- `Tab` cycles through autocomplete candidates.
- `/ta hide`, `/ta show`, `/ta toggle` control the panel visibility.
- `/ta clear` clears the addon log.

---

## 4. Help System

Help is organized by topic. Start here:

```
/ta help
```

That prints the topic list. Drill into one with:

```
/ta help navigation
/ta help combat
/ta help quests
/ta help economy
/ta help automation
/ta help social
/ta help accessibility
/ta help advanced
/ta help testing
```

The topic listings are the canonical command reference. This tutorial is
a guided tour through the same material with usage notes and ordering.

---

## 5. Reading Your Character

The character readouts are the safest commands to learn first. Nothing
here changes the world.

```
/ta status        # health and current resource
/ta stats         # full stat sheet
/ta xp            # experience progress
/ta buffs         # buffs and timers
/ta gear          # equipped items summary
/ta inventory     # bag contents and free space
/ta money         # current currency
/ta skills        # weapon/profession/defense skill levels
```

For combat readouts:

```
/ta dps           # fight DPS, session DPS, weapon DPS
/ta weapondps     # main-hand and off-hand auto DPS
/ta range         # approximate distance to current target
/ta behind        # positional check for rear attacks
```

---

## 6. Navigation and the Cell Grid

Text Adventurer overlays the world with a **cell grid**. Each cell is a
fixed area you can mark, list, and navigate by name. This is what
replaces the minimap when you play headless.

```
/ta where         # zone, subzone, facing
/ta cell          # current cell bounds and your position in it
/ta map           # ASCII map of the area around you
```

Marking and recalling locations:

```
/ta markcell Quest_Giver_A
/ta markedcells           # list all marks
/ta showmark 3            # highlight one mark on the world map
/ta deletemark 3
```

Tune the grid:

```
/ta cellyards 40          # set cell size to a fixed yard distance
/ta cellanchor            # recenter the grid on your current spot
```

### DF Mode (tactical map window)

DF Mode is a Dwarf-Fortress-style ASCII tactical overlay. It is the
densest source of awareness in the addon.

```
/ta df on                 # turn it on
/ta df off                # turn it off
/ta df combined           # threat + exploration view
/ta df threat             # show only threat overlay
/ta df exploration        # show only what you have seen
/ta df status             # print summary to chat
```

Tuning DF Mode:

```
/ta df grid 31            # 31x31 cells (odd numbers between 5 and 99)
/ta df markradius 4       # how far marked-cell halos extend
/ta df hue on             # color tiles by terrain type
/ta df legend on          # show legend overlay
/ta df orientation rotating   # rotate the map with your facing
```

DF Mode is purely visual. It never moves you and never targets anything.

---

## 7. Quests and NPC Flows

These commands let you read quest text, accept and turn in quests, and
plan your next objective without using the mouse.

```
/ta quests                # quest log summary
/ta questinfo 3           # full text of quest #3
/ta questinfo "Kobold Camp Cleanup"
```

Conversations:

```
/ta gossip                # show NPC gossip options
/ta choose 1              # pick option 1
/ta complete              # complete the active turn-in
/ta rewards               # list reward choices
/ta rewardinfo 2          # inspect stats for reward 2
/ta select 2              # take reward 2
/ta accept 1              # accept popup dialog #1
/ta decline 1
```

Quest routing (recommendation, not navigation):

```
/ta questroute            # ranked next-objective recommendation
/ta questroute top 5      # show more candidates
/ta questroute explain    # include score factors
/ta questroute mark       # place a waypoint marker on the top pick
```

Trainer and recipe windows:

```
/ta trainer
/ta train 1
/ta train all
/ta recipes Cooking
/ta craft 2 5             # craft recipe #2 five times
```

---

## 8. Economy: Bags, Vendors, Banking, Mail

```
/ta inventory             # bag contents and free space
/ta bank                  # open the bank window first
/ta gear                  # equipped items
/ta equip Linen Shirt     # equip by item name
/ta money
```

Vendor flow:

```
/ta vendor                # list vendor inventory after opening one
/ta vendorinfo 4          # inspect a vendor item
/ta buycheck 4 10         # confirm affordability
/ta buy 4 10              # actually purchase 10
/ta buyback               # list sold-item buyback slots
/ta sell 0 5              # sell from bag 0 slot 5
/ta selljunk              # sell all gray-quality bag items
/ta restock "Refreshing Spring Water" 20
/ta repair                # repair gear at a vendor
/ta repairstatus
```

Mail and looting commands live alongside these in `/ta help economy`.

---

## 9. Combat Awareness and Theorycraft

The theorycraft modules are read-only models. They do not cast or move.

Warlock DPS model (data-driven):

```
/ta warlockdps                     # baseline live estimate
/ta warlockdps mode shadow
/ta warlockdps mode fire
/ta warlockdps assumptions
/ta warlockdps mapping             # show spreadsheet linkage
```

Warlock prompt (next-action suggestion for current target):

```
/ta warlockprompt                  # one-shot suggestion
/ta warlockprompt on               # auto-prompt while in combat
/ta warlockprompt status
```

Warrior and Paladin helpers:

```
/ta warriorprompt
/ta warriorprompt on
/ta sealdps                        # SoR vs SoC compare
/ta sealdps live                   # use current character stats
/ta weapondance                    # bag/equipped weapon comparison
/ta swingtimer on                  # SWING NOW hint for SoR weapon dance
```

ML XP recommender:

```
/ta ml xp
/ta ml xp explain
/ta ml xp mode balanced
/ta ml xp rates
```

---

## 10. Social and Targeting

```
/ta who Hogger            # /who lookup printed in the log
/ta who                   # last result list
/ta target nearest
/ta target next
/ta target corpse
/ta target Defias
```

Chat slash forms (`/s`, `/p`, `/g`, `/w`, `/raid`, `/rw`) work directly
inside the terminal input.

---

## 11. Accessibility: the `/look` Bridge

The `/look` bridge is for descriptive scene reporting. It only describes
what is on your screen; it does not move, target, or cast.

```
/look                     # show last cached description and reminder
/look last                # description only
/look set "Kobold camp ahead, three patrols visible."
/look telemetry           # machine-readable world telemetry
/look labels preset combat
/look status
```

Companion `py` commands probe the optional Python bridge if you have
one configured:

```
/ta py status
/ta py howto
/ta py limits
```

---

## 12. Automation Toggles

These toggles change addon behavior. Read each line carefully before
flipping it on.

```
/ta autostart on           # auto-open the panel on login
/ta autostart off
/ta autoquests on          # automatic accept/turn-in on quest popups
/ta autoquests off
/ta chat on                # narrate chat traffic into the log
/ta textmode on            # immersive black-screen text mode
/ta performance on         # reduce UI cost and tune ticker rates
/ta settings               # view current cvars / quick settings
```

`autoquests` is the most invasive toggle. Leave it off until you have
seen what `accept` and `decline` look like manually.

---

## 13. Advanced: Macros, Bindings, Diagnostics

```
/ta macros                          # list macros
/ta macroinfo 1                     # inspect macro 1
/ta macrocreate ShadowOpen "/cast Corruption"
/ta macroset 1 "/cast Shadow Bolt"
/ta macrorename 1 ShadowFiller
/ta macrodelete 1
/ta bind 61 22                      # spellbook entry 22 -> action slot 61
/ta bindmacro 61 1                  # macro 1 -> action slot 61
/ta binditem 61 0 5                 # item from bag 0 slot 5 -> slot 61
/ta actions                         # list all bound action bar slots
/ta actions bar6                    # slots 61-72
/ta spellbook 1                     # spells in tab 1
/ta debug                           # popup dialog diagnostics
```

---

## 14. A Suggested First Session

1. `/ta` to open the terminal.
2. `/ta help` and skim the topic list.
3. `/ta status`, `/ta stats`, `/ta gear`, `/ta xp` to confirm telemetry.
4. `/ta where`, `/ta cell`, `/ta map` to read your surroundings.
5. `/ta df on` then `/ta df combined` to bring up the tactical overlay.
6. `/ta quests` and `/ta questinfo 1` to read your first quest.
7. `/ta questroute` for a routing recommendation.
8. Walk somewhere new and try `/ta markcell Start` and
   `/ta markedcells`.
9. Pull a low-level mob and watch `/ta dps` and `/ta range` between
   fights.
10. When everything is comfortable, decide whether to enable
    `/ta autostart on`.

---

## 15. Where to Read Next

- `/ta help <topic>` for the canonical command reference per category.
- `README.md` for a higher-level feature overview and release notes.
- The `Modules/` folder for source-level documentation of each command
  group.

If a command in this tutorial does not match what you see in-game,
trust the in-game `/ta help` output. The tutorial is curated; the help
text is generated from the live command set.
