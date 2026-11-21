class_name SetOutContainerBehavior
extends TaskBehavior
## Fetches one unit from storage (e.g. a folded box) and sets it out, open, on a free spot.
## It becomes the order item's container, which later steps work at.

## What's fetched from storage.
@export var supply: StorageKind
## Look of the container once it's set out, drawn under and over whatever goes in it.
@export var open_under_texture: Texture2D
@export var open_over_texture: Texture2D
## Where things put in the container sit, relative to it (e.g. raised onto a box's floor).
@export var contents_offset: Vector2 = Vector2.ZERO


## True if a pawn is fetching or opening the order item's container right now.
static func is_on_its_way(order_item: OrderItem) -> bool:
	for job: Job in order_item.prep_jobs:
		if job.task_type.get_behavior() is SetOutContainerBehavior and job.claimed_by != null:
			return true
	return false


func get_carried(job: Job) -> Item:
	return job.order_item.container


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if get_carried(job) != null:
		return super(pawn, job, work)
	var storage: Station = work.find_supply(supply)
	if storage == null:
		return false
	for spot: WorkSpot in get_spots(job, work):
		if work.start_job(pawn, job, spot, [JobStop.take_supply(storage)] as Array[JobStop]):
			return true
	return false


func on_supply_taken(job: Job, station: Station, pawn: Pawn, work: WorkManager) -> void:
	job.order_item.container = work.spawn_item(station.get_storage_layout().textures[0])
	pawn.hold_item(job.order_item.container)


func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	var container: Item = pawn.release_item()
	if container != null:
		job.station.put_item(job.spot, container)


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	var container: Item = job.order_item.container
	container.set_texture(null)
	container.set_wrap(open_under_texture, open_over_texture, contents_offset)


func after_finished(job: Job, work: WorkManager) -> void:
	work.on_container_ready(job.order_item)
