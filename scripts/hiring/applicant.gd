class_name Applicant
extends RefCounted
## Someone in the resume stack (see Hiring): who they'd be if hired. The resume shows their
## name, skills as rough bands and asking wage; their traits only show once hired.

var display_name: String = ""
## Work type -> skill level.
var skills: Dictionary[WorkType, int] = {}
var traits: Array[PawnTrait] = []
## Hourly wage they ask for (their fair wage).
var asking_wage: float = 0.0
## The day their resume arrived.
var arrived_day: int = 0


func get_best_skill() -> int:
	var best: int = 0
	for work_type: WorkType in skills:
		best = maxi(best, skills[work_type])
	return best
