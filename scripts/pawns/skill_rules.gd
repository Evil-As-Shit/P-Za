class_name SkillRules
extends Resource
## How skill levels work: their range, how a level changes work time, how much practice
## each level takes, and what new pawns start with. All numbers are placeholders.

@export var max_level: int = 20
## The level that works at a task's base time. Lower is slower, higher is faster.
@export var base_level: int = 10
## Work time multiplier at level 0.
@export var slowest_time: float = 2.0
## Work time multiplier at max_level.
@export var fastest_time: float = 0.5
## Shop minutes of practice to go from level L to L + 1 are (L + 1) times this.
@export var minutes_per_level: float = 10.0
## Starting levels are rolled between these (inclusive).
@export var start_min: int = 2
@export var start_max: int = 8


## How many times the base work time a pawn at `level` takes: slowest_time at 0, 1 at
## base_level, fastest_time at max_level, in straight lines between.
func time_multiplier(level: int) -> float:
	var clamped: int = clampi(level, 0, max_level)
	if clamped <= base_level:
		return lerpf(slowest_time, 1.0, float(clamped) / base_level)
	return lerpf(1.0, fastest_time, float(clamped - base_level) / (max_level - base_level))


## Shop minutes of practice to go from `level` to the next.
func minutes_to_next(level: int) -> float:
	return (level + 1) * minutes_per_level


func roll_start_level(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(start_min, start_max)
