extends "res://tests/test_base.gd"
## Tables standing in front of the walk-in's front walls, beside its front corner, are drawn
## over every wall piece they overlap: each table strip sorts after them. (A corner piece
## sorted as one at the corner used to cover the table beside it.)

const TABLE := preload("res://resources/stations/long_table.tres")

var _build: BuildMode


func _start() -> void:
	stop_random_orders()
	_build = world.get_node("BuildMode")
	var floor: ShopFloor = world.get_node("ShopFloor")
	for pawn: Pawn in work.get_pawns():
		pawn.process_mode = Node.PROCESS_MODE_DISABLED
		pawn.global_position = floor.cell_to_global(Vector2i(16, 0))
	world._set_build_mode(true)
	# The walk-in in the back corner, with room in front of it.
	var walk_in: Station = world.get_node("Entities/WalkIn")
	_build.pick_up(walk_in)
	_build.hover(Vector2i(0, 0))
	while walk_in.facing != 0:
		_build.rotate()
	if not _build.confirm():
		fail("the walk-in didn't fit in the back corner")
		return
	for station_name: String in ["BoxingTable", "BoxPallet", "BoxingTable2"]:
		_build.pick_up(world.get_node("Entities/" + station_name))
		_build.sell()
	# Along the front-right wall and along the front-left wall, each beside the front corner.
	var tables: Array[Station] = []
	for placement: Array in [[Vector2i(4, 3), 3], [Vector2i(3, 4), 0]]:
		_build.choose(TABLE)
		_build._ghost.facing = placement[1]
		_build.hover(placement[0])
		var table: Station = _build._ghost
		if not _build.confirm():
			fail("a table didn't fit at %s" % placement[0])
			return
		tables.append(table)
	_build.cancel()
	world._set_build_mode(false)

	var walls: Array[Sprite2D] = []
	walls.assign(walk_in._room._walls.get_children())
	for table: Station in tables:
		for strip: Sprite2D in table._strips.get_children():
			var from_x: float = strip.global_position.x
			var to_x: float = from_x + strip.region_rect.size.x
			for wall: Sprite2D in walls:
				var left: float = wall.global_position.x + wall.offset.x
				var width: float = wall.region_rect.size.x if wall.region_enabled else wall.texture.get_width()
				if left < to_x and left + width > from_x and wall.global_position.y >= strip.global_position.y:
					fail("a wall piece at %s sorts over the table at %s (strip at x %d)" % [
						wall.global_position, table.cell, from_x])
					return
	pass_test("tables beside the walk-in's front corner draw over its walls")
