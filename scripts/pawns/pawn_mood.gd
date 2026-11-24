class_name PawnMood
extends RefCounted
## A pawn's mood (0-100) and what drives it: stress and timed mood effects. Mood drifts
## toward its target (see get_target()). Its pawn ticks it in shop minutes.

signal breakdown_started
signal breakdown_ended

enum Band { BREAKING, STRESSED, CONTENT, HAPPY }

const BAND_NAMES: Array[String] = ["Breaking", "Stressed", "Content", "Happy"]

var rules: MoodRules
var mood: float = 50.0
## 0-100. Builds on a job during a rush, eases after.
var stress: float = 0.0

var _rushing: bool = false
## Worked a job during the current rush.
var _worked_rush: bool = false
## Mood effect -> shop minutes left.
var _effects: Dictionary[MoodEffect, float] = {}
var _breakdown_left: float = 0.0
var _cooldown_left: float = 0.0


func _init(p_rules: MoodRules) -> void:
	rules = p_rules
	mood = get_target()


## What mood drifts toward: the base, less stress, plus mood effects.
func get_target() -> float:
	var target: float = rules.base_mood - stress / 100.0 * rules.stress_mood_cost
	for effect: MoodEffect in _effects:
		target += effect.mood
	return clampf(target, 0.0, 100.0)


## Moves time on by `minutes` shop minutes. `has_job`: the pawn is on a job.
func tick(minutes: float, has_job: bool) -> void:
	if minutes <= 0.0:
		return
	if is_on_breakdown() or not _rushing:
		stress -= rules.stress_ease_per_minute * minutes
	elif has_job:
		stress += rules.stress_rise_per_minute * minutes
		_worked_rush = true
	stress = clampf(stress, 0.0, 100.0)
	for effect: MoodEffect in _effects.keys():
		_effects[effect] -= minutes
		if _effects[effect] <= 0.0:
			_effects.erase(effect)
	mood = move_toward(mood, get_target(), rules.mood_drift_per_minute * minutes)
	_cooldown_left = maxf(_cooldown_left - minutes, 0.0)
	if is_on_breakdown():
		_breakdown_left -= minutes
		if _breakdown_left <= 0.0:
			_breakdown_left = 0.0
			_cooldown_left = rules.breakdown_cooldown_minutes
			breakdown_ended.emit()
	elif mood < rules.breaking_below and _cooldown_left <= 0.0:
		start_breakdown()


func start_breakdown() -> void:
	if is_on_breakdown():
		return
	_breakdown_left = rules.breakdown_minutes
	breakdown_started.emit()


## True during a breakdown: the pawn takes no new jobs.
func is_on_breakdown() -> bool:
	return _breakdown_left > 0.0


func is_rushing() -> bool:
	return _rushing


## The shop started or stopped rushing. Pawns who worked it feel better once it's over.
func set_rushing(rushing: bool) -> void:
	if rushing == _rushing:
		return
	_rushing = rushing
	if not rushing and _worked_rush and rules.rush_survived != null:
		add_effect(rules.rush_survived)
	_worked_rush = false


## Starts (or restarts) a mood effect.
func add_effect(effect: MoodEffect) -> void:
	_effects[effect] = effect.minutes


## Mood effect -> shop minutes left.
func get_effects() -> Dictionary[MoodEffect, float]:
	return _effects


func get_band() -> Band:
	if mood < rules.breaking_below:
		return Band.BREAKING
	if mood < rules.stressed_below:
		return Band.STRESSED
	if mood >= rules.happy_at:
		return Band.HAPPY
	return Band.CONTENT


func get_band_name() -> String:
	return BAND_NAMES[get_band()]


## Work speed multiplier from mood and the rush.
func get_speed_multiplier() -> float:
	var speed: float = rules.rush_speed if _rushing else 1.0
	match get_band():
		Band.HAPPY:
			speed *= rules.happy_speed
		Band.STRESSED, Band.BREAKING:
			speed *= rules.stressed_speed
	return speed


## Skill levels added to (or taken from) the quality of a hands-on step.
func get_quality_levels() -> int:
	match get_band():
		Band.HAPPY:
			return rules.happy_quality_levels
		Band.STRESSED, Band.BREAKING:
			return rules.stressed_quality_levels
	return 0
