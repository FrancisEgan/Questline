# Questline

A quest tracker for OctoWoW and Vanilla 1.12. Find quest objectives with clean map highlights, discover nearby questgivers, and track your party's progress in creature tooltips.

![Quest tracker](screenshot1.png)
![Quest areas and questgivers on the map](screenshot2.png)

## Features

- Zone-based quest tracker that follows you as you travel, with a Show World toggle for your full quest log
- Quest levels with difficulty-colored numbers and level-based sorting
- Click a quest to highlight its map area without changing your tracker page or sorting
- Ctrl-click to highlight multiple quests and move the group to the top, sorted by level
- Precise action icons for single-location objectives and question marks for turn-ins
- Questgiver markers on the map and minimap, with combined tooltips for nearby NPCs
- Creature tooltips with quest objectives, item drop rates, and live progress
- Shared quest progress from party members running Questline, with class-colored names
- NPC tooltips showing available, in-progress, and completed quests
- Shift-click to link a quest in open chat; right-click to open it in the quest log
- Movable, collapsible trackers with saved positions and highlights
- Standalone quest database; no pfQuest dependency

## Commands

- `/ql` or `/questline` — Show help
- `/ql tracker on` / `/ql tracker off` — Show or hide the tracker
- `/ql legacy on` / `/ql legacy off` — Show or hide pfQuest's world-map pins
- `/ql reset` — Reset tracker positions and expand both panels
- `/ql status` — Show addon version and database status

## Credits

Database material comes from pfQuest, pfQuest-turtle, and pfQuest-octo. Their MIT notices are included in `licenses/`.
