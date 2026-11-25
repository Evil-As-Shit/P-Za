class_name HiringRules
extends Resource
## How hiring works: how many resumes arrive each day and how long they stay, how the
## shop's rating moves applicants' starting skills, how skills read on a resume, and what a
## new hire starts with. All numbers are placeholders.

## Resumes that arrive as each day starts.
@export var resumes_per_day: int = 3
## Days a resume stays in the stack before it's gone.
@export var days_to_expire: int = 3
## The rating where applicants roll the usual starting skills (see SkillRules).
@export var neutral_rating: float = 3.0
## Starting skill levels move this many levels per star above (or below) neutral_rating.
@export var levels_per_star: float = 2.0
## A resume shows each skill as the last band whose minimum level it reaches.
@export var band_names: Array[String] = ["Novice", "Decent", "Expert"]
@export var band_min_levels: Array[int] = [0, 7, 14]
## Every grid priority a new hire starts with.
@export var start_priority: int = 3


## How many levels the shop's `rating` moves applicants' starting skills.
func get_level_shift(rating: float) -> int:
	return roundi((rating - neutral_rating) * levels_per_star)


## How `level` reads on a resume, e.g. "Decent".
func get_band(level: int) -> String:
	var band: String = band_names[0] if not band_names.is_empty() else ""
	for i: int in mini(band_names.size(), band_min_levels.size()):
		if level >= band_min_levels[i]:
			band = band_names[i]
	return band
