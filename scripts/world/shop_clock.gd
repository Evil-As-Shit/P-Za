class_name ShopClock
extends Node
## The shop's day and time of day, and how fast the game runs. A day covers opening to
## closing hours; when it ends the next one starts. Speed scales all game time (pawns,
## baking, timers), so pausing freezes the shop while the camera and HUD keep working.

signal time_changed(day: int, minute_of_day: int)
signal day_started(day: int)
signal speed_changed(speed: int)

## Real minutes one day lasts at 1x speed.
@export var day_length_minutes: float = 10.0
@export_range(0, 23) var open_hour: int = 10
@export_range(1, 24) var close_hour: int = 22
## Game speeds the player can pick. 0 is paused.
@export var speeds: Array[int] = [0, 1, 2, 3]

var day: int = 1
var speed: int = 1
## Speed to go back to when unpausing.
var _resume_speed: int = 1
## Game seconds since opening today.
var _elapsed: float = 0.0
var _last_minute: int = -1


func _ready() -> void:
	set_speed(1)
	day_started.emit(day)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var day_seconds: float = day_length_minutes * 60.0
	_elapsed += delta
	while _elapsed >= day_seconds:
		_elapsed -= day_seconds
		day += 1
		day_started.emit(day)
	var minute: int = get_minute_of_day()
	if minute != _last_minute:
		_last_minute = minute
		time_changed.emit(day, minute)


## Shop-clock minutes that pass in `game_seconds` of game time.
func to_clock_minutes(game_seconds: float) -> float:
	return game_seconds * (close_hour - open_hour) * 60.0 / (day_length_minutes * 60.0)


## Minutes since midnight on the shop clock.
func get_minute_of_day() -> int:
	var open_minutes: float = (close_hour - open_hour) * 60.0
	var fraction: float = _elapsed / (day_length_minutes * 60.0)
	return open_hour * 60 + int(fraction * open_minutes)


func set_speed(new_speed: int) -> void:
	speed = maxi(new_speed, 0)
	if speed > 0:
		_resume_speed = speed
	Engine.time_scale = float(speed)
	speed_changed.emit(speed)


func toggle_pause() -> void:
	set_speed(_resume_speed if speed == 0 else 0)


static func format_time(minute_of_day: int) -> String:
	return "%02d:%02d" % [floori(minute_of_day / 60.0), minute_of_day % 60]
