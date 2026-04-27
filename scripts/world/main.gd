extends Node3D

const GRUNT_SCENE := preload("res://scenes/entities/grunt.tscn")
const MONSTER_COUNT := 1000
const FIBONACCI_ANGLE := 2.399963229728653
const SURFACE_OFFSET := 0.05
const NORTH_POLE_MONSTER_COLOR := Color(1.0, 0.05, 0.03, 1.0)
const LOD_UPDATE_INTERVAL := 0.25
const MONSTER_ACTIVE_DISTANCE := 160.0
const MONSTER_RENDER_DISTANCE := 260.0
const MONSTER_ACTIVE_DISTANCE_SQUARED := MONSTER_ACTIVE_DISTANCE * MONSTER_ACTIVE_DISTANCE
const MONSTER_RENDER_DISTANCE_SQUARED := MONSTER_RENDER_DISTANCE * MONSTER_RENDER_DISTANCE

# Terrain LOD constants
const TERRAIN_CHUNK_COUNT    : int   = 128    # Fibonacci-distributed patches across the sphere
const TERRAIN_COLLISION_DIST : float = 500.0  # surface distance: spawn + full collision
const TERRAIN_RENDER_DIST    : float = 850.0  # surface distance: visible, no collision

@onready var player: CharacterBody3D = $Player
@onready var hud: HUD = $HUD
@onready var north_pole_beam: Node3D = $NorthPoleBeam

var _grunts: Array[Grunt] = []
var _lod_timer: float = 0.0

var _terrain_dirs  : Array[Vector3]       # chunk center directions (Fibonacci sphere)
var _terrain_nodes : Array               # Array[TerrainChunk|null], parallel to _terrain_dirs
var _terrain_gen   : TerrainGenerator


func _ready() -> void:
	var player_health: Health = player.get_node("Health")
	hud.connect_to_player(player_health, player, north_pole_beam)
	_init_terrain()
	_spawn_grunts()
	_update_monster_lod()
	_update_terrain_lod()


func _process(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer > 0.0:
		return
	_lod_timer = LOD_UPDATE_INTERVAL
	_update_monster_lod()
	_update_terrain_lod()


# ---------- Terrain ----------

func _init_terrain() -> void:
	_terrain_gen = TerrainGenerator.new()
	_terrain_dirs.resize(TERRAIN_CHUNK_COUNT)
	_terrain_nodes.resize(TERRAIN_CHUNK_COUNT)
	for i: int in range(TERRAIN_CHUNK_COUNT):
		_terrain_dirs[i] = _fibonacci_sphere_direction(i, TERRAIN_CHUNK_COUNT)
		_terrain_nodes[i] = null


func _spawn_terrain_chunk(index: int) -> void:
	var dir : Vector3 = _terrain_dirs[index]
	var mesh : ArrayMesh = _terrain_gen.build_sphere_patch(dir)
	var chunk := TerrainChunk.new()
	chunk.name = "TC_%d" % index
	add_child(chunk)
	chunk.setup(mesh)
	_terrain_nodes[index] = chunk


func _update_terrain_lod() -> void:
	var player_dir : Vector3 = (player.global_position - Planet.CENTER).normalized()

	for i: int in range(TERRAIN_CHUNK_COUNT):
		var chunk_dir : Vector3 = _terrain_dirs[i]
		var cos_angle : float   = clampf(chunk_dir.dot(player_dir), -1.0, 1.0)
		var surf_dist : float   = acos(cos_angle) * Planet.RADIUS

		var chunk : TerrainChunk = _terrain_nodes[i] as TerrainChunk

		if surf_dist <= TERRAIN_COLLISION_DIST:
			if chunk == null:
				_spawn_terrain_chunk(i)
				chunk = _terrain_nodes[i]
			chunk.visible = true
			chunk.enable_collision()
		elif surf_dist <= TERRAIN_RENDER_DIST:
			if chunk == null:
				_spawn_terrain_chunk(i)
				chunk = _terrain_nodes[i]
			chunk.visible = true
			chunk.disable_collision()
		else:
			if chunk != null:
				chunk.queue_free()
				_terrain_nodes[i] = null


# ---------- Monsters ----------

func _spawn_grunts() -> void:
	var north_direction: Vector3 = (north_pole_beam.global_position - Planet.CENTER).normalized()
	_spawn_grunt_at(_surface_position(north_direction), true)

	for i: int in range(MONSTER_COUNT - 1):
		var direction: Vector3 = _fibonacci_sphere_direction(i, MONSTER_COUNT - 1)
		if direction.dot(north_direction) > 0.995:
			direction = direction.rotated(Vector3.RIGHT, 0.12).normalized()
		_spawn_grunt_at(_surface_position(direction), false)


func _spawn_grunt_at(world_pos: Vector3, is_north_pole_monster: bool) -> void:
	var grunt: Grunt = GRUNT_SCENE.instantiate() as Grunt
	add_child(grunt)
	grunt.global_position = world_pos
	grunt.initialize(player)
	_grunts.append(grunt)
	if is_north_pole_monster:
		grunt.name = "NorthPoleRedGrunt"
		grunt.set_skeleton_color(NORTH_POLE_MONSTER_COLOR)


func _surface_position(direction: Vector3) -> Vector3:
	var safe_direction: Vector3 = direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector3.UP
	return Planet.CENTER + safe_direction.normalized() * (Planet.RADIUS + SURFACE_OFFSET)


func _fibonacci_sphere_direction(index: int, count: int) -> Vector3:
	var y: float = 1.0 - (float(index) / float(maxi(1, count - 1))) * 2.0
	var radius: float = sqrt(maxf(0.0, 1.0 - y * y))
	var theta: float = FIBONACCI_ANGLE * float(index)
	return Vector3(cos(theta) * radius, y, sin(theta) * radius).normalized()


func _update_monster_lod() -> void:
	var player_position: Vector3 = player.global_position
	for index: int in range(_grunts.size() - 1, -1, -1):
		var grunt: Grunt = _grunts[index]
		if not is_instance_valid(grunt):
			_grunts.remove_at(index)
			continue
		var distance_squared: float = grunt.global_position.distance_squared_to(player_position)
		var is_visible: bool = distance_squared <= MONSTER_RENDER_DISTANCE_SQUARED
		var is_active: bool = distance_squared <= MONSTER_ACTIVE_DISTANCE_SQUARED
		grunt.set_lod_state(is_active, is_visible)
