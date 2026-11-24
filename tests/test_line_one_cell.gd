extends "res://tests/test_base.gd"
## A register line only one cell long: the second customer stands on the register cell
## behind the first, and once the first order is taken they're at the register, so theirs
## is taken too.

var _lobby: Lobby


func _start() -> void:
	stop_random_orders()
	timeout_frames = 60 * 120
	clock.set_speed(6)
	_lobby = world.get_node("Lobby")
	_lobby.max_line = 1
	if _lobby.get_line_cells().size() != 1:
		fail("the line has %d cells, expected 1" % _lobby.get_line_cells().size())
		return
	# Admitted past the line limit, so both stand on the one cell.
	for i: int in 2:
		var recipes: Array[Recipe] = [world.debug_recipe]
		var job: Job = work.take_order(recipes, rack.now_minutes, work.quote_order(recipes), true)
		_lobby.admit(job)


func _step() -> void:
	if rack.get_ticket_count() < 2:
		return
	pass_test("both orders taken from a one-cell line")
