class_name Pawn
extends Node2D
## A staff member. Walks along paths it is given and animates to match.
## It doesn't choose where to go; its owner decides and calls follow_path().

signal path_finished

@export var move_speed: float = 40.0

var _path: PackedVector2Array = PackedVector2Array()
var _facing_up: bool = false
var _facing_right: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_play_idle()


func _process(delta: float) -> void:
	if _path.is_empty():
		return

	var to_target: Vector2 = _path[0] - global_position
	var step: float = move_speed * delta
	if to_target.length() <= step:
		global_position = _path[0]
		_path.remove_at(0)
		if _path.is_empty():
			_play_idle()
			path_finished.emit()
		return

	_face(to_target)
	global_position += to_target.normalized() * step
	_sprite.play(&"walk_up" if _facing_up else &"walk_down")


## Walks through each point in order (global positions). Emits path_finished at the end.
func follow_path(points: PackedVector2Array) -> void:
	_path = points


func is_moving() -> bool:
	return not _path.is_empty()


func _face(direction: Vector2) -> void:
	if not is_zero_approx(direction.y):
		_facing_up = direction.y < 0.0
	if not is_zero_approx(direction.x):
		_facing_right = direction.x > 0.0
	# The sheet only has left-facing art; right-facing is a horizontal flip.
	_sprite.flip_h = _facing_right


func _play_idle() -> void:
	_sprite.play(&"idle_up" if _facing_up else &"idle_down")
