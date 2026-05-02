---
description: "Review Text Adventurer for roleplay immersion gaps, missing WoW interaction surfaces, and quest text presentation"
name: "RP Immersion Review"
argument-hint: "Optional focus, e.g. quest text, NPC dialogue, banking, vendors, travel, survival, Hardcore RP"
agent: "agent"
model: "Claude Opus 4.7 (copilot)"
---

You are reviewing the Text Adventurer WoW Classic Era addon for player immersion and true roleplay experience. Use Claude 4.7 for this review. If the prompt runner does not automatically select Claude 4.7 from frontmatter, switch to Claude 4.7 manually before continuing.

Primary goals:

1. Identify gaps where the addon breaks immersion because important WoW interactions are missing, too mechanical, or not narrated in the terminal.
2. Audit which WoW Classic Era APIs/events/functions could improve roleplay presentation.
3. Propose roleplay-first features that preserve Text Adventurer's terminal-driven style.
4. Specifically design a quest text feature where quest dialogue appears in the Text Adventurer box when viewing or accepting quests, with support for both manual and autoquest flows.

Start with these files and areas:

- [README](../../README.md) for addon intent and command surface.
- [textadventurer.lua](../../textadventurer.lua), especially:
  - quest/gossip handlers and event responses
  - `AcceptQuest`, `CompleteQuest`, `QuestFrame`, and gossip-related code paths
  - `ReportInventory`, `ReportBank`, vendor/trainer/reporting functions, readable-item support, and narrative output helpers
  - `AddLine`, color channels, terminal command dispatch, and any existing autoquest behavior
- [Modules/Commands.lua](../../Modules/Commands.lua) for command registration and input flow.
- [Modules/QuestCommands.lua](../../Modules/QuestCommands.lua) for quest terminal behavior.
- [Modules/EconomyCommands.lua](../../Modules/EconomyCommands.lua) for bank/vendor/inventory immersion surfaces.
- [Modules/HelpTopics.lua](../../Modules/HelpTopics.lua) for discoverability and command naming.
- [Modules/SpellbookCommands.lua](../../Modules/SpellbookCommands.lua) for an example of richer terminal presentation.

Context and constraints:

- This is a WoW Classic Era addon. Avoid recommendations that require forbidden automation, protected frame manipulation in combat, or retail-only APIs.
- Preserve Hardcore-friendly safety and clarity. Immersion should not hide critical danger or failure information.
- Prefer low-risk, high-impact additions over rewrites.
- Keep the terminal-first roleplay fantasy: the player should feel like they are experiencing the world through a text adventure, not just triggering UI shortcuts.
- Separate confirmed Classic Era APIs from uncertain or retail-only APIs.
- Call out any recommendations that require in-game verification.

Review questions:

1. Immersion gaps:
   - Which player interactions currently feel too game-mechanical instead of roleplay/narrative?
   - Which major WoW systems are missing from the terminal experience?
   - Are banking, inventory, vendor, trainer, quest, gossip, spellbook, mailbox, auction, innkeeper, flight master, repair, reputation, death/ghost, weather, time-of-day, rest, fatigue, underwater breath, durability, readable-item, and world-object flows represented well enough?
   - Which missing systems would most break immersion for a Hardcore roleplay player?
   - Which existing command outputs should be rephrased or enriched without making them verbose or slower to use?

2. Quest text feature:
   - How should Text Adventurer capture and print quest title, greeting, objective, progress, completion, and reward text when a player opens, accepts, progresses, or completes a quest?
   - Which Classic Era-safe APIs/events should be used, such as:
     - `QUEST_DETAIL`
     - `QUEST_PROGRESS`
     - `QUEST_COMPLETE`
     - `QUEST_GREETING`
     - `GOSSIP_SHOW`
     - `GetTitleText`
     - `GetQuestText`
     - `GetObjectiveText`
     - `GetProgressText`
     - `GetRewardText`
     - `GetGreetingText`
     - `GetGossipText`
     - legacy gossip quest APIs where available
   - How should this interact with existing `autoquests on/off` behavior?
   - If autoquest is enabled, should the addon print quest title/objectives/story before accepting, or provide a short "read first" mode?
   - What should the default be for immersion: instant accept, print-first accept, or manual accept?
   - How should repeated quest text be deduplicated so it does not spam?
   - What command surface should exist? Consider:
     - `questtext on/off`
     - `questtext repeat`
     - `questtext full/brief`
     - `autoquests readfirst`
     - `quest accept`
     - `quest decline`

3. RP feature ideas:
   - NPC dialogue narration and gossip summaries.
   - Vendor, trainer, banker, innkeeper, flight master, repair, mailbox, and auction house terminal narration.
   - Zone arrival/departure narration.
   - Rested/inn/campfire flavor.
   - Hardcore danger narration for low health, durability, poison, disease, curses, fatigue, drowning, elites, caves, hyperspawns, and dangerous pulls.
   - Reputation and faction reaction flavor.
   - Death, ghost, spirit healer, and corpse-run narration.
   - Class-specific roleplay prompts.
   - Profession/crafting narration.
   - Readable books, letters, plaques, signs, and item text.
   - Weather/time-of-day ambience if Classic Era exposes usable APIs.
   - More immersive inventory/bank phrasing.

4. WoW API audit:
   - List specific Classic Era functions/events the addon is not using but should consider.
   - Separate:
     - confirmed Classic Era APIs/events
     - likely Classic Era APIs/events needing in-game verification
     - retail-only or unsafe APIs/events to avoid
   - Identify any protected actions or combat restrictions that would affect implementation.
   - Identify the safest event hooks for narrative-only output.

Expected output:

1. **Executive summary**: top immersion opportunities and the best first feature to build.
2. **Missing WoW surfaces**: ranked list of systems/functions/events likely worth adding.
3. **Quest text design**: concrete event/API flow for showing quest text in the Text Adventurer box.
4. **Autoquest interaction**: recommended behavior for manual quests vs autoquests, including whether "read first" should be default.
5. **Roleplay feature backlog**: staged implementation plan from safest/highest-impact to more experimental.
6. **Patch candidates**: Lua-level pseudocode or small diffs for quest text capture, but do not apply changes unless explicitly asked.
7. **Testing checklist**: in-game scenarios to verify, including quest pickup, quest progress, quest completion, gossip quests, autoquests on/off, repeatable quests, NPCs with multiple quests, and abandoned/reaccepted quests.

If an observation is uncertain, label it clearly as a hypothesis and say what in-game test would confirm it.
