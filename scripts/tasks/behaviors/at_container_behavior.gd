class_name AtContainerBehavior
extends TaskBehavior
## Worked at the spot where the order item's container is set out (e.g. cutting a pizza in
## its box). An item set down elsewhere is brought over and put in first. It can close the
## container, which then becomes the order item's item (e.g. a closed box).

## If true, the container closes when the work is done.
@export var closes_container: bool = false


## Order items whose item sits set down on a spot, waiting for its container (e.g. a pizza
## out of the oven before its box was opened).
static func count_waiting(work: WorkManager) -> int:
	var count: int = 0
	for ticket: Ticket in work.get_make_tickets():
		for order_item: OrderItem in ticket.order_items:
			var job: Job = order_item.current_job
			if (
				order_item.container == null and order_item.item != null
				and order_item.item.station != null and job != null
				and job.task_type.get_behavior() is AtContainerBehavior
				and not job.task_type.get_behavior() is IntoContainerBehavior
			):
				count += 1
	return count


func get_spots(job: Job, work: WorkManager) -> Array[WorkSpot]:
	var result: Array[WorkSpot] = []
	var spot: WorkSpot = work.get_container_spot(job.order_item)
	if spot != null:
		result.append(spot)
	return result


func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var item: Item = pawn.release_item()
	if item == null:
		return
	var container: Item = job.order_item.container
	if container != null and job.station.get_item(job.spot) == container:
		container.put_in(item)
	else:
		job.station.put_item(job.spot, item)


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if not closes_container:
		return
	# The item and its container become one (e.g. a closed box).
	var order_item: OrderItem = job.order_item
	order_item.container.take_out(order_item.item)
	order_item.item.queue_free()
	order_item.item = order_item.container
	order_item.container = null
	order_item.item.set_wrap(null, null)
