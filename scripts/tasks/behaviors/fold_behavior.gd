class_name FoldBehavior
extends TaskBehavior
## Restocking (a shop job the WorkManager opens while it's needed), done in two parts by
## one pawn: standing at the storage it takes from (the flat-box pallet), they take one
## unit and work it in hand (fold it); then they carry it to storage with room for it
## (folded boxes) and put it away. Work stations stay free for orders. Only one pawn does
## this at a time, and room is claimed up front, so they never make more than fits.

enum Part { FOLD, PUT_AWAY }

## Taken from storage (e.g. flat boxes); the pawn works standing at it.
@export var supply: StorageKind
## Where the finished one is put away (e.g. Boxes).
@export var stores: StorageKind
## How the finished one looks (e.g. a closed box).
@export var finished_texture: Texture2D
## Shop minutes to put it away once there.
@export var put_away_minutes: float = 0.1
## Only if the pawn can't get to storage: someone else carries it there later.
@export var put_away_task: TaskType


## There's supply to work, room for the result, and nobody doing it already.
func is_needed(work: WorkManager) -> bool:
	return (
		not is_under_way(work) and work.find_supply(supply) != null
		and work.find_room(stores) != null
	)


func try_start(pawn: Pawn, job: Job, work: WorkManager) -> bool:
	if is_under_way(work):
		return false
	var source: Station = work.find_supply(supply)
	var destination: Station = work.find_room(stores)
	if source == null or destination == null or source.is_reserved(0):
		return false
	var spot := WorkSpot.new(source, 0)
	if not work.start_job(pawn, job, spot, [JobStop.take_supply(source)] as Array[JobStop]):
		return false
	destination.claim_room()
	job.destination = destination
	work.add_shop_job(job)
	return true


func get_work_seconds(job: Job) -> float:
	if job.part == Part.PUT_AWAY:
		return ShopClock.minutes_to_seconds(put_away_minutes)
	return super(job)


func on_supply_taken(job: Job, station: Station, pawn: Pawn, work: WorkManager) -> void:
	job.target = work.spawn_item(station.get_storage_layout().textures[0])
	job.target.display_name = "Box"
	pawn.hold_item(job.target)


## Folding is done in hand, so nothing is set down; at storage, it's put away.
func on_work_started(job: Job, pawn: Pawn, _work: WorkManager) -> void:
	if job.part != Part.PUT_AWAY:
		return
	var item: Item = pawn.release_item()
	if item != null:
		item.queue_free()
	job.target = null
	job.destination.add_stock()


func on_finished(job: Job, _pawn: Pawn, _work: WorkManager) -> void:
	if job.part == Part.FOLD:
		job.target.set_texture(finished_texture)


## Folded: the same pawn carries it to storage. If they can't get there, they set it down
## and it becomes a job of its own for someone else.
func continue_job(job: Job, pawn: Pawn, work: WorkManager) -> bool:
	if job.part != Part.FOLD:
		return false
	var spots: Array[WorkSpot] = [WorkSpot.new(job.destination, 0)]
	if work.start_next_part(pawn, job, Part.PUT_AWAY, spots):
		return true
	var put_away := Job.new(put_away_task, null, null)
	put_away.target = job.target
	put_away.destination = job.destination
	work.add_shop_job(put_away)
	work.drop_on_floor(pawn.release_item(), work.get_cell(pawn))
	return false


## Interrupted (e.g. the pallet or the rack was picked up): the job is dropped. Its room in
## storage is handed back and the box it had in hand is gone.
func on_withdrawn(job: Job, work: WorkManager) -> void:
	var stored: bool = job.part == Part.PUT_AWAY and job.target == null
	if not stored and job.destination != null and is_instance_valid(job.destination):
		job.destination.unclaim_room()
	if job.target != null and is_instance_valid(job.target):
		job.target.queue_free()
	job.target = null
	work.cancel_shop_job(job)
