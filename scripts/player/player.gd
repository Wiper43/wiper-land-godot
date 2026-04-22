extends CharacterBody3D

const WALK_SPEED := 14.0
const SPRINT_SPEED := 14.0
const FLY_SPEED := 200.0
const FLY_SPRINT_SPEED := 90.0
const JUMP_FORCE := 12.0
const GRAVITY := 30.0
const MOUSE_SENS := 0.002
const GROUND_STICK_FORCE := 4.0
const CAMERA_FIRST_PERSON_OFFSET := Vector3(0, 0.0, 0.0)
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
const FLAME_ATTACK_SOUND: AudioStream = preload("res://assets/audio/flame_attack_lowfi.wav")
const BOMB_EXPLOSION_SOUND: AudioStream = preload("res://assets/audio/bomb_explosion_lowfi.wav")
const PLAYER_SOFT_OUCH_SOUND: AudioStream = preload("res://assets/audio/player_soft_ouch_lowfi.wav")

@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var camera_arm: Node3D = $CameraArm
@onready var health: Health = $Health

var look_pitch := 0.0
var fly_mode := false
var body_forward := Vector3.FORWARD
var _attack_timer := 0.0
var _bomb_timer := 0.0
var _external_knockback_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var surface_up := Planet.surface_up(global_position)
	body_forward = Planet.project_on_plane(-global_transform.basis.z, surface_up)
	if body_forward.length_squared() < 0.001:
		body_forward = Vector3.FORWARD
	body_forward = body_forward.normalized()
	health.died.connect(_on_died)
	_update_camera_pose()


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


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_bomb_timer = maxf(0.0, _bomb_timer - delta)
	var surface_up := Planet.surface_up(global_position)
	up_direction = surface_up
	_align_to_planet(surface_up)

	if fly_mode:
		_apply_fly_movement(surface_up)
	else:
		_apply_ground_gravity(surface_up, delta)
		_apply_ground_movement(surface_up)
		_apply_jump(surface_up)

	move_and_slide()
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
	var vertical_velocity := surface_up * velocity.dot(surface_up)
	velocity = move_dir * speed + vertical_velocity + _external_knockback_velocity


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


func _update_camera_pose() -> void:
	camera_arm.rotation = Vector3(look_pitch, 0.0, 0.0)
	camera.position = CAMERA_FLY_OFFSET if fly_mode else CAMERA_FIRST_PERSON_OFFSET
