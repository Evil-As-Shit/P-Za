extends "res://tests/test_base.gd"
## Oven doneness: a pizza is perfect for a minute after it's baked, over after that. The Oven
## pawn taking it out aims for the middle of that window, off by up to 1.5 minutes at level
## 0, 0.5 at level 10 and none at 20: too early is under (taken out mid-bake), too late is
## over. Left in the oven with nobody to take it out, it burns.

enum Phase { PERFECT, UNDER, OVER }

const OVEN := preload("res://resources/work_types/oven.tres")
const UNDER := DonenessRules.Doneness.UNDER
const PERFECT := DonenessRules.Doneness.PERFECT
const OVER := DonenessRules.Doneness.OVER

var _rules: DonenessRules = preload("res://resources/tasks/bake_doneness.tres")
var _phase: Phase = Phase.PERFECT
var _ticket: Ticket
## Each pawn's Oven priority (by pawn order) while it's turned off. Not keyed by pawn: a
## dictionary of nodes held until the test quits can crash Godot on exit.
var _priorities: Array[int] = []
var _ordered_at: int = 0


func _start() -> void:
	stop_random_orders()
	var skill_rules: SkillRules = work.get_pawns()[0].skill_rules
	for check: Array in [[-0.1, UNDER], [0.0, PERFECT], [1.0, PERFECT], [1.1, OVER]]:
		if _rules.judge(check[0]) != check[1]:
			fail("taken out %.1f min after done judged %d, expected %d" % [check[0], _rules.judge(check[0]), check[1]])
			return
	for check: Array in [[0, 1.5], [10, 0.5], [20, 0.0]]:
		if not is_equal_approx(_rules.max_error(check[0], skill_rules), check[1]):
			fail("level %d can be off by %.2f min, expected %.2f" % [check[0], _rules.max_error(check[0], skill_rules), check[1]])
			return
	for pawn: Pawn in work.get_pawns():
		pawn.set_skill(OVEN, skill_rules.max_level)
	clock.set_speed(6)
	_ticket = order_pizzas(1)


func _step() -> void:
	if _ticket.order_items.is_empty():
		# Gone out (its items are let go).
		if _phase == Phase.OVER and _priorities.is_empty():
			pass_test("perfect, under when taken out early, over when left in")
		return
	var doneness: DonenessRules.Doneness = _ticket.order_items[0].doneness
	match _phase:
		Phase.PERFECT:
			if doneness == DonenessRules.Doneness.NONE:
				return
			if doneness != DonenessRules.Doneness.PERFECT:
				fail("a top-level Oven pawn's pizza came out %d, expected perfect" % doneness)
				return
			# Aiming two minutes before it's done: taken out mid-bake.
			_rules.perfect_minutes = -4.0
			_phase = Phase.UNDER
			_ticket = order_pizzas(1)
		Phase.UNDER:
			if doneness == DonenessRules.Doneness.NONE:
				return
			_rules.perfect_minutes = 1.0
			if doneness != DonenessRules.Doneness.UNDER:
				fail("a pizza taken out early came out %d, expected under" % doneness)
				return
			if _ticket.order_items[0].item.busy:
				fail("a pizza taken out early is still baking")
				return
			# Nobody on Oven until well after it's done.
			for pawn: Pawn in work.get_pawns():
				_priorities.append(pawn.get_priority(OVEN))
				pawn.set_priority(OVEN, 0)
			_phase = Phase.OVER
			_ordered_at = clock.get_open_minutes()
			_ticket = order_pizzas(1)
		Phase.OVER:
			if not _priorities.is_empty() and clock.get_open_minutes() - _ordered_at > 15:
				for index: int in _priorities.size():
					work.get_pawns()[index].set_priority(OVEN, _priorities[index])
				_priorities.clear()
				work.assign_all()
			if doneness == DonenessRules.Doneness.NONE:
				return
			if doneness != DonenessRules.Doneness.OVER:
				fail("a pizza left in the oven came out %d, expected over" % doneness)
				return
			# The test ends once it's gone out, not while it's carried (see above).
