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

@export_group("Breakdown")
## Shop minutes a breakdown lasts.
@export var breakdown_minutes: float = 20.0
## Shop minutes after a breakdown before another can start.
@export var breakdown_cooldown_minutes: float = 60.0
