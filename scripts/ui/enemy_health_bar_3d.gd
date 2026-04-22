class_name EnemyHealthBar3D
extends Node3D

const BAR_WIDTH: float = 1.35
const BAR_HEIGHT: float = 0.13
const BACK_DEPTH: float = 0.015
const FILL_DEPTH: float = 0.02
const VISIBLE_SECONDS_AFTER_DAMAGE: float = 4.0

@export var height_offset: float = 2.25

var _health: Health = null
var _visible_timer: float = 0.0
var _last_health: float = 0.0

var _bar_back: MeshInstance3D = null
var _bar_fill: MeshInstance3D = null
var _fill_material: StandardMaterial3D = null


func _ready() -> void:
	_build_bar()
	visible = false
	set_process(false)


func connect_health(health: Health) -> void:
	_health = health
	_last_health = health.current_health
	health.health_changed.connect(_on_health_changed)
	_update_bar(health.current_health, health.max_health)


func show_briefly() -> void:
	_visible_timer = VISIBLE_SECONDS_AFTER_DAMAGE
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	position = Vector3(0.0, height_offset, 0.0)
	_face_current_camera()
	if _visible_timer > 0.0:
		_visible_timer = maxf(0.0, _visible_timer - delta)
		if _visible_timer <= 0.0:
			visible = false
			set_process(false)


func _build_bar() -> void:
	var back_material: StandardMaterial3D = StandardMaterial3D.new()
	back_material.albedo_color = Color(0.04, 0.035, 0.03, 0.92)
	back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_fill_material = StandardMaterial3D.new()
	_fill_material.albedo_color = Color(0.85, 0.08, 0.06, 1.0)
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var back_mesh: BoxMesh = BoxMesh.new()
	back_mesh.size = Vector3(BAR_WIDTH, BAR_HEIGHT, BACK_DEPTH)

	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(BAR_WIDTH, BAR_HEIGHT * 0.72, FILL_DEPTH)

	_bar_back = MeshInstance3D.new()
	_bar_back.name = "Back"
	_bar_back.mesh = back_mesh
	_bar_back.set_surface_override_material(0, back_material)
	add_child(_bar_back)

	_bar_fill = MeshInstance3D.new()
	_bar_fill.name = "Fill"
	_bar_fill.mesh = fill_mesh
	_bar_fill.position = Vector3(0.0, 0.0, -0.01)
	_bar_fill.set_surface_override_material(0, _fill_material)
	add_child(_bar_fill)


func _face_current_camera() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var to_camera: Vector3 = camera.global_position - global_position
	if to_camera.length_squared() < 0.001:
		return
	look_at(global_position + to_camera.normalized(), Planet.surface_up(global_position))


func _on_health_changed(current: float, maximum: float) -> void:
	_update_bar(current, maximum)
	if current < _last_health:
		show_briefly()
	_last_health = current


func _update_bar(current: float, maximum: float) -> void:
	if _bar_fill == null:
		return
	var fraction: float = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_bar_fill.scale = Vector3(fraction, 1.0, 1.0)
	_bar_fill.position.x = -BAR_WIDTH * (1.0 - fraction) * 0.5
	if _fill_material != null:
		_fill_material.albedo_color = Color(lerpf(0.95, 0.1, fraction), lerpf(0.05, 0.75, fraction), 0.05, 1.0)
