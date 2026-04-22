# Wiper-Land Current State

Last updated: 2026-04-22

This is the current playable Godot prototype state for Wiper-Land.

## Project Snapshot

Wiper-Land is a first-person combat sandbox on a spherical planet. The player starts near the south pole and can move, fly, fight skeleton enemies, use fire attacks, open a map, and test performance with many monsters spread across the globe.

Engine: Godot 4.6, Forward Plus renderer

Main scene:

```text
scenes/world/main.tscn
```

## World Scale

Planet math lives in:

```text
scripts/game/planet.gd
```

Current planet constants:

```gdscript
const CENTER := Vector3(0, -1024, 0)
const RADIUS := 1024.0
```

World scale:

```text
Radius:        1024u
Diameter:      2048u
Circumference: about 6434u
```

`u` means Godot world units. The project currently treats distance values like attack range, detection range, and planet radius as world units.

## Terrain

The world loads a terrain patch from:

```text
assets/models/terrain/terrain_patch.glb
```

At startup, `scripts/world/main.gd` instantiates the GLB and calls `create_trimesh_collision()` on mesh children so the patch has runtime collision.

There is also a Blender terrain generator prototype in:

```text
blender/terrain/generate_wiper_land_terrain.py
```

The generator is intended to create a curved south-pole terrain patch with procedural height and vertex-color terrain styling.

## Player

Player scene:

```text
scenes/player/player.tscn
```

Player script:

```text
scripts/player/player.gd
```

Current player features:

- Planet-relative gravity and orientation through the `Planet` autoload.
- First-person camera in ground mode.
- Fly mode toggle with a third-person camera offset.
- Walk, sprint, jump, fly up, and fly down.
- Health component with death/respawn.
- Enemy hit response with damage, knockback, and a soft ouch sound.

Important movement values:

```gdscript
WALK_SPEED = 14.0
SPRINT_SPEED = 14.0
FLY_SPEED = 200.0
FLY_SPRINT_SPEED = 90.0
JUMP_FORCE = 12.0
GRAVITY = 30.0
```

## Combat

The player currently has two attacks.

Left mouse:

```text
Melee / short flame attack
```

Values:

```gdscript
ATTACK_RANGE = 3.0
ATTACK_DAMAGE = 25.0
ATTACK_KNOCKBACK = 12.0
ATTACK_COOLDOWN = 0.5
```

Right mouse:

```text
Flame bomb
```

Values:

```gdscript
BOMB_RANGE = 20.0
BOMB_RADIUS = 5.0
BOMB_DAMAGE = 15.0
BOMB_KNOCKBACK = 18.0
BOMB_COOLDOWN = 1.5
```

Combat uses sphere queries against the enemy collision layer. Knockback is projected onto the planet surface so characters are pushed along the ground instead of straight through the sphere.

## Enemies

Enemy scene:

```text
scenes/entities/grunt.tscn
```

Enemy script:

```text
scripts/entities/grunt.gd
```

The current enemy is a skeleton-styled grunt. It uses a capsule collision shape for stable gameplay collision, while the visible skeleton is built from simple primitive mesh pieces.

Current enemy behavior:

- `IDLE`
- `CHASE`
- `ATTACK`

Aggro values:

```gdscript
DETECTION_RADIUS = 14.0
ATTACK_RADIUS = 2.0
ATTACK_DAMAGE = 10.0
ATTACK_COOLDOWN = 1.2
KNOCKBACK_FORCE = 8.0
```

Enemy UI:

- A yellow `!` appears above a monster when it aggros toward the player.
- A yellow `?` appears for 3 seconds after it loses aggro.
- A health bar appears above monsters after they take damage.

## Monster Stress Test

The world currently spawns 1000 monsters for FPS testing.

Configured in:

```text
scripts/world/main.gd
```

Values:

```gdscript
MONSTER_COUNT = 1000
MONSTER_ACTIVE_DISTANCE = 160.0
MONSTER_RENDER_DISTANCE = 260.0
LOD_UPDATE_INTERVAL = 0.25
```

Spawn behavior:

- 1 special red skeleton named `NorthPoleRedGrunt` spawns at the north pole marker direction.
- 999 normal skeletons are spread across the globe using a Fibonacci sphere distribution.

LOD behavior:

- Within 160u: monster is visible, collision is enabled, and AI/physics update.
- From 160u to 260u: monster can remain visible, but AI/physics/collision are disabled.
- Beyond 260u: monster visual is hidden and AI/physics/collision are disabled.

This is meant for performance testing and is not final world-spawning design.

## UI

HUD script:

```text
scripts/ui/hud.gd
```

HUD scene:

```text
scenes/ui/hud.tscn
```

Current HUD features:

- Player HP bar with numeric `current / maximum` text.
- FPS meter above the options panel.
- Bottom-right options panel with Master Volume slider.
- Default master volume is 10%.
- Top-center compass with N, S, E, W.
- `M` key toggles a map overlay.
- Map overlay shows player world position and geographic position.

Map readout:

```text
XYZ x, y, z
Lat latitude  Lon longitude  Alt altitude
```

The map also shows a player marker and a north arrow matching the top compass direction.

## Pole Markers And Sun

The world has two pole beams:

- North pole beam: white
- South pole beam: red

There is also a fixed emissive sun mesh and warm sun glow in `main.tscn`.

## Audio

Current generated placeholder sounds:

```text
assets/audio/flame_attack_lowfi.wav
assets/audio/bomb_explosion_lowfi.wav
assets/audio/player_soft_ouch_lowfi.wav
```

Sound triggers:

- Flame attack plays a low-fi fire burst.
- Bomb explosion plays a low-fi explosion.
- Player hit plays a soft ouch.

## Input

Current important controls:

| Action | Key / Button |
|--------|--------------|
| Move forward | W |
| Move back | S |
| Move left | A |
| Move right | D |
| Jump | Space |
| Sprint | Left Shift |
| Toggle fly | F |
| Fly down | Left Ctrl |
| Melee / flame attack | Left mouse |
| Flame bomb | Right mouse |
| Toggle map | M |
| Release mouse | Escape |

## Physics Layers

Current physics convention:

| Layer | Bitmask | Who |
|-------|---------|-----|
| 1 | 1 | World |
| 2 | 2 | Player |
| 3 | 4 | Enemy |

Player and enemies collide physically with the world. Combat hit detection queries the enemy layer.

## Known Performance Notes

The 1000-monster setup is intentionally heavy. Performance depends heavily on:

- Monster count.
- Active/render LOD distances.
- Skeleton visual complexity.
- Number of monsters close enough to run AI/physics.
- Label3D markers and health bars visible at once.

If FPS is too low, first tune these values in `scripts/world/main.gd`:

```gdscript
MONSTER_COUNT
MONSTER_ACTIVE_DISTANCE
MONSTER_RENDER_DISTANCE
LOD_UPDATE_INTERVAL
```

## Not Yet Built

Still missing from the intended Milestone A / vertical slice:

- Resource pickups.
- Hunger system.
- Day/night cycle.
- One mini-dungeon with a puzzle.
- Home Dance / recall mechanic.
- Death -> Life Line system.
- More complete biome coverage beyond the current terrain patch.

Future features:

- Spell crafting.
- Ranged attacks.
- Additional enemy types.
- Predator/prey ecosystem.
- Enemy affixes.
- Biomes and difficulty scaling by latitude.
- Villages / save points.
- More complete sound design.
