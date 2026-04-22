class_name Grunt
extends CharacterBody3D

const WALK_SPEED := 4.5
const DETECTION_RADIUS := 14.0
const ATTACK_RADIUS := 2.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 1.2
const KNOCKBACK_FORCE := 8.0
const KNOCKBACK_DECAY := 8.0
const SURFACE_OFFSET := 0.05
const FLOOR_COLLISION_MASK := 1
const FLOOR_PROBE_ABOVE := 6.0
const FLOOR_PROBE_BELOW := 8.0
const WALK_ANIM_SPEED := 8.0
const LEG_SWING_AMOUNT := 0.45
const VISUAL_BOB_AMOUNT := 0.04
const MOVING_ANIM_THRESHOLD := 0.2
const ALERT_HEIGHT_OFFSET := 2.75
const LOST_AGGRO_MARKER_SECONDS := 3.0

enum State { IDLE, CHASE, ATTACK }

@onready var health: Health = $Health
@onready var health_bar: EnemyHealthBar3D = $EnemyHealthBar3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var skeleton_visual: Node3D = $SkeletonVisual
@onready var left_leg: MeshInstance3D = $SkeletonVisual/LeftLeg
@onready var right_leg: MeshInstance3D = $SkeletonVisual/RightLeg
@onready var left_arm: MeshInstance3D = $SkeletonVisual/LeftArm
@onready var right_arm: MeshInstance3D = $SkeletonVisual/RightArm

var _state: State = State.IDLE
var _player: CharacterBody3D = null
var _attack_timer: float = 0.0
var _body_forward: Vector3 = Vector3.FORWARD
var _move_velocity: Vector3 = Vector3.ZERO
var _walk_cycle: float = 0.0
var _visual_base_position: Vector3 = Vector3.ZERO
var _left_leg_base_rotation: Vector3 = Vector3.ZERO
var _right_leg_base_rotation: Vector3 = Vector3.ZERO
var _left_arm_base_rotation: Vector3 = Vector3.ZERO
var _right_arm_base_rotation: Vector3 = Vector3.ZERO
var _is_lod_active: bool = true
var _is_lod_visible: bool = true
var _lost_aggro_timer: float = 0.0
var _alert_marker: Label3D = null


func _ready() -> void:
	health.died.connect(_on_died)
	health_bar.connect_health(health)
	_create_alert_marker()
	_visual_base_position = skeleton_visual.position
	_left_leg_base_rotation = left_leg.rotation
	_right_leg_base_rotation = right_leg.rotation
	_left_arm_base_rotation = left_arm.rotation
	_right_arm_base_rotation = right_arm.rotation
	var surface_up := Planet.surface_up(global_position)
	_body_forward = Planet.project_on_plane(Vector3.FORWARD, surface_up)
	if _body_forward.length_squared() < 0.001:
		_body_forward = Vector3.FORWARD
	_body_forward = _body_forward.normalized()


func initialize(player: CharacterBody3D) -> void:
	_player = player


func set_skeleton_color(color: Color) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	var visual_root: Node3D = get_node("SkeletonVisual")
	for child: Node in visual_root.find_children("*", "MeshInstance3D"):
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null or mesh_instance.name.contains("Eye"):
			continue
		mesh_instance.set_surface_override_material(0, material)


func set_lod_state(is_active: bool, is_visible: bool) -> void:
	if _is_lod_active == is_active and _is_lod_visible == is_visible:
		return
	_is_lod_active = is_active
	_is_lod_visible = is_visible
	set_physics_process(is_active)
	skeleton_visual.visible = is_visible
	collision_shape.disabled = not is_active
	if not is_active:
		_state = State.IDLE
		_lost_aggro_timer = 0.0
		_move_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		_reset_walk_pose()
	if not is_visible:
		health_bar.visible = false
		health_bar.set_process(false)
		_alert_marker.visible = false


func _physics_process(delta: float) -> void:
	var surface_up := Planet.surface_up(global_position)
	up_direction = surface_up
	_align_to_planet(surface_up)
	_update_state()
	_run_state(surface_up, delta)
	_apply_glued_movement(surface_up, delta)
	_update_walk_animation(delta)
	_update_alert_marker(delta)


func _update_state() -> void:
	var previous_state: State = _state
	if _player == null:
		_state = State.IDLE
	else:
		var dist := global_position.distance_to(_player.global_position)
		if dist <= ATTACK_RADIUS:
			_state = State.ATTACK
		elif dist <= DETECTION_RADIUS:
			_state = State.CHASE
		else:
			_state = State.IDLE
	if previous_state != State.IDLE and _state == State.IDLE:
		_lost_aggro_timer = LOST_AGGRO_MARKER_SECONDS
	elif _state != State.IDLE:
		_lost_aggro_timer = 0.0


func _run_state(surface_up: Vector3, delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	match _state:
		State.IDLE:
			_apply_friction(surface_up)
		State.CHASE:
			_move_toward_player(surface_up)
		State.ATTACK:
			_apply_friction(surface_up)
			if _attack_timer <= 0.0:
				_do_attack()


func _move_toward_player(surface_up: Vector3) -> void:
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	var flat := Planet.project_on_plane(to_player, surface_up)
	if flat.length_squared() < 0.001:
		return
	_body_forward = flat.normalized()
	_move_velocity = _body_forward * WALK_SPEED


func _apply_friction(surface_up: Vector3) -> void:
	_move_velocity = Planet.project_on_plane(_move_velocity, surface_up).lerp(Vector3.ZERO, 0.2)


func _do_attack() -> void:
	if _player == null:
		return
	_attack_timer = ATTACK_COOLDOWN
	var knockback_dir := Planet.project_on_plane(
		_player.global_position - global_position,
		Planet.surface_up(_player.global_position)
	)
	if _player.has_method("receive_enemy_hit"):
		_player.call("receive_enemy_hit", ATTACK_DAMAGE, knockback_dir, KNOCKBACK_FORCE)
		return
	var player_health: Health = _player.get_node_or_null("Health")
	if player_health != null:
		player_health.take_damage(ATTACK_DAMAGE)
	if knockback_dir.length_squared() > 0.001:
		_player.velocity += knockback_dir.normalized() * KNOCKBACK_FORCE


func _align_to_planet(surface_up: Vector3) -> void:
	_body_forward = Planet.project_on_plane(_body_forward, surface_up)
	if _body_forward.length_squared() < 0.001:
		_body_forward = Planet.project_on_plane(Vector3.FORWARD, surface_up)
	if _body_forward.length_squared() < 0.001:
		_body_forward = Planet.project_on_plane(Vector3.RIGHT, surface_up)
	_body_forward = _body_forward.normalized()
	global_transform.basis = Planet.align_basis_to_surface(_body_forward, surface_up)


func _apply_glued_movement(surface_up: Vector3, delta: float) -> void:
	var knockback_velocity := Planet.project_on_plane(velocity, surface_up)
	var tangent_velocity := Planet.project_on_plane(_move_velocity + knockback_velocity, surface_up)
	global_position += tangent_velocity * delta
	_snap_to_floor(surface_up)
	velocity = knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)


func _snap_to_floor(surface_up: Vector3) -> void:
	var ray_start := global_position + surface_up * FLOOR_PROBE_ABOVE
	var ray_end := global_position - surface_up * FLOOR_PROBE_BELOW
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, FLOOR_COLLISION_MASK)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector3) + surface_up * SURFACE_OFFSET
		return

	_snap_to_planet_surface()


func _snap_to_planet_surface() -> void:
	var from_center := global_position - Planet.CENTER
	if from_center.length_squared() < 0.001:
		global_position = Planet.CENTER + Vector3.UP * (Planet.RADIUS + SURFACE_OFFSET)
		return
	global_position = Planet.CENTER + from_center.normalized() * (Planet.RADIUS + SURFACE_OFFSET)


func _update_walk_animation(delta: float) -> void:
	var horizontal_speed: float = Planet.project_on_plane(_move_velocity, up_direction).length()
	var is_moving: bool = _state == State.CHASE and horizontal_speed > MOVING_ANIM_THRESHOLD
	if is_moving:
		_walk_cycle += delta * WALK_ANIM_SPEED
		var swing: float = sin(_walk_cycle) * LEG_SWING_AMOUNT
		left_leg.rotation = _left_leg_base_rotation + Vector3(swing, 0.0, 0.0)
		right_leg.rotation = _right_leg_base_rotation + Vector3(-swing, 0.0, 0.0)
		left_arm.rotation = _left_arm_base_rotation + Vector3(-swing * 0.45, 0.0, 0.0)
		right_arm.rotation = _right_arm_base_rotation + Vector3(swing * 0.45, 0.0, 0.0)
		skeleton_visual.position = _visual_base_position + Vector3(0.0, absf(sin(_walk_cycle * 2.0)) * VISUAL_BOB_AMOUNT, 0.0)
		return

	left_leg.rotation = left_leg.rotation.lerp(_left_leg_base_rotation, 0.25)
	right_leg.rotation = right_leg.rotation.lerp(_right_leg_base_rotation, 0.25)
	left_arm.rotation = left_arm.rotation.lerp(_left_arm_base_rotation, 0.25)
	right_arm.rotation = right_arm.rotation.lerp(_right_arm_base_rotation, 0.25)
	skeleton_visual.position = skeleton_visual.position.lerp(_visual_base_position, 0.25)


func _reset_walk_pose() -> void:
	left_leg.rotation = _left_leg_base_rotation
	right_leg.rotation = _right_leg_base_rotation
	left_arm.rotation = _left_arm_base_rotation
	right_arm.rotation = _right_arm_base_rotation
	skeleton_visual.position = _visual_base_position


func _create_alert_marker() -> void:
	_alert_marker = Label3D.new()
	_alert_marker.name = "AlertMarker"
	_alert_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_marker.font_size = 80
	_alert_marker.modulate = Color(1.0, 0.86, 0.05, 1.0)
	_alert_marker.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_alert_marker.outline_size = 18
	_alert_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert_marker.no_depth_test = true
	_alert_marker.visible = false
	add_child(_alert_marker)
	_alert_marker.position = Vector3(0.0, ALERT_HEIGHT_OFFSET, 0.0)


func _update_alert_marker(delta: float) -> void:
	if _alert_marker == null:
		return
	_alert_marker.position = Vector3(0.0, ALERT_HEIGHT_OFFSET, 0.0)
	if not _is_lod_visible:
		_alert_marker.visible = false
		return
	if _state == State.CHASE or _state == State.ATTACK:
		_alert_marker.text = "!"
		_alert_marker.modulate = Color(1.0, 0.86, 0.05, 1.0)
		_alert_marker.visible = true
		return
	if _lost_aggro_timer > 0.0:
		_lost_aggro_timer = maxf(0.0, _lost_aggro_timer - delta)
		_alert_marker.text = "?"
		_alert_marker.modulate = Color(1.0, 0.86, 0.05, 1.0)
		_alert_marker.visible = true
		return
	_alert_marker.visible = false


func _on_died() -> void:
	queue_free()
