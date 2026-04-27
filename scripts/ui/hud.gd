class_name HUD
extends CanvasLayer

const DEFAULT_MASTER_VOLUME: float = 0.1
const MASTER_BUS_NAME: StringName = &"Master"

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var hp_text: Label = $MarginContainer/VBoxContainer/HPBar/HPText
@onready var climb_energy_bar: ProgressBar = $MarginContainer/VBoxContainer/ClimbEnergyBar
@onready var climb_energy_text: Label = $MarginContainer/VBoxContainer/ClimbEnergyBar/ClimbEnergyText
@onready var fps_value: Label = $FPSPanel/FPSValue
@onready var volume_slider: HSlider = $OptionsPanel/VBoxContainer/MasterVolumeSlider
@onready var volume_value: Label = $OptionsPanel/VBoxContainer/VolumeRow/VolumeValue
@onready var compass_needle: Label = $CompassPanel/CompassNeedle
@onready var map_panel: PanelContainer = $MapPanel
@onready var map_body: Control = $MapPanel/VBoxContainer/MapBody
@onready var player_dot: ColorRect = $MapPanel/VBoxContainer/MapBody/PlayerDot
@onready var map_north_arrow: Label = $MapPanel/VBoxContainer/MapBody/MapNorthArrow
@onready var world_position_value: Label = $MapPanel/VBoxContainer/WorldPositionValue
@onready var geo_position_value: Label = $MapPanel/VBoxContainer/GeoPositionValue

var _player: Node3D = null
var _north_target: Node3D = null


func _ready() -> void:
	map_panel.visible = false
	_set_mouse_filter_recursive(map_panel, Control.MOUSE_FILTER_IGNORE)
	volume_slider.value = DEFAULT_MASTER_VOLUME * 100.0
	volume_slider.value_changed.connect(_on_master_volume_changed)
	_apply_master_volume(DEFAULT_MASTER_VOLUME)


func _process(_delta: float) -> void:
	fps_value.text = "FPS %d" % Engine.get_frames_per_second()
	_update_compass()
	if map_panel.visible:
		_update_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		map_panel.visible = not map_panel.visible
		if map_panel.visible:
			_update_map()
		get_viewport().set_input_as_handled()


func connect_to_player(player_health: Health, player_node: Node3D, north_target: Node3D) -> void:
	_player = player_node
	_north_target = north_target
	hp_bar.max_value = player_health.max_health
	hp_bar.value = player_health.current_health
	_update_hp_text(player_health.current_health, player_health.max_health)
	player_health.health_changed.connect(_on_health_changed)
	if player_node.has_signal("climb_energy_changed"):
		player_node.connect("climb_energy_changed", _on_climb_energy_changed)


func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	_update_hp_text(current, maximum)


func _update_hp_text(current: float, maximum: float) -> void:
	hp_text.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_climb_energy_changed(current: float, maximum: float, should_show: bool) -> void:
	climb_energy_bar.max_value = maximum
	climb_energy_bar.value = current
	climb_energy_bar.visible = should_show
	climb_energy_text.text = "Climb %.1f / %.1f" % [current, maximum]


func _on_master_volume_changed(value: float) -> void:
	_apply_master_volume(value / 100.0)


func _apply_master_volume(linear_volume: float) -> void:
	var clamped_volume: float = clampf(linear_volume, 0.0, 1.0)
	var bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, clamped_volume <= 0.0)
		if clamped_volume > 0.0:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped_volume))
	volume_value.text = "%d%%" % roundi(clamped_volume * 100.0)


func _update_map() -> void:
	if _player == null:
		return
	var world_position: Vector3 = _player.global_position
	var from_center: Vector3 = world_position - Planet.CENTER
	var distance_from_center: float = from_center.length()
	if distance_from_center < 0.001:
		return
	var surface_direction: Vector3 = from_center / distance_from_center
	var latitude: float = -rad_to_deg(asin(clampf(surface_direction.y, -1.0, 1.0)))
	var longitude: float = rad_to_deg(atan2(surface_direction.x, surface_direction.z))
	var altitude: float = distance_from_center - Planet.RADIUS

	world_position_value.text = "XYZ  %.1f, %.1f, %.1f" % [
		world_position.x,
		world_position.y,
		world_position.z,
	]
	geo_position_value.text = "Lat %.2f  Lon %.2f  Alt %.1f" % [
		latitude,
		longitude,
		altitude,
	]
	_update_player_dot(latitude, longitude)


func _update_player_dot(latitude: float, longitude: float) -> void:
	var map_size: Vector2 = map_body.size
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	var x_fraction: float = clampf((longitude + 180.0) / 360.0, 0.0, 1.0)
	var y_fraction: float = clampf((90.0 - latitude) / 180.0, 0.0, 1.0)
	var dot_half_size: Vector2 = player_dot.size * 0.5
	var marker_center: Vector2 = Vector2(
		x_fraction * map_size.x,
		y_fraction * map_size.y
	)
	marker_center.x = clampf(marker_center.x, dot_half_size.x, map_size.x - dot_half_size.x)
	marker_center.y = clampf(marker_center.y, dot_half_size.y, map_size.y - dot_half_size.y)
	player_dot.position = marker_center - dot_half_size
	map_north_arrow.position = marker_center - map_north_arrow.size * 0.5


func _update_compass() -> void:
	if _player == null or _north_target == null:
		return
	var surface_up: Vector3 = Planet.surface_up(_player.global_position)
	var player_forward: Vector3 = Planet.project_on_plane(-_player.global_transform.basis.z, surface_up)
	var north_direction: Vector3 = Planet.project_on_plane(_north_target.global_position - _player.global_position, surface_up)
	if north_direction.length_squared() < 0.001:
		north_direction = Planet.project_on_plane(Vector3.FORWARD, surface_up)
	if north_direction.length_squared() < 0.001:
		north_direction = Planet.project_on_plane(Vector3.RIGHT, surface_up)
	if player_forward.length_squared() < 0.001 or north_direction.length_squared() < 0.001:
		return
	player_forward = player_forward.normalized()
	north_direction = north_direction.normalized()
	var bearing: float = player_forward.signed_angle_to(north_direction, surface_up)
	compass_needle.rotation = -bearing
	map_north_arrow.rotation = -bearing


func _set_mouse_filter_recursive(node: Node, mouse_filter: int) -> void:
	if node is Control:
		(node as Control).mouse_filter = mouse_filter
	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child, mouse_filter)
