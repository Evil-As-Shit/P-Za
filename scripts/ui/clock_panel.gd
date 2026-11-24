class_name ClockPanel
extends PanelContainer
## HUD clock: weekday and day, time, cash, the shop's rating and popularity, a RUSH tag while rushing, and
## speed buttons (pause, then each speed). Reports the player's picks.

signal speed_requested(speed: int)

const NEGATIVE_COLOR := Color(1.0, 0.45, 0.4)

@onready var _day: Label = %Day
@onready var _time: Label = %Time
@onready var _cash: Label = %Cash
@onready var _rating: Label = %Rating
@onready var _popularity: Label = %Popularity
@onready var _rush: Label = %Rush
@onready var _buttons: HBoxContainer = %SpeedButtons


## Builds one button per speed (0 shows as pause). Keys 1, 2, 3... pick them in order.
func setup(speeds: Array[int]) -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for index: int in speeds.size():
		var speed: int = speeds[index]
		var button := Button.new()
		button.text = "||" if speed == 0 else "%dx" % speed
		button.tooltip_text = "Pause (Space)" if speed == 0 else "%dx speed (%d)" % [speed, index]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(32, 0)
		button.set_meta(&"speed", speed)
		button.pressed.connect(speed_requested.emit.bind(speed))
		_buttons.add_child(button)


func show_time(day: int, minute_of_day: int) -> void:
	_day.text = "%s, Day %d" % [ShopClock.get_weekday_name(day), day]
	_time.text = ShopClock.format_time(minute_of_day)


func show_cash(cash: float) -> void:
	_cash.text = ShopFinances.format_money(cash)
	_cash.modulate = NEGATIVE_COLOR if cash < -0.005 else Color.WHITE


## The shop's rating out of 5 stars.
func show_rating(rating: float) -> void:
	_rating.text = "%.1f/5" % rating


## How well known the shop is, out of `max_popularity`.
func show_popularity(popularity: float, max_popularity: float) -> void:
	_popularity.text = "Pop %d/%d" % [roundi(popularity), roundi(max_popularity)]


## Shows the RUSH tag while the shop is rushing.
func show_rush(rushing: bool) -> void:
	_rush.visible = rushing


func show_speed(speed: int) -> void:
	for button: Node in _buttons.get_children():
		(button as Button).set_pressed_no_signal(button.get_meta(&"speed") == speed)
