extends "res://tests/test_base.gd"
## The build menu: every buildable station has a category and a tile with its sprite, the
## first category shows at the start, and picking another shows only its tiles.


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var build: BuildMode = world.get_node("BuildMode")
	var panel: BuildPanel = hud.get_node("BuildPanel")
	world._set_build_mode(true)

	for data: StationData in build.catalog:
		if data.build_category == null:
			fail("%s has no build category" % data.display_name)
			return
		var tile: BuildTile = panel._buttons_by_data.get(data)
		if tile == null or tile.get_node("%Art").texture == null:
			fail("%s has no tile with a sprite" % data.display_name)
			return

	var categories: Array[Node] = panel.get_node("%Categories").get_children()
	if categories.size() < 2:
		fail("only %d build categories" % categories.size())
		return
	var first: StationData = build.catalog[0]
	if not panel._buttons_by_data[first].is_visible_in_tree():
		fail("the first category isn't shown at the start")
		return
	var second: Button = categories[1]
	second.button_pressed = true
	if panel._buttons_by_data[first].is_visible_in_tree():
		fail("picking another category didn't switch the tiles")
		return
	pass_test("build menu lists every station by category with its sprite")
