class_name OrderItem
extends RefCounted
## One thing on an order (e.g. one pizza), worked through its recipe one step (job) at a
## time. Prep steps (e.g. setting out a box) open once the steps before them are done, and
## are worked alongside the steps after them. An order's items are worked in parallel.

var ticket: Ticket
var recipe: Recipe
## Index of the current (non-prep) step. Prep steps are skipped over.
var step_index: int = 0
## Job for the current step, or null once every step is done.
var current_job: Job = null
## Prep jobs not done yet, open or not.
var prep_jobs: Array[Job] = []
## Recipe position of each prep job: it opens once step_index has passed it.
var _prep_indices: Dictionary[Job, int] = {}
## The thing being made (e.g. the pizza, then its closed box), once its first step started.
var item: Item = null
## What the item goes into (e.g. an open box), once it's been set out.
var container: Item = null
## Sits on the order's stack (the first finished item is the stack's base).
var stacked: bool = false


func _init(p_ticket: Ticket, p_recipe: Recipe) -> void:
	ticket = p_ticket
	recipe = p_recipe
	for index: int in recipe.steps.size():
		if recipe.steps[index].prep:
			var job := Job.new(recipe.steps[index], ticket, self)
			job.recipe_step = true
			prep_jobs.append(job)
			_prep_indices[job] = index
	_start_current_step()


## Every recipe step is done (e.g. the pizza is boxed).
func is_complete() -> bool:
	return step_index >= recipe.steps.size() and prep_jobs.is_empty()


## Jobs that can be worked now: open prep jobs first, then the current step.
func get_active_jobs() -> Array[Job]:
	var jobs: Array[Job] = []
	for job: Job in prep_jobs:
		if _prep_indices[job] < step_index:
			jobs.append(job)
	if current_job != null:
		jobs.append(current_job)
	return jobs


## Call after one of its jobs is finished: drops a prep job, or moves on to the next step.
func finish_job(job: Job) -> void:
	if prep_jobs.has(job):
		prep_jobs.erase(job)
		_prep_indices.erase(job)
		return
	step_index += 1
	_start_current_step()


## Drops all jobs so items and jobs (which reference each other) can be freed.
func clear_jobs() -> void:
	current_job = null
	prep_jobs.clear()
	_prep_indices.clear()


func _start_current_step() -> void:
	while step_index < recipe.steps.size() and recipe.steps[step_index].prep:
		step_index += 1
	current_job = null
	if step_index < recipe.steps.size():
		current_job = Job.new(recipe.steps[step_index], ticket, self)
		current_job.recipe_step = true
