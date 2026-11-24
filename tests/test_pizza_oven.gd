extends "res://tests/test_base.gd"
## The 2x2 pizza oven (the starting shop's ovens): it bakes two pizzas side by side (its
## cover shows the lit window while baking), and the order still goes out.

const PIZZA_OVEN := preload("res://resources/stations/pizza_oven.tres")

var _oven: Station
var _ticket: Ticket
var _saw_lit: bool = false
var _saw_both: bool = false


func _start() -> void:
	stop_random_orders()
	if PIZZA_OVEN.get_facings() != [0, 1, 2, 3]:
		fail("pizza oven can face %s, expected all four" % [PIZZA_OVEN.get_facings()])
		return
	# Only one oven, so both pizzas bake in it.
	world._set_build_mode(true)
	var build: BuildMode = world.get_node("BuildMode")
	if not build.pick_up(world.get_node("Entities/PizzaOven2")) or not build.sell():
		fail("couldn't sell the second pizza oven")
		return
	world._set_build_mode(false)
	_oven = world.get_node("Entities/PizzaOven")
	if _oven.data != PIZZA_OVEN or _oven.get_footprint_cells().size() != 4:
		fail("the starting oven isn't a 2x2 pizza oven")
		return

	clock.set_speed(6)
	rack.patience_minutes = 100000
	rack.patience_past_quote = 100000
	_ticket = order_pizzas(2)
	rack.ticket_completed.connect(_on_completed)


func _step() -> void:
	if _oven == null:
		return
	var lit: Texture2D = PIZZA_OVEN.get_cover_texture(_oven.facing, true)
	var cover: Sprite2D = _oven._cover
	if _oven.is_working():
		if cover.texture != lit:
			fail("the oven was baking but its cover wasn't lit")
			return
		_saw_lit = true
	elif cover.texture == lit:
		fail("the oven's cover stayed lit with nothing baking")
		return
	if _oven.get_item(0) != null and _oven.get_item(1) != null:
		_saw_both = true


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	if not _saw_lit:
		fail("never saw the pizza oven baking")
		return
	if not _saw_both:
		fail("never saw two pizzas in the pizza oven at once")
		return
	pass_test("two pizzas baked side by side in the pizza oven at facing %d" % _oven.facing)
