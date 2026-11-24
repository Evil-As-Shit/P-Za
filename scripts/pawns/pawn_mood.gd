class_name PawnMood
extends RefCounted
## A pawn's mood (0-100) and what drives it: stress, energy, social and timed mood effects,
## plus their opinions of the other pawns (changed by Social). Mood drifts toward its target
## (see get_target()). Also tracks breaks: at a break table the pawn's job is the break;
## resting standing (no free table) is a timer here. Its pawn ticks it in shop minutes.

signal breakdown_started
signal breakdown_ended
## A standing break (see start_standing_break()) is over.
signal break_ended

enum Band { BREAKING, STRESSED, CONTENT, HAPPY }

const BAND_NAMES: Array[String] = ["Breaking", "Stressed", "Content", "Happy"]

var rules: MoodRules
var mood: float = 50.0
## 0-100. Builds on a job during a rush, eases after.
var stress: float = 0.0
## 0-100. Drains on a job, refills on breaks and overnight.
var energy: float = 100.0
## Multiplies how fast stress builds (from traits, e.g. Calm).
var stress_gain: float = 1.0
## 0-100. Filled by company, drained alone (see Social).
var social: float = 50.0
## Multiplies how much company matters to them (from traits, e.g. Chatty).
var social_need: float = 1.0
## Other pawn -> opinion of them (-100 to 100). Missing means 0.
var opinions: Dictionary[Pawn, float] = {}
## Mood from their pay against what they think they deserve (set by their pawn; see PayRules).
var pay_mood: float = 0.0
## Shop minutes of today's one break (0: none today). Set from their schedule (see
## MoodRules.get_break_minutes()).
var break_length: float = 0.0
## Today's break is over.
var break_taken: bool = false
## Their shift is nearly over without a break: they take it now, tired or not.
var break_due: bool = false

var _rushing: bool = false
## Worked a job during the current rush.
var _worked_rush: bool = false
## Mood effect -> shop minutes left.
var _effects: Dictionary[MoodEffect, float] = {}
var _breakdown_left: float = 0.0
var _cooldown_left: float = 0.0
## Shop minutes left of a standing break.
var _standing_break_left: float = 0.0


func _init(p_rules: MoodRules) -> void:
	rules = p_rules
	mood = get_target()
	break_length = rules.short_break_minutes


## What mood drifts toward: the base, less stress and tiredness, plus social, pay and mood
## effects.
func get_target() -> float:
	var target: float = rules.base_mood - stress / 100.0 * rules.stress_mood_cost + pay_mood
	if energy < rules.tired_below:
		target -= (rules.tired_below - energy) / rules.tired_below * rules.tired_mood_cost
	target += (social - 50.0) / 50.0 * rules.social_mood_cost
	for effect: MoodEffect in _effects:
		target += effect.mood
	return clampf(target, 0.0, 100.0)


## Moves time on by `minutes` shop minutes. `has_job`: the pawn is on a job.
## `resting_at_table`: they're taking their break at a break table.
func tick(minutes: float, has_job: bool, resting_at_table: bool = false) -> void:
	if minutes <= 0.0:
		return
	var resting: bool = resting_at_table or is_on_standing_break()
	if is_on_breakdown() or resting or not _rushing:
		stress -= rules.stress_ease_per_minute * minutes
	elif has_job:
		stress += rules.stress_rise_per_minute * minutes * stress_gain
		_worked_rush = true
	stress = clampf(stress, 0.0, 100.0)
	if resting_at_table:
		energy += rules.table_rest_per_minute * minutes
	elif is_on_standing_break():
		energy += rules.standing_rest_per_minute * minutes
	elif has_job:
		var drain: float = rules.energy_drain_per_minute * minutes
		energy -= drain * rules.rush_energy_drain if _rushing else drain
	energy = clampf(energy, 0.0, 100.0)
	if is_on_standing_break():
		_standing_break_left -= minutes
		if _standing_break_left <= 0.0:
			_standing_break_left = 0.0
			finish_break()
			break_ended.emit()
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


## True if the pawn should take today's break now: low on energy (very low during a rush),
## or it's due (see break_due). Only one a day.
func wants_break() -> bool:
	if is_on_breakdown() or is_on_standing_break() or break_taken or break_length <= 0.0:
		return false
	return break_due or energy < (rules.must_break_below if _rushing else rules.break_below)


## Starts today's break resting where they stand (no free break table): no new jobs until
## break_ended.
func start_standing_break() -> void:
	_standing_break_left = break_length


func is_on_standing_break() -> bool:
	return _standing_break_left > 0.0


## Today's break (at a table or standing) is over.
func finish_break() -> void:
	break_taken = true
	if rules.took_break != null:
		add_effect(rules.took_break)


func get_opinion(of: Pawn) -> float:
	return opinions.get(of, 0.0)


func change_opinion(of: Pawn, amount: float) -> void:
	opinions[of] = clampf(get_opinion(of) + amount, -100.0, 100.0)


func change_social(amount: float) -> void:
	social = clampf(social + amount, 0.0, 100.0)


func is_lonely() -> bool:
	return social < rules.lonely_below


## A night's rest: full energy, and a break to take, for the new day.
func rest_overnight() -> void:
	energy = 100.0
	break_taken = false
	break_due = false


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


## Work speed multiplier from mood, energy and the rush.
func get_speed_multiplier() -> float:
	var speed: float = rules.rush_speed if _rushing else 1.0
	if energy < rules.exhausted_below:
		speed *= rules.exhausted_speed
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
