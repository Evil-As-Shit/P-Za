class_name Ticket
extends RefCounted
## A printed order on the rack. Works through its recipe one step (job) at a time.

enum Section { WAIT, MAKE }

var order_number: int
var recipe: Recipe
var section: Section = Section.WAIT
var step_index: int = 0
## Job for the current step, or null once every step is done.
var current_job: Job = null


func _init(p_order_number: int, p_recipe: Recipe) -> void:
	order_number = p_order_number
	recipe = p_recipe
	_start_current_step()


func is_complete() -> bool:
	return step_index >= recipe.steps.size()


func is_in_progress() -> bool:
	return current_job != null and current_job.claimed_by != null


## Moves on to the next recipe step after the current job is finished.
func advance() -> void:
	step_index += 1
	_start_current_step()


func get_title() -> String:
	return "#%d · %s" % [order_number, recipe.display_name]


func _start_current_step() -> void:
	current_job = null if is_complete() else Job.new(recipe.steps[step_index], self)
