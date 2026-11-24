extends "res://tests/test_base.gd"
## The lobby: an inner wall stands between it and the kitchen (pawns can't cross it), the
## register and pickup counter are worked from the kitchen side, the lobby is still reached
## through the staff door, and idle pawns don't wander into it.

const LOBBY_TILE := Vector2i(1, 0)


func _start() -> void:
	stop_random_orders()
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	var walls: ShopWalls = world.get_node("Entities/Walls")
	if walls.inner_walls.is_empty():
		fail("no inner walls")
		return
	for wall: Vector3i in walls.inner_walls:
		var cell := Vector2i(wall.x, wall.y)
		var across: Vector2i = cell + ShopWalls.SIDE_STEP[wall.z]
		if not shop_floor.is_edge_blocked(cell, across):
			fail("pawns can cross the inner wall between %s and %s" % [cell, across])
			return

	var lobby: Array[Vector2i] = []
	for cell: Vector2i in shop_floor.get_used_cells():
		if shop_floor.get_cell_atlas_coords(cell) == LOBBY_TILE:
			lobby.append(cell)
	if lobby.is_empty():
		fail("no lobby floor")
		return
	for path: String in ["Entities/Register", "Entities/PickupCounter"]:
		var station: Station = world.get_node(path)
		for cell: Vector2i in station.get_work_cells():
			if lobby.has(cell):
				fail("%s is worked from the lobby" % station.name)
				return
		# Its lobby side is open (a customer would stand there).
		var front: Vector2i = station.cell + Vector2i(0, 1)
		if not lobby.has(front) or shop_floor.is_edge_blocked(station.cell, front):
			fail("%s isn't open to the lobby" % station.name)
			return

	var kitchen_cell: Vector2i = (world.get_node("Entities/Register") as Station).get_work_cells()[0]
	if shop_floor.get_path_points(kitchen_cell, lobby[0]).is_empty():
		fail("the lobby can't be reached from the kitchen")
		return
	for i: int in 500:
		if lobby.has(shop_floor.get_random_walkable_cell()):
			fail("idle pawns can wander into the lobby")
			return
	pass_test("inner wall up, counters face the kitchen, lobby reachable but not wandered into")
