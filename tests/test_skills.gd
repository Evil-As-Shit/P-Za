extends "res://tests/test_base.gd"
## Skills: levels run 0-20 and set work time (2x at 0, base at 10, half at 20). Pawns start
## with random levels (2-8) in each skill but Hauling, and practice raises them: each shop
## minute worked counts, and level L to L + 1 takes (L + 1) x 10 minutes.

const STRETCH := preload("res://resources/work_types/dough_stretching.tres")
const CUTTING := preload("res://resources/work_types/cutting.tres")
const HAULING := preload("res://resources/work_types/hauling.tres")

var _ticket: Ticket
var _level_ups: int = 0


func _start() -> void:
	stop_random_orders()
	var pawn: Pawn = work.get_pawns()[0]
	var rules: SkillRules = pawn.skill_rules
	for check: Array in [[0, 2.0], [5, 1.5], [10, 1.0], [15, 0.75], [20, 0.5]]:
		if not is_equal_approx(rules.time_multiplier(check[0]), check[1]):
			fail("level %d works at %.2fx time, expected %.2fx" % [check[0], rules.time_multiplier(check[0]), check[1]])
			return

	# Starting levels.
	pawn.skills.clear()
	pawn.roll_skills(work.work_types, RandomNumberGenerator.new())
	for work_type: WorkType in work.work_types:
		if not work_type.has_skill:
			if pawn.skills.has(work_type):
				fail("%s got a skill level" % work_type.display_name)
				return
			continue
		var level: int = pawn.get_skill(work_type)
		if level < rules.start_min or level > rules.start_max:
			fail("%s started at level %d" % [work_type.display_name, level])
			return

	# Speed.
	pawn.set_skill(CUTTING, 0)
	if not is_equal_approx(pawn.get_work_rate(CUTTING), 0.5):
		fail("level 0 works at rate %.2f, expected 0.5" % pawn.get_work_rate(CUTTING))
		return
	pawn.set_skill(CUTTING, 20)
	if not is_equal_approx(pawn.get_work_rate(CUTTING), 2.0):
		fail("level 20 works at rate %.2f, expected 2" % pawn.get_work_rate(CUTTING))
		return
	if not is_equal_approx(pawn.get_work_rate(HAULING), pawn.work_speed):
		fail("Hauling speed depends on skill")
		return

	# Practice: 0 -> 1 takes 10 minutes and 1 -> 2 takes 20, leaving 5 of 35.
	pawn.set_skill(CUTTING, 0)
	pawn.skill_leveled_up.connect(func(_type: WorkType, _level: int) -> void: _level_ups += 1)
	pawn.practice(CUTTING, 35.0)
	if pawn.get_skill(CUTTING) != 2 or _level_ups != 2 or not is_equal_approx(pawn.get_practice(CUTTING), 5.0):
		fail("35 minutes of practice from 0 gave level %d (%d level-ups, %.1f left), expected 2 with 5 left" % [pawn.get_skill(CUTTING), _level_ups, pawn.get_practice(CUTTING)])
		return
	pawn.set_skill(CUTTING, 10)
	_even_out_skills()

	# Real work gives practice.
	clock.set_speed(6)
	_ticket = order_pizzas(1)
	rack.ticket_completed.connect(_on_completed)


func _on_completed(ticket: Ticket) -> void:
	if ticket != _ticket:
		return
	var stretched: float = 0.0
	var cut: float = 0.0
	for pawn: Pawn in work.get_pawns():
		stretched += pawn.get_practice(STRETCH)
		cut += pawn.get_practice(CUTTING)
		if pawn.get_practice(HAULING) > 0.0:
			fail("%s practiced Hauling" % pawn.display_name)
			return
	if stretched <= 0.0 or cut <= 0.0:
		fail("making a pizza gave no practice (stretching %.2f, cutting %.2f min)" % [stretched, cut])
		return
	pass_test("levels set work time and grow with practice (stretching %.2f, cutting %.2f min)" % [stretched, cut])
