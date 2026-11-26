extends "res://tests/test_base.gd"
## Storage as stacks in surface slots: each stack takes its kind's footprint (cheese bag
## 6×4, others 6×6) and grows by its kind's stacked height up to the surface's clearance;
## stacks never overlap, and fill back first, lower shelf before top. Flat boxes are stored
## in bundles of 12, and taking one box leaves a partly used bundle on top.

const CHEESE := preload("res://resources/storage_kinds/cheese.tres")
const FLAT_BOX := preload("res://resources/storage_kinds/flat_box.tres")


func _start() -> void:
	stop_random_orders()
	var cheese_rack: Station = world.get_node("Entities/CheeseRack")
	# 16×8 slots per shelf: four 6×4 bags; 22 px / 5 px = 4 high; two shelves.
	if cheese_rack.get_capacity_for(CHEESE) != 32 or cheese_rack.get_stock(CHEESE) != 32:
		fail("the cheese rack holds %d/%d bags, not 32" % [
			cheese_rack.get_stock(CHEESE), cheese_rack.get_capacity_for(CHEESE)])
		return
	var problem: String = _check_stacks(cheese_rack)
	if problem != "":
		fail(problem)
		return

	# Taking bags empties the last stack set down first, which frees its slots.
	var first: StoredStack = cheese_rack._stacks[0]
	var last: StoredStack = cheese_rack._stacks[-1]
	if first.surface != 0 or last.surface != 1:
		fail("stacks didn't fill the lower shelf before the top one")
		return
	take_units(cheese_rack, CHEESE, 4)
	if cheese_rack._stacks.has(last) or cheese_rack.get_room_for(CHEESE) != 4:
		fail("an emptied stack didn't free its slots")
		return

	# 36 px / 1.8 px = 20 bundles of 12 on the pallet.
	var pallet: Station = world.get_node("Entities/BoxPallet")
	if pallet.get_stock(FLAT_BOX) != 240 or pallet._stacks.size() != 1:
		fail("the pallet holds %d flat boxes in %d stacks, not 240 in 1" % [
			pallet.get_stock(FLAT_BOX), pallet._stacks.size()])
		return
	take_units(pallet, FLAT_BOX, 1)
	var bundles: Array[int] = pallet._stacks[0].lefts
	if bundles.size() != 20 or bundles.back() != 11:
		fail("taking a flat box left %d bundles, the top with %d" % [bundles.size(), bundles.back()])
		return
	take_units(pallet, FLAT_BOX, 11)
	if pallet._stacks[0].lefts.size() != 19 or pallet.get_stock(FLAT_BOX) != 228:
		fail("using up a bundle didn't take it off the pallet")
		return
	pass_test("stacks fit their footprints and clearance, fill back first, bundles of 12")


## Every stack inside its surface, clear of the others, and no taller than it allows.
func _check_stacks(station: Station) -> String:
	var stacks: Array[StoredStack] = station._stacks
	for i: int in stacks.size():
		var stack: StoredStack = stacks[i]
		var surface: StorageSurface = station.data.storage_surfaces[stack.surface]
		if not surface.area.encloses(stack.area) or stack.area.size != stack.kind.slot_size:
			return "a stack at %s doesn't fit its surface or footprint" % stack.area
		if stack.lefts.size() * stack.kind.stack_height > surface.clearance + 0.01:
			return "a stack of %d is taller than its shelf" % stack.lefts.size()
		for j: int in range(i + 1, stacks.size()):
			if stacks[j].surface == stack.surface and stacks[j].area.intersects(stack.area):
				return "stacks at %s and %s overlap" % [stack.area, stacks[j].area]
	return ""
