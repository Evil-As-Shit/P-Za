class_name JobStop
extends RefCounted
## A place a pawn stops on the way to a job's work spot, and what they do there (pick
## something up, set something out...). Whatever it needs is claimed when the job is
## assigned, and handed back with release() if the pawn never gets there.

enum Action {
	## Pick up the job's item from where it is (a spot or the floor).
	PICK_UP,
	## Take one stored unit from a storage station.
	TAKE_SUPPLY,
	## Set the carried ingredient container out on a spot, and take a unit from it.
	SET_OUT,
	## Take a unit from an ingredient container set out on a spot.
	TAKE_UNIT,
	## Drop the carried empty container off at storage for empties.
	STORE_EMPTY,
	## Set the carried dirty dish down on a dish sink's dirty drainboard.
	DROP_DISH,
	## Take a clean dish off a dish sink's clean drainboard.
	TAKE_DISH,
	## Take a side item (e.g. an empty sauce bucket) off a station's side areas.
	TAKE_SIDE,
	## Set the carried side item out in a station's side areas.
	SET_SIDE,
	## Take a supply case off a delivery drop-off (see DockCases).
	TAKE_CASE,
}

var action: Action
## Where the pawn stands.
var cell: Vector2i
var station: Station = null
var spot: int = -1
## The ingredient container a unit is taken from (TAKE_UNIT), or the side item taken
## (TAKE_SIDE).
var container: Item = null
## The clean dish taken (TAKE_DISH), or the dish taken from storage that holds dishes
## (TAKE_SUPPLY; null for its top one).
var dish: Dish = null
## The supply case taken (TAKE_CASE).
var supply: SupplyItem = null
## The kind taken (TAKE_SUPPLY) or the kind of empty stored (STORE_EMPTY).
var kind: StorageKind = null


func _init(p_action: Action, p_cell: Vector2i) -> void:
	action = p_action
	cell = p_cell


static func pick_up(p_cell: Vector2i) -> JobStop:
	return JobStop.new(Action.PICK_UP, p_cell)


## Taking a unit of `p_kind` from storage: for storage that holds dishes, `p_dish` (or its
## top one).
static func take_supply(p_station: Station, p_kind: StorageKind, p_dish: Dish = null) -> JobStop:
	var stop := JobStop.new(Action.TAKE_SUPPLY, p_station.get_work_cell(0))
	stop.station = p_station
	stop.kind = p_kind
	stop.dish = p_dish
	return stop


static func set_out(p_station: Station, p_spot: int) -> JobStop:
	var stop := JobStop.new(Action.SET_OUT, p_station.get_work_cell(p_spot))
	stop.station = p_station
	stop.spot = p_spot
	return stop


static func take_unit(p_container: Item) -> JobStop:
	var stop := JobStop.new(
		Action.TAKE_UNIT, p_container.station.get_work_cell(p_container.spot)
	)
	stop.container = p_container
	return stop


static func store_empty(p_station: Station, p_kind: StorageKind, p_dish: Dish) -> JobStop:
	var stop := JobStop.new(Action.STORE_EMPTY, p_station.get_work_cell(0))
	stop.station = p_station
	stop.kind = p_kind
	stop.dish = p_dish
	return stop


static func drop_dish(p_sink: Station) -> JobStop:
	var stop := JobStop.new(
		Action.DROP_DISH, p_sink.get_work_cell(p_sink.data.dish_sink.dirty_spot)
	)
	stop.station = p_sink
	return stop


static func take_dish(p_sink: Station, p_dish: Dish) -> JobStop:
	var stop := JobStop.new(
		Action.TAKE_DISH, p_sink.get_work_cell(p_sink.data.dish_sink.clean_spot)
	)
	stop.station = p_sink
	stop.dish = p_dish
	return stop


## Taking `p_item` off its station's side areas, standing at `p_cell`.
static func take_side(p_item: Item, p_cell: Vector2i) -> JobStop:
	var stop := JobStop.new(Action.TAKE_SIDE, p_cell)
	stop.station = p_item.station
	stop.container = p_item
	return stop


## Setting the carried item out in `p_station`'s side areas, standing at `p_cell`.
static func set_side(p_station: Station, p_cell: Vector2i) -> JobStop:
	var stop := JobStop.new(Action.SET_SIDE, p_cell)
	stop.station = p_station
	return stop


## Taking a case of `p_supply` off a delivery drop-off.
static func take_case(p_station: Station, p_supply: SupplyItem) -> JobStop:
	var stop := JobStop.new(Action.TAKE_CASE, p_station.get_work_cell(0))
	stop.station = p_station
	stop.supply = p_supply
	return stop


## Claims what the stop needs.
func claim() -> void:
	match action:
		Action.TAKE_SUPPLY:
			station.claim_supply(kind)
		Action.SET_OUT:
			station.reserve(spot)
		Action.TAKE_UNIT:
			container.claim_unit()
		Action.STORE_EMPTY:
			station.claim_room(kind, dish)
		Action.DROP_DISH:
			station.get_dish_boards().claim_dirty_room()
		Action.TAKE_DISH:
			station.get_dish_boards().claim_clean(dish)
		Action.TAKE_CASE:
			station.get_dock_cases().claim(supply)


## Hands back what claim() took, for a stop the pawn won't make.
func release() -> void:
	match action:
		Action.TAKE_SUPPLY:
			station.unclaim_supply(kind)
		Action.SET_OUT:
			station.release(spot)
		Action.TAKE_UNIT:
			if is_instance_valid(container):
				container.unclaim_unit()
		Action.STORE_EMPTY:
			station.unclaim_room(kind, dish)
		Action.DROP_DISH:
			station.get_dish_boards().unclaim_dirty_room()
		Action.TAKE_DISH:
			station.get_dish_boards().unclaim_clean(dish)
		Action.TAKE_CASE:
			station.get_dock_cases().unclaim(supply)
