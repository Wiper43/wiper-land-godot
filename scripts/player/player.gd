extends CharacterBody3D

signal climb_energy_changed(current: float, maximum: float, should_show: bool)

const WALK_SPEED := 14.0
const SPRINT_SPEED := 14.0
const FLY_SPEED := 200.0
const FLY_SPRINT_SPEED := 90.0
const JUMP_FORCE := 12.0
const GRAVITY := 30.0
const MOUSE_SENS := 0.002
const GROUND_STICK_FORCE := 4.0
const CAMERA_FIRST_PERSON_OFFSET := Vector3(0, 0.0, 0.0)
const CAMERA_THIRD_PERSON_OFFSET := Vector3(0, 2.2, 7.0)
const CAMERA_FLY_OFFSET := Vector3(0, 3.5, 14.0)
const EXTERNAL_KNOCKBACK_DECAY := 16.0

const ATTACK_RANGE := 3.0
const ATTACK_DAMAGE := 25.0
const ATTACK_KNOCKBACK := 12.0
const ATTACK_COOLDOWN := 0.5
const ATTACK_VFX_PUFF_COUNT: int = 9
const ATTACK_VFX_DURATION: float = 0.22
const ATTACK_VFX_FLAME_LENGTH: float = 3.2
const ATTACK_VFX_FLAME_WIDTH: float = 0.65
const ATTACK_VFX_FIREBALL_RADIUS: float = 0.55

const BOMB_RANGE := 20.0
const BOMB_RADIUS := 5.0
const BOMB_DAMAGE := 15.0
const BOMB_KNOCKBACK := 18.0
const BOMB_COOLDOWN := 1.5
const BOMB_TRAVEL_TIME := 0.28
const BOMB_VFX_DURATION := 0.55
const BOMB_PUFF_COUNT: int = 12
const MAX_CLIMB_ENERGY: float = 5.0
const CLIMB_SPEED: float = 3.5
const CLIMB_STRAFE_SPEED: float = 5.0
const CLIMB_DETECT_DISTANCE: float = 1.35
const CLIMB_MIN_SURFACE_SIZE: float = 2.0
const CLIMB_SURFACE_PROBE_OUTSET: float = 0.18
const CLIMB_SURFACE_PROBE_DEPTH: float = 0.7
const CLIMB_JUMP_OUT_FORCE: float = 8.0
const CLIMB_JUMP_UP_FORCE: float = 8.0
const CLIMB_STICK_FORCE: float = 7.0
const CLIMB_STICK_MIN_ANGLE: float = 85.0
const CLIMB_RECOVER_DELAY: float = 0.8
const CLIMB_RECOVER_RATE: float = 1.35
const CLIMB_MIN_ANGLE: float = 45.0
const CLIMB_MAX_ANGLE: float = 95.0
const CLIMB_MOVE_DRAIN_RATE: float = 1.0
const CLIMB_IDLE_DRAIN_RATE: float = 0.5
const CLIMB_HUD_VISIBLE_SECONDS: float = 1.2
const CLIMB_LEDGE_FORWARD_DISTANCE: float = 1.05
const CLIMB_LEDGE_UP_DISTANCE: float = 2.2
const CLIMB_LEDGE_DOWN_DISTANCE: float = 3.4
const CLIMB_LEDGE_FACE_CHECK_DISTANCE: float = 1.25
const CLIMB_VERTICAL_LEDGE_MIN_ANGLE: float = 85.0
const CLIMB_VERTICAL_LEDGE_FORWARD_DISTANCE: float = 0.42
const CLIMB_VERTICAL_LEDGE_UP_DISTANCE: float = 1.55
const CLIMB_VERTICAL_LEDGE_DOWN_DISTANCE: float = 2.45
const CLIMB_VERTICAL_LEDGE_FACE_CHECK_DISTANCE: float = 0.65
const CLIMB_VERTICAL_MANTLE_FORWARD_NUDGE: float = 0.18
const MANTLE_DURATION: float = 0.5
const MANTLE_SURFACE_OFFSET: float = 0.08
const MANTLE_FORWARD_NUDGE: float = 0.35
const MANTLE_MIN_TOP_GAIN: float = 0.35
const MANTLE_CONTACT_MISSING_GRACE: float = 0.1
const MANTLE_COOLDOWN: float = 0.25
const MANTLE_HAND_ORBIT_RADIUS: float = 0.42
const MANTLE_HAND_ORBIT_SPEED: float = 24.0
const MANTLE_HAND_SIZE: float = 0.12
const EDGE_GUARD_FORWARD_DISTANCE: float = 0.85
const EDGE_GUARD_RAY_UP: float = 0.65
const EDGE_GUARD_RAY_DOWN: float = 2.0
const FLAME_ATTACK_SOUND: AudioStream = preload("res://assets/audio/flame_attack_lowfi.wav")
const BOMB_EXPLOSION_SOUND: AudioStream = preload("res://assets/audio/bomb_explosion_lowfi.wav")
const PLAYER_SOFT_OUCH_SOUND: AudioStream = preload("res://assets/audio/player_soft_ouch_lowfi.wav")

@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var camera_arm: Node3D = $CameraArm
@onready var health: Health = $Health
@onready var visual_body: Node3D = $VisualBody

var look_pitch := 0.0
var fly_mode := false
var third_person_mode := false
var body_forward := Vector3.FORWARD
var _attack_timer := 0.0
var _bomb_timer := 0.0
var _external_knockback_velocity: Vector3 = Vector3.ZERO
var _climb_energy: float = MAX_CLIMB_ENERGY
var _is_climbing: bool = false
var _climb_normal: Vector3 = Vector3.ZERO
var _last_climb_normal: Vector3 = Vector3.ZERO
var _climb_surface_angle: float = 0.0
var _climb_is_moving: bool = false
var _climb_recover_timer: float = 0.0
var _climb_hud_visible_timer: float = 0.0
var _is_mantling: bool = false
var _mantle_timer: float = 0.0
var _mantle_missing_contact_timer: float = 0.0
var _mantle_cooldown_timer: float = 0.0
var _mantle_start_position: Vector3 = Vector3.ZERO
var _mantle_target_position: Vector3 = Vector3.ZERO
var _mantle_vfx_root: Node3D = null
var _mantle_left_hand: MeshInstance3D = null
var _mantle_right_hand: MeshInstance3D = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var surface_up := Planet.surface_up(global_position)
	body_forward = Planet.project_on_plane(-global_transform.basis.z, surface_up)
	if body_forward.length_squared() < 0.001:
		body_forward = Vector3.FORWARD
	body_forward = body_forward.normalized()
	health.died.connect(_on_died)
	_update_camera_pose()
	_emit_climb_energy(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var surface_up := Planet.surface_up(global_position)
		body_forward = body_forward.rotated(surface_up, -event.relative.x * MOUSE_SENS).normalized()
		look_pitch = clamp(look_pitch - event.relative.y * MOUSE_SENS, -1.35, 1.35)
		_update_camera_pose()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if _attack_timer <= 0.0:
			_do_melee_attack()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _bomb_timer <= 0.0:
			_do_flame_bomb()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("toggle_fly"):
		fly_mode = not fly_mode
		velocity = Vector3.ZERO
		_update_camera_pose()

	if event.is_action_pressed("toggle_third_person"):
		third_person_mode = not third_person_mode
		_update_camera_pose()


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_bomb_timer = maxf(0.0, _bomb_timer - delta)
	_mantle_cooldown_timer = maxf(0.0, _mantle_cooldown_timer - delta)
	var surface_up := Planet.surface_up(global_position)
	up_direction = surface_up
	_align_to_planet(surface_up)

	if _is_mantling:
		_apply_mantle(delta)
		_update_climb_energy(delta)
		return
	elif fly_mode:
		_is_climbing = false
		_apply_fly_movement(surface_up)
	else:
		var was_climbing: bool = _is_climbing
		_update_climb_contact(surface_up)
		_update_climb_state(surface_up)
		if _is_climbing:
			_mantle_missing_contact_timer = 0.0
			_apply_climb_movement(surface_up)
			if _has_mantle_intent() and _try_start_mantle(surface_up):
				velocity = Vector3.ZERO
		elif was_climbing \
				and Input.is_action_pressed("climb") \
				and _has_mantle_intent() \
				and _update_mantle_missing_contact(delta) \
				and _try_start_mantle(surface_up):
			velocity = Vector3.ZERO
		else:
			_apply_ground_gravity(surface_up, delta)
			_apply_ground_movement(surface_up)
			_apply_jump(surface_up)

	move_and_slide()
	_update_climb_energy(delta)
	_decay_external_knockback(delta)


func _align_to_planet(surface_up: Vector3) -> void:
	body_forward = Planet.project_on_plane(body_forward, surface_up)
	if body_forward.length_squared() < 0.001:
		body_forward = Planet.project_on_plane(Vector3.FORWARD, surface_up)
	if body_forward.length_squared() < 0.001:
		body_forward = Planet.project_on_plane(Vector3.RIGHT, surface_up)
	body_forward = body_forward.normalized()
	global_transform.basis = Planet.align_basis_to_surface(body_forward, surface_up)


func _apply_ground_gravity(surface_up: Vector3, delta: float) -> void:
	var gravity_dir := -surface_up

	if is_on_floor():
		var inward_velocity := velocity.dot(gravity_dir)
		if inward_velocity > 0.0:
			velocity -= gravity_dir * inward_velocity
		velocity += gravity_dir * GROUND_STICK_FORCE
	else:
		velocity += gravity_dir * GRAVITY * delta


func _apply_ground_movement(surface_up: Vector3) -> void:
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var move_dir := _get_surface_move_input(surface_up)
	if Input.is_action_pressed("climb") and is_on_floor():
		move_dir = _apply_edge_guard(move_dir, surface_up)
	var vertical_velocity := surface_up * velocity.dot(surface_up)
	velocity = move_dir * speed + vertical_velocity + _external_knockback_velocity


func _update_climb_contact(surface_up: Vector3) -> void:
	_climb_normal = Vector3.ZERO
	_climb_surface_angle = 0.0
	_try_climb_slide_contacts(surface_up)
	if _climb_normal.length_squared() > 0.001:
		return

	_try_climb_floor_contact(surface_up)
	if _climb_normal.length_squared() > 0.001:
		return

	var probe_forward: Vector3 = -camera.global_transform.basis.z
	if probe_forward.length_squared() < 0.001:
		probe_forward = body_forward
	probe_forward = probe_forward.normalized()
	_try_climb_ray(surface_up, probe_forward)
	if _climb_normal.length_squared() > 0.001:
		return

	_try_climb_ray(surface_up, body_forward)


func _try_climb_slide_contacts(surface_up: Vector3) -> void:
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		_set_climb_contact(collision.get_normal(), surface_up, collision.get_position())
		if _climb_normal.length_squared() > 0.001:
			return


func _try_climb_ray(surface_up: Vector3, probe_direction: Vector3) -> void:
	if probe_direction.length_squared() < 0.001:
		return
	var safe_direction: Vector3 = Planet.project_on_plane(probe_direction, surface_up)
	if safe_direction.length_squared() < 0.001:
		safe_direction = probe_direction
	safe_direction = safe_direction.normalized()
	var ray_start: Vector3 = global_position + surface_up * 1.0
	var ray_end: Vector3 = ray_start + safe_direction * CLIMB_DETECT_DISTANCE
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_set_climb_contact(hit["normal"] as Vector3, surface_up, hit["position"] as Vector3)


func _set_climb_contact(normal: Vector3, surface_up: Vector3, contact_point: Vector3) -> void:
	var angle: float = _surface_angle(normal, surface_up)
	if not _is_angle_in_range(angle, CLIMB_MIN_ANGLE, CLIMB_MAX_ANGLE):
		return
	if not _has_min_climb_surface_size(normal.normalized(), surface_up, contact_point):
		return
	_climb_normal = normal.normalized()
	_last_climb_normal = _climb_normal
	_climb_surface_angle = angle


func _try_climb_floor_contact(surface_up: Vector3) -> void:
	var ray_start: Vector3 = global_position + surface_up * 1.0
	var ray_end: Vector3 = global_position - surface_up * 2.4
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_set_climb_contact(hit["normal"] as Vector3, surface_up, hit["position"] as Vector3)


func _has_min_climb_surface_size(normal: Vector3, surface_up: Vector3, contact_point: Vector3) -> bool:
	var wall_up: Vector3 = Planet.project_on_plane(surface_up, normal)
	if wall_up.length_squared() < 0.001:
		wall_up = Planet.project_on_plane(body_forward, normal)
	if wall_up.length_squared() < 0.001:
		return false
	wall_up = wall_up.normalized()
	var wall_right: Vector3 = wall_up.cross(normal)
	if wall_right.length_squared() < 0.001:
		return false
	wall_right = wall_right.normalized()

	var half_size: float = CLIMB_MIN_SURFACE_SIZE * 0.5
	return _climb_surface_probe(contact_point + wall_right * half_size, normal, surface_up) \
		and _climb_surface_probe(contact_point - wall_right * half_size, normal, surface_up) \
		and _climb_surface_probe(contact_point + wall_up * half_size, normal, surface_up) \
		and _climb_surface_probe(contact_point - wall_up * half_size, normal, surface_up)


func _climb_surface_probe(sample_point: Vector3, normal: Vector3, surface_up: Vector3) -> bool:
	var ray_start: Vector3 = sample_point + normal * CLIMB_SURFACE_PROBE_OUTSET
	var ray_end: Vector3 = sample_point - normal * CLIMB_SURFACE_PROBE_DEPTH
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_normal: Vector3 = (hit["normal"] as Vector3).normalized()
	if hit_normal.dot(normal) < 0.92:
		return false
	var angle: float = _surface_angle(hit_normal, surface_up)
	return _is_angle_in_range(angle, CLIMB_MIN_ANGLE, CLIMB_MAX_ANGLE)


func _update_climb_state(surface_up: Vector3) -> void:
	var can_climb: bool = _climb_normal.length_squared() > 0.001 and _climb_energy > 0.0
	_is_climbing = Input.is_action_pressed("climb") and can_climb
	if _is_climbing:
		up_direction = surface_up


func _apply_climb_movement(surface_up: Vector3) -> void:
	if Input.is_action_just_pressed("jump"):
		velocity = _climb_normal * CLIMB_JUMP_OUT_FORCE + surface_up * CLIMB_JUMP_UP_FORCE
		_is_climbing = false
		_climb_recover_timer = CLIMB_RECOVER_DELAY
		return

	var wall_up: Vector3 = Planet.project_on_plane(surface_up, _climb_normal)
	if wall_up.length_squared() < 0.001:
		wall_up = surface_up
	wall_up = wall_up.normalized()
	var wall_right: Vector3 = wall_up.cross(_climb_normal)
	if wall_right.length_squared() < 0.001:
		wall_right = body_forward.cross(surface_up)
	wall_right = wall_right.normalized()

	var climb_dir: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		climb_dir += wall_up
	if Input.is_action_pressed("move_back"):
		climb_dir -= wall_up
	if Input.is_action_pressed("move_right"):
		climb_dir += wall_right
	if Input.is_action_pressed("move_left"):
		climb_dir -= wall_right

	_climb_is_moving = climb_dir.length_squared() > 0.001
	if _climb_is_moving:
		climb_dir = climb_dir.normalized() * CLIMB_SPEED
	velocity = climb_dir + _get_climb_stick_velocity(surface_up) + _external_knockback_velocity


func _try_start_mantle(surface_up: Vector3) -> bool:
	if _mantle_cooldown_timer > 0.0:
		return false
	if _last_climb_normal.length_squared() < 0.001:
		return false
	var is_vertical_ledge: bool = _climb_surface_angle >= CLIMB_VERTICAL_LEDGE_MIN_ANGLE
	if not is_vertical_ledge and not _is_near_climb_ledge(surface_up):
		return false
	var top_forward: Vector3 = Planet.project_on_plane(-_last_climb_normal, surface_up)
	if top_forward.length_squared() < 0.001:
		top_forward = Planet.project_on_plane(body_forward, surface_up)
	if top_forward.length_squared() < 0.001:
		return false
	top_forward = top_forward.normalized()
	var ledge_forward_distance: float = CLIMB_VERTICAL_LEDGE_FORWARD_DISTANCE \
		if is_vertical_ledge else CLIMB_LEDGE_FORWARD_DISTANCE
	var ledge_up_distance: float = CLIMB_VERTICAL_LEDGE_UP_DISTANCE \
		if is_vertical_ledge else CLIMB_LEDGE_UP_DISTANCE
	var ledge_down_distance: float = CLIMB_VERTICAL_LEDGE_DOWN_DISTANCE \
		if is_vertical_ledge else CLIMB_LEDGE_DOWN_DISTANCE
	var ray_start: Vector3 = global_position \
		+ top_forward * ledge_forward_distance \
		+ surface_up * ledge_up_distance
	var ray_end: Vector3 = ray_start - surface_up * ledge_down_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var top_gain: float = ((hit["position"] as Vector3) - global_position).dot(surface_up)
	if top_gain < MANTLE_MIN_TOP_GAIN:
		return false
	var top_normal: Vector3 = (hit["normal"] as Vector3).normalized()
	if _surface_angle(top_normal, surface_up) > rad_to_deg(floor_max_angle):
		return false
	var forward_nudge: float = CLIMB_VERTICAL_MANTLE_FORWARD_NUDGE \
		if is_vertical_ledge else MANTLE_FORWARD_NUDGE
	_mantle_start_position = global_position
	_mantle_target_position = (hit["position"] as Vector3) \
		+ surface_up * MANTLE_SURFACE_OFFSET \
		+ top_forward * forward_nudge
	_mantle_timer = 0.0
	_is_mantling = true
	_is_climbing = false
	_climb_normal = Vector3.ZERO
	_last_climb_normal = Vector3.ZERO
	_climb_surface_angle = 0.0
	_climb_is_moving = false
	_mantle_missing_contact_timer = 0.0
	_mantle_cooldown_timer = MANTLE_COOLDOWN
	velocity = Vector3.ZERO
	_start_mantle_vfx()
	return true


func _is_near_climb_ledge(surface_up: Vector3) -> bool:
	var normal: Vector3 = _last_climb_normal
	if normal.length_squared() < 0.001:
		normal = _climb_normal
	if normal.length_squared() < 0.001:
		return false
	normal = normal.normalized()
	var wall_up: Vector3 = Planet.project_on_plane(surface_up, normal)
	if wall_up.length_squared() < 0.001:
		return true
	wall_up = wall_up.normalized()
	var face_check_distance: float = CLIMB_VERTICAL_LEDGE_FACE_CHECK_DISTANCE \
		if _climb_surface_angle >= CLIMB_VERTICAL_LEDGE_MIN_ANGLE else CLIMB_LEDGE_FACE_CHECK_DISTANCE
	var upper_sample: Vector3 = global_position + surface_up * 1.0 + wall_up * face_check_distance
	return not _climb_surface_probe(upper_sample, normal, surface_up)


func _has_mantle_intent() -> bool:
	return Input.is_action_pressed("move_forward") or Input.is_action_pressed("jump")


func _update_mantle_missing_contact(delta: float) -> bool:
	_mantle_missing_contact_timer += delta
	return _mantle_missing_contact_timer >= MANTLE_CONTACT_MISSING_GRACE


func _apply_mantle(delta: float) -> void:
	_mantle_timer = minf(MANTLE_DURATION, _mantle_timer + delta)
	var progress: float = _mantle_timer / MANTLE_DURATION
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	global_position = _mantle_start_position.lerp(_mantle_target_position, eased_progress)
	velocity = Vector3.ZERO
	_external_knockback_velocity = Vector3.ZERO
	_update_mantle_vfx()
	if _mantle_timer >= MANTLE_DURATION:
		global_position = _mantle_target_position
		_is_mantling = false
		_mantle_cooldown_timer = MANTLE_COOLDOWN
		_stop_mantle_vfx()


func _start_mantle_vfx() -> void:
	_stop_mantle_vfx()
	_mantle_vfx_root = Node3D.new()
	_mantle_vfx_root.name = "MantleHandsVFX"
	get_tree().current_scene.add_child(_mantle_vfx_root)
	_mantle_left_hand = _create_mantle_hand(Color(0.35, 0.85, 1.0, 1.0))
	_mantle_right_hand = _create_mantle_hand(Color(1.0, 0.85, 0.25, 1.0))
	_update_mantle_vfx()


func _create_mantle_hand(color: Color) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = MANTLE_HAND_SIZE
	mesh.height = MANTLE_HAND_SIZE * 2.0
	var hand: MeshInstance3D = MeshInstance3D.new()
	hand.mesh = mesh
	hand.set_surface_override_material(0, material)
	if _mantle_vfx_root != null:
		_mantle_vfx_root.add_child(hand)
	return hand


func _update_mantle_vfx() -> void:
	if _mantle_vfx_root == null or _mantle_left_hand == null or _mantle_right_hand == null:
		return
	var surface_up: Vector3 = Planet.surface_up(global_position)
	var forward: Vector3 = Planet.project_on_plane(body_forward, surface_up)
	if forward.length_squared() < 0.001:
		forward = Planet.project_on_plane(Vector3.FORWARD, surface_up)
	if forward.length_squared() < 0.001:
		forward = Planet.project_on_plane(Vector3.RIGHT, surface_up)
	forward = forward.normalized()
	var right: Vector3 = forward.cross(surface_up).normalized()
	var center: Vector3 = global_position + surface_up * 1.45 + forward * 0.35
	var spin: float = _mantle_timer * MANTLE_HAND_ORBIT_SPEED
	_mantle_vfx_root.global_position = Vector3.ZERO
	_mantle_left_hand.global_position = center \
		+ right * cos(spin) * MANTLE_HAND_ORBIT_RADIUS \
		+ surface_up * sin(spin) * MANTLE_HAND_ORBIT_RADIUS
	_mantle_right_hand.global_position = center \
		+ right * cos(spin + PI) * MANTLE_HAND_ORBIT_RADIUS \
		+ surface_up * sin(spin + PI) * MANTLE_HAND_ORBIT_RADIUS


func _stop_mantle_vfx() -> void:
	if _mantle_vfx_root != null and is_instance_valid(_mantle_vfx_root):
		_mantle_vfx_root.queue_free()
	_mantle_vfx_root = null
	_mantle_left_hand = null
	_mantle_right_hand = null


func _apply_edge_guard(move_dir: Vector3, surface_up: Vector3) -> Vector3:
	if move_dir.length_squared() < 0.001:
		return move_dir
	var test_position: Vector3 = global_position + move_dir.normalized() * EDGE_GUARD_FORWARD_DISTANCE
	var ray_start: Vector3 = test_position + surface_up * EDGE_GUARD_RAY_UP
	var ray_end: Vector3 = test_position - surface_up * EDGE_GUARD_RAY_DOWN
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.ZERO
	var ground_normal: Vector3 = (hit["normal"] as Vector3).normalized()
	if _surface_angle(ground_normal, surface_up) > rad_to_deg(floor_max_angle):
		return Vector3.ZERO
	return move_dir


func _get_climb_stick_velocity(surface_up: Vector3) -> Vector3:
	if _climb_surface_angle < CLIMB_STICK_MIN_ANGLE:
		return Vector3.ZERO
	var stick_direction: Vector3 = Planet.project_on_plane(-_climb_normal, surface_up)
	if stick_direction.length_squared() < 0.001:
		return Vector3.ZERO
	return stick_direction.normalized() * CLIMB_STICK_FORCE


func _surface_angle(normal: Vector3, surface_up: Vector3) -> float:
	if normal.length_squared() < 0.001:
		return 0.0
	return rad_to_deg(acos(clampf(normal.normalized().dot(surface_up), -1.0, 1.0)))


func _is_angle_in_range(angle: float, minimum: float, maximum: float) -> bool:
	return angle >= minimum and angle <= maximum


func _update_climb_energy(delta: float) -> void:
	if _is_climbing:
		var drain_rate: float = _get_climb_drain_rate()
		_climb_energy = maxf(0.0, _climb_energy - drain_rate * delta)
		_climb_recover_timer = CLIMB_RECOVER_DELAY
		_climb_hud_visible_timer = CLIMB_HUD_VISIBLE_SECONDS
		if _climb_energy <= 0.0:
			_is_climbing = false
	else:
		_climb_is_moving = false
		_climb_recover_timer = maxf(0.0, _climb_recover_timer - delta)
		if _climb_recover_timer <= 0.0:
			_climb_energy = minf(MAX_CLIMB_ENERGY, _climb_energy + CLIMB_RECOVER_RATE * delta)
		if _climb_energy < MAX_CLIMB_ENERGY:
			_climb_hud_visible_timer = CLIMB_HUD_VISIBLE_SECONDS
		else:
			_climb_hud_visible_timer = maxf(0.0, _climb_hud_visible_timer - delta)
	_emit_climb_energy(_is_climbing or _climb_hud_visible_timer > 0.0 or _climb_energy < MAX_CLIMB_ENERGY)


func _get_climb_drain_rate() -> float:
	if _climb_is_moving:
		return CLIMB_MOVE_DRAIN_RATE
	return CLIMB_IDLE_DRAIN_RATE


func _emit_climb_energy(should_show: bool) -> void:
	climb_energy_changed.emit(_climb_energy, MAX_CLIMB_ENERGY, should_show)


func _apply_jump(surface_up: Vector3) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity += surface_up * JUMP_FORCE


func _apply_fly_movement(surface_up: Vector3) -> void:
	var speed := FLY_SPRINT_SPEED if Input.is_action_pressed("sprint") else FLY_SPEED
	var move_dir := _get_surface_move_input(surface_up)

	if Input.is_action_pressed("jump"):
		move_dir += surface_up
	if Input.is_action_pressed("fly_down"):
		move_dir -= surface_up

	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()

	velocity = move_dir * speed + _external_knockback_velocity


func _get_surface_move_input(surface_up: Vector3) -> Vector3:
	var move_dir := Vector3.ZERO
	var right := body_forward.cross(surface_up).normalized()

	if Input.is_action_pressed("move_forward"):
		move_dir += body_forward
	if Input.is_action_pressed("move_back"):
		move_dir -= body_forward
	if Input.is_action_pressed("move_left"):
		move_dir -= right
	if Input.is_action_pressed("move_right"):
		move_dir += right

	return move_dir.normalized() if move_dir.length_squared() > 0.001 else Vector3.ZERO


func receive_enemy_hit(amount: float, knockback_direction: Vector3, knockback_force: float) -> void:
	health.take_damage(amount)
	apply_knockback(knockback_direction, knockback_force)
	_play_one_shot_sound(PLAYER_SOFT_OUCH_SOUND, global_position, -6.0, 12.0)


func apply_knockback(direction: Vector3, force: float) -> void:
	var surface_up := Planet.surface_up(global_position)
	var flat_direction := Planet.project_on_plane(direction, surface_up)
	if flat_direction.length_squared() < 0.001:
		return
	_external_knockback_velocity += flat_direction.normalized() * force


func _decay_external_knockback(delta: float) -> void:
	_external_knockback_velocity = _external_knockback_velocity.move_toward(
		Vector3.ZERO,
		EXTERNAL_KNOCKBACK_DECAY * delta
	)


func _do_melee_attack() -> void:
	_attack_timer = ATTACK_COOLDOWN
	var surface_up := Planet.surface_up(global_position)
	var attack_forward := -camera.global_transform.basis.z
	if attack_forward.length_squared() < 0.001:
		attack_forward = body_forward
	attack_forward = attack_forward.normalized()
	_spawn_attack_vfx(attack_forward, surface_up)
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = ATTACK_RANGE
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = global_transform
	params.collision_mask = 4
	var hits := space.intersect_shape(params, 8)
	for hit: Dictionary in hits:
		var body := hit.collider as Node
		if body == null or body == self:
			continue
		var enemy_health: Health = body.get_node_or_null("Health")
		if enemy_health == null:
			continue
		enemy_health.take_damage(ATTACK_DAMAGE)
		var knockback_dir := Planet.project_on_plane(
			body.global_position - global_position,
			surface_up
		)
		if knockback_dir.length_squared() > 0.001 and body is CharacterBody3D:
			(body as CharacterBody3D).velocity += knockback_dir.normalized() * ATTACK_KNOCKBACK


func _spawn_attack_vfx(attack_forward: Vector3, surface_up: Vector3) -> void:
	var effect_root: Node3D = Node3D.new()
	effect_root.name = "AttackFireVFX"
	get_tree().current_scene.add_child(effect_root)

	var right: Vector3 = attack_forward.cross(surface_up)
	if right.length_squared() < 0.001:
		right = camera.global_transform.basis.x
	right = right.normalized()
	var origin: Vector3 = global_position \
		+ surface_up * 1.2 \
		+ right * 0.3 \
		+ attack_forward * 0.4
	_play_one_shot_sound(FLAME_ATTACK_SOUND, origin, -8.0, 18.0)

	for i: int in range(ATTACK_VFX_PUFF_COUNT):
		var progress: float = float(i) / float(maxi(1, ATTACK_VFX_PUFF_COUNT - 1))
		var side_offset: float = sin(progress * TAU * 1.5) * ATTACK_VFX_FLAME_WIDTH * progress
		var vertical_offset: float = cos(progress * TAU) * ATTACK_VFX_FLAME_WIDTH * 0.35 * progress
		var puff_position: Vector3 = origin
		puff_position += attack_forward * (ATTACK_VFX_FLAME_LENGTH * progress)
		puff_position += right * side_offset
		puff_position += surface_up * vertical_offset
		var puff_radius: float = lerpf(0.18, 0.42, progress)
		var puff_color: Color = Color(1.0, lerpf(0.85, 0.18, progress), 0.02, 1.0)
		_spawn_vfx_sphere(effect_root, puff_position, puff_radius, puff_color, ATTACK_VFX_DURATION)

	var fireball_position: Vector3 = origin + attack_forward * ATTACK_VFX_FLAME_LENGTH
	_spawn_vfx_light(effect_root, fireball_position, Color(1.0, 0.35, 0.05, 1.0), ATTACK_VFX_DURATION)
	_spawn_vfx_sphere(
		effect_root,
		fireball_position,
		ATTACK_VFX_FIREBALL_RADIUS,
		Color(1.0, 0.18, 0.0, 1.0),
		ATTACK_VFX_DURATION * 1.35
	)

	await get_tree().create_timer(ATTACK_VFX_DURATION * 1.45).timeout
	if is_instance_valid(effect_root):
		effect_root.queue_free()


func _spawn_vfx_sphere(
	parent: Node3D,
	world_position: Vector3,
	radius: float,
	color: Color,
	duration: float
) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, material)
	parent.add_child(mesh_instance)
	mesh_instance.global_position = world_position

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * 1.8, duration)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)


func _spawn_vfx_light(
	parent: Node3D,
	world_position: Vector3,
	color: Color,
	duration: float
) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 5.0
	parent.add_child(light)
	light.global_position = world_position

	var tween: Tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)


func _do_flame_bomb() -> void:
	_bomb_timer = BOMB_COOLDOWN
	var surface_up := Planet.surface_up(global_position)
	var bomb_forward := -camera.global_transform.basis.z
	if bomb_forward.length_squared() < 0.001:
		bomb_forward = body_forward
	bomb_forward = bomb_forward.normalized()

	var ray_start := camera.global_position
	var ray_end := ray_start + bomb_forward * BOMB_RANGE
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 0b00000101)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	var explosion_pos := ray_end if result.is_empty() else result["position"] as Vector3

	_spawn_bomb_projectile(explosion_pos, surface_up, bomb_forward)


func _spawn_bomb_projectile(target: Vector3, surface_up: Vector3, forward: Vector3) -> void:
	var right := forward.cross(surface_up)
	if right.length_squared() < 0.001:
		right = camera.global_transform.basis.x
	right = right.normalized()
	var origin := global_position + surface_up * 1.2 + right * 0.3 + forward * 0.4

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.0, 1.0)
	mat.emission_energy_multiplier = 4.0

	var proj_mesh: SphereMesh = SphereMesh.new()
	proj_mesh.radius = 0.22
	proj_mesh.height = 0.44

	var proj: MeshInstance3D = MeshInstance3D.new()
	proj.mesh = proj_mesh
	proj.set_surface_override_material(0, mat)
	get_tree().current_scene.add_child(proj)
	proj.global_position = origin

	var tween: Tween = create_tween()
	tween.tween_property(proj, "global_position", target, BOMB_TRAVEL_TIME)
	tween.tween_callback(func() -> void:
		proj.queue_free()
		_explode_bomb(target, Planet.surface_up(target))
	)


func _explode_bomb(explosion_pos: Vector3, surface_up: Vector3) -> void:
	_play_one_shot_sound(BOMB_EXPLOSION_SOUND, explosion_pos, -2.0, 44.0)
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = BOMB_RADIUS
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), explosion_pos)
	params.collision_mask = 4
	var hits := space.intersect_shape(params, 16)
	for hit: Dictionary in hits:
		var body := hit.collider as Node
		if body == null or body == self:
			continue
		var enemy_health: Health = body.get_node_or_null("Health")
		if enemy_health != null:
			enemy_health.take_damage(BOMB_DAMAGE)
		var knockback_dir := Planet.project_on_plane(
			body.global_position - explosion_pos, surface_up
		)
		if knockback_dir.length_squared() > 0.001 and body is CharacterBody3D:
			(body as CharacterBody3D).velocity += knockback_dir.normalized() * BOMB_KNOCKBACK
	_spawn_bomb_explosion_vfx(explosion_pos, surface_up)


func _spawn_bomb_explosion_vfx(explosion_pos: Vector3, surface_up: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "BombExplosionVFX"
	get_tree().current_scene.add_child(root)

	# White core flash — disappears quickly
	_spawn_vfx_sphere(root, explosion_pos, 0.4, Color(1.0, 0.95, 0.7, 1.0), BOMB_VFX_DURATION * 0.3)

	# Main fireball — expands to fill AOE radius
	var fireball_mat: StandardMaterial3D = StandardMaterial3D.new()
	fireball_mat.albedo_color = Color(1.0, 0.3, 0.02, 1.0)
	fireball_mat.emission_enabled = true
	fireball_mat.emission = Color(1.0, 0.25, 0.0, 1.0)
	fireball_mat.emission_energy_multiplier = 3.0
	fireball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fireball_mat.albedo_color.a = 0.85
	var fireball_mesh: SphereMesh = SphereMesh.new()
	fireball_mesh.radius = 0.5
	fireball_mesh.height = 1.0
	var fireball: MeshInstance3D = MeshInstance3D.new()
	fireball.mesh = fireball_mesh
	fireball.set_surface_override_material(0, fireball_mat)
	root.add_child(fireball)
	fireball.global_position = explosion_pos
	var fb_tween: Tween = create_tween()
	fb_tween.set_parallel(true)
	fb_tween.tween_property(fireball, "scale", Vector3.ONE * (BOMB_RADIUS * 2.0), BOMB_VFX_DURATION)
	fb_tween.tween_property(fireball_mat, "emission_energy_multiplier", 0.0, BOMB_VFX_DURATION)

	# Shockwave ring — thin cylinder expanding outward
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.55, 0.1, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.45, 0.05, 1.0)
	ring_mat.emission_energy_multiplier = 2.0
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = 0.5
	ring_mesh.bottom_radius = 0.5
	ring_mesh.height = 0.12
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.set_surface_override_material(0, ring_mat)
	root.add_child(ring)
	ring.global_position = explosion_pos
	ring.global_transform.basis = Basis(
		surface_up.cross(Vector3.FORWARD).normalized(),
		surface_up,
		Vector3.FORWARD
	)
	var ring_tween: Tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector3(BOMB_RADIUS * 2.2, 1.0, BOMB_RADIUS * 2.2), BOMB_VFX_DURATION * 0.7)
	ring_tween.tween_property(ring_mat, "emission_energy_multiplier", 0.0, BOMB_VFX_DURATION * 0.7)

	# Fire puffs scattered around explosion
	var tangent := surface_up.cross(Vector3.RIGHT)
	if tangent.length_squared() < 0.001:
		tangent = surface_up.cross(Vector3.FORWARD)
	tangent = tangent.normalized()
	for i: int in range(BOMB_PUFF_COUNT):
		var angle := TAU * float(i) / float(BOMB_PUFF_COUNT)
		var spread_dir := tangent.rotated(surface_up, angle)
		var dist := lerpf(1.0, BOMB_RADIUS * 0.85, float(i % 2))
		var puff_pos := explosion_pos + spread_dir * dist + surface_up * lerpf(0.3, 1.8, float(i) / float(BOMB_PUFF_COUNT))
		var puff_color := Color(1.0, lerpf(0.7, 0.1, float(i) / float(BOMB_PUFF_COUNT)), 0.0, 1.0)
		_spawn_vfx_sphere(root, puff_pos, lerpf(0.35, 0.75, float(i) / float(BOMB_PUFF_COUNT)), puff_color, BOMB_VFX_DURATION)

	# Light pulse
	_spawn_vfx_light(root, explosion_pos, Color(1.0, 0.4, 0.05, 1.0), BOMB_VFX_DURATION)
	var bright_light: OmniLight3D = OmniLight3D.new()
	bright_light.light_color = Color(1.0, 0.7, 0.2, 1.0)
	bright_light.light_energy = 10.0
	bright_light.omni_range = BOMB_RADIUS * 3.0
	root.add_child(bright_light)
	bright_light.global_position = explosion_pos
	var lt: Tween = create_tween()
	lt.tween_property(bright_light, "light_energy", 0.0, BOMB_VFX_DURATION * 0.5)

	await get_tree().create_timer(BOMB_VFX_DURATION * 1.2).timeout
	if is_instance_valid(root):
		root.queue_free()


func _play_one_shot_sound(
	stream: AudioStream,
	world_position: Vector3,
	volume_db: float,
	max_distance: float
) -> void:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	get_tree().current_scene.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()


func _on_died() -> void:
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	global_position = Vector3(0.0, 1.0, 0.0)
	velocity = Vector3.ZERO
	_external_knockback_velocity = Vector3.ZERO
	_is_climbing = false
	_climb_energy = MAX_CLIMB_ENERGY
	_emit_climb_energy(false)


func _update_camera_pose() -> void:
	camera_arm.rotation = Vector3(look_pitch, 0.0, 0.0)
	if fly_mode:
		camera.position = CAMERA_FLY_OFFSET
	elif third_person_mode:
		camera.position = CAMERA_THIRD_PERSON_OFFSET
	else:
		camera.position = CAMERA_FIRST_PERSON_OFFSET
	visual_body.visible = fly_mode or third_person_mode
