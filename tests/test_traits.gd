extends "res://tests/test_base.gd"
## Traits: each pawn rolls 2, never two opposites (same group). Calm and Nervous change how
## fast stress builds; Hard worker and Lazy change work speed and how often they check
## their phone. The pawn panel lists them.

const HAULING := preload("res://resources/work_types/hauling.tres")
const CALM := preload("res://resources/pawns/traits/calm.tres")
const NERVOUS := preload("res://resources/pawns/traits/nervous.tres")
const HARD_WORKER := preload("res://resources/pawns/traits/hard_worker.tres")
const LAZY := preload("res://resources/pawns/traits/lazy.tres")


func _start() -> void:
	stop_random_orders()
	var pawn: Pawn = work.get_pawns()[0]
	var rules: TraitRules = pawn.trait_rules

	# Rolls: the right count, no opposites, and every trait turns up.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen: Dictionary[PawnTrait, bool] = {}
	for i: int in 200:
		var rolled: Array[PawnTrait] = rules.roll(rng)
		if rolled.size() < rules.min_traits or rolled.size() > rules.max_traits:
			fail("rolled %d traits" % rolled.size())
			return
		var groups: Array[StringName] = []
		for each: PawnTrait in rolled:
			if groups.has(each.group):
				fail("rolled two %s traits" % each.group)
				return
			groups.append(each.group)
			seen[each] = true
	if seen.size() != rules.traits.size():
		fail("only %d of %d traits ever rolled" % [seen.size(), rules.traits.size()])
		return
	pawn.roll_traits(rng)
	if pawn.traits.size() != rules.min_traits:
		fail("a pawn with no traits rolled %d" % pawn.traits.size())
		return

	# Stress: Calm builds it at half the rate, Nervous 1.5x.
	for check: Array in [[CALM, 0.5], [NERVOUS, 1.5]]:
		pawn.set_traits([check[0]])
		pawn.mood.stress = 0.0
		pawn.mood.set_rushing(true)
		pawn.mood.tick(10.0, true)
		pawn.mood.set_rushing(false)
		var expected: float = pawn.mood.rules.stress_rise_per_minute * 10.0 * check[1]
		if not is_equal_approx(pawn.mood.stress, expected):
			fail("%s: 10 rush minutes gave stress %.2f, expected %.2f" % [check[0].display_name, pawn.mood.stress, expected])
			return

	# Speed and slacking.
	pawn.mood.mood = pawn.mood.rules.base_mood
	for check: Array in [[HARD_WORKER, 1.1, 0.5], [LAZY, 0.9, 2.0]]:
		pawn.set_traits([check[0]])
		if not is_equal_approx(pawn.get_work_rate(HAULING), pawn.work_speed * check[1]) \
				or not is_equal_approx(pawn.get_slack(), check[2]):
			fail("%s works at %.2f and slacks %.2fx" % [check[0].display_name, pawn.get_work_rate(HAULING), pawn.get_slack()])
			return

	# The panel lists them.
	pawn.set_traits([CALM, LAZY])
	var hud: Hud = world.get_node("Hud")
	hud.show_pawn(pawn)
	var label: Label = hud.get_node("PawnPanel")._traits
	if label.text != "Traits: Calm, Lazy":
		fail("the pawn panel shows \"%s\"" % label.text)
		return
	pass_test("traits roll without opposites and change stress, speed and slacking")
