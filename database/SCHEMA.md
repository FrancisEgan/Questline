# Database schema 1

All entity tables are JSON objects keyed by numeric ID strings. Runtime Lua uses numeric entity keys and string location keys. IDs from different kinds are distinct.

| File | Record fields |
| --- | --- |
| `quests.json` | `title`, `level`, `minLevel`, `raceMask`, `classMask`, `description`, `summary`, `starters`, `finishers`, `objectives`, `prerequisites`, `closes`, `attributes` |
| `units.json`, `objects.json` | `name`, `coordinates`, `faction`, `level`, `attributes` |
| `items.json` | `name`, `drops: { units, objects, groups }`, `vendors`, `attributes` |
| `lootGroups.json` | `units`, `objects`, `groups`, `attributes`; the first three map source IDs to upstream values |
| `itemUses.json` | Item ID to an array of `{kind, id, spell}` interactions; negative upstream IDs become positive `object` IDs |
| `events.json` | `coordinates`, `attributes`; exploration trigger targets |
| `zones.json` | `name`, `coordinateCount`, optional `bounds: { parent, width, height, x, y }` |
| `reference.json` | Merged profession names, service/resource metadata, minimap dimensions, and Turtle quest patch metadata; the compiler extracts profession names and zone dimensions needed at runtime |

Targets are `{kind, id}`. Kinds are `unit`, `object`, `item`, `event`, `use`, and `zone`. A `use` ID is a quest item, resolved through `itemUses`. No objective ordering or required quantity is invented: live quest-log objective strings supply current counts. Extra upstream fields are retained in `attributes` rather than discarded or assigned guessed semantics.

Coordinates are arrays of `[x, y, zoneId, respawnSeconds?]`. X/Y use percentages in the named zone, not continent coordinates. Zero-zero placeholders, non-finite values, out-of-range points, and non-positive zone IDs are rejected. Respawn is optional. Duplicate X/Y/zone triples collapse to one coordinate. Faction is the upstream friendly-faction string (`A`, `H`, `AH`, or empty/unspecified). Unit levels may be ranges, so they remain strings.

`overrides.json` holds local recursive patches. An empty object changes nothing; an empty array removes all members of an array; `null` removes a field or record. Rebuild after changing it. If upstream refresh is wanted, apply import first, then build; build applies overrides in memory and leaves the imported snapshot intact.

Runtime `QuestlineDB.locations[targetKey][zoneId]` contains:

- `anchor`: `[x,y]`, an actual spawn near the largest cluster's center, used for the quest selector.
- `points`: arrays of `[x,y]` for precise markers.
- `runs`: runtime schema 2 packs zero-based `[row, startColumn, exclusiveEndColumn]` triples into strings. Each integer occupies two characters from `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_`; its value is `firstDigit * 64 + secondDigit`. Each triple is six characters. `tools/packed-runs.js` encodes/decodes this generated representation. `QuestlineDB.grid` is 1280. The normalized JSON remains schema 1 and is unchanged by this runtime encoding.
- `spawns`: number of unique source points in that zone.

Turn-in location keys are prefixed `turnin:` and always use point geometry. Ordinary keys look like `item:5087` or `unit:3338`. Multiple quests reuse target geometry. The runtime retains objective names, summary/description for identification, and finishers. It also retains minimum level, race/class masks, `prerequisites`, reverse `blockedBy` lists derived from other quests' `closes`, an optional profession name (`skill`), holiday `event`, and explicit `repeatable` flags for availability checks. Prerequisites follow the upstream any-completed-predecessor semantics; unrecorded requirements are not invented.

`QuestlineDB.mobObjectives[normalizedMobName]` is a generated array of `unit:<id>` and `item:<id>` objective keys used by mob tooltips. Names are lowercase with normalized whitespace. The compiler follows direct unit drops and reference-loot groups, retains zero-rate quest-only drops, and excludes negative/disabled drops, vendors, and containers. Only targets used by quests enter this index. Item and mob names still come from the owned JSON; runtime progress and required counts come from the current quest log, not this index. Rebuild to regenerate `Data/MobObjectives.lua` after corrections to item sources or mob names.

`QuestlineDB.mobDropRates[normalizedMobName][itemKey] = percentage` is generated in the same `Data/MobObjectives.lua` file. It contains positive known percentages up to 100 for quest items. Direct unit rates take precedence over reference records. For reference loot, the item's reference chance supplies the percentage; membership values are not multiplied into it. Cycles are guarded, and conflicting reference paths or same-name NPC variants omit the percentage. Zero/unknown, negative, invalid, and vendor-only values never become displayed drop percentages, while the objective index still retains valid sources with unknown rates. The tooltip adds rates to a per-mob copy of the live counter so one mob's percentage cannot affect another's.

`QuestlineDB.npcQuests[normalizedNPCName] = {starters={questIDs}, finishers={questIDs}}` is the reverse NPC role index in `Data/NPCQuests.lua`. Only unit targets are included; a talk-to objective is identified independently from the live objective text and quest summary.

`QuestlineDB.givers[unitID] = {name, quests={questIDs}, coordinates={{x,y,zoneID}, ...}}` contains NPC starters and deduplicated recorded positions. `QuestlineDB.zoneGivers[zoneID] = {unitIDs}` limits lookup to the displayed zone. These are generated as `Data/QuestGivers.lua` and `Data/ZoneGivers.lua`. Unlocated NPCs can still have tooltip offers, but receive no invented map position. Multiple quests offered by one NPC share its marker.

Runtime zones have an optional `mapSize = {widthYards,heightYards}`, extracted from `reference.minimap`, for converting zone percentages to minimap distance. These are map dimensions, not pixel sizes. Unknown dimensions disable minimap markers for that zone.

`QuestlineSettings.completedQuests[questID] = true` is per-character history, separate from all generated database tables. Native server history, a one-time pfQuest history import, and confirmed quest-completion messages can add entries. Recent NPC offers and availability caches remain session-only.
