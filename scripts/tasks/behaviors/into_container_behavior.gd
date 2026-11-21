class_name IntoContainerBehavior
extends AtContainerBehavior
## Brings the item to its container and puts it in (e.g. a pizza from the oven into its
## open box). If the container isn't out yet, the item is set down on a free spot instead,
## so it doesn't wait (e.g. in the oven), and a later at-container step moves it in. When
## the pawn picks the item up, they go to the container if it's out by then, or wait for it
## if someone is setting it out.


func get_spots(job: Job, work: WorkManager) -> Array[WorkSpot]:
	var at_container: Array[WorkSpot] = super(job, work)
	if not at_container.is_empty():
		return at_container
	var result: Array[WorkSpot] = work.get_free_spots(job.task_type, get_carried(job))
	# Setting this item down without its container must leave a spot free to set the
	# container out on, for it and every other item already waiting. Otherwise unboxed
	# pizzas could fill every spot and no box could ever be opened.
	if result.size() < AtContainerBehavior.count_waiting(work) + 2:
		result.clear()
	return result


func on_picked_up(job: Job, pawn: Pawn, work: WorkManager) -> void:
	var container_spot: WorkSpot = work.get_container_spot(job.order_item)
	if container_spot == null:
		if SetOutContainerBehavior.is_on_its_way(job.order_item):
			work.wait_for_container(job.order_item, pawn)
		return
	if not container_spot.is_same(WorkSpot.new(job.station, job.spot)):
		work.redirect(job, pawn, container_spot)
