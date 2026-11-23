class_name DonenessRules
extends Resource
## How done something comes out of a station that works it on its own (e.g. a pizza from
## the oven). It's perfect for a short window after it's done, and over after that. The pawn
## taking it out aims for the middle of that window but misjudges it by a random amount,
## less with more skill: too early is under, too late is over. All numbers are placeholders.

enum Doneness { NONE, UNDER, PERFECT, OVER }

## Shop minutes after it's done that it stays perfect.
@export var perfect_minutes: float = 1.0
## Most a pawn's guess can be off, in shop minutes, at skill level 0, the base level and the
## top level (straight lines between).
@export var error_at_zero: float = 1.5
@export var error_at_base: float = 0.5
@export var error_at_max: float = 0.0
## Placeholder tints for the item's art.
@export var under_tint: Color = Color(1.25, 1.2, 1.0)
@export var over_tint: Color = Color(0.55, 0.42, 0.32)


## How it comes out when taken out `minutes_after_done` shop minutes after it was done
## (negative: before).
func judge(minutes_after_done: float) -> Doneness:
	if minutes_after_done < 0.0:
		return Doneness.UNDER
	if minutes_after_done <= perfect_minutes:
		return Doneness.PERFECT
	return Doneness.OVER


## Most a pawn at `level` can be off, in shop minutes.
func max_error(level: int, skill_rules: SkillRules) -> float:
	if skill_rules == null:
		return error_at_base
	var clamped: int = clampi(level, 0, skill_rules.max_level)
	if clamped <= skill_rules.base_level:
		return lerpf(error_at_zero, error_at_base, float(clamped) / skill_rules.base_level)
	return lerpf(
		error_at_base, error_at_max,
		float(clamped - skill_rules.base_level) / (skill_rules.max_level - skill_rules.base_level))


## Shop minutes after it's done that a pawn at `level` thinks it's time to take it out.
func roll_pull_minutes(level: int, skill_rules: SkillRules) -> float:
	var error: float = max_error(level, skill_rules)
	return perfect_minutes * 0.5 + randf_range(-error, error)


## Tint for the item's art, white for perfect.
func get_tint(doneness: Doneness) -> Color:
	match doneness:
		Doneness.UNDER:
			return under_tint
		Doneness.OVER:
			return over_tint
	return Color.WHITE
