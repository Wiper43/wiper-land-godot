# Wiper-Land — Codex Agent Instructions

**Engine:** Godot 4.6, Forward Plus renderer
**Description:** First-person combat sandbox on a spherical planet
**Developer:** Solo dev (Wiper43)

---

## Local Tooling

Godot executable:

`E:\edge downloads 2025\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe`

Use this path for command-line validation when Godot is not on `PATH`, for example:

```powershell
& "E:\edge downloads 2025\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe" --path "E:\wiper-land-godot"
```

Prefer headless or command-line checks for script/scene validation when possible. Open the editor UI only when visual inspection or editor-only tooling is needed.

---

## Wiki

This is the Godot project for Wiper-Land.

For persistent project memory, read and maintain the companion brain vault:

`E:\Wiper-Land-Obsidian\Wiper-Land-Brain`

Use that vault's `AGENTS.md` as the source of truth for wiki workflows.

When code changes affect project knowledge, update the brain vault using the `scan` workflow:
- Read current Godot files here.
- Update relevant pages in `E:\Wiper-Land-Obsidian\Wiper-Land-Brain\wiki\`.
- Append to `wiki/log.md`.

### `update brain` From This Godot Project

When the user says `update brain` in this Godot project, use the companion vault exactly like the brain repo does:

1. Treat `E:\Wiper-Land-Obsidian\Wiper-Land-Brain\AGENTS.md` as the source of truth for the full workflow.
2. Review the current conversation for durable project knowledge: code changes, design decisions, debugging discoveries, implementation gotchas, open questions answered, tooling changes, and explicit memories.
3. Create a session note in the vault at `raw/session-YYYY-MM-DD-codex-<topic>.md`.
4. Create or update the matching source summary at `wiki/sources/session-YYYY-MM-DD-codex-<topic>.md`.
5. Update every affected wiki page, especially `wiki/overview.md`, `wiki/index.md`, `wiki/log.md`, and relevant pages under `game/`, `systems/`, `entities/`, `concepts/`, `godot/`, `decisions/`, `analyses/`, or `wiper/`.
6. If code changed, also run the `scan` workflow against the touched Godot files before writing the final wiki synthesis.
7. Mark every Codex-authored session note, source page, and log entry with `Agent: Codex`.
8. Preserve raw/session files as provenance. Do not overwrite older session notes.

In short: a Codex session opened in this Godot repo should be able to remember work by writing back to the brain vault, not by keeping memory only in chat.

---

## What This Game Is

Wiper-Land is a first-person survival-combat sandbox set on a spherical planet. The player spawns at the south pole and pushes north through escalating danger. The sphere is the core spatial mechanic — enemies approach from any direction including over the horizon. No quest markers, no hand-holding. Permadeath.

**Three Pillars:**
- Exploration & freedom (Breath of the Wild)
- Randomized danger (Diablo — procedural spawns with affixes)
- Physics chaos (Fall Guys — knockback, ragdoll, environmental kills)

---

## Project Structure

```
E:\wiper-land-godot\
├── scripts/
│   ├── player/player.gd        — complete: planet gravity, movement, melee attack
│   ├── combat/health.gd        — complete: reusable Health component
│   ├── entities/grunt.gd       — complete: grunt enemy with state machine AI
│   ├── game/planet.gd          — complete: Planet autoload singleton (sphere math)
│   ├── ui/hud.gd               — complete: HP bar HUD
│   └── world/main.gd           — complete: scene init, grunt spawner
├── scenes/
│   ├── world/main.tscn         — entry point: globe + player instance
│   ├── player/player.tscn      — player scene
│   ├── entities/grunt.tscn     — grunt enemy scene
│   └── ui/hud.tscn             — HUD overlay
└── assets/
    ├── audio/
    ├── fonts/
    ├── models/
    └── textures/
```

---

## Coding Conventions

- **Full type annotations** on all variables, constants, and function signatures
- `snake_case` for variables and functions
- `UPPER_SNAKE_CASE` for constants
- `@onready` for all node path lookups — never access nodes in `_init()`
- Guard normalized vectors: `if vec.length_squared() < 0.001: return`
- **No global gravity** — all gravity is custom and sphere-relative via `Planet` autoload
- `class_name` declared on all scripts that need to be referenced by type

---

## Autoload: Planet Singleton

`scripts/game/planet.gd` is registered as the autoload **`Planet`**. All sphere math lives here. Any script can call `Planet.*` without inheritance.

```gdscript
extends Node
const CENTER := Vector3(0, -1024, 0)
const RADIUS := 1024.0

func surface_up(world_pos: Vector3) -> Vector3          # direction away from planet center
func project_on_plane(vector: Vector3, normal: Vector3) -> Vector3
func align_basis_to_surface(forward: Vector3, up: Vector3) -> Basis
```

**Rule:** Never duplicate sphere math in a script. Always call `Planet.*`.

---

## Player (`scripts/player/player.gd`)

**Type:** `CharacterBody3D`
**Scene tree:**
```
Player (CharacterBody3D)   collision_layer=2, collision_mask=1
├── CollisionShape3D        CapsuleShape3D r=0.4 h=1.8, offset Y+0.9
├── CameraArm (Node3D)      at Y+1.6 (eye height)
│   └── Camera3D
└── Health (Node)           health.gd, max_health=100.0
```

**Constants:**
| Name | Value | Role |
|------|-------|------|
| `WALK_SPEED` | 8.0 | Ground movement |
| `SPRINT_SPEED` | 14.0 | Held Shift on ground |
| `FLY_SPEED` | 200.0 | Default fly speed |
| `FLY_SPRINT_SPEED` | 90.0 | Shift while flying (precision mode) |
| `JUMP_FORCE` | 12.0 | Upward impulse |
| `GRAVITY` | 30.0 | Airborne acceleration |
| `GROUND_STICK_FORCE` | 4.0 | Keeps player on curved surface |
| `MOUSE_SENS` | 0.002 | Radians per pixel |
| `ATTACK_RANGE` | 3.0 | Melee sphere radius |
| `ATTACK_DAMAGE` | 25.0 | Per hit |
| `ATTACK_KNOCKBACK` | 12.0 | Surface-plane knockback speed |
| `ATTACK_COOLDOWN` | 0.5 | Seconds between attacks |

**Movement modes:**
- **Walk** (default) — planet gravity, first-person camera
- **Sprint** — hold Shift, planet gravity, first-person camera
- **Fly** — press F, no gravity, 3rd-person camera offset

**Input map:**
| Action | Key |
|--------|-----|
| `move_forward` | W |
| `move_back` | S |
| `move_left` | A |
| `move_right` | D |
| `jump` | Space |
| `sprint` | Left Shift |
| `toggle_fly` | F |
| `fly_down` | Left Ctrl |
| `ui_cancel` | Escape (releases mouse) |

**Melee attack:** Left mouse button (while mouse captured). First click after mouse release = recapture only, no attack. Hits all enemies within `ATTACK_RANGE` simultaneously. Knockback projected onto surface plane (stays flat on sphere).

**Death / respawn:** `_on_died()` resets HP, teleports to `Vector3(0, 1, 0)` (south pole surface), clears velocity.

---

## Health Component (`scripts/combat/health.gd`)

Reusable `Node` — attach as child of any entity.

```gdscript
class_name Health extends Node
@export var max_health: float = 100.0
signal died()
signal health_changed(current: float, maximum: float)
func take_damage(amount: float) -> void
func heal(amount: float) -> void
func get_fraction() -> float
```

- Player Health: max=100 (in player.tscn)
- Grunt Health: max=30 (set via @export in grunt.tscn)
- HUD listens to `health_changed` signal

---

## Grunt Enemy (`scripts/entities/grunt.gd`)

**Type:** `class_name Grunt extends CharacterBody3D`
**Scene tree:**
```
Grunt (CharacterBody3D)   collision_layer=4, collision_mask=1
├── CollisionShape3D      CapsuleShape3D r=0.4 h=1.8, offset Y+0.9
├── MeshInstance3D        CapsuleMesh, red material, offset Y+0.9
└── Health (Node)         max_health=30.0
```

**State machine:**
```
IDLE → (dist ≤ 14u) → CHASE → (dist ≤ 2u) → ATTACK
     ← (dist > 14u) ←       ← (dist > 2u) ←
```

**Constants:**
| Name | Value |
|------|-------|
| `WALK_SPEED` | 4.5 |
| `GRAVITY` | 30.0 |
| `GROUND_STICK_FORCE` | 4.0 |
| `ATTACK_DAMAGE` | 10.0 |
| `ATTACK_COOLDOWN` | 1.2 |
| `KNOCKBACK_FORCE` | 8.0 |
| `CHASE_RANGE` | 14.0 |
| `ATTACK_RANGE` | 2.0 |

**Jitter-free gravity pattern** (critical — do not change this pattern):
```gdscript
# In CHASE: always set a fresh velocity, never accumulate
velocity = _body_forward * WALK_SPEED - surface_up * GROUND_STICK_FORCE

# In IDLE/ATTACK: fresh stick force with friction
velocity = horizontal.lerp(Vector3.ZERO, 0.2) - surface_up * GROUND_STICK_FORCE

# Gravity only accumulates when airborne
if not is_on_floor():
    velocity -= surface_up * GRAVITY * delta
```

**Initialization:** `grunt.initialize(player)` gives the grunt its player reference. Must be called AFTER `add_child()` and `global_position` assignment.

---

## Physics Layers

| Layer | Bitmask | Name | Who |
|-------|---------|------|-----|
| 1 | 1 | world | Globe (StaticBody3D) |
| 2 | 2 | player | Player (CharacterBody3D) |
| 3 | 4 | enemy | Grunt (CharacterBody3D) |

- Player attack query: `collision_mask = 4` (finds enemies)
- Grunt + player: `collision_mask = 1` (collide with world only)

---

## World / Main Scene (`scripts/world/main.gd`)

Spawns 4 grunts at game start in a ring around the south pole.

**Correct spawn order:**
```gdscript
add_child(grunt)                    # 1. enter scene tree first
grunt.global_position = world_pos   # 2. then set global position
grunt.initialize(player)            # 3. then give player reference
```

---

## HUD (`scripts/ui/hud.gd`)

Displays an HP bar. Listens to the player's `Health.health_changed` signal and updates a `ProgressBar` node.

---

## Current State (Milestone A — In Progress)

**Done:**
- Planet gravity + custom surface orientation
- Player walk/sprint/fly movement
- First-person camera
- Melee attack with range query and knockback
- Health component (player + grunt)
- Grunt enemy with IDLE/CHASE/ATTACK state machine
- HUD HP bar
- 4 grunts spawned at start

**Not yet built (Milestone A remaining):**
- Resource pickup (sticks, food, materials)
- Hunger system
- Day/night cycle
- One mini-dungeon with a puzzle
- Home Dance / recall mechanic
- Death → Life Line system
- One biome (terrain, not just a bare globe)

**Not yet built (Milestone B+):**
- Spell crafting
- Ranged attacks
- 2nd+ enemy type
- Predator/prey ecosystem (enemies hunt each other)
- Enemy affixes (Diablo-style)
- Biomes with difficulty scaling by latitude
- Procedural spawner system
- Villages (save points)
- Sound design

---

## Key Rules

1. Never duplicate sphere math — always use `Planet.*`
2. Follow the jitter-free gravity pattern in all entities
3. Spawn order: `add_child()` → `global_position` → `initialize()`
4. `collision_layer`/`collision_mask` must match the physics layer table above
5. Full type annotations on everything
6. `@onready` for all node lookups


