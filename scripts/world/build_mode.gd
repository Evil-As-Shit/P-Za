class_name BuildMode
extends Node
## Lets the player place new stations and move existing ones. While active, a chosen
## station follows the mouse as a ghost, green where it fits and red where it doesn't. A
## click places it (and keeps the tool for another), R turns it, right-click or Esc lets go.
## Clicking a station picks it up to move (with what's on it, even if it's in use), or to
## sell with Delete. A walk-in carries the stations inside it along, and can only be sold
## empty. Building is free for now, and selling pays nothing back.

## A new station was placed. The owner sets it up (blocks its cells, puts it to work).
signal station_built(station: Station)
## An existing station was picked up. The owner stops using it until move_finished.
signal move_started(station: Station)
## A picked-up station was put down (at its new place, or back where it was).
signal move_finished(station: Station)
## A picked-up station was sold. It's gone; anything stored on it goes with it.
signal station_sold(station: Station)
## A station was picked up or let go, so selling became possible or not (a station with
## something on its spots can be moved but not sold).
signal holding_changed(can_sell: bool)

@export var station_scene: PackedScene
## Stations the player can build, in menu order.
@export var catalog: Array[StationData] = []

var active: bool = false

var _floor: ShopFloor
var _entities: Node2D
var _stations: Array[Station] = []
var _pawns: Array[Pawn] = []
## Returns the items lying on the floor (Array[Item]), which can't be built over.
var _floor_items: Callable
## The station following the mouse (new, or picked up to move), or null.
var _ghost: Station = null
## True if the ghost is an existing station being moved.
var _moving: bool = false
var _move_from_cell: Vector2i
var _move_from_facing: int
## Stations inside a walk-in being moved, which come along, and where each was (cell x,
## cell y, facing).
var _contents: Array[Station] = []
var _contents_from: Dictionary[Station, Vector3i] = {}
var _fits: bool = false


## `stations` and `pawns` are the owner's live lists, used to check placements, and
## `floor_items` returns the items lying on the floor.
func setup(
	shop_floor: ShopFloor, entities: Node2D, stations: Array[Station], pawns: Array[Pawn],
	floor_items: Callable
) -> void:
	_floor = shop_floor
	_entities = entities
	_stations = stations
	_pawns = pawns
	_floor_items = floor_items


func set_active(on: bool) -> void:
	if not on:
		cancel()
	active = on


## Starts placing a new station of this type.
func choose(data: StationData) -> void:
	cancel()
	var station := station_scene.instantiate() as Station
	station.data = data
	station.facing = data.default_facing
	station.role = data.default_role
	_entities.add_child(station)
	_ghost = station
	_moving = false
	hover(_mouse_cell())


## Picks an existing station up to move it, with whatever is on it (and, for a walk-in,
## the stations inside it). Pawns using them stop until they're put down (see
## WorkManager.remove_station()). Returns false if there's none.
func pick_up(station: Station) -> bool:
	if station == null:
		return false
	cancel()
	_ghost = station
	_moving = true
	_move_from_cell = station.cell
	_move_from_facing = station.facing
	_contents.clear()
	_contents_from.clear()
	if station.data.walk_in != null:
		for other: Station in _stations:
			if other != station and other.get_footprint_cells().all(station.is_room_cell):
				_contents.append(other)
				_contents_from[other] = Vector3i(other.cell.x, other.cell.y, other.facing)
	move_started.emit(station)
	for content: Station in _contents:
		move_started.emit(content)
	holding_changed.emit(_can_sell())
	hover(station.cell)
	return true


## Sells the picked-up station. Building is free for now, so selling pays nothing back.
## Returns false if no existing station is picked up, if something sits on it (orders
## would lose what they're made in, e.g. an open pizza box), or if it's a walk-in with
## anything inside.
func sell() -> bool:
	if _ghost == null or not _moving or not _can_sell():
		return false
	var station: Station = _ghost
	_ghost = null
	_moving = false
	station_sold.emit(station)
	station.queue_free()
	holding_changed.emit(false)
	return true


func _can_sell() -> bool:
	return _ghost != null and not _ghost.has_items() and _contents.is_empty()


## Moves the ghost (and what's inside it) to `cell` and checks whether it fits there.
func hover(cell: Vector2i) -> void:
	if _ghost == null:
		return
	_ghost.cell = cell
	_ghost.place(_floor)
	_carry_contents()
	_fits = _fits_here(_group())
	for station: Station in _group():
		station.show_as_ghost(_fits)


## Turns the ghost to its next facing (one it has art for, or mirrored art).
func rotate() -> void:
	if _ghost == null:
		return
	var facings: Array[int] = _ghost.data.get_facings()
	if facings.size() < 2:
		return
	_ghost.facing = facings[(facings.find(_ghost.facing) + 1) % facings.size()]
	hover(_ghost.cell)


## Puts the ghost down if it fits. A new station is replaced by another ghost of the same
## type, ready to place again. Returns false if it doesn't fit.
func confirm() -> bool:
	if _ghost == null or not _fits:
		return false
	var group: Array[Station] = _group()
	_ghost = null
	_contents.clear()
	for station: Station in group:
		station.end_ghost()
	if _moving:
		_moving = false
		# The walk-in first, so what's inside knows it's in one.
		for station: Station in group:
			move_finished.emit(station)
		holding_changed.emit(false)
		return true
	var built: Station = group[0]
	station_built.emit(built)
	choose(built.data)
	_ghost.facing = built.facing
	hover(built.cell)
	return true


## Lets go of the ghost: a new one is discarded, a moved one (and what's inside it) goes
## back where it was.
func cancel() -> void:
	if _ghost == null:
		return
	var group: Array[Station] = _group()
	var station: Station = _ghost
	_ghost = null
	_contents.clear()
	if _moving:
		_moving = false
		station.cell = _move_from_cell
		station.facing = _move_from_facing
		station.place(_floor)
		for content: Station in group.slice(1):
			var from: Vector3i = _contents_from[content]
			content.cell = Vector2i(from.x, from.y)
			content.facing = from.z
			content.place(_floor)
		for each: Station in group:
			each.end_ghost()
			move_finished.emit(each)
		holding_changed.emit(false)
	else:
		station.queue_free()


func has_ghost() -> bool:
	return _ghost != null


## True if the ghost fits where it is now.
func fits() -> bool:
	return _ghost != null and _fits


## Handles build input while active. Returns true if the event was used.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if _ghost != null and _mouse_cell() != _ghost.cell:
			hover(_mouse_cell())
		return false
	if event.is_action_pressed(&"rotate_station"):
		rotate()
		return true
	if event.is_action_pressed(&"sell_station"):
		return sell()
	if event.is_action_pressed(&"ui_cancel"):
		if _ghost != null:
			cancel()
			return true
		return false
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return false
	if click.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		return true
	if click.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _ghost != null:
		confirm()
	else:
		var station: Station = _station_under_mouse()
		if station != null:
			pick_up(station)
	return true


## The ghost, then what's inside it.
func _group() -> Array[Station]:
	var group: Array[Station] = [_ghost]
	group.append_array(_contents)
	return group


## Moves and turns what's inside a moved walk-in along with it, keeping the layout.
func _carry_contents() -> void:
	var turn: int = _ghost.facing - _move_from_facing
	for content: Station in _contents:
		var from: Vector3i = _contents_from[content]
		var offset: Vector2i = StationData.rotate_offset(
			Vector2i(from.x, from.y) - _move_from_cell, turn
		)
		content.cell = _ghost.cell + offset
		content.facing = posmod(from.z + turn, 4)
		content.place(_floor)


## True if the stations (a ghost, then what's inside it) fit where they are: on free floor,
## with their work spots free, not covering anyone's work spot, not straddling a walk-in's
## wall, and leaving every work spot and pawn able to reach the others.
func _fits_here(group: Array[Station]) -> bool:
	var footprint: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	var access: Array[Vector2i] = []
	var edges: Array[Vector4i] = []
	var rooms: Array[Station] = []
	var room_floor: Array[Vector2i] = []
	for station: Station in group:
		if not station.data.get_facings().has(station.facing):
			return false
		footprint.append_array(station.get_footprint_cells())
		blocked.append_array(station.get_blocked_cells())
		access.append_array(station.get_work_cells())
		edges.append_array(station.get_wall_edges())
		if station.data.walk_in != null:
			rooms.append(station)
			room_floor.append_array(station.get_footprint_cells())
	var pawn_cells: Array[Vector2i] = []
	for pawn: Pawn in _pawns:
		if not pawn.is_away():
			pawn_cells.append(_floor.global_to_cell(pawn.global_position))
	for cell: Vector2i in footprint:
		if not _floor.has_floor(cell) or not _floor.is_walkable(cell):
			return false
	# Pawns and things set down on the floor would be shut in under it.
	for item: Item in _floor_items.call():
		pawn_cells.append(_floor.global_to_cell(item.global_position))
	for cell: Vector2i in blocked:
		if pawn_cells.has(cell):
			return false
	for cell: Vector2i in access:
		if blocked.has(cell) or not _floor.is_walkable(cell):
			return false
	var others: Array[Vector2i] = []
	for other: Station in _stations:
		if other.data.walk_in != null:
			rooms.append(other)
			for cell: Vector2i in room_floor:
				if other.is_room_cell(cell):
					return false
			continue
		for cell: Vector2i in other.get_work_cells():
			if blocked.has(cell):
				return false
			others.append(cell)
		# A walk-in can't be put down over what's already there.
		for cell: Vector2i in other.get_footprint_cells() + other.get_work_cells():
			if room_floor.has(cell):
				return false
	# Each station stands (with its work spots) wholly inside one walk-in, or outside them all.
	for station: Station in group:
		if station.data.walk_in == null and not _inside_one_or_none(station, rooms):
			return false

	# Try it: put it up and check everything can still be reached.
	for cell: Vector2i in blocked:
		_floor.set_cell_blocked(cell, true)
	for edge: Vector4i in edges:
		_floor.set_edge_blocked(Vector2i(edge.x, edge.y), Vector2i(edge.z, edge.w), true)
	var targets: Array[Vector2i] = access + others + pawn_cells
	for cell: Vector2i in room_floor:
		if not blocked.has(cell):
			targets.append(cell)
	var reachable: bool = true
	for cell: Vector2i in targets:
		if _floor.get_path_points(targets[0], cell).is_empty():
			reachable = false
			break
	for cell: Vector2i in blocked:
		_floor.set_cell_blocked(cell, false)
	for edge: Vector4i in edges:
		_floor.set_edge_blocked(Vector2i(edge.x, edge.y), Vector2i(edge.z, edge.w), false)
	return reachable


static func _inside_one_or_none(station: Station, rooms: Array[Station]) -> bool:
	var cells: Array[Vector2i] = station.get_footprint_cells() + station.get_work_cells()
	for room: Station in rooms:
		var inside: int = cells.filter(room.is_room_cell).size()
		if inside == cells.size():
			return true
		if inside > 0:
			return false
	return true


func _mouse_cell() -> Vector2i:
	return _floor.global_to_cell(_floor.get_global_mouse_position())


## The station under the mouse, or null. Checks a little below too, since tabletops are
## drawn above their floor cells. A station inside a walk-in comes before the walk-in.
func _station_under_mouse() -> Station:
	var point: Vector2 = _floor.get_global_mouse_position()
	for rooms: bool in [false, true]:
		for lift: float in [0.0, 16.0]:
			var cell: Vector2i = _floor.global_to_cell(point + Vector2(0.0, lift))
			for station: Station in _stations:
				if (station.data.walk_in != null) == rooms \
						and station.get_footprint_cells().has(cell):
					return station
	return null
