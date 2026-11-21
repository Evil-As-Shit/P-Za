class_name BuildMode
extends Node
## Lets the player place new stations and move existing ones. While active, a chosen
## station follows the mouse as a ghost, green where it fits and red where it doesn't. A
## click places it (and keeps the tool for another), R turns it, right-click or Esc lets go.
## Clicking an idle station picks it up to move, or to sell with Delete. Building is free
## for now, and selling pays nothing back.

## A new station was placed. The owner sets it up (blocks its cells, puts it to work).
signal station_built(station: Station)
## An existing station was picked up. The owner stops using it until move_finished.
signal move_started(station: Station)
## A picked-up station was put down (at its new place, or back where it was).
signal move_finished(station: Station)
## A picked-up station was sold. It's gone; anything stored on it goes with it.
signal station_sold(station: Station)
## A station was picked up or let go, so selling became possible or not.
signal holding_changed(holding_existing: bool)

@export var station_scene: PackedScene
## Stations the player can build, in menu order.
@export var catalog: Array[StationData] = []

var active: bool = false

var _floor: ShopFloor
var _entities: Node2D
var _stations: Array[Station] = []
var _pawns: Array[Pawn] = []
## The station following the mouse (new, or picked up to move), or null.
var _ghost: Station = null
## True if the ghost is an existing station being moved.
var _moving: bool = false
var _move_from_cell: Vector2i
var _move_from_facing: int
var _fits: bool = false


## `stations` and `pawns` are the owner's live lists, used to check placements.
func setup(
	shop_floor: ShopFloor, entities: Node2D, stations: Array[Station], pawns: Array[Pawn]
) -> void:
	_floor = shop_floor
	_entities = entities
	_stations = stations
	_pawns = pawns


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
	_entities.add_child(station)
	_ghost = station
	_moving = false
	hover(_mouse_cell())


## Picks an existing station up to move it. Returns false if it's busy.
func pick_up(station: Station) -> bool:
	if not station.is_idle():
		return false
	cancel()
	_ghost = station
	_moving = true
	_move_from_cell = station.cell
	_move_from_facing = station.facing
	move_started.emit(station)
	holding_changed.emit(true)
	hover(station.cell)
	return true


## Sells the picked-up station. Building is free for now, so selling pays nothing back.
## Returns false if no existing station is picked up.
func sell() -> bool:
	if _ghost == null or not _moving:
		return false
	var station: Station = _ghost
	_ghost = null
	_moving = false
	station_sold.emit(station)
	station.queue_free()
	holding_changed.emit(false)
	return true


## Moves the ghost to `cell` and checks whether it fits there.
func hover(cell: Vector2i) -> void:
	if _ghost == null:
		return
	_ghost.cell = cell
	_ghost.place(_floor)
	_fits = _fits_here(_ghost)
	_ghost.show_as_ghost(_fits)


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
	var station: Station = _ghost
	_ghost = null
	station.end_ghost()
	if _moving:
		_moving = false
		move_finished.emit(station)
		holding_changed.emit(false)
		return true
	station_built.emit(station)
	choose(station.data)
	_ghost.facing = station.facing
	hover(station.cell)
	return true


## Lets go of the ghost: a new one is discarded, a moved one goes back where it was.
func cancel() -> void:
	if _ghost == null:
		return
	var station: Station = _ghost
	_ghost = null
	if _moving:
		_moving = false
		station.cell = _move_from_cell
		station.facing = _move_from_facing
		station.place(_floor)
		station.end_ghost()
		move_finished.emit(station)
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


## True if the station fits where it is: on free floor, with its work spots free, not
## covering anyone's work spot, and leaving every work spot and pawn able to reach the
## others.
func _fits_here(station: Station) -> bool:
	var footprint: Array[Vector2i] = station.get_footprint_cells()
	var pawn_cells: Array[Vector2i] = []
	for pawn: Pawn in _pawns:
		pawn_cells.append(_floor.global_to_cell(pawn.global_position))
	for cell: Vector2i in footprint:
		if not _floor.has_floor(cell) or not _floor.is_walkable(cell) or pawn_cells.has(cell):
			return false
	var own_work_cells: Array[Vector2i] = station.get_work_cells()
	for cell: Vector2i in own_work_cells:
		if footprint.has(cell) or not _floor.is_walkable(cell):
			return false
	var others: Array[Vector2i] = []
	for other: Station in _stations:
		for cell: Vector2i in other.get_work_cells():
			if footprint.has(cell):
				return false
			others.append(cell)
	# Try it: block the footprint and check everything can still be reached.
	for cell: Vector2i in footprint:
		_floor.set_cell_blocked(cell, true)
	var hub: Vector2i = own_work_cells[0]
	var reachable: bool = true
	for cell: Vector2i in own_work_cells + others + pawn_cells:
		if _floor.get_path_points(hub, cell).is_empty():
			reachable = false
			break
	for cell: Vector2i in footprint:
		_floor.set_cell_blocked(cell, false)
	return reachable


func _mouse_cell() -> Vector2i:
	return _floor.global_to_cell(_floor.get_global_mouse_position())


## The station under the mouse, or null. Checks a little below too, since tabletops are
## drawn above their floor cells.
func _station_under_mouse() -> Station:
	var point: Vector2 = _floor.get_global_mouse_position()
	for lift: float in [0.0, 16.0]:
		var cell: Vector2i = _floor.global_to_cell(point + Vector2(0.0, lift))
		for station: Station in _stations:
			if station.get_footprint_cells().has(cell):
				return station
	return null
