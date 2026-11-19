class_name Pawn
extends Node2D
## A staff member. Walks paths and works jobs it is given, and animates to match.
## It doesn't choose what to do; its owner decides and calls follow_path() or assign_job().

signal path_finished
signal job_finished(job: Job)

enum State { IDLE, WALKING, WALKING_TO_JOB, WORKING }

@export var move_speed: float = 40.0
## Seconds of work done per second. Skill and mood will change this later.
@export var work_speed: float = 1.0

var _state: State = State.IDLE
var _path: PackedVector2Array = PackedVector2Array()
var _job: Job = null
var _work_target: Vector2 = Vector2.ZERO
var _facing_up: bool = false
var _facing_right: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_play_idle()


func _process(delta: float) -> void:
	match _state:
		State.WALKING, State.WALKING_TO_JOB:
			_step_along_path(delta)
		State.WORKING:
			_do_work(delta)


## Walks through each point in order (global positions). Emits path_finished at the end.
## Only valid while the pawn has no job.
func follow_path(points: PackedVector2Array) -> void:
	if has_job():
		return
	_path = points
	_state = State.WALKING


## Walks the path to the job's work spot, then works until done. Emits job_finished.
func assign_job(job: Job, path: PackedVector2Array, work_target: Vector2) -> void:
	_job = job
	_job.claimed_by = self
	_work_target = work_target
	_path = path
	_state = State.WALKING_TO_JOB


func has_job() -> bool:
	return _job != null


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
	if _state == State.WALKING_TO_JOB:
		_state = State.WORKING
		_face(_work_target - global_position)
		_play_idle()
		return
	_state = State.IDLE
	_play_idle()
	path_finished.emit()


func _do_work(delta: float) -> void:
	if not _job.add_work(work_speed * delta):
		return
	var job: Job = _job
	_job = null
	_state = State.IDLE
	job_finished.emit(job)


func _face(direction: Vector2) -> void:
	if not is_zero_approx(direction.y):
		_facing_up = direction.y < 0.0
	if not is_zero_approx(direction.x):
		_facing_right = direction.x > 0.0
	# The sheet only has left-facing art; right-facing is a horizontal flip.
	_sprite.flip_h = _facing_right


func _play_idle() -> void:
	_sprite.play(&"idle_up" if _facing_up else &"idle_down")
