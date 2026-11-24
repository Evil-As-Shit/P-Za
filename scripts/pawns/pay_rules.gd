class_name PayRules
extends Resource
## What a pawn thinks they deserve an hour (from their best skill, more for the manager), how
## their pay against that moves their mood, and when they ask for a raise. All numbers are
## placeholders.

@export var base_wage: float = 12.0
## Added to the fair wage for each level of the pawn's best skill.
@export var per_level: float = 0.5
## Added to the manager's fair wage.
@export var manager_bonus: float = 3.0
## Wages change in steps of this much (the pay buttons, and rounding the fair wage).
@export var wage_step: float = 0.5
@export var min_wage: float = 0.0

@export_group("Mood")
## Mood per dollar an hour above (or below) their fair wage.
@export var mood_per_dollar: float = 2.0
## Pay never moves mood further than this either way.
@export var max_mood: float = 10.0

@export_group("Raises")
## They ask for a raise once their fair wage is this far above their wage.
@export var raise_gap: float = 1.0
## Given when the player turns a raise down.
@export var turned_down: MoodEffect
## Days after being turned down before they ask again.
@export var ask_again_days: int = 3
@export_group("")


## The fair wage for a pawn whose best skill is `best_level`, rounded to the wage step.
func get_fair_wage(best_level: int, is_manager: bool) -> float:
	var wage: float = base_wage + per_level * best_level
	if is_manager:
		wage += manager_bonus
	return snap_wage(wage)


func snap_wage(wage: float) -> float:
	return maxf(snappedf(wage, wage_step), min_wage)


## Mood from being paid `wage` when they think they deserve `fair`.
func get_mood(wage: float, fair: float) -> float:
	return clampf((wage - fair) * mood_per_dollar, -max_mood, max_mood)
