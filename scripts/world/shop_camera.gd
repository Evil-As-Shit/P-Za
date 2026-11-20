class_name ShopCamera
extends Camera2D
## Player camera: pan with WASD/arrows or middle-mouse drag, zoom with the mouse wheel.

@export var pan_speed: float = 400.0
## Whole-number zoom levels keep the pixel art crisp.
@export var zoom_levels: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0]
@export var start_zoom_index: int = 2

var _zoom_index: int = 0
var _dragging: bool = false
## Panning not applied yet. The camera only moves in whole pixels so the art stays on the
## pixel grid.
var _pan_remainder: Vector2 = Vector2.ZERO


func _ready() -> void:
	_zoom_index = clampi(start_zoom_index, 0, zoom_levels.size() - 1)
	_apply_zoom()


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down"
	)
	_pan(direction * pan_speed * delta / zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_change_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_change_zoom(-1)
			MOUSE_BUTTON_MIDDLE:
				_dragging = button.pressed
		return

	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_pan(-motion.relative / zoom.x)


## Moves by `amount`, in whole pixels, carrying the fraction over to the next move.
func _pan(amount: Vector2) -> void:
	_pan_remainder += amount
	var step: Vector2 = _pan_remainder.round()
	position = position.round() + step
	_pan_remainder -= step


func _change_zoom(steps: int) -> void:
	_zoom_index = clampi(_zoom_index + steps, 0, zoom_levels.size() - 1)
	_apply_zoom()


func _apply_zoom() -> void:
	var level: float = zoom_levels[_zoom_index]
	zoom = Vector2(level, level)
