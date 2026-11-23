extends "res://tests/test_base.gd"
## The Boxing role's pizza cutter: a Boxing table has one between its pizzas (on whole pixels, and
## it comes along when the table turns). Changing the role takes it away; setting Boxing
## again brings it back.

const CUTTER := preload("res://resources/items/pizza_cutter.tres")
const BOXING := preload("res://resources/station_roles/boxing.tres")
const PREP := preload("res://resources/station_roles/prep.tres")


func _start() -> void:
	stop_random_orders()
	var table: Station = world.get_node("Entities/BoxingTable")
	var cutters: Array[Item] = table.get_side_items()
	if cutters.size() != 1 or cutters[0]._sprite.texture != CUTTER.texture:
		fail("the boxing table should start with one cutter, has %d side items" % cutters.size())
		return
	var cutter: Item = cutters[0]
	if table._side_items[cutter] != Rect2i(7, 1, 2, 4):
		fail("the cutter isn't between the table's two pizza spots: %s" % table._side_items[cutter])
		return
	var shop_floor: ShopFloor = world.get_node("ShopFloor")
	var start_facing: int = table.facing
	for facing: int in table.data.get_facings():
		table.facing = facing
		table.place(shop_floor)
		if table.get_side_items() != [cutter] or cutter.global_position != cutter.global_position.round():
			fail("at facing %d the cutter wasn't carried along on whole pixels" % facing)
			return
	table.facing = start_facing
	table.place(shop_floor)

	table.set_role(PREP)
	if not table.get_side_items().is_empty():
		fail("the cutter stayed after the table was set to Prep")
		return
	table.set_role(BOXING)
	if table.get_side_items().size() != 1:
		fail("setting Boxing again didn't bring the cutter back")
		return
	pass_test("the Boxing table has a cutter between its pizzas, which goes and comes with the role")
