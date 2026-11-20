class_name Ticket
extends RefCounted
## A printed order on the rack. Works through its recipe one step (job) at a time. Prep
## steps (e.g. setting out a box) are open from the start, alongside the others.

enum Section { WAIT, MAKE }

var order_number: int
var recipe: Recipe
var section: Section = Section.WAIT
## Index of the current (non-prep) step. Prep steps are skipped over.
var step_index: int = 0
## Job for the current step, or null once every step is done.
var current_job: Job = null
## Prep jobs not done yet. They can be worked at any time.
var prep_jobs: Array[Job] = []
## The thing being made (e.g. the pizza), once its first step has started.
var item: Item = null
## What the item goes into (e.g. an open box), once it's been set out.
var container: Item = null
## Every step is done and the order is waiting to go out. It stays on the rack until then.
var ready: bool = false


func _init(p_order_number: int, p_recipe: Recipe) -> void:
	order_number = p_order_number
	recipe = p_recipe
	for step: TaskType in recipe.steps:
		if step.prep:
			prep_jobs.append(Job.new(step, self))
	_start_current_step()


func is_complete() -> bool:
	return step_index >= recipe.steps.size() and prep_jobs.is_empty()


## Jobs that can be worked now: prep jobs first, then the current step.
func get_active_jobs() -> Array[Job]:
	var jobs: Array[Job] = prep_jobs.duplicate()
	if current_job != null:
		jobs.append(current_job)
	return jobs


func is_in_progress() -> bool:
	for job: Job in get_active_jobs():
		if job.claimed_by != null:
			return true
	return false


## Call after a job is finished: drops a prep job, or moves on to the next step.
func finish_job(job: Job) -> void:
	if prep_jobs.has(job):
		prep_jobs.erase(job)
		return
	step_index += 1
	_start_current_step()


func get_title() -> String:
	return "#%d · %s" % [order_number, recipe.display_name]


## Drops all jobs so tickets and jobs (which reference each other) can be freed.
func clear_jobs() -> void:
	current_job = null
	prep_jobs.clear()


func _start_current_step() -> void:
	while step_index < recipe.steps.size() and recipe.steps[step_index].prep:
		step_index += 1
	current_job = null if step_index >= recipe.steps.size() else Job.new(
		recipe.steps[step_index], self
	)
