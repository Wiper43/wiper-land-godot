class_name TargetDummy
extends StaticBody3D

const RESET_DELAY: float = 1.25

@onready var health: Health = $Health
@onready var health_bar: EnemyHealthBar3D = $EnemyHealthBar3D

var _reset_timer: SceneTreeTimer = null


func _ready() -> void:
	health.died.connect(_on_died)
	health_bar.connect_health(health)
	health_bar.show_briefly()


func _on_died() -> void:
	if _reset_timer != null:
		return
	_reset_timer = get_tree().create_timer(RESET_DELAY)
	await _reset_timer.timeout
	_reset_timer = null
	health.current_health = health.max_health
	health.health_changed.emit(health.current_health, health.max_health)
	health_bar.show_briefly()
