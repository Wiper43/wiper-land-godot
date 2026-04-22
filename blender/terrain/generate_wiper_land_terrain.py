"""
Generate Wiper-Land prototype terrain assets in Blender.

Run from Blender:
    blender --background --python blender/terrain/generate_wiper_land_terrain.py

Outputs:
    assets/models/terrain/terrain_patch.glb
    assets/models/terrain/south_pole_biome_patch.glb
    assets/models/terrain_props/*.glb
    blender/terrain/generated/wiper_land_terrain_kit.blend
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Vector


REPO_ROOT: Path = Path(__file__).resolve().parents[2]
TERRAIN_OUTPUT_DIR: Path = REPO_ROOT / "assets" / "models" / "terrain"
PROP_OUTPUT_DIR: Path = REPO_ROOT / "assets" / "models" / "terrain_props"
BLEND_OUTPUT_DIR: Path = REPO_ROOT / "blender" / "terrain" / "generated"
BLEND_OUTPUT_PATH: Path = BLEND_OUTPUT_DIR / "wiper_land_terrain_kit.blend"
TERRAIN_OUTPUT_PATH: Path = TERRAIN_OUTPUT_DIR / "terrain_patch.glb"
LEGACY_TERRAIN_OUTPUT_PATH: Path = TERRAIN_OUTPUT_DIR / "south_pole_biome_patch.glb"

PLANET_RADIUS: float = 1024.0
PLANET_CENTER: Vector = Vector((0.0, -1024.0, 0.0))
TERRAIN_HALF_SIZE: float = 100.0
TERRAIN_GRID_STEPS: int = 128
MAX_HEIGHT: float = 22.0
RIVER_DEPTH: float = 5.5
RIVER_BAND: float = 0.065
CLIFF_SLOPE: float = 1.25
RANDOM_SEED: int = 43


def ensure_dirs() -> None:
    TERRAIN_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PROP_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    BLEND_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for collection in bpy.data.collections:
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def make_collection(name: str) -> bpy.types.Collection:
    collection: bpy.types.Collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def link_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    collection.objects.link(obj)
    for existing_collection in obj.users_collection:
        if existing_collection != collection:
            existing_collection.objects.unlink(obj)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.95,
    metallic: float = 0.0,
) -> bpy.types.Material:
    material: bpy.types.Material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf: bpy.types.Node = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


def make_vertex_color_material(name: str) -> bpy.types.Material:
    material: bpy.types.Material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes: bpy.types.Nodes = material.node_tree.nodes
    links: bpy.types.NodeLinks = material.node_tree.links
    bsdf: bpy.types.Node = nodes["Principled BSDF"]
    try:
        color_node: bpy.types.Node = nodes.new("ShaderNodeVertexColor")
        color_node.layer_name = "terrain_color"
        links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
    except Exception:
        try:
            attr_node: bpy.types.Node = nodes.new("ShaderNodeAttribute")
            attr_node.attribute_name = "terrain_color"
            links.new(attr_node.outputs["Color"], bsdf.inputs["Base Color"])
        except Exception:
            bsdf.inputs["Base Color"].default_value = (0.28, 0.52, 0.20, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.98
    return material


def create_materials() -> dict[str, bpy.types.Material]:
    return {
        "terrain_vertex": make_vertex_color_material("WL_Terrain_Vertex_Color"),
        "grass": make_material("WL_Grass_Moss", (0.32, 0.58, 0.28, 1.0)),
        "grass_dark": make_material("WL_Grass_Dark", (0.18, 0.39, 0.22, 1.0)),
        "dirt": make_material("WL_Dirt_Warm", (0.43, 0.30, 0.17, 1.0)),
        "stone": make_material("WL_Stone_Cool", (0.38, 0.43, 0.42, 1.0)),
        "stone_dark": make_material("WL_Stone_Dark", (0.22, 0.25, 0.25, 1.0)),
        "bark": make_material("WL_Bark", (0.34, 0.20, 0.11, 1.0)),
        "leaf": make_material("WL_Leaf_Bright", (0.20, 0.54, 0.24, 1.0)),
        "leaf_dark": make_material("WL_Leaf_Dark", (0.12, 0.36, 0.17, 1.0)),
        "flower": make_material("WL_Flower_Red", (0.85, 0.15, 0.12, 1.0)),
        "reed": make_material("WL_Reed", (0.48, 0.52, 0.23, 1.0)),
        "crystal": make_material("WL_Crystal_Blue", (0.10, 0.55, 0.85, 1.0), 0.45),
    }


def surface_position_from_tangent(x: float, z: float, height: float) -> Vector:
    south_pole: Vector = PLANET_CENTER + Vector((0.0, PLANET_RADIUS, 0.0))
    direction: Vector = south_pole + Vector((x, 0.0, z)) - PLANET_CENTER
    if direction.length_squared < 0.001:
        direction = Vector((0.0, 1.0, 0.0))
    return PLANET_CENTER + direction.normalized() * (PLANET_RADIUS + height)


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    t: float = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def color_lerp(
    a: tuple[float, float, float, float],
    b: tuple[float, float, float, float],
    t: float,
) -> tuple[float, float, float, float]:
    return (
        lerp(a[0], b[0], t),
        lerp(a[1], b[1], t),
        lerp(a[2], b[2], t),
        lerp(a[3], b[3], t),
    )


def hash_2d(x: int, z: int, seed: int) -> float:
    n: int = x * 374761393 + z * 668265263 + seed * 1442695041
    n = (n ^ (n >> 13)) * 1274126177
    n = n ^ (n >> 16)
    return ((n & 0xFFFFFFFF) / 0xFFFFFFFF) * 2.0 - 1.0


def value_noise_2d(x: float, z: float, seed: int) -> float:
    x0: int = math.floor(x)
    z0: int = math.floor(z)
    tx: float = x - float(x0)
    tz: float = z - float(z0)
    tx = tx * tx * (3.0 - 2.0 * tx)
    tz = tz * tz * (3.0 - 2.0 * tz)

    a: float = hash_2d(x0, z0, seed)
    b: float = hash_2d(x0 + 1, z0, seed)
    c: float = hash_2d(x0, z0 + 1, seed)
    d: float = hash_2d(x0 + 1, z0 + 1, seed)
    return lerp(lerp(a, b, tx), lerp(c, d, tx), tz)


def fbm_noise_2d(x: float, z: float, seed: int, frequency: float, octaves: int) -> float:
    value: float = 0.0
    amplitude: float = 1.0
    amplitude_sum: float = 0.0
    current_frequency: float = frequency
    for octave in range(octaves):
        value += value_noise_2d(x * current_frequency, z * current_frequency, seed + octave * 1013) * amplitude
        amplitude_sum += amplitude
        amplitude *= 0.5
        current_frequency *= 2.0
    return value / amplitude_sum


def ridged_noise_2d(x: float, z: float, seed: int, frequency: float, octaves: int) -> float:
    value: float = 0.0
    amplitude: float = 1.0
    amplitude_sum: float = 0.0
    current_frequency: float = frequency
    for octave in range(octaves):
        ridge: float = 1.0 - abs(value_noise_2d(x * current_frequency, z * current_frequency, seed + octave * 1543))
        value += ridge * ridge * amplitude
        amplitude_sum += amplitude
        amplitude *= 0.52
        current_frequency *= 2.05
    return value / amplitude_sum


def warped_coordinates(x: float, z: float) -> tuple[float, float]:
    warp_x: float = fbm_noise_2d(x, z, RANDOM_SEED + 4, 0.007, 2)
    warp_z: float = fbm_noise_2d(x + 419.2, z + 831.7, RANDOM_SEED + 4, 0.007, 2)
    return x + warp_x * 35.0, z + warp_z * 35.0


def terrain_height(x: float, z: float) -> float:
    wx, wz = warped_coordinates(x, z)

    continental: float = fbm_noise_2d(wx, wz, RANDOM_SEED, 0.005, 3) * 0.5 + 0.5
    continental = smoothstep(0.35, 0.65, continental)

    peak: float = ridged_noise_2d(wx, wz, RANDOM_SEED + 1, 0.018, 5)
    peak = pow(peak, 1.8)

    hill: float = fbm_noise_2d(wx, wz, RANDOM_SEED + 2, 0.025, 4) * 0.5 + 0.5
    height: float = lerp(hill * 4.0, peak * MAX_HEIGHT, continental)
    height += fbm_noise_2d(wx, wz, RANDOM_SEED + 3, 0.10, 2) * 0.5

    river_value: float = fbm_noise_2d(wx, wz, RANDOM_SEED + 5, 0.011, 2)
    carve: float = max(0.0, RIVER_BAND - abs(river_value)) / RIVER_BAND
    carve = pow(carve, 0.65)
    altitude_mask: float = max(0.0, min(1.0, 1.0 - height / (MAX_HEIGHT * 0.55)))
    height -= carve * RIVER_DEPTH * altitude_mask

    return height


def terrain_color(height: float, slope: float) -> tuple[float, float, float, float]:
    if height > MAX_HEIGHT * 0.78:
        return (0.93, 0.94, 0.98, 1.0)
    if slope > CLIFF_SLOPE:
        return (0.44, 0.37, 0.28, 1.0)
    if height < 0.8:
        return (0.38, 0.28, 0.16, 1.0)
    t: float = max(0.0, min(1.0, height / (MAX_HEIGHT * 0.5)))
    return color_lerp((0.18, 0.44, 0.14, 1.0), (0.28, 0.52, 0.20, 1.0), t)


def terrain_slope(ix: int, iz: int, heights: list[float], step: float, row: int) -> float:
    x0: int = max(ix - 1, 0)
    x1: int = min(ix + 1, TERRAIN_GRID_STEPS)
    z0: int = max(iz - 1, 0)
    z1: int = min(iz + 1, TERRAIN_GRID_STEPS)
    dx: float = (heights[iz * row + x1] - heights[iz * row + x0]) / (step * float(x1 - x0))
    dz: float = (heights[z1 * row + ix] - heights[z0 * row + ix]) / (step * float(z1 - z0))
    return math.sqrt(dx * dx + dz * dz)


def create_terrain_patch(materials: dict[str, bpy.types.Material], collection: bpy.types.Collection) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    step: float = (TERRAIN_HALF_SIZE * 2.0) / float(TERRAIN_GRID_STEPS)
    row: int = TERRAIN_GRID_STEPS + 1
    heights: list[float] = []
    colors: list[tuple[float, float, float, float]] = []

    for z_index in range(TERRAIN_GRID_STEPS + 1):
        z: float = -TERRAIN_HALF_SIZE + float(z_index) * step
        for x_index in range(TERRAIN_GRID_STEPS + 1):
            x: float = -TERRAIN_HALF_SIZE + float(x_index) * step
            height: float = terrain_height(x, z)
            heights.append(height)
            pos: Vector = surface_position_from_tangent(x, z, height)
            vertices.append((pos.x, pos.y, pos.z))

    for z_index in range(TERRAIN_GRID_STEPS + 1):
        for x_index in range(TERRAIN_GRID_STEPS + 1):
            vertex_index: int = z_index * row + x_index
            slope: float = terrain_slope(x_index, z_index, heights, step, row)
            colors.append(terrain_color(heights[vertex_index], slope))

    for z_index in range(TERRAIN_GRID_STEPS):
        for x_index in range(TERRAIN_GRID_STEPS):
            a: int = z_index * row + x_index
            b: int = a + 1
            c: int = a + row + 1
            d: int = a + row
            faces.append((a, b, c, d))

    mesh: bpy.types.Mesh = bpy.data.meshes.new("SouthPoleBiomePatchMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    terrain: bpy.types.Object = bpy.data.objects.new("SouthPoleBiomePatch", mesh)
    terrain.data.materials.append(materials["terrain_vertex"])

    color_attribute: bpy.types.Attribute = terrain.data.color_attributes.new(
        name="terrain_color",
        type="BYTE_COLOR",
        domain="CORNER",
    )
    for polygon in terrain.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = terrain.data.loops[loop_index].vertex_index
            color_attribute.data[loop_index].color = colors[vertex_index]

    link_to_collection(terrain, collection)

    bpy.context.view_layer.objects.active = terrain
    terrain.select_set(True)
    bpy.ops.object.shade_flat()
    terrain.select_set(False)
    return terrain


def add_cube_object(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj: bpy.types.Object = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    link_to_collection(obj, collection)
    return obj


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    segments: int = 16,
    rings: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj: bpy.types.Object = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    link_to_collection(obj, collection)
    bpy.ops.object.shade_flat()
    return obj


def add_cone(
    name: str,
    vertices: int,
    radius1: float,
    radius2: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
    )
    obj: bpy.types.Object = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    link_to_collection(obj, collection)
    bpy.ops.object.shade_flat()
    return obj


def add_cylinder(
    name: str,
    vertices: int,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj: bpy.types.Object = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    link_to_collection(obj, collection)
    bpy.ops.object.shade_flat()
    return obj


def add_prop_empty(name: str, collection: bpy.types.Collection) -> bpy.types.Object:
    empty: bpy.types.Object = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    collection.objects.link(empty)
    return empty


def parent_all(parent: bpy.types.Object, children: Iterable[bpy.types.Object]) -> None:
    for child in children:
        child.parent = parent


def make_rock_stack(name: str, collection: bpy.types.Collection, materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root: bpy.types.Object = add_prop_empty(name, collection)
    children: list[bpy.types.Object] = []
    for index in range(4):
        obj: bpy.types.Object = add_uv_sphere(
            f"{name}_stone_{index}",
            (random.uniform(-0.6, 0.6), 0.2 + index * 0.25, random.uniform(-0.45, 0.45)),
            (random.uniform(0.55, 1.1), random.uniform(0.25, 0.55), random.uniform(0.45, 0.9)),
            materials["stone" if index % 2 == 0 else "stone_dark"],
            collection,
            10,
            6,
        )
        obj.rotation_euler = (random.random() * 0.8, random.random() * 1.5, random.random() * 0.8)
        children.append(obj)
    parent_all(root, children)
    return root


def make_tree(name: str, collection: bpy.types.Collection, materials: dict[str, bpy.types.Material], broad: bool) -> bpy.types.Object:
    root: bpy.types.Object = add_prop_empty(name, collection)
    trunk: bpy.types.Object = add_cylinder(f"{name}_trunk", 8, 0.22, 2.3, (0.0, 1.15, 0.0), materials["bark"], collection)
    crown_material: bpy.types.Material = materials["leaf"] if broad else materials["leaf_dark"]
    crowns: list[bpy.types.Object] = []
    if broad:
        crowns.append(add_uv_sphere(f"{name}_crown_a", (0.0, 2.6, 0.0), (1.35, 1.0, 1.25), crown_material, collection, 12, 6))
        crowns.append(add_uv_sphere(f"{name}_crown_b", (-0.55, 2.25, 0.2), (0.9, 0.7, 0.8), crown_material, collection, 12, 6))
        crowns.append(add_uv_sphere(f"{name}_crown_c", (0.55, 2.2, -0.2), (0.9, 0.65, 0.85), crown_material, collection, 12, 6))
    else:
        crowns.append(add_cone(f"{name}_leaf_low", 10, 1.25, 0.0, 1.8, (0.0, 2.0, 0.0), crown_material, collection))
        crowns.append(add_cone(f"{name}_leaf_high", 10, 0.9, 0.0, 1.55, (0.0, 2.85, 0.0), crown_material, collection))
    parent_all(root, [trunk, *crowns])
    return root


def make_log(name: str, collection: bpy.types.Collection, materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root: bpy.types.Object = add_prop_empty(name, collection)
    log: bpy.types.Object = add_cylinder(f"{name}_log", 12, 0.35, 2.7, (0.0, 0.35, 0.0), materials["bark"], collection)
    log.rotation_euler = (0.0, math.radians(90.0), random.uniform(-0.2, 0.2))
    caps: list[bpy.types.Object] = [
        add_cylinder(f"{name}_cap_a", 12, 0.36, 0.04, (-1.35, 0.35, 0.0), materials["dirt"], collection),
        add_cylinder(f"{name}_cap_b", 12, 0.36, 0.04, (1.35, 0.35, 0.0), materials["dirt"], collection),
    ]
    for cap in caps:
        cap.rotation_euler = (0.0, math.radians(90.0), 0.0)
    parent_all(root, [log, *caps])
    return root


def make_reed_patch(name: str, collection: bpy.types.Collection, materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root: bpy.types.Object = add_prop_empty(name, collection)
    children: list[bpy.types.Object] = []
    for index in range(9):
        height: float = random.uniform(0.9, 1.9)
        x: float = random.uniform(-0.75, 0.75)
        z: float = random.uniform(-0.75, 0.75)
        reed: bpy.types.Object = add_cube_object(
            f"{name}_reed_{index}",
            (x, height * 0.5, z),
            (0.035, height * 0.5, 0.035),
            materials["reed"],
            collection,
        )
        reed.rotation_euler = (random.uniform(-0.18, 0.18), 0.0, random.uniform(-0.18, 0.18))
        children.append(reed)
    parent_all(root, children)
    return root


def make_flower_clump(name: str, collection: bpy.types.Collection, materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root: bpy.types.Object = add_prop_empty(name, collection)
    children: list[bpy.types.Object] = []
    for index in range(7):
        x: float = random.uniform(-0.65, 0.65)
        z: float = random.uniform(-0.65, 0.65)
        stem: bpy.types.Object = add_cube_object(f"{name}_stem_{index}", (x, 0.25, z), (0.025, 0.25, 0.025), materials["leaf_dark"], collection)
        bloom: bpy.types.Object = add_uv_sphere(f"{name}_bloom_{index}", (x, 0.55, z), (0.12, 0.08, 0.12), materials["flower"], collection, 8, 4)
        children.extend([stem, bloom])
    parent_all(root, children)
    return root


def make_crystal_cluster(name: str, collection: bpy.types.Collection, materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root: bpy.types.Object = add_prop_empty(name, collection)
    children: list[bpy.types.Object] = []
    for index in range(5):
        crystal: bpy.types.Object = add_cone(
            f"{name}_crystal_{index}",
            6,
            random.uniform(0.12, 0.24),
            0.02,
            random.uniform(0.8, 1.55),
            (random.uniform(-0.45, 0.45), random.uniform(0.4, 0.8), random.uniform(-0.45, 0.45)),
            materials["crystal"],
            collection,
        )
        crystal.rotation_euler = (random.uniform(-0.25, 0.25), random.uniform(0.0, 3.14), random.uniform(-0.25, 0.25))
        children.append(crystal)
    parent_all(root, children)
    return root


def make_props(materials: dict[str, bpy.types.Material], collection: bpy.types.Collection) -> list[bpy.types.Object]:
    props: list[bpy.types.Object] = [
        make_rock_stack("prop_01_rounded_boulder_cluster", collection, materials),
        make_rock_stack("prop_02_flat_stepping_stones", collection, materials),
        make_tree("prop_03_broadleaf_tree", collection, materials, True),
        make_tree("prop_04_south_pole_pine", collection, materials, False),
        make_log("prop_05_fallen_log", collection, materials),
        make_reed_patch("prop_06_reed_patch", collection, materials),
        make_flower_clump("prop_07_red_flower_clump", collection, materials),
        make_crystal_cluster("prop_08_blue_crystal_cluster", collection, materials),
        make_tree("prop_09_small_bent_tree", collection, materials, True),
        make_rock_stack("prop_10_tall_shard_rocks", collection, materials),
        make_reed_patch("prop_11_tall_grass_patch", collection, materials),
        make_log("prop_12_half_buried_root", collection, materials),
    ]
    props[1].scale = (1.25, 0.45, 1.0)
    props[8].scale = (0.7, 0.85, 0.7)
    props[8].rotation_euler = (0.0, 0.0, math.radians(8.0))
    props[9].scale = (0.75, 1.55, 0.75)
    props[11].scale = (1.15, 0.75, 0.7)
    return props


def place_props_on_demo_patch(props: list[bpy.types.Object]) -> None:
    positions: list[tuple[float, float]] = [
        (-24.0, -18.0), (-12.0, -24.0), (3.0, -25.0), (18.0, -18.0),
        (-28.0, 0.0), (-12.0, 5.0), (6.0, 6.0), (25.0, 2.0),
        (-21.0, 21.0), (-4.0, 24.0), (12.0, 21.0), (28.0, 18.0),
    ]
    for prop, (x, z) in zip(props, positions):
        prop.location = surface_position_from_tangent(x, z, terrain_height(x, z) + 0.15)
        prop.rotation_euler = (0.0, random.uniform(0.0, math.tau), 0.0)


def select_hierarchy(root: bpy.types.Object) -> None:
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)


def export_selected_glb(path: Path) -> None:
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def export_assets(terrain: bpy.types.Object, props: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    terrain.select_set(True)
    bpy.context.view_layer.objects.active = terrain
    export_selected_glb(TERRAIN_OUTPUT_PATH)
    export_selected_glb(LEGACY_TERRAIN_OUTPUT_PATH)
    terrain.select_set(False)

    for prop in props:
        bpy.ops.object.select_all(action="DESELECT")
        select_hierarchy(prop)
        bpy.context.view_layer.objects.active = prop
        export_selected_glb(PROP_OUTPUT_DIR / f"{prop.name}.glb")


def add_lighting_and_camera() -> None:
    bpy.ops.object.light_add(type="SUN", location=(0.0, 8.0, 8.0))
    sun: bpy.types.Object = bpy.context.object
    sun.name = "PreviewSun"
    sun.data.energy = 2.0
    sun.rotation_euler = (math.radians(45.0), 0.0, math.radians(35.0))

    bpy.ops.object.camera_add(location=(0.0, 32.0, 72.0), rotation=(math.radians(62.0), 0.0, math.radians(180.0)))
    bpy.context.scene.camera = bpy.context.object


def main() -> None:
    random.seed(RANDOM_SEED)
    ensure_dirs()
    clear_scene()

    materials: dict[str, bpy.types.Material] = create_materials()
    terrain_collection: bpy.types.Collection = make_collection("WL_Procedural_Terrain")
    props_collection: bpy.types.Collection = make_collection("WL_Terrain_Props")

    terrain: bpy.types.Object = create_terrain_patch(materials, terrain_collection)
    props: list[bpy.types.Object] = make_props(materials, props_collection)
    add_lighting_and_camera()
    export_assets(terrain, props)
    place_props_on_demo_patch(props)

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT_PATH))
    print(f"Wiper-Land terrain kit written to {BLEND_OUTPUT_PATH}")
    print(f"Terrain GLB written to {TERRAIN_OUTPUT_PATH}")
    print(f"Prop GLBs written to {PROP_OUTPUT_DIR}")


if __name__ == "__main__":
    main()
