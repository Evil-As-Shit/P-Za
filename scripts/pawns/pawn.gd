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
## Practice raised a skill to a new level.
signal skill_leveled_up(work_type: WorkType, level: int)
## Mood fell too low: the pawn takes no new jobs until breakdown_ended.
signal breakdown_started
signal breakdown_ended
## A break resting standing (no free break table) is over.
signal break_ended

enum State { IDLE, WALKING, WALKING_TO_STOP, WAITING_AT_STOP, WALKING_TO_JOB, WORKING }

## Priorities run from 1 (done first) to this. 0 means the pawn never does that work.
const LOWEST_PRIORITY: int = 4
## How far past a sidestep the floor is checked (as a multiple of it), so a pawn at the
## middle of its cell doesn't step aside toward a wall half a cell away.
const SIDESTEP_REACH: float = 2.5

@export var display_name: String = "Pawn"
## Work type -> priority (1 to LOWEST_PRIORITY). Missing or 0 means never.
@export var priorities: Dictionary[WorkType, int] = {}
## Work type -> skill level (0 to skill_rules.max_level). Only for work types with a skill.
@export var skills: Dictionary[WorkType, int] = {}
@export var skill_rules: SkillRules
## How mood works (see PawnMood). Null: no mood.
@export var mood_rules: MoodRules
## The shop's manager (one at a time): quotes each order's wait. They still work as usual.
@export var is_manager: bool = false

## Paid per shop hour, for the whole day, at closing.
@export var hourly_wage: float = 15.0
@export var move_speed: float = 60.0
## Seconds of work done per second, before skill, mood and the rush.
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

## The floor the pawn walks on (set by its owner), so it doesn't step aside into a wall or
## furniture. Null means anywhere.
var shop_floor: ShopFloor = null
## Mood, stress and mood effects (null without mood_rules).
var mood: PawnMood = null

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
## Game seconds spent walking for the current job so far (to its stops and work spot).
var _walk_seconds: float = 0.0
## Work type -> shop minutes of practice toward the next skill level.
var _practice: Dictionary[WorkType, float] = {}

## Everything drawn for the pawn. Moved while stepping aside; it sorts on its own (the pawn
## is y-sorted), so the pawn is drawn in front of or behind others where it's drawn.
@onready var _body: Node2D = $Body
@onready var _sprite: AnimatedSprite2D = $Body/Sprite
@onready var _work_bar: ProgressBar = $Body/WorkBar
@onready var _hold_point: Marker2D = $Body/HoldPoint


func _ready() -> void:
	add_to_group(&"pawns")
	if mood_rules != null:
		mood = PawnMood.new(mood_rules)
		mood.breakdown_started.connect(breakdown_started.emit)
		mood.breakdown_ended.connect(breakdown_ended.emit)
		mood.break_ended.connect(break_ended.emit)
	_play_idle()
	_place_hold_point()


func _process(delta: float) -> void:
	if mood != null:
		mood.tick(delta / ShopClock.minutes_to_seconds(1.0), has_job(), is_resting())
	_avoid_others(delta)
	match _state:
		State.WALKING, State.WALKING_TO_STOP, State.WALKING_TO_JOB:
			if _job != null:
				_walk_seconds += delta
			_step_along_path(delta)
		State.WORKING:
			_do_work(delta)


## The offset the pawn is drawn at while stepping aside (zero when not).
func get_sidestep_offset() -> Vector2:
	return _sidestep_offset


## True while at the work spot, working the job.
func is_working() -> bool:
	return _state == State.WORKING


func is_walking() -> bool:
	return _state == State.WALKING or _state == State.WALKING_TO_STOP or _state == State.WALKING_TO_JOB


## While walking near another pawn: steps aside, away from them (to the right when meeting
## head-on, so two pawns pass each other), and slows down. Eases back once clear. Never
## steps toward a wall or furniture: then the other way, or not at all.
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
			for try_side: float in [side, -side]:
				var aside: Vector2 = _to_screen(right * try_side).normalized() * sidestep
				if _can_step_toward(aside):
					target = aside
					break
	var offset: Vector2 = _sidestep_offset.move_toward(target, sidestep_speed * delta)
	if offset == _sidestep_offset:
		return
	_sidestep_offset = offset
	_body.position = _sidestep_offset


## True if stepping aside by `aside` (screen pixels) keeps the pawn's look on its side of
## any wall or furniture: the floor just past it that way is open to the pawn's cell.
func _can_step_toward(aside: Vector2) -> bool:
	if shop_floor == null:
		return true
	var here: Vector2i = shop_floor.global_to_cell(global_position)
	var past: Vector2i = shop_floor.global_to_cell(global_position + aside * SIDESTEP_REACH)
	if past == here:
		return true
	return shop_floor.is_walkable(past) and not shop_floor.is_edge_blocked(here, past)


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


## Stops a walk taken without a job (wandering) where the pawn is, without emitting
## path_finished.
func stop_walking() -> void:
	if has_job() or _state != State.WALKING:
		return
	_path.clear()
	_state = State.IDLE
	_play_idle()


## The paths still to walk: the current one (empty while working), then any after it.
func get_route() -> Array[PackedVector2Array]:
	var route: Array[PackedVector2Array] = [_path]
	route.append_array(_next_paths)
	return route


## Replaces the paths from get_route() with new ones to the same places (e.g. around a
## station put down in the way). Each path must start where the one before it ends.
func set_route(route: Array[PackedVector2Array]) -> void:
	_path = route[0]
	_next_paths.assign(route.slice(1))


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
	_walk_seconds = 0.0
	_on_phone = false
	_work_target = work_target
	_next_paths = stop_paths.duplicate()
	_next_paths.append(work_path)
	_walk_next_path()


func _walk_next_path() -> void:
	_path = _next_paths.pop_front()
	_state = State.WALKING_TO_STOP if not _next_paths.is_empty() else State.WALKING_TO_JOB


## Carries `item` in front of the pawn, with the holding animations.
func hold_item(item: Item) -> void:
	_held_item = item
	item.reparent(_hold_point, false)
	item.position = Vector2.ZERO
	_place_hold_point()
	if not is_walking():
		_play_idle()


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


## Game seconds spent walking for the current job so far (not waiting at stops).
func get_walk_seconds() -> float:
	return _walk_seconds


## The item the pawn is carrying, or null.
func get_held_item() -> Item:
	return _held_item


## Lets go of the held item and returns it. The caller moves it somewhere.
func release_item() -> Item:
	var item: Item = _held_item
	_held_item = null
	if not is_walking():
		_play_idle()
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


## Skill level in the work type (0 if never set).
func get_skill(work_type: WorkType) -> int:
	return skills.get(work_type, 0)


func set_skill(work_type: WorkType, level: int) -> void:
	skills[work_type] = clampi(level, 0, skill_rules.max_level)
	_practice.erase(work_type)


## Shop minutes of practice toward the skill's next level.
func get_practice(work_type: WorkType) -> float:
	return _practice.get(work_type, 0.0)


## Gives a starting level to each skill the pawn doesn't have a level in yet.
func roll_skills(work_types: Array[WorkType], rng: RandomNumberGenerator) -> void:
	for work_type: WorkType in work_types:
		if work_type.has_skill and not skills.has(work_type):
			skills[work_type] = skill_rules.roll_start_level(rng)


## Work seconds per second on a task of this work type, after skill, mood and the rush.
func get_work_rate(work_type: WorkType) -> float:
	var rate: float = work_speed
	if mood != null:
		rate *= mood.get_speed_multiplier()
	if work_type == null or not work_type.has_skill or skill_rules == null:
		return rate
	return rate / skill_rules.time_multiplier(get_skill(work_type))


## The skill level a hands-on step of this work type counts as for quality: the pawn's
## level, raised or lowered by mood.
func get_quality_level(work_type: WorkType) -> int:
	var level: int = get_skill(work_type)
	if mood != null:
		level += mood.get_quality_levels()
	return clampi(level, 0, skill_rules.max_level) if skill_rules != null else maxi(level, 0)


## True during a breakdown (see PawnMood): no new jobs.
func is_on_breakdown() -> bool:
	return mood != null and mood.is_on_breakdown()


## True while they take no new jobs: on a breakdown or resting standing on a break.
func is_off_work() -> bool:
	return mood != null and (mood.is_on_breakdown() or mood.is_on_standing_break())


## True while taking their break at a break table (working a rest task there).
func is_resting() -> bool:
	return _state == State.WORKING and _job != null and _job.task_type.rest


## True if they're low enough on energy to take a break now.
func wants_break() -> bool:
	return mood != null and mood.wants_break()


## A break is over (at a table, or resting standing).
func finish_break() -> void:
	if mood != null:
		mood.finish_break()


## Starts a break resting where they stand (see PawnMood.start_standing_break()).
func start_standing_break() -> void:
	if mood != null:
		mood.start_standing_break()


## A night's rest before the next day: full energy.
func rest_overnight() -> void:
	if mood != null:
		mood.rest_overnight()


## The shop started or stopped rushing.
func set_rushing(rushing: bool) -> void:
	if mood != null:
		mood.set_rushing(rushing)


## Adds shop minutes of practice to a skill, leveling it up as it fills.
func practice(work_type: WorkType, minutes: float) -> void:
	if work_type == null or not work_type.has_skill or skill_rules == null:
		return
	var level: int = get_skill(work_type)
	var total: float = get_practice(work_type) + minutes
	while level < skill_rules.max_level and total >= skill_rules.minutes_to_next(level):
		total -= skill_rules.minutes_to_next(level)
		level += 1
		skills[work_type] = level
		skill_leveled_up.emit(work_type, level)
	_practice[work_type] = total if level < skill_rules.max_level else 0.0


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
	if _held_item != null:
		_sprite.play(&"hold_walk_up" if _facing_up else &"hold_walk_down")
	else:
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
	var work_type: WorkType = _job.task_type.work_type
	practice(work_type, delta / ShopClock.minutes_to_seconds(1.0))
	# A break lasts its time whatever the pawn's speed.
	var rate: float = 1.0 if _job.task_type.rest else get_work_rate(work_type)
	var done: bool = _job.add_work(rate * delta)
	_update_work_bar()
	work_progressed.emit(_job, _job.get_progress())
	if not done:
		return
	var job: Job = _job
	_job = null
	_state = State.IDLE
	_work_bar.hide()
	job_finished.emit(job)


func _update_work_bar() -> void:
	_work_bar.value = _job.get_progress()


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
	_body.move_child(_hold_point, 0 if _facing_up else _sprite.get_index() + 1)


func _play_idle() -> void:
	if _held_item != null:
		_sprite.play(&"hold_idle_up" if _facing_up else &"hold_idle_down")
	elif _on_phone:
		_sprite.play(&"phone_up" if _facing_up else &"phone_down")
	else:
		_sprite.play(&"idle_up" if _facing_up else &"idle_down")
