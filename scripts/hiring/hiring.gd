class_name Hiring
extends Node
## The resume stack. A few resumes arrive as each day starts, better ones while the shop's
## rating is high, and each is gone after a few days. Hiring one makes its pawn (with no
## shifts yet); passing on one drops it. The world adds the pawn to the shop.

signal resumes_changed

@export var rules: HiringRules
@export var pawn_scene: PackedScene
## What applicants' skills, traits and asking wages are rolled with (the pawn scene's).
@export var skill_rules: SkillRules
@export var trait_rules: TraitRules
@export var pay_rules: PayRules

var _skill_types: Array[WorkType] = []
var _grid_types: Array[WorkType] = []
var _resumes: Array[Applicant] = []
## The number in the next applicant's placeholder name ("Pawn 7").
var _next_number: int = 1
var _rng := RandomNumberGenerator.new()


## `skill_types`: the skills applicants roll; `grid_types`: the priority grid's work types
## (a new hire's starting priorities); `staff_count`: pawns so far, for naming.
func setup(skill_types: Array[WorkType], grid_types: Array[WorkType], staff_count: int) -> void:
	_skill_types = skill_types
	_grid_types = grid_types
	_next_number = staff_count + 1
	_rng.randomize()


func get_resumes() -> Array[Applicant]:
	return _resumes


## A day starts: resumes past their time are gone and new ones arrive, rolled for the shop's
## `rating`.
func new_day(day: int, rating: float) -> void:
	for applicant: Applicant in _resumes.duplicate():
		if get_days_left(applicant, day) <= 0:
			_resumes.erase(applicant)
	for i: int in rules.resumes_per_day:
		_resumes.append(make_applicant(day, rating))
	resumes_changed.emit()


## Days `applicant`'s resume has left on `day` (it's gone at 0).
func get_days_left(applicant: Applicant, day: int) -> int:
	return applicant.arrived_day + rules.days_to_expire - day


## A new applicant: starting skills shifted by the rating, rolled traits, asking their fair
## wage.
func make_applicant(day: int, rating: float) -> Applicant:
	var applicant := Applicant.new()
	applicant.display_name = "Pawn %d" % _next_number
	_next_number += 1
	applicant.arrived_day = day
	var shift: int = rules.get_level_shift(rating)
	for work_type: WorkType in _skill_types:
		var level: int = skill_rules.roll_start_level(_rng) + shift
		applicant.skills[work_type] = clampi(level, 0, skill_rules.max_level)
	if trait_rules != null:
		applicant.traits = trait_rules.roll(_rng)
	applicant.asking_wage = pay_rules.get_fair_wage(applicant.get_best_skill(), false) \
		if pay_rules != null else 0.0
	return applicant


## Takes `applicant` out of the stack and returns their new pawn (not in the tree yet): at
## their asking wage, every grid priority at the start priority, and no shifts.
func hire(applicant: Applicant) -> Pawn:
	if not _resumes.has(applicant):
		return null
	_resumes.erase(applicant)
	var pawn := pawn_scene.instantiate() as Pawn
	pawn.display_name = applicant.display_name
	pawn.skills = applicant.skills.duplicate()
	pawn.traits = applicant.traits.duplicate()
	pawn.hourly_wage = applicant.asking_wage
	for work_type: WorkType in _grid_types:
		pawn.priorities[work_type] = rules.start_priority
	pawn.schedule = WorkSchedule.make(0, 0)
	resumes_changed.emit()
	return pawn


## Drops `applicant`'s resume.
func pass_on(applicant: Applicant) -> void:
	if _resumes.has(applicant):
		_resumes.erase(applicant)
		resumes_changed.emit()
