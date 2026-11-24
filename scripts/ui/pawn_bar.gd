class_name PawnBar
extends HBoxContainer
## The row of pawn cards along the top of the screen (see PawnCard). Keeps them up to date
## and passes clicks up.

## A card was clicked; `focus` is true on a double-click.
signal pawn_pressed(pawn: Pawn, focus: bool)

const CARD_SCENE := preload("res://scenes/ui/pawn_card.tscn")

var _cards: Array[PawnCard] = []


func _process(_delta: float) -> void:
	if visible:
		for card: PawnCard in _cards:
			card.refresh()


func show_pawns(pawns: Array[Pawn]) -> void:
	for card: PawnCard in _cards:
		card.queue_free()
	_cards.clear()
	for pawn: Pawn in pawns:
		var card := CARD_SCENE.instantiate() as PawnCard
		add_child(card)
		card.show_pawn(pawn)
		card.pressed.connect(pawn_pressed.emit)
		_cards.append(card)


## Highlights the selected pawn's card (none for null).
func show_selected(pawn: Pawn) -> void:
	for card: PawnCard in _cards:
		card.set_selected(card.pawn == pawn)


func get_cards() -> Array[PawnCard]:
	return _cards
