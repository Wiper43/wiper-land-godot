# Wiper-Land Godot — Claude Instructions

**Engine:** Godot 4.6, Forward Plus renderer
**Description:** First-person combat sandbox on a spherical planet

---

## Wiki

All project knowledge lives in the Obsidian vault at:
`E:\Wiper-Land-Obsidian\Wiper-Land-Brain\`

Read `wiki/index.md` there to orient before answering questions or making changes.
When you learn something new from the code, update the relevant wiki pages.

Key wiki pages:
- `wiki/overview.md` — current project state synthesis
- `wiki/game/overview.md` — game design intent
- `wiki/systems/player-movement.md` — full movement system
- `wiki/systems/combat.md` — combat system (stub)
- `wiki/entities/player.md` — player node, constants, input map
- `wiki/concepts/planet-gravity.md` — sphere gravity math
- `wiki/decisions/` — formal record of architectural choices
- `wiki/log.md` — append here after any ingest or significant update

Wiki folder summary:
- `game/` — design intent (what you're building)
- `systems/` — how things work (synthesizes everything)
- `entities/` — specific game objects
- `concepts/` — algorithms and math
- `godot/` — engine-specific knowledge
- `decisions/` — choices made
- `analyses/` — tradeoff explorations

Ingest workflow (when a new source is added to `raw/`):
1. Read the source
2. Create `wiki/sources/<name>.md`
3. Update affected pages across game/, systems/, entities/, concepts/, godot/
4. Add a decision to `decisions/` if a choice was made
5. Update `wiki/index.md` and append to `wiki/log.md`

---

## Project Structure

```
scripts/
  player/player.gd      — only complete script, planet gravity + movement
  combat/               — empty
  entities/             — empty
  game/                 — empty
  ui/                   — empty
  world/                — empty
scenes/
  world/main.tscn       — entry point, globe + player instance
  player/player.tscn    — player scene
assets/
  audio/ fonts/ models/ textures/
```

---

## Commands

- `update brain` — ingest the current session into the wiki (summarize conversation → save to `raw/` → update wiki pages → log it). Always include `**Agent:** Claude Code` in the raw session file header and in the `wiki/sources/` file. Append `[Claude Code]` at the end of the `wiki/log.md` heading for the entry.
- `ingest <file>` — ingest a specific file from `raw/`
- `lint` — check for broken wiki links
- `scan <file>` — re-read Godot source and update wiki

---

## Coding Conventions

- Full type annotations on all variables, constants, and function signatures
- `snake_case` for variables and functions, `UPPER_SNAKE_CASE` for constants
- `@onready` for all node path lookups
- Guard normalized vectors: `if vec.length_squared() < 0.001`
- No global gravity — all gravity is custom, sphere-relative
