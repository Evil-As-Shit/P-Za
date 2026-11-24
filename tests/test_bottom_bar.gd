extends "res://tests/test_base.gd"
## The bottom bar: its Priorities, Build and Supplies buttons open their windows one at a
## time (Build turns build mode on, and opening another window turns it off). Report is off
## until a day report exists, then reopens it, and closing a reopened report doesn't resume
## a paused day. The pawn inspect panel has Needs, Mood, Social and Skills tabs.


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var bar: BottomBar = hud.get_node("BottomBar")
	var build: BuildMode = world.get_node("BuildMode")
	var priorities: Control = hud.get_node("PriorityPanel")
	var build_panel: Control = hud.get_node("BuildPanel")
	var supplies: Control = hud.get_node("SupplyPanel")

	bar.get_button(BottomBar.SUPPLIES).button_pressed = true
	if not supplies.visible or priorities.visible or build_panel.visible:
		fail("Supplies didn't open alone")
		return
	bar.get_button(BottomBar.BUILD).button_pressed = true
	if not build.active or not build_panel.visible or supplies.visible:
		fail("Build didn't turn build mode on and close Supplies")
		return
	if not bar.get_button(BottomBar.BUILD).button_pressed or bar.get_button(BottomBar.SUPPLIES).button_pressed:
		fail("the bar's buttons don't show Build open")
		return
	hud.toggle_priorities()
	if build.active or build_panel.visible or not priorities.visible:
		fail("opening Priorities didn't end build mode")
		return
	if not bar.get_button(BottomBar.PRIORITIES).button_pressed:
		fail("the Priorities button isn't shown pressed")
		return
	bar.get_button(BottomBar.PRIORITIES).button_pressed = false
	if priorities.visible:
		fail("Priorities didn't close")
		return

	# Report: off until there's a report; reopened, closing it doesn't resume the day.
	var report_button: Button = bar.get_node("%Report")
	if not report_button.disabled:
		fail("Report works before any day report")
		return
	hud.show_report(DayReport.new())
	world._on_report_closed()
	if report_button.disabled:
		fail("Report stays off after a day report")
		return
	clock.set_speed(0)
	report_button.pressed.emit()
	var report_panel: DayReportPanel = hud.get_node("DayReportPanel")
	if not report_panel.visible:
		fail("Report didn't reopen the day report")
		return
	report_panel.continue_requested.emit()
	if report_panel.visible or clock.speed != 0:
		fail("closing a reopened report didn't just close it (speed %d)" % clock.speed)
		return

	# The pawn inspect panel's tabs.
	hud.show_pawn(work.get_pawns()[0])
	var tabs: TabContainer = hud.get_node("PawnPanel").get_node("%Tabs")
	var titles: PackedStringArray = []
	for i: int in tabs.get_tab_count():
		titles.append(tabs.get_tab_title(i))
	if titles != PackedStringArray(["Needs", "Mood", "Social", "Skills"]):
		fail("the pawn panel's tabs are %s" % [titles])
		return
	pass_test("bottom bar windows open one at a time; Report reopens; pawn panel has tabs")
