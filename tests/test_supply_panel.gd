extends "res://tests/test_base.gd"
## The supply panel: the bottom bar's Supplies button opens it, it lists each supply's stock and
## target and the next delivery (day 1 is a Monday, so Wednesday, Day 3), and its + and -
## buttons raise and lower a target by one case.

const CHEESE := preload("res://resources/supplies/cheese.tres")


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var panel: SupplyPanel = hud.get_node("SupplyPanel")
	var clock_panel: ClockPanel = hud.get_node("ClockPanel")
	var deliveries: Deliveries = world.get_node("Deliveries")
	var supplies: Button = (hud.get_node("BottomBar") as BottomBar).get_button(BottomBar.SUPPLIES)
	if panel.visible:
		fail("the supply panel should start hidden")
		return
	if not (clock_panel.get_node("%Day") as Label).text.begins_with("Mon, Day 1"):
		fail("the clock should show Mon, Day 1, shows %s" % (clock_panel.get_node("%Day") as Label).text)
		return
	supplies.button_pressed = true
	if not panel.visible:
		fail("the Supplies button didn't open the supply panel")
		return
	var stock: Label = panel._stock_labels[CHEESE]
	var target: int = deliveries.get_target(CHEESE)
	if stock.text != "%d / %d bags" % [deliveries.get_stock(CHEESE), target]:
		fail("the cheese row shows '%s'" % stock.text)
		return
	if (panel.get_node("%NextDelivery") as Label).text != "Next delivery: Wed, Day 3":
		fail("next delivery shows '%s'" % (panel.get_node("%NextDelivery") as Label).text)
		return
	# The cheese row's buttons follow its stock label: -, then +.
	var plus: Button = stock.get_parent().get_child(stock.get_index() + 2)
	var minus: Button = stock.get_parent().get_child(stock.get_index() + 1)
	plus.pressed.emit()
	if deliveries.get_target(CHEESE) != target + CHEESE.units_per_case \
			or not stock.text.ends_with("/ %d bags" % (target + CHEESE.units_per_case)):
		fail("+ didn't raise the cheese target by a case (now %d, shows '%s')" % [
			deliveries.get_target(CHEESE), stock.text])
		return
	minus.pressed.emit()
	minus.pressed.emit()
	if deliveries.get_target(CHEESE) != target - CHEESE.units_per_case:
		fail("- didn't lower the cheese target by a case")
		return
	supplies.button_pressed = false
	if panel.visible:
		fail("the Supplies button didn't close the supply panel")
		return
	pass_test("supply panel opens, shows stock, targets and the next delivery, and changes targets")
