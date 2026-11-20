class_name Pawn
extends Node2D
## A staff member. Walks paths and works jobs it is given, and animates to match.
## It doesn't choose what to do; its owner decides and calls follow_path() or assign_job().

signal path_finished
## Reached the spot to pick up the job's item. The owner should hand it over with hold_item().
signal pickup_reached(job: Job)
## Reached the work spot and is about to start working.
signal work_started(job: Job)
signal job_finished(job: Job)
## Emitted each frame of work with how far along the job is (0-1).
signal work_progressed(job: Job, progress: float)

enum State { IDLE, WALKING, WALKING_TO_PICKUP, WAITING_AT_PICKUP, WALKING_TO_JOB, WORKING }

## Priorities run from 1 (done first) to this. 0 means the pawn never does that work.
const LOWEST_PRIORITY: int = 4

@export var display_name: String = "Pawn"
## Work type -> priority (1 to LOWEST_PRIORITY). Missing or 0 means never.
@export var priorities: Dictionary[WorkType, int] = {}

@export var move_speed: float = 40.0
## Seconds of work done per second. Skill and mood will change this later.
@export var work_speed: float = 1.0
## Height above the feet a carried item is held at.
@export var hold_height: float = 24.0
## How far in front of the pawn a carried item is held, for a down-left facing.
@export var hold_reach: Vector2 = Vector2(-5.0, 3.0)

var _state: State = State.IDLE
var _path: PackedVector2Array = PackedVector2Array()
var _work_path: PackedVector2Array = PackedVector2Array()
var _job: Job = null
var _held_item: Item = null
var _on_phone: bool = false
var _work_target: Vector2 = Vector2.ZERO
var _facing_up: bool = false
var _facing_right: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _work_bar: ProgressBar = $WorkBar
@onready var _hold_point: Marker2D = $HoldPoint


func _ready() -> void:
	_play_idle()
	_place_hold_point()


func _process(delta: float) -> void:
	match _state:
		State.WALKING, State.WALKING_TO_PICKUP, State.WALKING_TO_JOB:
			_step_along_path(delta)
		State.WORKING:
			_do_work(delta)


## Walks through each point in order (global positions). Emits path_finished at the end.
## Only valid while the pawn has no job.
func follow_path(points: PackedVector2Array) -> void:
	if has_job():
		return
	_on_phone = false
	_path = points
	_state = State.WALKING


## Looks at their phone while standing idle, until the next walk or job.
func use_phone() -> void:
	if _state != State.IDLE:
		return
	_on_phone = true
	_play_idle()


## Walks `pickup_path` (if not empty) to fetch the job's item, then `work_path` to the
## work spot, then works until done. Emits pickup_reached, work_started and job_finished.
func assign_job(
	job: Job, pickup_path: PackedVector2Array, work_path: PackedVector2Array, work_target: Vector2
) -> void:
	_job = job
	_job.claimed_by = self
	_on_phone = false
	_work_target = work_target
	if pickup_path.is_empty():
		_path = work_path
		_state = State.WALKING_TO_JOB
	else:
		_path = pickup_path
		_work_path = work_path
		_state = State.WALKING_TO_PICKUP


## Carries `item` in front of the pawn (until there's a carry animation).
func hold_item(item: Item) -> void:
	_held_item = item
	item.reparent(_hold_point, false)
	item.position = Vector2.ZERO
	_place_hold_point()


## Call from pickup_reached when the item isn't ready yet: the pawn stands facing
## `look_at` until resume_job().
func wait_at_pickup(look_at: Vector2) -> void:
	if _state != State.WALKING_TO_JOB:
		return
	_state = State.WAITING_AT_PICKUP
	_face(look_at - global_position)
	_play_idle()


## Carries on to the work spot after wait_at_pickup().
func resume_job() -> void:
	if _state == State.WAITING_AT_PICKUP:
		_state = State.WALKING_TO_JOB


func get_job() -> Job:
	return _job


## Lets go of the held item and returns it. The caller moves it somewhere.
func release_item() -> Item:
	var item: Item = _held_item
	_held_item = null
	return item


## Stops walking to or working the current job and returns it, progress intact.
func drop_job() -> Job:
	var job: Job = _job
	_job = null
	_path.clear()
	_work_path.clear()
	_state = State.IDLE
	_work_bar.hide()
	_play_idle()
	if job != null:
		job.claimed_by = null
	return job


func has_job() -> bool:
	return _job != null


## 1 (first) to LOWEST_PRIORITY, or 0 if the pawn never does this work.
func get_priority(work_type: WorkType) -> int:
	return priorities.get(work_type, 0)


func set_priority(work_type: WorkType, priority: int) -> void:
	if priority <= 0:
		priorities.erase(work_type)
	else:
		priorities[work_type] = mini(priority, LOWEST_PRIORITY)


func _step_along_path(delta: float) -> void:
	if _path.is_empty():
		_on_path_end()
		return

	var to_target: Vector2 = _path[0] - global_position
	var step: float = move_speed * delta
	if to_target.length() <= step:
		global_position = _path[0]
		_path.remove_at(0)
		if _path.is_empty():
			_on_path_end()
		return

	_face(to_target)
	global_position += to_target.normalized() * step
	_sprite.play(&"walk_up" if _facing_up else &"walk_down")


func _on_path_end() -> void:
	if _state == State.WALKING_TO_PICKUP:
		_path = _work_path
		_work_path = PackedVector2Array()
		_state = State.WALKING_TO_JOB
		pickup_reached.emit(_job)
		return
	if _state == State.WALKING_TO_JOB:
		_state = State.WORKING
		_face(_work_target - global_position)
		_play_idle()
		_update_work_bar()
		_work_bar.show()
		work_started.emit(_job)
		return
	_state = State.IDLE
	_play_idle()
	path_finished.emit()


func _do_work(delta: float) -> void:
	var done: bool = _job.add_work(work_speed * delta)
	_update_work_bar()
	work_progressed.emit(_job, _work_bar.value)
	if not done:
		return
	var job: Job = _job
	_job = null
	_state = State.IDLE
	_work_bar.hide()
	job_finished.emit(job)


func _update_work_bar() -> void:
	var required: float = _job.get_work_required()
	_work_bar.value = 1.0 if required <= 0.0 else _job.work_done / required


func _face(direction: Vector2) -> void:
	if not is_zero_approx(direction.y):
		_facing_up = direction.y < 0.0
	if not is_zero_approx(direction.x):
		_facing_right = direction.x > 0.0
	# The sheet only has left-facing art; right-facing is a horizontal flip.
	_sprite.flip_h = _facing_right
	_place_hold_point()


## Holds carried items in front of the pawn, drawn behind them when facing away, and
## turned the way the pawn faces.
func _place_hold_point() -> void:
	if _held_item != null:
		_held_item.set_mirrored(not _facing_right)
	var reach: Vector2 = hold_reach
	if _facing_right:
		reach.x = -reach.x
	if _facing_up:
		reach.y = -reach.y
	_hold_point.position = reach + Vector2(0.0, -hold_height)
	move_child(_hold_point, 0 if _facing_up else _sprite.get_index() + 1)


func _play_idle() -> void:
	if _on_phone:
		_sprite.play(&"phone_up" if _facing_up else &"phone_down")
	else:
		_sprite.play(&"idle_up" if _facing_up else &"idle_down")
