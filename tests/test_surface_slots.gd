extends "res://tests/test_base.gd"
## Surface slots (see SlotGrid): at every facing, each spot's item sits on whole pixels in the
## middle of its cell (work areas are centered, with room all round), and items on a station
## draw back to front. A one-spot Boxing table has no room for the pizza cutter.

const BOXING := preload("res://resources/station_roles/boxing.tres")

const STATIONS := [
	"PrepTable", "BoxingTable", "PickupCounter", "EmptyDishesTable", "SmallOven", "Register",
	"DoughRack",
]


func _start() -> void:
	stop_random_orders()
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	for station_name: String in STATIONS:
		var station: Station = world.get_node("Entities/" + station_name)
		var start_facing: int = station.facing
		for facing: int in station.data.get_facings():
			station.facing = facing
			station.place(shop_floor)
			var problem: String = _check(station, shop_floor)
			if problem != "":
				fail("%s at facing %d: %s" % [station_name, facing, problem])
				return
		station.facing = start_facing
		station.place(shop_floor)
	var counter: Station = world.get_node("Entities/PickupCounter")
	counter.set_role(BOXING)
	if not counter.get_side_items().is_empty():
		fail("a one-spot Boxing table got a pizza cutter")
		return
	pass_test("items sit on whole pixels in the middle of their cells and draw back to front")


func _check(station: Station, shop_floor: ShopFloor) -> String:
	var items: Array[Item] = []
	for spot: int in station.get_spot_count():
		var at: Vector2 = station._item_positions[spot]
		if at != at.round():
			return "spot %d item at %s, not on a whole pixel" % [spot, at]
		var lift: Vector2 = station.data.item_offset - Vector2(0.0, station.data.spots[spot].item_height)
		var cell_middle: Vector2 = shop_floor.cell_to_global(
			station.data.get_item_cell(station.cell, station.facing, spot)
		) + lift
		if at != cell_middle:
			return "spot %d item moved off its cell's middle (%s, not %s)" % [spot, at, cell_middle]
		if station.get_item(spot) == null:
			var item: Item = work.spawn_item(null)
			station.put_item(spot, item)
			items.append(item)
	# Drawn back to front: each item's floor depth is at least the one before it.
	var last_y: float = -INF
	var problem: String = ""
	for child: Node in station._item_slot.get_children():
		var item := child as Item
		if item == null or item.spot < 0:
			continue
		var y: float = station._item_floor_y[item.spot]
		if y < last_y:
			problem = "spot %d draws over an item in front of it" % item.spot
		last_y = y
	for item: Item in items:
		station.take_item(item.spot)
		item.free()
	return problem
