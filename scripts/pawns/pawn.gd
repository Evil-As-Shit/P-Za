class_name Pawn
extends Node2D
## A staff member. Walks paths and works jobs it is given, and animates to match.
## It doesn't choose what to do; its owner decides and calls follow_path() or assign_job().

signal path_finished
## Reached one of the job's stops on the way to work (e.g. to pick something up). The owner
## does what the stop needs, like handing over an item with hold_item().
signal stop_reached(job: Job)
## Reached the work spot and is about to start working.
signal work_started(job: Job)
signal job_finished(job: Job)
## Emitted each frame of work with how far along the job is (0-1).
signal work_progressed(job: Job, progress: float)

enum State { IDLE, WALKING, WALKING_TO_STOP, WAITING_AT_STOP, WALKING_TO_JOB, WORKING }

## Priorities run from 1 (done first) to this. 0 means the pawn never does that work.
const LOWEST_PRIORITY: int = 4

@export var display_name: String = "Pawn"
## Work type -> priority (1 to LOWEST_PRIORITY). Missing or 0 means never.
@export var priorities: Dictionary[WorkType, int] = {}

## Paid per shop hour, for the whole day, at closing.
@export var hourly_wage: float = 15.0
@export var move_speed: float = 60.0
## Seconds of work done per second. Skill and mood will change this later.
@export var work_speed: float = 1.0
## Height above the feet a carried item is held at.
@export var hold_height: float = 24.0
## How far in front of the pawn a carried item is held, for a down-left facing.
@export var hold_reach: Vector2 = Vector2(-5.0, 3.0)

@export_group("Avoidance")
## Walking pawns closer than this to another pawn (on the floor, in pixels along the grid)
## step aside and slow down, so they pass instead of walking through each other.
@export var avoid_radius: float = 20.0
## How far they step aside, in screen pixels.
@export var sidestep: float = 7.0
## How fast they step aside and back, in pixels per second.
@export var sidestep_speed: float = 40.0
## Walking speed multiplier while passing close to someone.
@export_range(0.1, 1.0) var crowded_speed: float = 0.6
@export_group("")

var _state: State = State.IDLE
var _path: PackedVector2Array = PackedVector2Array()
## Paths still to walk after the current one: to each remaining stop, then to work.
var _next_paths: Array[PackedVector2Array] = []
## State to go back to after waiting at a stop.
var _resume_state: State = State.IDLE
var _job: Job = null
var _held_item: Item = null
var _on_phone: bool = false
var _work_target: Vector2 = Vector2.ZERO
var _facing_up: bool = false
var _facing_right: bool = false
## Where the pawn is drawn relative to where it really is, while stepping aside for
## someone. Only the look moves; paths, cells and jobs use the real position.
var _sidestep_offset: Vector2 = Vector2.ZERO
## Walking speed multiplier right now (crowded_speed while passing someone).
var _speed_factor: float = 1.0
var _work_bar_base: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _work_bar: ProgressBar = $WorkBar
@onready var _hold_point: Marker2D = $HoldPoint


func _ready() -> void:
	add_to_group(&"pawns")
	_work_bar_base = _work_bar.position
	_play_idle()
	_place_hold_point()


func _process(delta: float) -> void:
	_avoid_others(delta)
	match _state:
		State.WALKING, State.WALKING_TO_STOP, State.WALKING_TO_JOB:
			_step_along_path(delta)
		State.WORKING:
			_do_work(delta)


## The offset the pawn is drawn at while stepping aside (zero when not).
func get_sidestep_offset() -> Vector2:
	return _sidestep_offset


func is_walking() -> bool:
	return _state == State.WALKING or _state == State.WALKING_TO_STOP or _state == State.WALKING_TO_JOB


## While walking near another pawn: steps aside, away from them (to the right when meeting
## head-on, so two pawns pass each other), and slows down. Eases back once clear.
func _avoid_others(delta: float) -> void:
	var target := Vector2.ZERO
	_speed_factor = 1.0
	if is_walking() and not _path.is_empty():
		var nearest: Pawn = null
		var nearest_distance: float = avoid_radius
		for node: Node in get_tree().get_nodes_in_group(&"pawns"):
			var other := node as Pawn
			if other == self or other == null:
				continue
			var distance: float = _to_floor(other.global_position - global_position).length()
			if distance < nearest_distance:
				nearest = other
				nearest_distance = distance
		var heading: Vector2 = _to_floor(_path[0] - global_position)
		if nearest != null and heading.length() > 0.01:
			_speed_factor = crowded_speed
			heading = heading.normalized()
			var right := Vector2(-heading.y, heading.x)
			var to_other: Vector2 = _to_floor(nearest.global_position - global_position)
			var side: float = 1.0
			if absf(right.dot(to_other)) > 1.0:
				side = -signf(right.dot(to_other))
			target = _to_screen(right * side).normalized() * sidestep
	var offset: Vector2 = _sidestep_offset.move_toward(target, sidestep_speed * delta)
	if offset == _sidestep_offset:
		return
	_sidestep_offset = offset
	_sprite.position = _sidestep_offset
	_work_bar.position = _work_bar_base + _sidestep_offset
	_place_hold_point()


## Screen offset to floor distances (the floor's iso grid is squashed to half height).
static func _to_floor(screen: Vector2) -> Vector2:
	return Vector2(screen.x, screen.y * 2.0)


static func _to_screen(floor_offset: Vector2) -> Vector2:
	return Vector2(floor_offset.x, floor_offset.y / 2.0)


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


## Walks each of `stop_paths` in turn (emitting stop_reached at the end of each), then
## `work_path` to the work spot, then works until done. Emits work_started and job_finished.
func assign_job(
	job: Job, stop_paths: Array[PackedVector2Array], work_path: PackedVector2Array,
	work_target: Vector2
) -> void:
	_job = job
	_job.claimed_by = self
	_on_phone = false
	_work_target = work_target
	_next_paths = stop_paths.duplicate()
	_next_paths.append(work_path)
	_walk_next_path()


func _walk_next_path() -> void:
	_path = _next_paths.pop_front()
	_state = State.WALKING_TO_STOP if not _next_paths.is_empty() else State.WALKING_TO_JOB


## Carries `item` in front of the pawn (until there's a carry animation).
func hold_item(item: Item) -> void:
	_held_item = item
	item.reparent(_hold_point, false)
	item.position = Vector2.ZERO
	_place_hold_point()


## Call from stop_reached when the stop can't be done yet (e.g. the item is still baking):
## the pawn stands facing `look_at` until resume_job().
func wait_at_stop(look_at: Vector2) -> void:
	if _state != State.WALKING_TO_STOP and _state != State.WALKING_TO_JOB:
		return
	_resume_state = _state
	_state = State.WAITING_AT_STOP
	_face(look_at - global_position)
	_play_idle()


## Changes where the pawn will work: walks `path` there instead, once any stops left are
## done. `path` must start where the pawn is now (or at their last stop).
func redirect_work(path: PackedVector2Array, work_target: Vector2) -> void:
	_work_target = work_target
	if not _next_paths.is_empty():
		_next_paths[_next_paths.size() - 1] = path
	elif _state == State.WALKING_TO_JOB or (
		_state == State.WAITING_AT_STOP and _resume_state == State.WALKING_TO_JOB
	):
		_path = path


## From a stop with no stops left, makes one more stop on the way to work: walks
## `to_stop` (emitting stop_reached at its end), then `to_work`. Returns false if the pawn
## isn't on their way to work.
func detour(to_stop: PackedVector2Array, to_work: PackedVector2Array) -> bool:
	if _state != State.WALKING_TO_JOB or not _next_paths.is_empty():
		return false
	_next_paths = [to_work]
	_path = to_stop
	_state = State.WALKING_TO_STOP
	return true


## Carries on after wait_at_stop().
func resume_job() -> void:
	if _state == State.WAITING_AT_STOP:
		_state = _resume_state


func get_job() -> Job:
	return _job


## The item the pawn is carrying, or null.
func get_held_item() -> Item:
	return _held_item


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
	_next_paths.clear()
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
	var step: float = move_speed * _speed_factor * delta
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
	if _state == State.WALKING_TO_STOP:
		# Move on first, so a handler that makes the pawn wait pauses the next walk.
		_walk_next_path()
		stop_reached.emit(_job)
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
	_hold_point.position = reach + Vector2(0.0, -hold_height) + _sidestep_offset
	move_child(_hold_point, 0 if _facing_up else _sprite.get_index() + 1)


func _play_idle() -> void:
	if _on_phone:
		_sprite.play(&"phone_up" if _facing_up else &"phone_down")
	else:
		_sprite.play(&"idle_up" if _facing_up else &"idle_down")
