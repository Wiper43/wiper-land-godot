extends CharacterBody3D

# --- Stats ---
const SPEED        := 6.0
const SPRINT_SPEED := 10.0
const JUMP_FORCE   := 5.0
const GRAVITY      := 9.8
const MOUSE_SENS   := 0.002

# --- Nodes (assigned in _ready) ---
@onready var camera: Camera3D     = $CameraArm/Camera3D
@onready var camera_arm: Node3D   = $CameraArm

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera_arm.rotate_x(-event.relative.y * MOUSE_SENS)
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, -1.4, 1.4)

	# Release cursor with Escape
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement()
	_apply_jump()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _apply_movement() -> void:
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	var dir := Vector3.ZERO

	# Input relative to where the player is facing
	var basis := global_transform.basis
	if Input.is_action_pressed("move_forward"): dir -= basis.z
	if Input.is_action_pressed("move_back"):    dir += basis.z
	if Input.is_action_pressed("move_left"):    dir -= basis.x
	if Input.is_action_pressed("move_right"):   dir += basis.x

	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _apply_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE
