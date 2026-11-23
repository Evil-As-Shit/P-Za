extends "res://tests/test_base.gd"
## Surface slots (see SlotGrid): at every facing, on the stations with work areas, each spot's
## item sits on whole pixels, nudged from its cell's middle toward the pawn who works it, and
## items on a station draw back to front. Stations without work areas keep their items in the
## middle of the cell.

const CONFIGURED := ["PrepTable", "BoxingTable", "PickupCounter", "EmptyDoughTable"]
const UNCHANGED := ["SmallOven", "Register", "DoughRack"]


func _start() -> void:
	stop_random_orders()
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	for station_name: String in CONFIGURED + UNCHANGED:
		var station: Station = world.get_node("Entities/" + station_name)
		var start_facing: int = station.facing
		for facing: int in station.data.get_facings():
			station.facing = facing
			station.place(shop_floor)
			var problem: String = _check(station, shop_floor, CONFIGURED.has(station_name))
			if problem != "":
				fail("%s at facing %d: %s" % [station_name, facing, problem])
				return
		station.facing = start_facing
		station.place(shop_floor)
	pass_test("items sit on whole pixels in their work areas and draw back to front")


func _check(station: Station, shop_floor: ShopFloor, configured: bool) -> String:
	var items: Array[Item] = []
	for spot: int in station.get_spot_count():
		var at: Vector2 = station._item_positions[spot]
		if at != at.round():
			return "spot %d item at %s, not on a whole pixel" % [spot, at]
		var lift: Vector2 = station.data.item_offset - Vector2(0.0, station.data.spots[spot].item_height)
		var cell_middle: Vector2 = shop_floor.cell_to_global(
			station.data.get_item_cell(station.cell, station.facing, spot)
		) + lift
		# Compared on the floor, where the pawn stands.
		var pawn_at: Vector2 = shop_floor.cell_to_global(station.get_work_cell(spot)) + lift
		if configured:
			var nearer: float = cell_middle.distance_to(pawn_at) - at.distance_to(pawn_at)
			if nearer <= 0.0 or at.distance_to(cell_middle) > 5.0:
				return "spot %d item at %s isn't nudged toward its pawn from %s" % [spot, at, cell_middle]
		elif at != cell_middle:
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
