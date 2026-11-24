extends "res://tests/test_base.gd"
## The pawn bar: a card per pawn with a portrait, name, mood bar and most pressing status.
## Clicking a card selects the pawn (and highlights the card); double-clicking also centers
## the camera on them.


func _start() -> void:
	stop_random_orders()
	var hud: Hud = world.get_node("Hud")
	var bar: PawnBar = hud.get_node("PawnBar")
	var pawns: Array[Pawn] = work.get_pawns()
	var cards: Array[PawnCard] = bar.get_cards()
	if cards.size() != pawns.size():
		fail("the bar has %d cards for %d pawns" % [cards.size(), pawns.size()])
		return
	var card: PawnCard = cards[1]
	var pawn: Pawn = pawns[1]
	if card.pawn != pawn or card._portrait.texture == null or card._name.text != pawn.display_name:
		fail("the card doesn't show its pawn's portrait and name")
		return

	# Mood bar and status follow the pawn.
	pawn.mood.mood = 72.0
	card.refresh()
	if not is_equal_approx(card._mood_bar.value, 72.0) or card._status.text != "":
		fail("a happy, rested pawn shows mood %.0f and status \"%s\"" % [card._mood_bar.value, card._status.text])
		return
	pawn.mood.energy = pawn.mood.rules.tired_below - 1.0
	card.refresh()
	if card._status.text != "Tired":
		fail("a tired pawn's card says \"%s\"" % card._status.text)
		return
	pawn.mood.start_standing_break()
	card.refresh()
	if card._status.text != "On break":
		fail("a pawn on a break's card says \"%s\"" % card._status.text)
		return

	# Click: selected and highlighted, camera stays.
	var camera: ShopCamera = world.get_node("ShopCamera")
	var camera_at: Vector2 = camera.position
	card._gui_input(_click(false))
	if hud.get_shown_pawn() != pawn or card._style.border_color != PawnCard.SELECTED_BORDER:
		fail("clicking a card didn't select and highlight its pawn")
		return
	if camera.position != camera_at:
		fail("a single click moved the camera")
		return
	# Double-click: the camera centers on them.
	card._gui_input(_click(true))
	if camera.position != pawn.global_position.round():
		fail("double-clicking didn't center the camera on the pawn")
		return
	# Selecting something else clears the highlight.
	world._select(null)
	if card._style.border_color == PawnCard.SELECTED_BORDER:
		fail("the card stayed highlighted after the pawn was deselected")
		return
	pass_test("cards show each pawn; click selects, double-click centers the camera")


func _click(double: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = double
	return click
