class_name ClockPanel
extends PanelContainer
## HUD clock: day, time and speed buttons (pause, 1x, 2x, 3x). Reports the player's pick.

signal speed_requested(speed: int)

@onready var _day: Label = %Day
@onready var _time: Label = %Time
@onready var _buttons: HBoxContainer = %SpeedButtons


## Builds one button per speed (0 shows as pause).
func setup(speeds: Array[int]) -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for speed: int in speeds:
		var button := Button.new()
		button.text = "||" if speed == 0 else "%dx" % speed
		button.tooltip_text = "Pause (Space)" if speed == 0 else "Speed %d (%d)" % [speed, speed]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(32, 0)
		button.set_meta(&"speed", speed)
		button.pressed.connect(speed_requested.emit.bind(speed))
		_buttons.add_child(button)


func show_time(day: int, minute_of_day: int) -> void:
	_day.text = "Day %d" % day
	_time.text = ShopClock.format_time(minute_of_day)


func show_speed(speed: int) -> void:
	for button: Node in _buttons.get_children():
		(button as Button).set_pressed_no_signal(button.get_meta(&"speed") == speed)
