class_name ShopClock
extends Node
## The shop's day and time of day, and how fast the game runs. A day runs from its start to
## its end minute (set by the owner from the shop's hours and staff shifts, see set_span());
## the night between days is skipped. Speed scales all game time (pawns, baking, timers), so
## pausing freezes the shop while the camera and HUD keep working.

signal time_changed(day: int, minute_of_day: int)
signal day_started(day: int)
signal speed_changed(speed: int)

## Game seconds per shop minute when no clock is running.
const DEFAULT_SECONDS_PER_MINUTE: float = 2.5
## Weekday names, Monday first. Day 1 is a Monday.
const WEEKDAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

enum Weekday { MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY, SUNDAY }

## Game seconds (real seconds at 1x) one shop minute lasts.
@export var seconds_per_minute: float = DEFAULT_SECONDS_PER_MINUTE
## The shop's prep, open, last-order and closing times.
@export var hours: ShopHours
## Game speeds the player can pick. 0 is paused. Above about 12x pawns walk slower than
## they should (they reach at most one path point per frame).
@export var speeds: Array[int] = [0, 1, 3, 6, 12]

## The clock in play, so durations given in shop minutes can be converted anywhere.
static var _current: ShopClock = null

var day: int = 1
var speed: int = 1
## When today started and when it ends, in minutes since midnight.
var day_start_minute: int = 0
var day_end_minute: int = 0
## Speed to go back to when unpausing.
var _resume_speed: int = 1
## Minutes since midnight right now.
var _minute: float = 0.0
## When the next day starts (minutes since midnight).
var _next_start_minute: int = 0
## Shop minutes played on earlier days.
var _minutes_before_today: float = 0.0
var _last_minute: int = -1


func _enter_tree() -> void:
	_current = self
	# Its own copy: the player changes the hours in play.
	hours = hours.duplicate() if hours != null else ShopHours.new()
	day_start_minute = hours.prep_minute
	day_end_minute = hours.close_minute
	_next_start_minute = day_start_minute
	_minute = day_start_minute


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
		per_minute = _current.seconds_per_minute
	return minutes * per_minute


## Sets when days start and end (minutes since midnight). Today ends at `end_minute`, or
## right away if that's already past; `start_minute` applies from the next day.
func set_span(start_minute: int, end_minute: int) -> void:
	_next_start_minute = start_minute
	day_end_minute = maxi(end_minute, ceili(_minute))


## Restarts today at `start_minute`, ending at `end_minute` (for setting up day 1).
func restart_day(start_minute: int, end_minute: int) -> void:
	day_start_minute = start_minute
	_next_start_minute = start_minute
	day_end_minute = end_minute
	_minute = start_minute
	_last_minute = -1


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_minute += delta / seconds_per_minute
	if _minute >= day_end_minute:
		_minutes_before_today += day_end_minute - day_start_minute
		day += 1
		day_start_minute = _next_start_minute
		_minute = day_start_minute
		day_started.emit(day)
	var minute: int = get_minute_of_day()
	if minute != _last_minute:
		_last_minute = minute
		time_changed.emit(day, minute)


## Shop-clock minutes that pass in `game_seconds` of game time.
func to_clock_minutes(game_seconds: float) -> float:
	return game_seconds / seconds_per_minute


## Shop-clock minutes played in total, across days (the skipped nights don't count). For
## measuring how long things take.
func get_open_minutes() -> int:
	return int(_minutes_before_today + _minute - day_start_minute)


## Minutes since midnight on the shop clock.
func get_minute_of_day() -> int:
	return int(_minute)


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
