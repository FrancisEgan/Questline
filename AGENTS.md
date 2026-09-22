# Questline development

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for architecture, behavior, validation, and client limitations. Database formats are in [database/SCHEMA.md](database/SCHEMA.md); party synchronization is in [docs/PARTY_PROTOCOL.md](docs/PARTY_PROTOCOL.md).

- Target English OctoWoW / Vanilla 1.12 and Lua 5.0. Do not introduce modern WoW APIs or Lua syntax without a supported fallback.
- `database/` is the owned source; `Data/` is generated. Use `database/overrides.json` for durable database corrections and rebuild with `node tools/build.js` from this repository.
- Run `node tests/run.js` for runtime changes. For shared-tooltip changes, also run `node ../ClassicBestiary/tests/run.js` when that sibling addon is available.
- Preserve quest-log headers/selection, native tooltip fading, other addons' tooltip lines, and saved user preferences. Never guess objective matches by their position.
- Keep README.md focused on players, following the short introduction, screenshots, Features, and Commands format. Put implementation notes and test details in the development documentation.
