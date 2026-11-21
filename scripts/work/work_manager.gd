class_name WorkManager
extends Node
## Hands out work and sees it through. Idle pawns take open jobs by their priorities: the
## ticket rack's, plus shop jobs like throwing out leftovers. Each job's task behavior
## plans where it's done and what's fetched on the way, and handles what happens to the
## items; this node walks pawns through it. With nothing to do, pawns wander.

## An order's last job is done: it's ready to go out.
signal order_ready(ticket: Ticket)
## A finished step used up ingredients (or a box) costing this much.
signal ingredients_used(cost: float)
## A pawn took a customer's order at the register: its ticket should print now.
signal order_taken(recipes: Array[Recipe], placed_at: int)
## The number of customers waiting at the register changed.
signal waiting_orders_changed(count: int)

## Columns of the priority grid, left to right. On a priority tie, pawns pick leftmost.
@export var work_types: Array[WorkType] = []
## Spawned for every item (pizzas, boxes, containers).
@export var item_scene: PackedScene
## Taking leftovers to the garbage.
@export var throw_out_task: TaskType
## Taking a customer's order at the register.
@export var take_order_task: TaskType
@export var idle_time_min: float = 0.5
@export var idle_time_max: float = 2.0
## Chance an idle pawn checks their phone instead of just standing (placeholder).
@export_range(0.0, 1.0) var phone_chance: float = 0.3
@export var phone_time_min: float = 3.0
@export var phone_time_max: float = 6.0

var _floor: ShopFloor
var _entities: Node2D
var _rack: TicketRack
var _pawns: Array[Pawn] = []
var _stations: Array[Station] = []
## Pawns standing by a busy item (e.g. at the oven), waiting to pick it up.
var _waiting_for: Dictionary[Item, Pawn] = {}
## Pawns holding an order item's item (e.g. by the oven) while someone sets out its
## container.
var _waiting_for_container: Dictionary[OrderItem, Pawn] = {}
## Shop jobs outside any order (throwing out leftovers), not done yet.
var _shop_jobs: Array[Job] = []


## Call once before adding stations and pawns. Items are spawned under `entities`.
func setup(shop_floor: ShopFloor, entities: Node2D, rack: TicketRack) -> void:
	_floor = shop_floor
	_entities = entities
	_rack = rack


func add_station(station: Station) -> void:
	_stations.append(station)


## Stops using the station (e.g. while it's picked up to move). It must be idle.
func remove_station(station: Station) -> void:
	_stations.erase(station)


## Takes the pawn on as staff; they start by idling.
func add_pawn(pawn: Pawn) -> void:
	pawn.path_finished.connect(_on_pawn_path_finished.bind(pawn))
	pawn.stop_reached.connect(_on_pawn_stop_reached.bind(pawn))
	pawn.work_started.connect(_on_pawn_work_started.bind(pawn))
	pawn.job_finished.connect(_on_pawn_job_finished.bind(pawn))
	pawn.work_progressed.connect(_on_pawn_work_progressed.bind(pawn))
	_pawns.append(pawn)
	_wait_then_wander(pawn)


func get_pawns() -> Array[Pawn]:
	return _pawns


func get_stations() -> Array[Station]:
	return _stations


func get_shop_jobs() -> Array[Job]:
	return _shop_jobs


func get_make_tickets() -> Array[Ticket]:
	return _rack.get_tickets(Ticket.Section.MAKE)


#region Handing out work

## Offers open work to idle pawns, priority 1 first across everyone, so a pawn with a job
## at 1 gets it before another pawn who has it at 3.
func assign_all() -> void:
	for max_priority: int in range(1, Pawn.LOWEST_PRIORITY + 1):
		for pawn: Pawn in _pawns:
			try_assign(pawn, max_priority)


## Gives the pawn work by their priorities: priority 1 first, ties going to the leftmost
## work type, and within a work type the first open job in Make-rack order (shop jobs
## last). Only priorities up to `max_priority` are considered. Returns false if there's
## nothing they can do.
func try_assign(pawn: Pawn, max_priority: int = Pawn.LOWEST_PRIORITY) -> bool:
	if pawn.has_job():
		return true
	var jobs: Array[Job] = _rack.get_open_jobs()
	for job: Job in _shop_jobs:
		if job.claimed_by == null:
			jobs.append(job)
	for priority: int in range(1, max_priority + 1):
		for work_type: WorkType in work_types:
			if pawn.get_priority(work_type) != priority:
				continue
			for job: Job in jobs:
				if job.task_type.work_type == work_type and job.task_type.get_behavior().try_start(pawn, job, self):
					return true
	return false


## Gives the pawn the job if they can walk to each stop and then the spot. Claims what the
## stops need and reserves the spot.
func start_job(pawn: Pawn, job: Job, spot: WorkSpot, stops: Array[JobStop]) -> bool:
	var from_cell: Vector2i = get_cell(pawn)
	var stop_paths: Array[PackedVector2Array] = []
	for stop: JobStop in stops:
		var path: PackedVector2Array = get_walk_path(from_cell, stop.cell)
		if path.is_empty():
			return false
		stop_paths.append(path)
		from_cell = stop.cell
	var work_path: PackedVector2Array = get_walk_path(from_cell, spot.station.get_work_cell(spot.index))
	if work_path.is_empty():
		return false
	spot.station.reserve(spot.index)
	job.station = spot.station
	job.spot = spot.index
	for stop: JobStop in stops:
		stop.claim()
	job.stops = stops
	pawn.assign_job(job, stop_paths, work_path, spot.station.get_work_target(spot.index))
	_rack.notify_job_state_changed()
	return true


## Sends the pawn to work at `spot` instead of where they were headed (e.g. straight to a
## box that was opened while they waited at the oven). Returns false if they can't get
## there.
func redirect(job: Job, pawn: Pawn, spot: WorkSpot) -> bool:
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), spot.station.get_work_cell(spot.index))
	if path.is_empty():
		return false
	job.station.release(job.spot)
	spot.station.reserve(spot.index)
	job.station = spot.station
	job.spot = spot.index
	pawn.redirect_work(path, spot.station.get_work_target(spot.index))
	assign_all()
	return true


## The pawn's job was pulled (e.g. its ticket went back to Wait or was cancelled): they
## drop what they carry and look for other work.
func withdraw_job(job: Job) -> void:
	var pawn: Pawn = job.claimed_by
	var waited_for: Item = _waiting_for.find_key(pawn)
	if waited_for != null:
		_waiting_for.erase(waited_for)
	var waited_item: OrderItem = _waiting_for_container.find_key(pawn)
	if waited_item != null:
		_waiting_for_container.erase(waited_item)
	pawn.drop_job()
	var held: Item = pawn.release_item()
	if held != null:
		_drop_on_floor(held, get_cell(pawn))
	_release(job)
	_rack.notify_job_state_changed()
	_work_or_wander(pawn)

#endregion


#region Queries for task behaviors

## Free spots on stations that do `task`, with the one already holding `own` first.
func get_free_spots(task: TaskType, own: Item) -> Array[WorkSpot]:
	var result: Array[WorkSpot] = []
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
				result.push_front(WorkSpot.new(station, index))
			else:
				result.append(WorkSpot.new(station, index))
	return result


## The free spot where the order item's container sits set out and ready, or null.
func get_container_spot(order_item: OrderItem) -> WorkSpot:
	var container: Item = order_item.container
	if container == null or container.station == null:
		return null
	if container.station.is_reserved(container.spot):
		return null
	return WorkSpot.new(container.station, container.spot)


## First storage station with an unclaimed unit of `kind`, or null.
func find_supply(kind: StorageKind) -> Station:
	for station: Station in _stations:
		if station.has_supply(kind):
			return station
	return null


## First storage station with an unclaimed free place for `kind`, or null.
func find_room(kind: StorageKind) -> Station:
	for station: Station in _stations:
		if station.has_room(kind):
			return station
	return null


## True if the item (or what it's in) sits on the spot.
func is_item_at(item: Item, spot: WorkSpot) -> bool:
	var outer: Item = item.get_outermost()
	return outer.station == spot.station and outer.spot == spot.index


## Where a pawn stands to pick up an item: its spot's work cell, or the floor cell it's on.
func get_pickup_cell(item: Item) -> Vector2i:
	var outer: Item = item.get_outermost()
	if outer.station != null:
		return outer.station.get_work_cell(outer.spot)
	return _floor.global_to_cell(outer.global_position)


func get_cell(node: Node2D) -> Vector2i:
	return _floor.global_to_cell(node.global_position)


## Walking path between floor cells, or empty if there's no way.
func get_walk_path(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	return _floor.get_path_points(from_cell, to_cell)


func spawn_item(texture: Texture2D) -> Item:
	var item := item_scene.instantiate() as Item
	_entities.add_child(item)
	item.set_texture(texture)
	return item

#endregion


#region Containers

## The pawn holds the order item's item and waits until its container is set out.
func wait_for_container(order_item: OrderItem, pawn: Pawn) -> void:
	_waiting_for_container[order_item] = pawn
	pawn.wait_at_stop(pawn.global_position + Vector2(0.0, -1.0))


## The order item's container is set out: a pawn waiting with its item takes it there.
func on_container_ready(order_item: OrderItem) -> void:
	var pawn: Pawn = _waiting_for_container.get(order_item)
	if pawn == null:
		return
	_waiting_for_container.erase(order_item)
	var job: Job = pawn.get_job()
	if job != null:
		job.task_type.get_behavior().on_picked_up(job, pawn, self)
	pawn.resume_job()

#endregion


#region Register

## A customer orders `recipes` at shop time `placed_at`: they wait at the register until a
## pawn takes the order (see order_taken).
func take_order(recipes: Array[Recipe], placed_at: int) -> void:
	var job := Job.new(take_order_task, null, null)
	job.recipes = recipes
	job.placed_at = placed_at
	_shop_jobs.append(job)
	waiting_orders_changed.emit(get_waiting_orders().size())
	assign_all()


## Orders waiting at the register to be taken, oldest first.
func get_waiting_orders() -> Array[Job]:
	var waiting: Array[Job] = []
	for job: Job in _shop_jobs:
		if not job.recipes.is_empty():
			waiting.append(job)
	return waiting


## The customer gave up before their order was taken: it's dropped, and a pawn taking it
## stops.
func drop_order(job: Job) -> void:
	_shop_jobs.erase(job)
	if job.claimed_by != null:
		withdraw_job(job)
	waiting_orders_changed.emit(get_waiting_orders().size())

#endregion


#region Leftovers

## Adds a job to take `item` to the garbage, unless there is one already.
func throw_out(item: Item) -> void:
	for job: Job in _shop_jobs:
		if job.target == item:
			return
	var job := Job.new(throw_out_task, null, null)
	job.target = item
	_shop_jobs.append(job)


## Throws out everything made for a cancelled order. Its claimed jobs must already be
## withdrawn, so anything being carried is on the floor; that goes too.
func throw_out_leftovers(ticket: Ticket) -> void:
	var leftovers: Array[Item] = []
	for order_item: OrderItem in ticket.order_items:
		for item: Item in [order_item.item, order_item.container]:
			if item == null or not is_instance_valid(item):
				continue
			var outer: Item = item.get_outermost()
			# A dough container set out for everyone stays.
			if outer.ingredient != null and outer.station != null:
				continue
			if not leftovers.has(outer):
				leftovers.append(outer)
	for child: Node in _entities.get_children():
		if child is Item and not leftovers.has(child):
			leftovers.append(child as Item)
	for item: Item in leftovers:
		throw_out(item)
	assign_all()

#endregion


#region Pawns working

func _on_pawn_path_finished(pawn: Pawn) -> void:
	_work_or_wander(pawn)


func _on_pawn_stop_reached(job: Job, pawn: Pawn) -> void:
	var stop: JobStop = job.stops.pop_front()
	var behavior: TaskBehavior = job.task_type.get_behavior()
	match stop.action:
		JobStop.Action.PICK_UP:
			var item: Item = behavior.get_carried(job)
			if item.busy:
				# Not ready yet (e.g. still baking): stand by until the station is done.
				_waiting_for[item] = pawn
				var look_at: Vector2 = item.get_outermost().global_position
				if stop.station != null and stop.spot >= 0:
					look_at = stop.station.get_work_target(stop.spot)
				pawn.wait_at_stop(look_at)
				return
			_pick_up(job, pawn)
		JobStop.Action.TAKE_SUPPLY:
			stop.station.take_supply()
			behavior.on_supply_taken(job, stop.station, pawn, self)
		_:
			behavior.on_stop_reached(job, stop, pawn, self)


func _pick_up(job: Job, pawn: Pawn) -> void:
	var behavior: TaskBehavior = job.task_type.get_behavior()
	var item: Item = behavior.get_carried(job)
	if item.container != null and item.container.ingredient != null:
		# Left in a dropped ingredient container: take it out.
		item.container.take_out(item)
	var from_station: Station = item.station
	if from_station != null:
		from_station.take_item(item.spot)
	pawn.hold_item(item)
	behavior.on_picked_up(job, pawn, self)
	if from_station != null:
		# The spot is free for other tickets now.
		assign_all()


func _on_pawn_work_started(job: Job, pawn: Pawn) -> void:
	job.task_type.get_behavior().on_work_started(job, pawn, self)


func _on_pawn_work_progressed(job: Job, progress: float, _pawn: Pawn) -> void:
	var frames: Array[Texture2D] = job.task_type.work_frames
	if frames.is_empty() or job.order_item == null or job.order_item.item == null:
		return
	# The work is split into one stretch with no overlay, then one per frame.
	var index: int = mini(int(progress * (frames.size() + 1)), frames.size()) - 1
	job.order_item.item.set_overlay(frames[index] if index >= 0 else null)


func _on_pawn_job_finished(job: Job, pawn: Pawn) -> void:
	var task: TaskType = job.task_type
	var behavior: TaskBehavior = task.get_behavior()
	behavior.on_finished(job, pawn, self)
	if task.ingredient_cost != 0.0:
		ingredients_used.emit(task.ingredient_cost)
	_release(job)
	if job.ticket != null:
		_rack.complete_job(job)
	else:
		_shop_jobs.erase(job)
		if not job.recipes.is_empty():
			waiting_orders_changed.emit(get_waiting_orders().size())
			order_taken.emit(job.recipes, job.placed_at)
		assign_all()
	behavior.after_finished(job, self)
	# A recipe step changes how the item looks (a baking pizza changes once it's done).
	# Prep steps run alongside the others and don't.
	var order_item: OrderItem = job.order_item
	if job.recipe_step and not task.prep and order_item.item != null:
		var look: Texture2D = order_item.recipe.get_stage_texture(order_item.step_index)
		if task.unattended:
			_work_unattended(order_item.item, task, look)
		else:
			order_item.item.set_texture(look)
	if job.ticket != null and job.ticket.ready:
		order_ready.emit(job.ticket)
	if not pawn.has_job():
		_work_or_wander(pawn)


## The station works the item on its own; when done it takes its new look and can be
## moved again.
func _work_unattended(item: Item, task: TaskType, done_texture: Texture2D) -> void:
	item.busy = true
	var station: Station = item.station
	var spot: int = item.spot
	var tween: Tween = create_tween()
	tween.tween_method(
		func(progress: float) -> void: station.show_work(spot, progress),
		0.0, 1.0, task.get_work_seconds()
	)
	await tween.finished
	station.hide_work(spot)
	if not is_instance_valid(item):
		return
	item.busy = false
	item.set_texture(done_texture)
	var waiting: Pawn = _waiting_for.get(item)
	if waiting != null:
		_waiting_for.erase(item)
		_pick_up(waiting.get_job(), waiting)
		if not _waiting_for_container.values().has(waiting):
			waiting.resume_job()
	assign_all()


func _release(job: Job) -> void:
	if job.station != null:
		job.station.release(job.spot)
		job.station = null
		job.spot = -1
	for stop: JobStop in job.stops:
		stop.release()
	job.stops.clear()


func _drop_on_floor(item: Item, cell: Vector2i) -> void:
	item.reparent(_entities, false)
	item.global_position = _floor.cell_to_global(cell)

#endregion


#region Idling

func _work_or_wander(pawn: Pawn) -> void:
	if not try_assign(pawn):
		_wait_then_wander(pawn)


func _wait_then_wander(pawn: Pawn) -> void:
	var wait: float = randf_range(idle_time_min, idle_time_max)
	if randf() < phone_chance:
		pawn.use_phone()
		wait = randf_range(phone_time_min, phone_time_max)
	get_tree().create_timer(wait).timeout.connect(_send_to_random_cell.bind(pawn))


func _send_to_random_cell(pawn: Pawn) -> void:
	if pawn.has_job():
		return
	var path: PackedVector2Array = get_walk_path(get_cell(pawn), _floor.get_random_walkable_cell())
	if path.size() < 2:
		_wait_then_wander(pawn)
		return
	pawn.follow_path(path)

#endregion
