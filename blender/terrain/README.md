# Wiper-Land Blender Terrain Generator

This folder contains a repeatable Blender generator for prototype terrain art.

## Run

From the repository root:

```powershell
blender --background --python blender/terrain/generate_wiper_land_terrain.py
```

If Blender is not on `PATH`, run the same command with the full path to `blender.exe`.

## Outputs

- `assets/models/terrain/terrain_patch.glb`
- `assets/models/terrain/south_pole_biome_patch.glb`
- `assets/models/terrain_props/prop_01_rounded_boulder_cluster.glb`
- `assets/models/terrain_props/prop_02_flat_stepping_stones.glb`
- `assets/models/terrain_props/prop_03_broadleaf_tree.glb`
- `assets/models/terrain_props/prop_04_south_pole_pine.glb`
- `assets/models/terrain_props/prop_05_fallen_log.glb`
- `assets/models/terrain_props/prop_06_reed_patch.glb`
- `assets/models/terrain_props/prop_07_red_flower_clump.glb`
- `assets/models/terrain_props/prop_08_blue_crystal_cluster.glb`
- `assets/models/terrain_props/prop_09_small_bent_tree.glb`
- `assets/models/terrain_props/prop_10_tall_shard_rocks.glb`
- `assets/models/terrain_props/prop_11_tall_grass_patch.glb`
- `assets/models/terrain_props/prop_12_half_buried_root.glb`
- `blender/terrain/generated/wiper_land_terrain_kit.blend`

## Terrain Recipe

The terrain patch is generated as a curved south-pole biome piece using the same planet radius and center as the Godot `Planet` autoload. `terrain_patch.glb` is the game-facing file loaded by `scripts/world/main.gd`; `south_pole_biome_patch.glb` is exported as a compatibility copy for older experiments.

The mesh uses the same prototype recipe as the in-Godot south pole terrain:

- Mountains: ridged fractal noise multiplied by a continental highland mask.
- Hills: standard fBm blended into lowland zones.
- Rivers: valleys carved where low-frequency river noise crosses zero.
- Cliffs: height-gradient slope drives rock color.
- Domain warp: all sampling coordinates are warped before terrain features are evaluated.
- Vertex colors: snow, rock, grass, and riverbed colors are baked into the mesh with no texture dependency.

The props are stylized low-poly meshes intended for quick Godot import and iteration.
