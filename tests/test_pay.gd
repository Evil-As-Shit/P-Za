extends "res://tests/test_base.gd"
## Pay: each pawn's fair wage comes from their best skill (more for the manager), and their
## wage against it moves their mood. The Pay tab's buttons change the wage. Once their fair
## wage passes their wage by enough, they ask for a raise at the start of a day; giving it
## pays them fair, turning it down hurts their mood and they wait a few days to ask again.

const CUTTING := preload("res://resources/work_types/cutting.tres")


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var panel: PawnPanel = hud.get_node("PawnPanel")
	var pawn: Pawn = work.get_pawns()[0]
	var rules: PayRules = pawn.pay_rules
	if rules == null:
		fail("pawns have no pay rules")
		return
	work.set_manager(null)

	# Fair wage from the best skill.
	for work_type: WorkType in pawn.skills.keys():
		pawn.set_skill(work_type, 2)
	pawn.set_skill(CUTTING, 10)
	var fair: float = rules.base_wage + rules.per_level * 10
	if not is_equal_approx(pawn.get_fair_wage(), fair):
		fail("fair wage %.2f, expected %.2f" % [pawn.get_fair_wage(), fair])
		return
	work.set_manager(pawn)
	if not is_equal_approx(pawn.get_fair_wage(), fair + rules.manager_bonus):
		fail("the manager's fair wage is %.2f, expected %.2f" % [pawn.get_fair_wage(), fair + rules.manager_bonus])
		return
	work.set_manager(null)

	# Mood from pay, capped.
	pawn.set_wage(fair)
	if not is_zero_approx(pawn.get_pay_mood()):
		fail("fair pay gives mood %.1f" % pawn.get_pay_mood())
		return
	pawn.set_wage(fair + 2.0)
	await process_frame
	var target: float = pawn.mood.get_target()
	if not is_equal_approx(pawn.get_pay_mood(), 2.0 * rules.mood_per_dollar):
		fail("$2 over fair gives mood %.1f" % pawn.get_pay_mood())
		return
	pawn.set_wage(fair - 100.0)
	if not is_equal_approx(pawn.get_pay_mood(), -rules.max_mood):
		fail("very low pay gives mood %.1f, expected %.1f" % [pawn.get_pay_mood(), -rules.max_mood])
		return
	await process_frame
	if pawn.mood.get_target() >= target:
		fail("underpaid, mood still heads toward %.1f" % pawn.mood.get_target())
		return

	# The Pay tab's buttons step the wage.
	pawn.set_wage(fair)
	hud.show_pawn(pawn)
	panel._wage_up.pressed.emit()
	if not is_equal_approx(pawn.hourly_wage, fair + rules.wage_step):
		fail("+ set the wage to %.2f" % pawn.hourly_wage)
		return
	panel._wage_down.pressed.emit()
	panel._wage_down.pressed.emit()
	if not is_equal_approx(pawn.hourly_wage, fair - rules.wage_step):
		fail("- set the wage to %.2f" % pawn.hourly_wage)
		return

	# Not underpaid enough to ask.
	pawn.check_raise(2)
	if pawn.wants_raise():
		fail("asked for a raise only %.2f under fair" % rules.wage_step)
		return

	# Underpaid: asks, and gets it.
	pawn.set_wage(fair - rules.raise_gap)
	pawn.check_raise(2)
	if not pawn.wants_raise() or PawnCard.get_status(pawn) != "Wants a raise":
		fail("underpaid by %.2f, didn't ask for a raise (status \"%s\")" % [rules.raise_gap, PawnCard.get_status(pawn)])
		return
	panel._update_pay()
	if not panel._raise.visible:
		fail("the Pay tab doesn't offer the raise")
		return
	panel._give_raise.pressed.emit()
	if pawn.wants_raise() or not is_equal_approx(pawn.hourly_wage, fair):
		fail("after the raise: wage %.2f, still asking %s" % [pawn.hourly_wage, pawn.wants_raise()])
		return

	# Asks again, is turned down: mood effect, and no asking for a few days.
	pawn.set_wage(fair - rules.raise_gap)
	pawn.check_raise(2)
	panel._turn_down.pressed.emit()
	if pawn.wants_raise() or not pawn.mood.get_effects().has(rules.turned_down):
		fail("turning the raise down didn't stop it or hurt their mood")
		return
	var day: int = clock.day
	pawn.check_raise(day + rules.ask_again_days - 1)
	if pawn.wants_raise():
		fail("asked again too soon")
		return
	pawn.check_raise(day + rules.ask_again_days)
	if not pawn.wants_raise():
		fail("didn't ask again after %d days" % rules.ask_again_days)
		return

	# Raised by hand instead: stops asking.
	pawn.set_wage(fair)
	if pawn.wants_raise():
		fail("still asking after being paid fair")
		return
	pass_test("fair wage from best skill, pay moves mood, raises asked, given and turned down")
