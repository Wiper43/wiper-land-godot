extends Node3D

const GRUNT_SCENE := preload("res://scenes/entities/grunt.tscn")
const TARGET_DUMMY_SCENE := preload("res://scenes/entities/target_dummy.tscn")
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
const SANDBOX_DIRECTION: Vector3 = Vector3.UP
const SANDBOX_ALTITUDE: float = 260.0
const SANDBOX_FLOOR_THICKNESS: float = 1.0
const SANDBOX_TOGGLE_HEIGHT: float = 2.5
const SANDBOX_LABEL_HEIGHT: float = 2.0
const SANDBOX_SURFACE_OFFSET: float = 0.05

@onready var player: CharacterBody3D = $Player
@onready var hud: HUD = $HUD
@onready var north_pole_beam: Node3D = $NorthPoleBeam

var _grunts: Array[Grunt] = []
var _lod_timer: float = 0.0

var _terrain_dirs  : Array[Vector3]       # chunk center directions (Fibonacci sphere)
var _terrain_nodes : Array               # Array[TerrainChunk|null], parallel to _terrain_dirs
var _terrain_gen   : TerrainGenerator
var _sandbox_root: Node3D = null
var _sandbox_active: bool = false
var _sandbox_return_position: Vector3 = Vector3.ZERO
var _sandbox_return_basis: Basis = Basis()
var _sandbox_spawn_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	var player_health: Health = player.get_node("Health")
	hud.connect_to_player(player_health, player, north_pole_beam)
	_init_terrain()
	_build_sandbox()
	_spawn_grunts()
	_update_monster_lod()
	_update_terrain_lod()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_sandbox"):
		_toggle_sandbox()
		get_viewport().set_input_as_handled()


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


# ---------- Sandbox ----------

func _build_sandbox() -> void:
	_sandbox_root = Node3D.new()
	_sandbox_root.name = "DevSandbox"
	add_child(_sandbox_root)

	var origin: Vector3 = Planet.CENTER + SANDBOX_DIRECTION.normalized() * (Planet.RADIUS + SANDBOX_ALTITUDE)
	var up: Vector3 = Planet.surface_up(origin)
	var forward: Vector3 = Planet.project_on_plane(Vector3.FORWARD, up)
	if forward.length_squared() < 0.001:
		forward = Planet.project_on_plane(Vector3.RIGHT, up)
	forward = forward.normalized()
	var right: Vector3 = forward.cross(up).normalized()
	_create_sandbox_box(
		"MainFloor",
		origin - up * (SANDBOX_FLOOR_THICKNESS * 0.5),
		Vector3(132.0, SANDBOX_FLOOR_THICKNESS, 86.0),
		Basis(right, up, -forward),
		Color(0.18, 0.23, 0.22, 1.0)
	)
	_create_sandbox_box(
		"FallLanding",
		origin - forward * 58.0 - up * 18.0,
		Vector3(34.0, SANDBOX_FLOOR_THICKNESS, 24.0),
		Basis(right, up, -forward),
		Color(0.12, 0.19, 0.24, 1.0)
	)
	_create_sandbox_box(
		"JumpLedge",
		origin - forward * 25.0 + right * 48.0 + up * 5.0,
		Vector3(16.0, SANDBOX_FLOOR_THICKNESS, 14.0),
		Basis(right, up, -forward),
		Color(0.24, 0.24, 0.15, 1.0)
	)
	_create_sandbox_backstop(origin, right, up, forward)
	_create_sandbox_slopes(origin, right, up, forward)
	_create_target_dummies(origin, right, up, forward)
	_create_sandbox_label("SANDBOX  T=return", origin + up * 3.0 - forward * 42.0, up)
	_sandbox_spawn_position = _snap_to_sandbox_floor(origin - forward * 46.0, up) + up * SANDBOX_TOGGLE_HEIGHT


func _create_sandbox_slopes(origin: Vector3, right: Vector3, up: Vector3, forward: Vector3) -> void:
	var angles: Array[float] = [15.0, 30.0, 45.0, 60.0, 75.0, 90.0, 105.0]
	var start_x: float = -48.0
	for i: int in range(angles.size()):
		var angle: float = angles[i]
		var x_offset: float = start_x + float(i) * 16.0
		var ramp_length: float = 11.0
		var ramp_thickness: float = 0.5
		var ramp_basis: Basis = Basis(right, up, -forward).rotated(right, deg_to_rad(angle))
		var center: Vector3 = origin + right * x_offset + forward * 8.0
		center += up * (ramp_thickness * 0.5 + sin(deg_to_rad(angle)) * ramp_length * 0.5)
		_create_sandbox_box(
			"Slope_%d" % roundi(angle),
			center,
			Vector3(7.0, ramp_thickness, ramp_length),
			ramp_basis,
			_slope_color(angle)
		)
		_create_sandbox_label("%d deg" % roundi(angle), center + up * SANDBOX_LABEL_HEIGHT, up)


func _create_sandbox_backstop(origin: Vector3, right: Vector3, up: Vector3, forward: Vector3) -> void:
	_create_sandbox_box(
		"AttackBackstop",
		origin + forward * 34.0 + up * 4.0,
		Vector3(54.0, 8.0, 1.0),
		Basis(right, up, -forward),
		Color(0.22, 0.12, 0.12, 1.0)
	)


func _create_target_dummies(origin: Vector3, right: Vector3, up: Vector3, forward: Vector3) -> void:
	for i: int in range(4):
		var dummy: StaticBody3D = TARGET_DUMMY_SCENE.instantiate() as StaticBody3D
		_sandbox_root.add_child(dummy)
		var target_position: Vector3 = origin + right * (-18.0 + float(i) * 12.0) + forward * 26.0
		dummy.global_position = _snap_to_sandbox_floor(target_position, up)
		dummy.global_transform.basis = Planet.align_basis_to_surface(-forward, Planet.surface_up(dummy.global_position))


func _snap_to_sandbox_floor(target_position: Vector3, up: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		target_position + up * 12.0,
		target_position - up * 24.0,
		1
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return target_position + up * SANDBOX_SURFACE_OFFSET
	return (hit["position"] as Vector3) + up * SANDBOX_SURFACE_OFFSET


func _create_sandbox_box(
	box_name: String,
	world_position: Vector3,
	size: Vector3,
	basis: Basis,
	color: Color
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 0
	_sandbox_root.add_child(body)
	body.global_transform = Transform3D(basis, world_position)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.shape = shape
	body.add_child(collision_shape)


func _create_sandbox_label(label_text: String, world_position: Vector3, _up: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.name = "Label_%s" % label_text.replace(" ", "_")
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.modulate = Color(0.92, 0.98, 1.0, 1.0)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.outline_size = 10
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.no_depth_test = true
	_sandbox_root.add_child(label)
	label.global_position = world_position


func _slope_color(angle: float) -> Color:
	if angle < 45.0:
		return Color(0.18, 0.36, 0.21, 1.0)
	if angle < 75.0:
		return Color(0.72, 0.48, 0.12, 1.0)
	return Color(0.26, 0.36, 0.75, 1.0)


func _toggle_sandbox() -> void:
	if _sandbox_active:
		player.global_transform = Transform3D(_sandbox_return_basis, _sandbox_return_position)
		player.velocity = Vector3.ZERO
		_sandbox_active = false
		return
	_sandbox_return_position = player.global_position
	_sandbox_return_basis = player.global_transform.basis
	player.global_position = _sandbox_spawn_position
	player.velocity = Vector3.ZERO
	_sandbox_active = true


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
