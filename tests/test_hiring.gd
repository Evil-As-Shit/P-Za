extends "res://tests/test_base.gd"
## Hiring: resumes arrive each day (skills shown as bands, better with a higher rating) and
## expire after a few days. Hiring one adds a pawn at their asking wage with no shifts;
## passing drops it. Firing a pawn sends them out the door, and then they're gone.

var _hud: Hud
var _fired: Pawn = null
var _fired_name: String = ""


func _start() -> void:
	stop_random_orders()
	_hud = world.get_node("Hud")
	var hiring: Hiring = world.get_node("Hiring")
	var rules: HiringRules = hiring.rules
	var skill_rules: SkillRules = hiring.skill_rules

	# The first day's stack.
	if hiring.get_resumes().size() != rules.resumes_per_day:
		fail("%d resumes on day 1, expected %d" % [hiring.get_resumes().size(), rules.resumes_per_day])
		return
	var bottom: BottomBar = _hud.get_node("BottomBar")
	if bottom.get_button(BottomBar.HIRING).text != "Hiring (%d)" % rules.resumes_per_day:
		fail("the Hiring button says \"%s\"" % bottom.get_button(BottomBar.HIRING).text)
		return

	# The rating moves starting skills.
	for check: Array in [[5.0, 4], [1.0, -4]]:
		var shift: int = check[1]
		for i: int in 20:
			var applicant: Applicant = hiring.make_applicant(clock.day, check[0])
			for work_type: WorkType in applicant.skills:
				var level: int = applicant.skills[work_type]
				if level < maxi(skill_rules.start_min + shift, 0) or level > skill_rules.start_max + shift:
					fail("at %.0f stars a skill rolled %d" % [check[0], level])
					return
	if rules.get_band(3) != "Novice" or rules.get_band(7) != "Decent" or rules.get_band(20) != "Expert":
		fail("skill bands are wrong")
		return

	# Expiry: the first stack is gone after its days, replaced by a new one.
	var first: Array[Applicant] = hiring.get_resumes().duplicate()
	hiring.new_day(clock.day + 1, 3.0)
	if hiring.get_resumes().size() != rules.resumes_per_day * 2:
		fail("resumes didn't pile up")
		return
	hiring.new_day(clock.day + rules.days_to_expire, 3.0)
	for applicant: Applicant in first:
		if hiring.get_resumes().has(applicant):
			fail("a resume outlasted %d days" % rules.days_to_expire)
			return

	# Hire from the panel.
	_hud.open_window(BottomBar.HIRING)
	var panel: HiringPanel = _hud.get_node("HiringPanel")
	var applicant: Applicant = hiring.get_resumes()[0]
	var staff: int = work.get_pawns().size()
	panel.get_hire_button(applicant).pressed.emit()
	if work.get_pawns().size() != staff + 1 or hiring.get_resumes().has(applicant):
		fail("hiring didn't add the pawn or drop the resume")
		return
	var hired: Pawn = work.get_pawns()[staff]
	if hired.display_name != applicant.display_name or not is_equal_approx(hired.hourly_wage, applicant.asking_wage):
		fail("the hire is %s at %.2f" % [hired.display_name, hired.hourly_wage])
		return
	if hired.on_shift or not hired.is_away() or hired.schedule.get_work_minutes() != 0:
		fail("a new hire should start at home with no shifts")
		return
	for work_type: WorkType in work.work_types:
		if hired.get_priority(work_type) != rules.start_priority:
			fail("a new hire's %s priority is %d" % [work_type.display_name, hired.get_priority(work_type)])
			return
	if (_hud.get_node("PawnBar") as PawnBar).get_cards().size() != staff + 1:
		fail("the pawn bar doesn't show the new hire")
		return
	# Scheduled now, they come in.
	hired.schedule.set_working(clock.get_minute_of_day() / WorkSchedule.SLOT_MINUTES, true)
	if not hired.on_shift:
		fail("a scheduled new hire didn't come on shift")
		return

	# Pass on one.
	var passed: Applicant = hiring.get_resumes()[0]
	panel.get_pass_button(passed).pressed.emit()
	if hiring.get_resumes().has(passed):
		fail("passing didn't drop the resume")
		return

	# Firing someone at home: gone at once.
	panel.get_hire_button(hiring.get_resumes()[0]).pressed.emit()
	var at_home: Pawn = work.get_pawns()[work.get_pawns().size() - 1]
	var before: int = work.get_pawns().size()
	work.fire(at_home)
	if work.get_pawns().size() != before - 1:
		fail("firing a pawn at home didn't remove them")
		return

	# Fire the manager from the pawn panel (two presses).
	_fired = work.get_manager()
	_fired_name = _fired.display_name
	_hud.show_pawn(_fired)
	var pawn_panel: PawnPanel = _hud.get_node("PawnPanel")
	pawn_panel._fire.pressed.emit()
	if _fired.let_go:
		fail("one press fired them")
		return
	pawn_panel._fire.pressed.emit()
	if not _fired.let_go or work.get_manager() != null:
		fail("firing didn't let the manager go")
		return


func _step() -> void:
	# A freed pawn compares equal to null, so the name says whether one was fired.
	if _fired_name == "":
		return
	if is_instance_valid(_fired) and work.get_pawns().has(_fired):
		return
	if (_hud.get_node("PawnBar") as PawnBar).get_cards().size() != work.get_pawns().size():
		fail("the pawn bar still shows %s" % _fired_name)
		return
	if _hud.get_shown_pawn() != null:
		fail("the pawn panel still shows %s" % _fired_name)
		return
	pass_test("resumes arrive and expire, hires join with no shifts, fired staff leave")
