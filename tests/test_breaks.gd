extends "res://tests/test_base.gd"
## Energy and breaks: energy drains on a job (twice as fast in a rush), lowers mood when
## tired and slows work when exhausted, and is full again overnight. A tired pawn takes a
## break (in a rush only when very tired): at a free spot on a table set to Break, where
## energy refills fast and no work is taken, or else resting standing, slower. Either way
## they get "Took a break" afterward.

const BREAK_ROLE := preload("res://resources/station_roles/break.tres")

var _rules: MoodRules
var _pawn: Pawn
var _table: Station
var _saw_resting: bool = false


func _start() -> void:
	stop_random_orders()
	_rules = load("res://resources/pawns/mood_rules.tres")
	var problem: String = _check_mood()
	if problem != "":
		fail(problem)
		return

	# A real pawn, tired, with a break table: they go and rest there.
	_table = world.get_node("Entities/BoxingTable3")
	world._on_role_change_requested(_table, BREAK_ROLE)
	if _table.role != BREAK_ROLE:
		fail("the table didn't take the Break role")
		return
	_pawn = work.get_pawns()[0]
	_pawn.mood.energy = 20.0
	if _pawn.has_job():
		work.withdraw_job(_pawn.get_job())
	clock.set_speed(6)
	work.assign_all()
	if _pawn.get_job() == null or _pawn.get_job().task_type != work.break_task:
		fail("a tired pawn didn't head for the break table")
		return
	if _pawn.get_job().station != _table:
		fail("the break isn't at the break table")


func _step() -> void:
	if _pawn == null:
		return
	if _pawn.is_resting():
		_saw_resting = true
		if work.try_assign(_pawn) and _pawn.get_job().task_type != work.break_task:
			fail("a pawn on a break took work")
		return
	if not _saw_resting or _pawn.has_job():
		return
	# The break is over.
	if _pawn.mood.energy < minf(20.0 + _rules.table_rest_per_minute * _pawn.mood.break_length * 0.9, 99.0):
		fail("a break at the table only brought energy to %.1f" % _pawn.mood.energy)
		return
	if not _pawn.mood.get_effects().has(_rules.took_break):
		fail("no \"Took a break\" after a break at the table")
		return
	pass_test("energy drains and refills; breaks at a break table or standing")


## Energy, tiredness and standing breaks on their own.
func _check_mood() -> String:
	var mood := PawnMood.new(_rules)
	mood.tick(10.0, true)
	if not is_equal_approx(mood.energy, 100.0 - _rules.energy_drain_per_minute * 10.0):
		return "10 minutes on a job left energy at %.2f" % mood.energy
	mood.tick(10.0, false)
	if not is_equal_approx(mood.energy, 100.0 - _rules.energy_drain_per_minute * 10.0):
		return "energy drained while idle"
	mood.set_rushing(true)
	var before: float = mood.energy
	mood.tick(10.0, true)
	if not is_equal_approx(before - mood.energy, _rules.energy_drain_per_minute * 10.0 * _rules.rush_energy_drain):
		return "a rush didn't drain energy faster"
	mood.set_rushing(false)
	mood.get_effects().clear()

	# Tired: lower mood; exhausted: slower.
	var rested: float = mood.get_target()
	mood.energy = 0.0
	if not is_equal_approx(rested - mood.get_target(), _rules.tired_mood_cost):
		return "no energy cost %.1f mood, expected %.1f" % [rested - mood.get_target(), _rules.tired_mood_cost]
	mood.mood = _rules.base_mood
	if not is_equal_approx(mood.get_speed_multiplier(), _rules.exhausted_speed):
		return "an exhausted pawn works at %.2f" % mood.get_speed_multiplier()

	# Wanting a break: under break_below, or under must_break_below in a rush.
	mood.energy = (_rules.break_below + _rules.must_break_below) / 2.0
	if not mood.wants_break():
		return "a tired pawn doesn't want a break"
	mood.set_rushing(true)
	if mood.wants_break():
		return "a tired pawn wants a break in a rush"
	mood.energy = _rules.must_break_below / 2.0
	if not mood.wants_break():
		return "a very tired pawn doesn't want a break in a rush"
	mood.set_rushing(false)
	mood.get_effects().clear()

	# Resting standing: slower refill, then "Took a break".
	var ended: Array[int] = [0]
	mood.break_ended.connect(func() -> void: ended[0] += 1)
	mood.energy = 20.0
	mood.start_standing_break()
	if mood.wants_break():
		return "a pawn on a break still wants one"
	for i: int in int(mood.break_length) + 1:
		mood.tick(1.0, false)
	var expected: float = 20.0 + _rules.standing_rest_per_minute * mood.break_length
	if ended[0] != 1 or not is_equal_approx(mood.energy, expected):
		return "a standing break ended %d times with energy %.1f, expected once with %.1f" % [ended[0], mood.energy, expected]
	if not mood.get_effects().has(_rules.took_break):
		return "no \"Took a break\" after a standing break"
	# One break a day: tired again, no second one until the next day.
	mood.energy = _rules.must_break_below / 2.0
	if mood.wants_break():
		return "a pawn wants a second break the same day"
	mood.rest_overnight()
	if mood.energy != 100.0:
		return "a night's rest didn't refill energy"
	mood.energy = _rules.must_break_below / 2.0
	if not mood.wants_break():
		return "a tired pawn doesn't want their break the next day"
	return ""
