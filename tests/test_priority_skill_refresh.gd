extends "res://tests/test_base.gd"
## Priority grid: each cell's corner level and tooltip practice minutes keep up with the
## pawn as they practice and level up, without the grid being rebuilt.

const CUTTING := preload("res://resources/work_types/cutting.tres")


func _start() -> void:
	stop_random_orders()
	var pawn: Pawn = work.get_pawns()[0]
	pawn.set_skill(CUTTING, 0)
	(world.get_node("Hud/PriorityPanel") as Control).show()
	(world.get_node("Hud") as Hud).refresh_priorities()
	pawn.practice(CUTTING, 13.0)
	await process_frame
	await process_frame
	var cell: Button = _cell(pawn, CUTTING)
	var level: String = (cell.get_child(0) as Label).text
	if level != "1":
		fail("after leveling Cutting to 1 the grid shows %s" % level)
		return
	if not cell.tooltip_text.contains("3/20 min"):
		fail("tooltip didn't update with practice: %s" % cell.tooltip_text.replace("\n", " | "))
		return
	pass_test("grid shows the new level and practice")


## The grid cell for this pawn and work type.
func _cell(pawn: Pawn, work_type: WorkType) -> Button:
	var grid: GridContainer = world.get_node("Hud/PriorityPanel").get_node("%Grid")
	var row: int = work.get_pawns().find(pawn) + 1
	# After the name and the Manager box.
	var column: int = work.work_types.find(work_type) + 2
	return grid.get_child(row * grid.columns + column) as Button
