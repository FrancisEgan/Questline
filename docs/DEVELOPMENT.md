# Questline development notes

Standalone quest tracker and selected-quest map areas for the English OctoWoW / Vanilla 1.12 client. This is the first questing proof of concept, not a leveling route guide yet.

Current version: **0.1.15**. The addon title and chat prefix use `#8cccff`, matching the tracker mode buttons. Player-facing documentation belongs in the root README; this file preserves implementation details and verification guidance.

The renamed addon uses a new per-character saved-settings file. Existing settings from before the rename are not automatically loaded. To preserve them, fully exit WoW, copy the previous addon's per-character file from `WTF/Account/<account>/<realm>/<character>/SavedVariables/` to `Questline.lua`, and change its top-level settings variable to `QuestlineSettings`. Otherwise Questline starts with default preferences and records completion history normally; the previous saved file remains untouched.

## First test

1. Fully restart WoW so the new `Questline` addon folder is discovered. Enable **Questline** in the character selection AddOns menu.
2. Log in with quests in your quest log and open their zone map, such as the Barrens.
3. Click a numbered circle on the map or in the tracker to highlight its unfinished objectives in blue. Ctrl-click additional quests to highlight them together.
4. Single locations use precise bag / interaction markers. Completed quests show `?` at their turn-in locations.
5. Hover a gold **!** to see an NPC's available quests, then approach it to see the nearby minimap marker.

New characters start in **Quests - <current zone>**, showing quests with unfinished objectives or turn-ins in the physical zone, for example **Quests - Mulgore**. An existing saved World or Zone preference is preserved. Click **Show World** to return to all quests. Zone mode follows you as you travel, independently of the map you browse. Long zone names shorten to **Quests - Zone**; hover over the header for the full name. Unmapped quests are always available in World mode. Your mode choice is saved per character.

Quest labels include a **[level]** prefix in both trackers, quest tooltips, NPC sections, and questgiver marker tooltips. Only the number changes difficulty color (gray, green, yellow, orange, or red); quest names keep their existing color. In Ctrl-selection mode, both trackers show highlighted quests first, then the remaining quests. Normal single selection keeps the full level order and the current page. Each group sorts from lowest level to highest, preserving quest-log order for ties. Quest numbers stay attached to the global level order so moving a highlight does not renumber the map. Unknown levels have no prefix and sort last within their group. The actual Blizzard quest log is not rearranged. Colors refresh as you level up.

**Ctrl-left-click** a map circle, map action icon, tracker row, or tracker badge to add or remove that quest from the highlighted group. Each Ctrl-selection change returns both trackers to page one; more than five highlighted quests continue onto subsequent pages before the other quests. A normal left-click replaces the entire group with that one quest, exits selected-first sorting, and preserves the current tracker pages (clamped only if the filtered list shrinks). Ctrl-clicking the last highlighted quest leaves no highlights. Selections are saved per character, survive completion and zone changes, and are removed when their quests leave the log. Each tracker's zone filter still applies, so an off-zone highlight stays selected without appearing in that zone's list. All selected areas share the blue shading; overlaps are merged to avoid darker patches. Selected single-point objectives retain their action icons.

The map panel lists quests with mapped objectives in the displayed zone. Selection and numbering are shared across both trackers and modes. Normal circles have a shaded burgundy center and beveled gold rim; each selected circle has a yellow fill, dark numeral, and soft gold halo. Drag either panel's header to move it; `-` collapses it. Use the arrows or mouse wheel for additional pages; the scroll hint appears when there is more than one page. Positions and selection are saved per character.

In either tracker, **Shift-left-click** a quest row or its numbered circle while chat is open to insert its quest link at the cursor. **Right-click** to open that quest in the Blizzard quest log, expanding its category and scrolling it into view. Linking and opening the log preserve the highlighted map quest. Ordinary left-click still highlights the quest. Links use Octo's native quest-link API, with standard `GetQuestLink`, pfQuest's configured format, or a bracketed quest title as fallbacks. Nothing is sent until you submit the chat message.

Hover over a mob to see relevant kill and item-collection progress grouped under gold quest names, with each objective slightly indented. For example, Rattlecage Soldier shows **[8] The Mills Overrun** followed by **Notched Rib (40%) - 0/5**. Adult Plainstrider shows **Leg Meat (10%) - 1/2** using its own recorded drop rate. Percentages round to the nearest whole number and come from the owned database; unknown, invalid, or conflicting rates are omitted. Kill objectives have no drop percentage. Mobs shared by several quests show each quest separately, even when their counters are identical. Quests follow level order; objectives retain their live quest-log order. Counters update while hovering and turn green when complete. When the cursor leaves the unit, its quest details stay with the tooltip through its normal fade, until it hides or shows different content. They work in both tracker modes, including quests that are not selected. Existing tooltip details are retained; a complete matching quest group already supplied by pfQuest is not repeated. Updating to 0.1.12 requires one full restart to load the new party synchronization file.

When a party member shares a quest, its tooltip objectives expand to show **You: 1/2**, **Alice: 0/2**, and each other member's progress beneath the objective name. Mob-specific drop percentages stay beside the item name. Completed counts turn green; turn-in tooltips show each member's overall quest status. The main tracker rows keep their compact layout. Party members without synchronized data are omitted; the native shared-quest indicator does not produce a placeholder row. Names with usable data use `RAID_CLASS_COLORS` from the live party unit, with a plain-name fallback if the class is unknown. Questline cannot obtain their counters without a compatible sender, and does not read pfQuest's protocol.

Synchronization starts automatically in a normal party, including while the tracker is disabled. Updates are throttled and periodic snapshots repair missed messages. Disconnected members and counters older than 90 seconds are omitted. If no party member has usable data for an objective, retain the compact local objective instead of adding a redundant You row. Remote data stays in memory and is discarded when a member leaves or reconnects. This first version supports parties, not raids, and aligns identified quests by ID and objectives by normalized English text, type, and required count. Ambiguous or mismatched objectives are omitted rather than guessed. See [the party protocol](PARTY_PROTOCOL.md) for maintenance details.

NPC tooltips now group quests under **Available**, **In Progress**, and **Complete**, omitting empty sections. In-progress quests show indented objectives with live counts. Complete lists only quests that can be turned in to that NPC. Explicit talk-to objectives identify the conversation and its progress without treating that NPC as the questgiver. Tracker quest tooltips retain quest details without the blue click instructions.

Gold **!** markers show NPCs offering eligible quests on zone maps and, when nearby, on the minimap. Icons are 14 pixels instead of 20. Hovering a marker lists the names and available quests of all visible givers within 22 screen-scaled pixels, so overlapping NPCs can be inspected together. Each NPC gets one marker even if it offers several quests; moving NPCs use a recorded position on the world map and the nearest recorded position on the minimap. Minimap markers follow movement, zoom, and indoor/outdoor scale, clipping at the map edge. Continent views, object/item quest starters, and dungeon floors are outside this first implementation.

The normal tracker stays visible when the world map opens, alongside the map's own quest list. Minimap markers also remain visible and update normally when the map shows your current zone. While browsing another zone or a continent, Vanilla cannot provide fresh player coordinates for your physical zone: markers retain the last valid position until the current-zone map is restored or the world map closes. No position is borrowed from a different physical zone, and Questline never changes the map you are browsing to obtain coordinates.

Availability uses level, race, class, profession, recorded prerequisites, mutually exclusive quests, and completion history. Recently observed NPC dialogue takes precedence for one minute, including offers missing from the database; seasonal quests require an actual offer. Completion history is saved per character, initially copied from pfQuest if present and queried from the server when the client supports it. Subsequent confirmed completion messages record turn-ins; abandoning a quest does not mark it completed. Without previous history or the server query, older quest chains cannot be reliably predicted. The imported data does not cover every reputation or custom server condition, so **!** markers are previews of eligibility, not a server guarantee.

pfQuest is optional. If it is enabled, Questline hides its world-map pins and route lines for this session so they do not cover the new map. Its minimap behavior is retained. The original quest trackers are hidden while Questline's tracker is enabled. No pfQuest files, saved settings, or databases are changed.

| Command | Action |
| --- | --- |
| `/ql` | Help |
| `/ql tracker on` / `/ql tracker off` | Enable / disable the normal tracker and restore the old tracker |
| `/ql legacy on` / `/ql legacy off` | Restore / hide pfQuest world-map pins and route lines |
| `/ql reset` | Reset both panels' positions and expand them |
| `/ql status` | Version, database build, and identified quest count |

## Owned database

The normalized JSON under `database/` is the maintainable source. `Data/` contains generated Lua for the game. Neither playing nor rebuilding requires any pfQuest addon. Only explicitly re-importing upstream needs the three original folders.

This migration contains **6,701 quests**, **14,119 NPC records**, **21,158 object records**, and **24,862 item records**, plus zones, exploration triggers, reference loot, and quest-item interactions. It removed 128 duplicate coordinates. English names/text, faction and class/race restrictions, quest links, and extra source attributes are preserved. Non-English translations are outside this POC.

Import precedence is **pfQuest < pfQuest-turtle < pfQuest-octo**. A higher-priority record replaces the entire lower-priority record; coordinate lists are not blindly unioned. `_` deletes an upstream record. Each source's `overwrites.lua` is applied before merging, including Turtle's phantom dungeon zone correction and Octo's manual objective fixes. Equivalent phantom zone IDs are canonicalized, coordinates are validated and deduplicated, and duplicate zone names resolve deterministically to the ID with the most coordinate references.

`database/manifest.json` records input filenames, SHA-256 hashes, precedence, and counts. `reports/import.json` records record provenance, conflicts, tombstones, duplicate zone names, and six unresolved quest references. `reports/build.json` records geometry coverage and targets without locations. Missing references and missing spawn coverage are separate: crafting, unlocated NPCs, and other upstream gaps account for additional unmapped targets. Missing locations are never invented.

For durable corrections, edit **`database/overrides.json`** and rebuild. Patches recursively merge named fields; arrays replace arrays; `null` deletes a field or record. Import never overwrites this correction file. Direct edits to the normalized JSON also work, but a deliberate re-import will replace those files.

Example correction:

```json
{
  "units": {
    "3338": { "coordinates": [[52.2, 31.0, 17, 600]] }
  }
}
```

Coordinates use `[xPercent, yPercent, zoneId, optionalRespawnSeconds]`. Quest targets use `{ "kind": "unit|object|item|event|use|zone", "id": 123 }`. See [database/SCHEMA.md](../database/SCHEMA.md).

## Build and validation

Node.js is only for development. From `Interface/AddOns`:

```powershell
# Normal maintenance: rebuild from Questline's own data and corrections.
node Questline/tools/build.js
node Questline/tools/assets.js
node Questline/tests/run.js

# Optional upstream refresh; this replaces the normalized import snapshot.
node Questline/tools/import.js
node Questline/tools/build.js

# Optional interactive coordinate preview; open the resulting HTML in a browser.
node Questline/tools/preview.js
```

The tools use `luaparse` and the tests use `fengari`. This workspace's `.test-tools/node_modules` is supported; on another machine run `npm install` inside Questline using its `package.json`. The addon itself needs no Node packages. To distribute just the game addon, include the TOC, all root Lua files, `Data/`, `Textures/`, and `licenses/`.

Spawn groups, item drops (including reference loot), vendors, item-use targets, and turn-ins are resolved offline. Nearby points are clustered with map aspect ratio taken into account. Dense groups become padded hulls with gently rounded corners; separated groups remain separate. Small groups and turn-ins become precise markers. Hulls are rasterized into 1,280-row scanlines, packed into six-byte ASCII triples instead of thousands of Lua number slots. The client unions the highlighted quests' unfinished scanlines and draws their boundary using filtered, rounded contour tiles. Large interiors and straight edges are merged into rectangles, and textures are pooled. Numerals and halos retain their screen size when the map is zoomed. Full spawn tables are not loaded or reclustered while playing; a small, separate index retains questgiver positions for map/minimap pins. The blue areas are approximate coverage, not terrain-aware or navigation boundaries.

The automated suite validates normalized coordinates, priority and deletion rules, manual source corrections, geometry separation, all generated Lua syntax, and runtime behavior against a simulated 1.12 API. It exercises collapsed headers, restoring selection, title ambiguity, objective completion, failed quests, map/continent changes, turn-ins, point markers, shared selection, World/Zone filtering and pagination, travel independently of map browsing, pooling, and reversible pfQuest suppression. It also rejects Lua syntax introduced after 5.0. Fengari is a newer Lua VM, so this simulation does **not** replace an in-game smoke test.

The runtime harness also emulates [Lua 5.0's `ipairs` behavior](https://www.lua.org/source/5.0/lbaselib.c.html#luaB_ipairs), including its handling of extra return values. Map-click selection is exercised in both tracker modes and with an unknown physical zone.

Multi-selection tests cover Ctrl-click through map circles, action icons, both tracker rows and badges, selected-first level order, stable numbers, page overflow, simultaneous areas and points, zone filtering, saved selections, completion, removal, clearing all highlights, and normal-click replacement. They also check modifier precedence and clearing stale row tooltips after reordering.

Tracker-click tests cover native chat links and their fallbacks, preserving the draft cursor and log selection, right-clicking rows and circles, revealing collapsed categories, scrolling to the chosen quest, map-panel navigation, and stale, unknown, or ambiguous entries.

Mob-tooltip tests use the imported Rattlecage Soldier / Notched Rib and Night Web Spider records, exercising live item and kill counts, quest grouping, multiple objectives, shared items with independent counters, completion, failed/removed quests, tooltip reuse, and existing pfQuest groups. Fade tests run without `GetOwner`, verifying that mob and NPC quest lines persist after mouse leave without restarting the fade, and clear on hiding or content replacement (including identical titles). A separate check covers owner changes on clients with that optional method. The compiler's source lookup also covers reference-loot cycles, quest-only drops, and exclusion of vendor-only sources.

Level/rate tests verify stable ascending order, unchanged log contents and selection, matching map numbers, native/fallback difficulty colors, recoloring on level-up, and unknown levels. Drop-rate tests cover actual Leg Meat sources, direct and reference loot, conflicting names and reference paths, per-mob isolation, nearest-whole-percent rounding (including half-percent boundaries and tiny chances), and omission of unknown chances without removing objective counters.

NPC and pickup-marker tests exercise Deathguard Dillinger's quest chain, server offer lists, saved/native completion history, abandonment versus turn-in, race/class/profession restrictions, repeatable and seasonal quests, and Octo's Magistrix Ishalah conversation objective. Map tests use Sergra Darkthorn's imported position, checking zone browsing, map zoom, minimap distance/rotation/clipping, indoor detection, and marker changes after acceptance and turn-in. They also cover simultaneous tracker visibility, minimap movement with the world map open, retaining only same-zone position samples while browsing elsewhere, and nearby-giver tooltips on both maps (including zoom, duplicate, hidden and distant pins). Completion message parsing uses the client's format from [Vanilla GlobalStrings](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/GlobalStrings.lua).

The API implementation was checked against the original [1.12 QuestLogFrame](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/QuestLogFrame.lua) and [WorldMapFrame](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/master/1.12.1/FrameXML/WorldMapFrame.xml), plus the installed addons' actual usage.

## Current limits and in-game checks

- English quest identification uses quest links if the client supplies them; otherwise exact title, level, faction/class restrictions, and quest text. Ambiguous matches stay unmapped. Live objectives still appear in the tracker.
- Completed objective names are matched to target names, never assumed to share the database's order. Unmatched custom objective text remains visible until the quest completes.
- The imported data can still contain obsolete or server-specific records. Octo wins collisions, while Turtle-only additions are retained; retaining a record does not prove that quest is available on Octo.
- Only zone maps have areas. This POC does not project them onto continent maps, add minimap areas, select the best leveling route, or handle terrain/floors inside dungeons.
- The map list is a movable panel over the existing map, not a replacement for Blizzard's entire world-map layout.
- Test map zoom/pan with Magnify, finish an objective, turn in/abandon a quest, collapse quest-log categories, and reload. Actual rendering and the server's quest text still need confirmation in WoW.
- Open a zone map and hover a gold **!**, then close the map and approach that NPC. Check the minimap at different zoom levels. Pick up a quest, inspect its NPC progress, and turn it in to verify the next offer appears. Hover a conversation target separately from the giver/finisher. Move the cursor away from a quest mob and confirm its progress stays visible until the tooltip fades away.

## Credits

Database material comes from the installed copies of pfQuest (Shagu / contributors), pfQuest-turtle, and pfQuest-octo (Gurky / contributors). Their MIT notices are retained verbatim in `licenses/`. Questline's runtime, importer, geometry builder, and generated circle/action symbols are new. No RestedXP code or guide content is included.
