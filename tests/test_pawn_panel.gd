extends "res://tests/test_base.gd"
## Pawn panel: clicking a pawn shows their skills (level and practice to the next level);
## clicking empty floor hides it.

const CUTTING := preload("res://resources/work_types/cutting.tres")


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var pawn: Pawn = work.get_pawns()[0]
	# Pawns start on random cells, maybe behind furniture: stand them on open floor.
	pawn.global_position = (world.get_node("ShopFloor") as ShopFloor).cell_to_global(Vector2i(12, 7))
	# Others may stand in front of them.
	for other: Pawn in work.get_pawns():
		if other != pawn:
			other.global_position = pawn.global_position + Vector2(200.0, 0.0)
	world._select_at(pawn.global_position + Vector2(0.0, -20.0))
	if hud.get_shown_pawn() != pawn:
		fail("clicking %s didn't show them in the pawn panel" % pawn.display_name)
		return
	if hud.get_shown_station() != null:
		fail("a station stayed selected with a pawn")
		return

	var panel: PawnPanel = hud.get_node("PawnPanel")
	# Every grid skill, plus Managing.
	var skill_count: int = work.get_skill_types().size()
	if panel._levels.size() != skill_count or not panel._levels.has(work.managing):
		fail("panel shows %d skills, expected %d" % [panel._levels.size(), skill_count])
		return

	pawn.set_skill(CUTTING, 0)
	pawn.practice(CUTTING, 5.0)
	panel._update_skills()
	if panel._levels[CUTTING].text != "0" or not is_equal_approx(panel._bars[CUTTING].value, 0.5):
		fail("cutting shows level %s, bar %.2f; expected 0 and 0.5" % [panel._levels[CUTTING].text, panel._bars[CUTTING].value])
		return

	world._select_at(Vector2(-100000.0, -100000.0))
	if hud.get_shown_pawn() != null:
		fail("clicking empty floor didn't hide the pawn panel")
		return
	pass_test("pawn panel shows skills and practice")
