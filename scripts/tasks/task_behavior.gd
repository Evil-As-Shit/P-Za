class_name TaskBehavior
extends Resource
## How a task is planned and carried out. This base behavior carries the job's item to a
## free spot on a station that does the task (picking it up first if it's somewhere else)
## and works it there. Subclasses change where the work happens, what's fetched on the way
## and what happens to the items. The WorkManager calls these hooks; they act through it.


## The item the job moves to its spot, or null if it doesn't exist yet.
func get_carried(job: Job) -> Item:
	if job.target != null:
		return job.target
	return job.order_item.item if job.order_item != null else null


## Spots the job could be done at, best first.
func get_spots(job: Job, work: WorkManager) -> Array[WorkSpot]:
	return work.get_free_spots(job.task_type, get_carried(job))


## For restocking tasks (see WorkManager.restock_tasks): true while a job should be open.
func is_needed(_work: WorkManager) -> bool:
	return false


## True if a shop job of this behavior is under way (e.g. a pawn is folding a box), for
## tasks only one pawn does at a time.
func is_under_way(work: WorkManager) -> bool:
	for job: Job in work.get_shop_jobs():
		if job.task_type.get_behavior() == self:
			return true
	return false


## Gives the pawn the job if there's a spot they can reach (with any stops on the way).
func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	var carried: Item = get_carried(job)
	if carried != null and not work.is_available(carried):
		return false
	for spot: WorkSpot in get_spots(job, work):
		var stops: Array[JobStop] = []
		if carried != null and not work.is_item_at(carried, spot):
			stops.append(JobStop.pick_up(work.get_pickup_cell(carried)))
		elif carried != null and carried.busy:
			# Can't work an item in place while a station is still working it.
			continue
		if work.start_job(pawn, job, spot, stops):
			return true
	return false


## The pawn took a claimed unit of stock from `station` (a TAKE_SUPPLY stop) and should be
## handed what it became.
func on_supply_taken(_job: Job, _station: Station, _pawn: Pawn, _work: WorkManager) -> void:
	pass


## The pawn reached a stop this behavior planned (other than picking up or taking supply).
func on_stop_reached(_job: Job, _stop: JobStop, _pawn: Pawn, _work: WorkManager) -> void:
	pass


## The pawn picked up the job's item (a PICK_UP stop).
func on_picked_up(_job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	pass


## The pawn reached the work spot: they set down what they carry. A recipe's first step
## with nothing to carry starts the item there.
func on_work_started(job: Job, pawn: Pawn, work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	var order_item: OrderItem = job.order_item
	if item == null and order_item != null and order_item.item == null:
		item = work.spawn_item(order_item.recipe.get_stage_texture(order_item.step_index))
		item.display_name = order_item.recipe.display_name
		order_item.item = item
	if item != null:
		job.station.put_item(job.spot, item)


## Game seconds of pawn work for the job's current part (see Job.part).
func get_work_seconds(job: Job) -> float:
	return job.task_type.get_work_seconds()


## The work is done; the job is still holding its spot and the ticket hasn't moved on.
func on_finished(_job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	pass


## The job was taken off its pawn before it was done (see WorkManager.withdraw_job()): the
## spot and stops are let go, and anything carried was set down. Hands back anything else
## the behavior claimed.
func on_withdrawn(_job: Job, _work: WorkManager) -> void:
	pass


## Right after on_finished(): for a job done in parts, gives the same pawn the next part
## (e.g. carry what they just folded to storage) and returns true, so the job isn't done
## yet. Returns false when the job is done.
func continue_job(_job: Job, _pawn: Pawn, _work: WorkManager) -> bool:
	return false


## Right after on_finished(): false if what the pawn did wasn't the job's step itself (e.g.
## parking a pizza on a rack while the oven is full), so the job opens again for any pawn
## instead of the ticket moving on.
func is_step_done(_job: Job) -> bool:
	return true


## After the job let go of its spot and the ticket moved on.
func after_finished(_job: Job, _work: WorkManager) -> void:
	pass
