extends Node2D
## Prototype shop scene. Wires the floor, stations, job board and pawns together.
## Pawns take open jobs first; with nothing to do they wander between random cells.

@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0

var _pawns: Array[Pawn] = []
var _stations: Array[Station] = []

@onready var _floor: ShopFloor = $ShopFloor
@onready var _entities: Node2D = $Entities
@onready var _camera: ShopCamera = $ShopCamera
@onready var _job_board: JobBoard = $JobBoard


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	for child: Node in _entities.get_children():
		if child is Station:
			_setup_station(child as Station)
	for child: Node in _entities.get_children():
		if child is Pawn:
			_setup_pawn(child as Pawn)
	_job_board.job_posted.connect(_on_job_posted)
	for pawn: Pawn in _pawns:
		_give_work_or_wander(pawn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_queue_job"):
		for station: Station in _stations:
			_job_board.post(station.create_job())
		get_viewport().set_input_as_handled()


func _setup_station(station: Station) -> void:
	station.place(_floor)
	for cell: Vector2i in station.get_footprint_cells():
		_floor.set_cell_blocked(cell, true)
	_stations.append(station)


func _setup_pawn(pawn: Pawn) -> void:
	pawn.global_position = _floor.cell_to_global(_floor.get_random_walkable_cell())
	pawn.path_finished.connect(_on_pawn_path_finished.bind(pawn))
	pawn.job_finished.connect(_on_pawn_job_finished.bind(pawn))
	_pawns.append(pawn)


func _give_work_or_wander(pawn: Pawn) -> void:
	if pawn.has_job():
		return
	var job: Job = _job_board.claim_next()
	if job == null:
		_wait_then_wander(pawn)
		return
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	var path: PackedVector2Array = _floor.get_path_points(from_cell, job.station.get_work_cell())
	if path.is_empty():
		push_warning("No path to %s's work spot." % job.station.data.display_name)
		_job_board.return_job(job)
		_wait_then_wander(pawn)
		return
	pawn.assign_job(job, path, job.station.get_work_target())


func _send_to_random_cell(pawn: Pawn) -> void:
	if pawn.has_job():
		return
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	var path: PackedVector2Array = _floor.get_path_points(
		from_cell, _floor.get_random_walkable_cell()
	)
	if path.size() < 2:
		_wait_then_wander(pawn)
		return
	pawn.follow_path(path)


func _wait_then_wander(pawn: Pawn) -> void:
	var wait: float = randf_range(idle_time_min, idle_time_max)
	get_tree().create_timer(wait).timeout.connect(_send_to_random_cell.bind(pawn))


func _on_job_posted(job: Job) -> void:
	print("Job queued: %s (%d open)" % [job.task_type.display_name, _job_board.get_open_count()])
	for pawn: Pawn in _pawns:
		if not pawn.has_job():
			_give_work_or_wander(pawn)
			return


func _on_pawn_path_finished(pawn: Pawn) -> void:
	_give_work_or_wander(pawn)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	print("%s done (%d open)" % [job.task_type.display_name, _job_board.get_open_count()])
	_give_work_or_wander(pawn)
