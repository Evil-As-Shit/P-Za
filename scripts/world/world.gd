extends Node2D
## Prototype shop scene. Wires the floor, stations, ticket rack, HUD and pawns together.
## Idle pawns take Make-ticket work by their priorities; with nothing to do they wander.


## A station spot a job could be done at.
class Spot:
	var station: Station
	var index: int

	func _init(p_station: Station, p_index: int) -> void:
		station = p_station
		index = p_index


## Recipe printed by the debug hotkey until customers exist.
@export var debug_recipe: Recipe
## Columns of the priority grid, left to right. On a priority tie, pawns pick leftmost.
@export var work_types: Array[WorkType] = []
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0
## Chance an idle pawn checks their phone instead of just standing (placeholder).
@export_range(0.0, 1.0) var phone_chance: float = 0.3
@export var phone_time_min: float = 3.0
@export var phone_time_max: float = 6.0
## Item scene spawned when a ticket's first step starts (no ingredient storage yet).
@export var item_scene: PackedScene
## Seconds a finished order waits where it was handed off before it goes out (placeholder
## until customers pick orders up).
@export var pickup_wait: float = 5.0

var _pawns: Array[Pawn] = []
var _stations: Array[Station] = []
## Pawns standing by a busy item (e.g. at the oven), waiting to pick it up.
var _waiting_for: Dictionary[Item, Pawn] = {}
## Station shown in the station panel, or null.
var _selected_station: Station = null

@onready var _floor: ShopFloor = $ShopFloor
@onready var _entities: Node2D = $Entities
@onready var _walls: ShopWalls = $Entities/Walls
@onready var _camera: ShopCamera = $ShopCamera
@onready var _rack: TicketRack = $TicketRack
@onready var _rack_panel: TicketRackPanel = $Hud/TicketRackPanel
@onready var _priority_panel: PriorityPanel = $Hud/PriorityPanel
@onready var _station_panel: StationPanel = $Hud/StationPanel
@onready var _clock: ShopClock = $ShopClock
@onready var _clock_panel: ClockPanel = $Hud/ClockPanel


func _ready() -> void:
	_camera.position = _floor.cell_to_global(_floor.get_used_rect().get_center())
	_walls.build(_floor)
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
	_priority_panel.priority_change_requested.connect(_on_priority_change_requested)
	_priority_panel.show_priorities(_pawns, work_types)
	_station_panel.role_change_requested.connect(_on_role_change_requested)
	_station_panel.close_requested.connect(_select_station.bind(null))
	_clock_panel.setup(_clock.speeds)
	_clock_panel.speed_requested.connect(_clock.set_speed)
	_clock.time_changed.connect(_clock_panel.show_time)
	_clock.speed_changed.connect(_clock_panel.show_speed)
	_clock_panel.show_time(_clock.day, _clock.get_minute_of_day())
	_clock_panel.show_speed(_clock.speed)

	for pawn: Pawn in _pawns:
		_wait_then_wander(pawn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_queue_job"):
		_rack.print_ticket(debug_recipe)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_priorities"):
		_priority_panel.visible = not _priority_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_walls"):
		_walls.cycle_view_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_pause"):
		_clock.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"speed_1"):
		_clock.set_speed(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"speed_2"):
		_clock.set_speed(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"speed_3"):
		_clock.set_speed(3)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_select_station(_station_at(get_global_mouse_position()))
			get_viewport().set_input_as_handled()


## The role-taking station under a point, or null. Checks a little below the point too,
## since tabletops are drawn above their floor cells.
func _station_at(point: Vector2) -> Station:
	for lift: float in [0.0, 16.0]:
		var cell: Vector2i = _floor.global_to_cell(point + Vector2(0.0, lift))
		for station: Station in _stations:
			if station.has_roles() and station.get_footprint_cells().has(cell):
				return station
	return null


func _select_station(station: Station) -> void:
	if _selected_station != null:
		_selected_station.set_selected(false)
	_selected_station = station
	# Role labels show while a station is selected, like zones while editing them.
	for each: Station in _stations:
		each.show_role_label(station != null)
	if station == null:
		_station_panel.hide()
		return
	station.set_selected(true)
	_station_panel.show_station(station)


func _on_role_change_requested(station: Station, role: StationRole) -> void:
	station.set_role(role)
	if station == _selected_station:
		_station_panel.show_station(station)
	_on_rack_jobs_changed()


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
	pawn.work_progressed.connect(_on_pawn_work_progressed.bind(pawn))
	_pawns.append(pawn)


## Gives the pawn work by their priorities: priority 1 first, ties going to the leftmost
## work type, and within a work type the first open job in Make-rack order. Returns false
## if there's nothing they can do.
## Only priorities up to `max_priority` are considered.
func _try_assign_work(pawn: Pawn, max_priority: int = Pawn.LOWEST_PRIORITY) -> bool:
	if pawn.has_job():
		return true
	var jobs: Array[Job] = _rack.get_open_jobs()
	for priority: int in range(1, max_priority + 1):
		for work_type: WorkType in work_types:
			if pawn.get_priority(work_type) != priority:
				continue
			for job: Job in jobs:
				if job.task_type.work_type == work_type and _try_job(pawn, job):
					return true
	return false


## Assigns the job if the pawn can reach a free spot for it. If the job needs something
## brought (the ticket's item, or a supply from storage), the pawn fetches it on the way.
## A busy item (e.g. still baking) can be fetched early: the pawn waits by it.
func _try_job(pawn: Pawn, job: Job) -> bool:
	var from_cell: Vector2i = _floor.global_to_cell(pawn.global_position)
	var supply_station: Station = null
	var carried: Item = _get_carried(job)
	if job.task_type.fetch_supply != &"" and carried == null:
		supply_station = _find_supply(job.task_type.fetch_supply)
		if supply_station == null:
			return false
	for spot: Spot in _spots_for(job):
		var pickup_path := PackedVector2Array()
		var work_from: Vector2i = from_cell
		var pickup_cell: Vector2i = from_cell
		var needs_pickup: bool = false
		if supply_station != null:
			pickup_cell = supply_station.get_work_cell(0)
			needs_pickup = true
		elif carried != null and not _is_at(carried, spot):
			pickup_cell = _get_pickup_cell(carried)
			needs_pickup = true
		elif carried != null and carried.busy:
			# Can't work an item in place while a station is still working it.
			continue
		if needs_pickup:
			pickup_path = _floor.get_path_points(from_cell, pickup_cell)
			if pickup_path.is_empty():
				continue
			work_from = pickup_cell
		var work_path: PackedVector2Array = _floor.get_path_points(
			work_from, spot.station.get_work_cell(spot.index)
		)
		if work_path.is_empty():
			continue
		spot.station.reserve(spot.index)
		job.station = spot.station
		job.spot = spot.index
		if supply_station != null:
			supply_station.claim_supply()
			job.supply_station = supply_station
		pawn.assign_job(job, pickup_path, work_path, spot.station.get_work_target(spot.index))
		_rack.notify_job_state_changed()
		return true
	return false


## The ticket item this job moves to its spot: the container for set-out steps,
## otherwise the item being made. Null if it doesn't exist yet.
func _get_carried(job: Job) -> Item:
	if job.task_type.fetch_supply != &"":
		return job.ticket.container
	return job.ticket.item


## Free spots where the job can be done, with the one already holding its item first.
## Steps worked at the container go to the spot where it's set out. If it isn't ready, a
## step that puts the item in it sets the item down on a free spot instead (so a pizza
## doesn't wait in the oven for a box), and a later step moves it into the box.
func _spots_for(job: Job) -> Array[Spot]:
	var task: TaskType = job.task_type
	var own: Item = _get_carried(job)
	var result: Array[Spot] = []
	if task.is_at_container():
		var box_spot: Spot = _get_container_spot(job.ticket)
		if box_spot != null:
			result.append(box_spot)
			return result
		if not task.into_container:
			return result
	for station: Station in _stations:
		if not station.can_do(task):
			continue
		for index: int in station.get_spot_count():
			if station.is_reserved(index):
				continue
			var held: Item = station.get_item(index)
			if held != null and held != own:
				continue
			if held != null:
				result.push_front(Spot.new(station, index))
			else:
				result.append(Spot.new(station, index))
	return result


## The free spot where the ticket's container sits set out and ready, or null.
func _get_container_spot(ticket: Ticket) -> Spot:
	var container: Item = ticket.container
	if container == null or container.station == null:
		return null
	if container.station.is_reserved(container.spot):
		return null
	return Spot.new(container.station, container.spot)


## First storage station with an unclaimed unit of `kind`, or null.
func _find_supply(kind: StringName) -> Station:
	for station: Station in _stations:
		if station.has_supply(kind):
			return station
	return null


func _is_at(item: Item, spot: Spot) -> bool:
	var outer: Item = item.get_outermost()
	return outer.station == spot.station and outer.spot == spot.index


## Where a pawn stands to pick up an item: its spot's work cell, or the floor cell it's on.
func _get_pickup_cell(item: Item) -> Vector2i:
	var outer: Item = item.get_outermost()
	if outer.station != null:
		return outer.station.get_work_cell(outer.spot)
	return _floor.global_to_cell(outer.global_position)


func _spawn_item(texture: Texture2D) -> Item:
	var item := item_scene.instantiate() as Item
	_entities.add_child(item)
	item.set_texture(texture)
	return item


## The station works the item on its own; when done it takes its new look and can be
## moved again.
func _work_unattended(item: Item, task: TaskType, done_texture: Texture2D) -> void:
	item.busy = true
	var station: Station = item.station
	var spot: int = item.spot
	var tween: Tween = create_tween()
	tween.tween_method(
		func(progress: float) -> void: station.show_work(spot, progress),
		0.0, 1.0, task.base_work_time
	)
	await tween.finished
	station.hide_work()
	if not is_instance_valid(item):
		return
	item.busy = false
	item.set_texture(done_texture)
	var waiting: Pawn = _waiting_for.get(item)
	if waiting != null:
		_waiting_for.erase(item)
		_pick_up(waiting.get_job(), waiting)
		waiting.resume_job()
	_on_rack_jobs_changed()


## The finished order is picked up: its item leaves and frees its spot.
func _send_out(ticket: Ticket) -> void:
	var item: Item = ticket.item
	ticket.item = null
	if item != null:
		if item.station != null:
			item.station.take_item(item.spot)
		item.queue_free()
	_rack.send_out(ticket)


func _drop_on_floor(item: Item, cell: Vector2i) -> void:
	item.reparent(_entities, false)
	item.global_position = _floor.cell_to_global(cell)


func _work_or_wander(pawn: Pawn) -> void:
	if not _try_assign_work(pawn):
		_wait_then_wander(pawn)


func _release_station(job: Job) -> void:
	if job.station != null:
		job.station.release(job.spot)
		job.station = null
		job.spot = -1
	if job.supply_station != null:
		job.supply_station.unclaim_supply()
		job.supply_station = null


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


func _on_priority_change_requested(pawn: Pawn, work_type: WorkType, priority: int) -> void:
	pawn.set_priority(work_type, priority)
	_priority_panel.show_priorities(_pawns, work_types)
	_try_assign_work(pawn)


## Offers open work to idle pawns, priority 1 first across everyone, so a pawn with a job
## at 1 gets it before another pawn who has it at 3.
func _on_rack_jobs_changed() -> void:
	for max_priority: int in range(1, Pawn.LOWEST_PRIORITY + 1):
		for pawn: Pawn in _pawns:
			_try_assign_work(pawn, max_priority)


func _on_rack_job_withdrawn(job: Job) -> void:
	var pawn: Pawn = job.claimed_by
	var waited_for: Item = _waiting_for.find_key(pawn)
	if waited_for != null:
		_waiting_for.erase(waited_for)
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
	var item: Item = _get_carried(job)
	if job.supply_station == null and item.busy:
		# Not ready yet (e.g. still baking): stand by until the station is done with it.
		_waiting_for[item] = pawn
		pawn.wait_at_pickup(item.get_outermost().global_position)
		return
	_pick_up(job, pawn)


func _pick_up(job: Job, pawn: Pawn) -> void:
	var supply_station: Station = job.supply_station
	if supply_station != null:
		supply_station.take_supply()
		job.supply_station = null
		job.ticket.container = _spawn_item(supply_station.data.supply_texture)
		pawn.hold_item(job.ticket.container)
		return
	var item: Item = _get_carried(job)
	var from_station: Station = item.station
	if from_station != null:
		from_station.take_item(item.spot)
	pawn.hold_item(item)
	if from_station != null:
		# The spot is free for other tickets now.
		_on_rack_jobs_changed()


func _on_pawn_work_started(job: Job, pawn: Pawn) -> void:
	var ticket: Ticket = job.ticket
	var item: Item = pawn.release_item()
	if item == null and ticket.item == null and job.task_type.fetch_supply == &"":
		item = _spawn_item(ticket.recipe.get_stage_texture(ticket.step_index))
		ticket.item = item
	if item == null:
		return
	var at_box: bool = ticket.container != null and job.station.get_item(job.spot) == ticket.container
	if job.task_type.is_at_container() and at_box:
		ticket.container.put_in(item)
		return
	job.station.put_item(job.spot, item)


func _on_pawn_work_progressed(job: Job, progress: float, _pawn: Pawn) -> void:
	var frames: Array[Texture2D] = job.task_type.work_frames
	if frames.is_empty() or job.ticket.item == null:
		return
	# The work is split into one stretch with no overlay, then one per frame.
	var index: int = mini(int(progress * (frames.size() + 1)), frames.size()) - 1
	job.ticket.item.set_overlay(frames[index] if index >= 0 else null)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	var ticket: Ticket = job.ticket
	var task: TaskType = job.task_type
	if task.fetch_supply != &"":
		# The container is set out: show it open.
		ticket.container.set_texture(null)
		ticket.container.set_wrap(
			task.container_under_texture, task.container_over_texture,
			task.container_contents_offset
		)
	if task.closes_container:
		# The item and its container become one (e.g. a closed box).
		ticket.item.queue_free()
		ticket.item = ticket.container
		ticket.container = null
		ticket.item.set_wrap(null, null)

	var item: Item = ticket.item
	_release_station(job)
	_rack.complete_job(job)
	if item != null and task.unattended:
		_work_unattended(item, task, ticket.recipe.get_stage_texture(ticket.step_index))
	elif item != null and task.fetch_supply == &"":
		item.set_texture(ticket.recipe.get_stage_texture(ticket.step_index))
	if ticket.ready:
		get_tree().create_timer(pickup_wait).timeout.connect(_send_out.bind(ticket))
	if not pawn.has_job():
		_work_or_wander(pawn)
