extends Node2D
## Prototype shop scene. Wires the floor, stations, ticket rack, HUD and pawns together.
## Idle pawns take the first workable Make ticket; with nothing to do they wander.

## Recipe printed by the debug hotkey until customers exist.
@export var debug_recipe: Recipe
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0
## Chance an idle pawn checks their phone instead of just standing (placeholder).
@export_range(0.0, 1.0) var phone_chance: float = 0.3
@export var phone_time_min: float = 3.0
@export var phone_time_max: float = 6.0
## Item scene spawned when a ticket's first step starts (no ingredient storage yet).
@export var item_scene: PackedScene
## Seconds a finished item stays visible before it's cleared (no hand-off yet).
@export var finished_item_linger: float = 2.0

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
	pawn.pickup_reached.connect(_on_pawn_pickup_reached.bind(pawn))
	pawn.work_started.connect(_on_pawn_work_started.bind(pawn))
	pawn.job_finished.connect(_on_pawn_job_finished.bind(pawn))
	_pawns.append(pawn)


## Gives the pawn the first open job it can reach a free station for. Returns false if none.
## If the ticket's item is somewhere else, the pawn fetches it on the way.
func _try_assign_work(pawn: Pawn) -> bool:
	if pawn.has_job():
		return true
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	for job: Job in _rack.get_open_jobs():
		var item: Item = job.ticket.item
		for station: Station in _stations_for(job):
			var pickup_path := PackedVector2Array()
			var work_from: Vector2i = from_cell
			if item != null and item.station != station:
				var pickup_cell: Vector2i = _get_pickup_cell(item)
				pickup_path = _floor.get_path_points(from_cell, pickup_cell)
				if pickup_path.is_empty():
					continue
				work_from = pickup_cell
			var work_path: PackedVector2Array = _floor.get_path_points(
				work_from, station.get_work_cell()
			)
			if work_path.is_empty():
				continue
			station.reserve()
			job.station = station
			pawn.assign_job(job, pickup_path, work_path, station.get_work_target())
			_rack.notify_job_state_changed()
			return true
	return false


## Free stations that can do the job, with the one already holding its item first.
func _stations_for(job: Job) -> Array[Station]:
	var item: Item = job.ticket.item
	var result: Array[Station] = []
	for station: Station in _stations:
		if station.is_reserved() or not station.can_do(job.task_type):
			continue
		var held: Item = station.get_item()
		if held != null and held != item:
			continue
		if held != null:
			result.push_front(station)
		else:
			result.append(station)
	return result


## Where a pawn stands to pick up an item: the station's work spot, or the floor cell it's on.
func _get_pickup_cell(item: Item) -> Vector2i:
	if item.station != null:
		return item.station.get_work_cell()
	return _floor.global_to_cell(item.global_position)


func _drop_on_floor(item: Item, cell: Vector2i) -> void:
	item.reparent(_entities, false)
	item.global_position = _floor.cell_to_global(cell)


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
	if randf() < phone_chance:
		pawn.use_phone()
		wait = randf_range(phone_time_min, phone_time_max)
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
	var held: Item = pawn.release_item()
	if held != null:
		_drop_on_floor(held, _floor.global_to_cell(pawn.global_position))
	_release_station(job)
	_rack.notify_job_state_changed()
	_work_or_wander(pawn)


func _on_rack_ticket_completed(ticket: Ticket) -> void:
	print("Ticket %s complete" % ticket.get_title())


func _on_pawn_path_finished(pawn: Pawn) -> void:
	_work_or_wander(pawn)


func _on_pawn_pickup_reached(job: Job, pawn: Pawn) -> void:
	var item: Item = job.ticket.item
	var from_station: Station = item.station
	if from_station != null:
		from_station.take_item()
	pawn.hold_item(item)
	if from_station != null:
		# The station is free for other tickets now.
		_on_rack_jobs_changed()


func _on_pawn_work_started(job: Job, pawn: Pawn) -> void:
	var ticket: Ticket = job.ticket
	var item: Item = pawn.release_item()
	if item == null and ticket.item == null:
		item = item_scene.instantiate() as Item
		_entities.add_child(item)
		item.set_texture(ticket.recipe.get_stage_texture(ticket.step_index))
		ticket.item = item
	if item != null:
		job.station.put_item(item)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	var ticket: Ticket = job.ticket
	var item: Item = ticket.item
	var last_step: bool = ticket.step_index == ticket.recipe.steps.size() - 1
	if last_step and item != null:
		# Free the slot now; the finished item stays visible for a moment.
		job.station.take_item()
		ticket.item = null
	_release_station(job)
	_rack.complete_job(job)
	if item != null:
		item.set_texture(ticket.recipe.get_stage_texture(ticket.step_index))
		if last_step:
			get_tree().create_timer(finished_item_linger).timeout.connect(item.queue_free)
	if not pawn.has_job():
		_work_or_wander(pawn)
