extends Node2D
## Prototype shop scene. Wires the floor, stations, ticket rack, HUD and pawns together.
## Idle pawns take the first workable Make ticket; with nothing to do they wander.

## Recipe printed by the debug hotkey until customers exist.
@export var debug_recipe: Recipe
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0

var _pawns: Array[Pawn] = []
var _stations: Array[Station] = []

@onready var _floor: ShopFloor = $ShopFloor
@onready var _entities: Node2D = $Entities
@onready var _camera: ShopCamera = $ShopCamera
@onready var _rack: TicketRack = $TicketRack
@onready var _rack_panel: TicketRackPanel = $Hud/TicketRackPanel


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	for child: Node in _entities.get_children():
		if child is Station:
			_setup_station(child as Station)
	for child: Node in _entities.get_children():
		if child is Pawn:
			_setup_pawn(child as Pawn)

	_rack.changed.connect(_on_rack_changed)
	_rack.jobs_changed.connect(_on_rack_jobs_changed)
	_rack.job_withdrawn.connect(_on_rack_job_withdrawn)
	_rack.ticket_completed.connect(_on_rack_ticket_completed)
	_rack_panel.move_requested.connect(_rack.move_ticket)
	_on_rack_changed()

	for pawn: Pawn in _pawns:
		_wait_then_wander(pawn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_queue_job"):
		_rack.print_ticket(debug_recipe)
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


## Gives the pawn the first open job it can reach a free station for. Returns false if none.
func _try_assign_work(pawn: Pawn) -> bool:
	if pawn.has_job():
		return true
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	for job: Job in _rack.get_open_jobs():
		for station: Station in _stations:
			if station.is_reserved() or station.get_task_type() != job.task_type:
				continue
			var path: PackedVector2Array = _floor.get_path_points(from_cell, station.get_work_cell())
			if path.is_empty():
				continue
			station.reserve()
			job.station = station
			pawn.assign_job(job, path, station.get_work_target())
			_rack.notify_job_state_changed()
			return true
	return false


func _work_or_wander(pawn: Pawn) -> void:
	if not _try_assign_work(pawn):
		_wait_then_wander(pawn)


func _release_station(job: Job) -> void:
	if job.station != null:
		job.station.release()
		job.station = null


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


func _on_rack_changed() -> void:
	_rack_panel.show_rack(
		_rack.get_tickets(Ticket.Section.WAIT), _rack.get_tickets(Ticket.Section.MAKE)
	)


func _on_rack_jobs_changed() -> void:
	for pawn: Pawn in _pawns:
		_try_assign_work(pawn)


func _on_rack_job_withdrawn(job: Job) -> void:
	var pawn: Pawn = job.claimed_by
	pawn.drop_job()
	_release_station(job)
	_rack.notify_job_state_changed()
	_work_or_wander(pawn)


func _on_rack_ticket_completed(ticket: Ticket) -> void:
	print("Ticket %s complete" % ticket.get_title())


func _on_pawn_path_finished(pawn: Pawn) -> void:
	_work_or_wander(pawn)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	_release_station(job)
	_rack.complete_job(job)
	if not pawn.has_job():
		_work_or_wander(pawn)
