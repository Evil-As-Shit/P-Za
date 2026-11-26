extends "res://tests/test_base.gd"
## Storage filters: a newly built storage station allows nothing. The station panel's
## Allow all lets in every kind the station can keep there (not dough or cheese outside a
## walk-in), and a group with only some kinds allowed shows part-ticked. Allowed kinds share a
## rack pile by pile, each counted on its own, and an emptied pile is free for any allowed
## kind again. Unticking Boxes on the box rack sends newly folded boxes to another rack that
## allows them.

const PALLET := preload("res://resources/stations/box_pallet.tres")
const BOX := preload("res://resources/storage_kinds/box.tres")
const FLAT_BOX := preload("res://resources/storage_kinds/flat_box.tres")
const CHEESE := preload("res://resources/storage_kinds/cheese.tres")
const DOUGH := preload("res://resources/storage_kinds/dough.tres")
const CLEAN := preload("res://resources/storage_kinds/clean_dishes.tres")
const DISH := preload("res://resources/items/dough_container_dish.tres")

var _box_rack: Station
var _other_rack: Station
## Boxes the box rack may still get after Boxes is unticked: those already promised to it.
var _box_rack_most: int = 0


func _start() -> void:
	stop_random_orders()
	clock.set_speed(6)
	_box_rack = world.get_node("Entities/BoxRack")
	_other_rack = world.get_node("Entities/CleanDishesRack")

	# A new pallet (Storage by default) allows nothing.
	var build: BuildMode = world.get_node("BuildMode")
	world._set_build_mode(true)
	build.choose(PALLET)
	var ghost: Station = build._ghost
	if not ghost.is_storage() or not ghost.allowed_kinds.is_empty() or ghost.has_room(FLAT_BOX):
		fail("a new storage station doesn't start with nothing allowed")
		return
	build.cancel()
	world._set_build_mode(false)

	# Allow all from the panel: everything the rack can keep outside a walk-in.
	world._select(_other_rack)
	var panel: StationPanel = world._hud._station_panel
	if not panel._filter.visible:
		fail("the station panel doesn't show the storage filter")
		return
	panel._request_all(true)
	for kind: StorageKind in [BOX, CLEAN]:
		if not _other_rack.allows(kind):
			fail("Allow all didn't let %s in" % kind.display_name)
			return
	if _other_rack.allows(DOUGH) or _other_rack.allows(CHEESE):
		fail("a rack outside the walk-in allows dough or cheese")
		return

	# The walk-in's dough rack: dough allowed, cheese not.
	world._select(world.get_node("Entities/DoughRack"))
	var ingredients: TreeItem = _heading(panel, "Ingredients")
	if ingredients == null or not ingredients.is_indeterminate(0):
		fail("Ingredients (dough allowed, cheese not) isn't shown part-ticked")
		return
	world._select(null)

	# Kinds share the rack pile by pile: a clean dish takes a pile, boxes still fit in the
	# rest, each kind is counted on its own, and an emptied pile is free for boxes again.
	var box_room: int = _other_rack.get_room_for(BOX)
	if box_room <= 0 or not _other_rack.has_room(CLEAN):
		fail("an empty rack allowing clean dishes and boxes has no room for them")
		return
	_other_rack.claim_room(CLEAN, DISH)
	_other_rack.add_stock(CLEAN, -1, DISH)
	_other_rack.claim_room(BOX)
	_other_rack.add_stock(BOX)
	if not _other_rack.has_room(BOX) or _other_rack.get_room_for(BOX) >= box_room - 1:
		fail("a clean dish didn't take a pile of its own, or boxes have no room beside it")
		return
	if _other_rack.get_stock(CLEAN) != 1 or _other_rack.get_stock(BOX) != 1:
		fail("the rack holds %d clean dishes and %d boxes, not 1 and 1" % [
			_other_rack.get_stock(CLEAN), _other_rack.get_stock(BOX)])
		return
	take_units(_other_rack, BOX, 1)
	if _other_rack.get_top_dish(CLEAN) != DISH:
		fail("taking a box took the clean dish")
		return
	take_units(_other_rack, CLEAN, 1)
	if _other_rack.get_room_for(BOX) != box_room or _other_rack.get_stock() != 0:
		fail("the emptied rack didn't free its slots for boxes again (room %d, was %d; stock %d)" % [
			_other_rack.get_room_for(BOX), box_room, _other_rack.get_stock()])
		return

	# Boxes go only to the other rack now.
	world._on_storage_filter_change_requested(_other_rack, [CLEAN] as Array[StorageKind], false)
	world._on_storage_filter_change_requested(_box_rack, [BOX] as Array[StorageKind], false)
	if _box_rack.has_room(BOX):
		fail("the box rack takes boxes with Boxes unticked")
		return
	# Pawns already bringing a box there keep their place.
	_box_rack_most = _box_rack.get_stock() + room_claimed(_box_rack)


func _step() -> void:
	if _box_rack.get_stock() > _box_rack_most:
		fail("a folded box went to the box rack after Boxes was unticked")
		return
	if _other_rack.get_stock(BOX) >= 2:
		pass_test("filters: new allows nothing, Allow all, part-ticked groups, boxes rerouted")


## The filter's group row named `text`, or null.
func _heading(panel: StationPanel, text: String) -> TreeItem:
	for heading: TreeItem in panel._kinds.get_root().get_children():
		if heading.get_text(0) == text:
			return heading
	return null
