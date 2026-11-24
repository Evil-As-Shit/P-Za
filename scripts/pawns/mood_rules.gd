class_name MoodRules
extends Resource
## How mood works: what it drifts toward, how stress builds in a rush and eases after, the
## mood bands and what they do to speed and quality, and breakdowns. All numbers are
## placeholders.

## Mood with no stress and no mood effects.
@export var base_mood: float = 50.0
## Mood lost at full stress (100); less stress costs proportionally less.
@export var stress_mood_cost: float = 40.0
## Points per shop minute mood moves toward its target.
@export var mood_drift_per_minute: float = 1.0

@export_group("Stress")
## Stress gained per shop minute on a job during a rush.
@export var stress_rise_per_minute: float = 1.5
## Stress lost per shop minute when there's no rush (or during a breakdown).
@export var stress_ease_per_minute: float = 1.0

@export_group("Rush")
## Work speed multiplier during a rush.
@export var rush_speed: float = 1.25
## Given to pawns who worked a rush, when it ends.
@export var rush_survived: MoodEffect

@export_group("Bands")
## Mood at or above this is Happy.
@export var happy_at: float = 70.0
## Mood below this is Stressed.
@export var stressed_below: float = 30.0
## Mood below this is Breaking: the pawn has a breakdown.
@export var breaking_below: float = 15.0
@export var happy_speed: float = 1.1
@export var stressed_speed: float = 0.9
## Skill levels added to (or taken from) a hands-on step's quality.
@export var happy_quality_levels: int = 2
@export var stressed_quality_levels: int = -2

@export_group("Energy")
## Energy lost per shop minute on a job (rush_energy_drain times that in a rush).
@export var energy_drain_per_minute: float = 0.25
@export var rush_energy_drain: float = 2.0
## Below this energy, mood drops, down to tired_mood_cost lower at 0.
@export var tired_below: float = 40.0
@export var tired_mood_cost: float = 20.0
## Below this energy, work is slower by exhausted_speed.
@export var exhausted_below: float = 15.0
@export var exhausted_speed: float = 0.85

@export_group("Breaks")
## A pawn gets one break a day, by how long their schedule has them work: from
## short_shift_hours a short break, from long_shift_hours a long one; none below.
@export var short_shift_hours: float = 4.0
@export var short_break_minutes: float = 15.0
@export var long_shift_hours: float = 8.0
@export var long_break_minutes: float = 30.0
## Below this energy a pawn takes their break once the shop isn't rushing.
@export var break_below: float = 30.0
## Below this energy a pawn takes their break even in a rush.
@export var must_break_below: float = 10.0
## Not tired by the time this few shop minutes of their shift are left, they take it anyway
## (placeholder).
@export var break_due_minutes_left: float = 120.0
## Energy gained per shop minute at a break table, and resting standing (no free table).
@export var table_rest_per_minute: float = 5.0
@export var standing_rest_per_minute: float = 2.0
## Given at the end of every break.
@export var took_break: MoodEffect

@export_group("Social")
## Mood moved at social 0 or 100 (none at 50). See Social for how social changes.
@export var social_mood_cost: float = 10.0
## Below this social, the pawn is lonely.
@export var lonely_below: float = 20.0

@export_group("Breakdown")
## Shop minutes a breakdown lasts.
@export var breakdown_minutes: float = 20.0
## Shop minutes after a breakdown before another can start.
@export var breakdown_cooldown_minutes: float = 60.0
@export_group("")


## Shop minutes of break a day for `work_minutes` of scheduled work (0 for none).
func get_break_minutes(work_minutes: float) -> float:
	if work_minutes >= long_shift_hours * 60.0:
		return long_break_minutes
	if work_minutes >= short_shift_hours * 60.0:
		return short_break_minutes
	return 0.0
