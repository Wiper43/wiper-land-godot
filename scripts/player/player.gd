extends CharacterBody3D

const WALK_SPEED := 8.0
const SPRINT_SPEED := 14.0
const FLY_SPEED := 200.0
const FLY_SPRINT_SPEED := 90.0
const JUMP_FORCE := 12.0
const GRAVITY := 30.0
const MOUSE_SENS := 0.002
const PLANET_CENTER := Vector3(0, -1024, 0)
const GROUND_STICK_FORCE := 4.0
const CAMERA_FIRST_PERSON_OFFSET := Vector3(0, 0.0, 0.0)
const CAMERA_FLY_OFFSET := Vector3(0, 3.5, 14.0)

@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var camera_arm: Node3D = $CameraArm

var look_pitch := 0.0
var fly_mode := false
var body_forward := Vector3.FORWARD

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	body_forward = _project_on_plane(-global_transform.basis.z, _get_surface_up())
	if body_forward.length_squared() < 0.001:
		body_forward = Vector3.FORWARD
	body_forward = body_forward.normalized()
	_update_camera_pose()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var surface_up := _get_surface_up()
		body_forward = body_forward.rotated(surface_up, -event.relative.x * MOUSE_SENS).normalized()
		look_pitch = clamp(look_pitch - event.relative.y * MOUSE_SENS, -1.35, 1.35)
		_update_camera_pose()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("toggle_fly"):
		fly_mode = not fly_mode
		velocity = Vector3.ZERO
		_update_camera_pose()

func _physics_process(delta: float) -> void:
	var surface_up := _get_surface_up()
	up_direction = surface_up
	_align_to_planet(surface_up)

	if fly_mode:
		_apply_fly_movement(surface_up)
	else:
		_apply_ground_gravity(surface_up, delta)
		_apply_ground_movement(surface_up)
		_apply_jump(surface_up)

	move_and_slide()

func _get_surface_up() -> Vector3:
	var offset := global_position - PLANET_CENTER
	if offset.length_squared() < 0.001:
		return Vector3.UP
	return offset.normalized()

func _align_to_planet(surface_up: Vector3) -> void:
	body_forward = _project_on_plane(body_forward, surface_up)
	if body_forward.length_squared() < 0.001:
		body_forward = _project_on_plane(Vector3.FORWARD, surface_up)
	if body_forward.length_squared() < 0.001:
		body_forward = _project_on_plane(Vector3.RIGHT, surface_up)
	body_forward = body_forward.normalized()

	var body_right := body_forward.cross(surface_up).normalized()
	var corrected_forward := surface_up.cross(body_right).normalized()
	global_transform.basis = Basis(body_right, surface_up, -corrected_forward).orthonormalized()

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
	velocity = move_dir * speed + vertical_velocity

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

	velocity = move_dir * speed

func _get_surface_move_input(surface_up: Vector3) -> Vector3:
	var move_dir := Vector3.ZERO
	var right := body_forward.cross(surface_up).normalized()

	if Input.is_action_pressed("move_forward"):
		move_dir += body_forward
	if Input.is_action_pressed("move_back"):
		move_dir -= body_forward
	if Input.is_action_pressed("move_left"):
		move_dir += right
	if Input.is_action_pressed("move_right"):
		move_dir -= right

	return move_dir.normalized() if move_dir.length_squared() > 0.001 else Vector3.ZERO

func _project_on_plane(vector: Vector3, plane_normal: Vector3) -> Vector3:
	return vector - plane_normal * vector.dot(plane_normal)

func _update_camera_pose() -> void:
	camera_arm.rotation = Vector3(look_pitch, 0.0, 0.0)
	camera.position = CAMERA_FLY_OFFSET if fly_mode else CAMERA_FIRST_PERSON_OFFSET
