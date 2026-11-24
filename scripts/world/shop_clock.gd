class_name ShopClock
extends Node
## The shop's day and time of day, and how fast the game runs. A day covers opening to
## closing hours; when it ends the next one starts. Speed scales all game time (pawns,
## baking, timers), so pausing freezes the shop while the camera and HUD keep working.

signal time_changed(day: int, minute_of_day: int)
signal day_started(day: int)
signal speed_changed(speed: int)

## Game seconds per shop minute when no clock is running (a 30-minute, 12-hour day).
const DEFAULT_SECONDS_PER_MINUTE: float = 2.5
## Weekday names, Monday first. Day 1 is a Monday.
const WEEKDAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

enum Weekday { MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY }

## Real minutes one day lasts at 1x speed.
@export var day_length_minutes: float = 30.0
@export_range(0, 23) var open_hour: int = 10
@export_range(1, 24) var close_hour: int = 22
## Game speeds the player can pick. 0 is paused. Above about 12x pawns walk slower than
## they should (they reach at most one path point per frame).
@export var speeds: Array[int] = [0, 1, 3, 6, 12]

## The clock in play, so durations given in shop minutes can be converted anywhere.
static var _current: ShopClock = null

var day: int = 1
var speed: int = 1
## Speed to go back to when unpausing.
var _resume_speed: int = 1
## Game seconds since opening today.
var _elapsed: float = 0.0
var _last_minute: int = -1


func _enter_tree() -> void:
	_current = self


func _ready() -> void:
	set_speed(1)
	day_started.emit(day)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _current == self:
		_current = null


## Game seconds that `minutes` shop minutes last (at 1x; speed scales game time itself).
static func minutes_to_seconds(minutes: float) -> float:
	var per_minute: float = DEFAULT_SECONDS_PER_MINUTE
	if _current != null:
		per_minute = _current.day_length_minutes / (_current.close_hour - _current.open_hour)
	return minutes * per_minute


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


## Shop-clock minutes the shop has been open in total, across days (closed hours don't
## count). For measuring how long things take.
func get_open_minutes() -> int:
	var minutes_per_day: int = (close_hour - open_hour) * 60
	return (day - 1) * minutes_per_day + get_minute_of_day() - open_hour * 60


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


## The weekday of `for_day` (day 1 is a Monday).
static func get_weekday(for_day: int) -> Weekday:
	return posmod(for_day - 1, 7) as Weekday


## Short weekday name of `for_day`, e.g. "Mon".
static func get_weekday_name(for_day: int) -> String:
	return WEEKDAY_NAMES[get_weekday(for_day)]


static func format_time(minute_of_day: int) -> String:
	return "%02d:%02d" % [floori(minute_of_day / 60.0), minute_of_day % 60]
