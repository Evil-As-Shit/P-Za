class_name TicketColumn
extends PanelContainer
## One rack section (Wait or Make). Tickets can be dragged within and between columns.
## Drops are reported with ticket_dropped; the column never changes the rack itself.

signal ticket_dropped(ticket: Ticket, section: Ticket.Section, index: int)

const TICKET_CARD_SCENE: PackedScene = preload("res://scenes/ui/ticket_card.tscn")

@export var section: Ticket.Section = Ticket.Section.WAIT
@export var title: String = ""

@onready var _header: Label = %Header
@onready var _cards: VBoxContainer = %Cards


func _ready() -> void:
	_header.text = title


## `now_minutes` is the current shop time, for showing how long each ticket has waited.
func show_tickets(tickets: Array[Ticket], now_minutes: int) -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for ticket: Ticket in tickets:
		var card := TICKET_CARD_SCENE.instantiate() as TicketCard
		_cards.add_child(card)
		card.show_ticket(ticket, now_minutes)
		card.set_drag_forwarding(
			_get_card_drag_data.bind(card),
			_can_drop_on_card.bind(card),
			_drop_on_card.bind(card)
		)


func update_times(now_minutes: int) -> void:
	for card: TicketCard in _cards.get_children():
		card.update_time(now_minutes)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).get("ticket") is Ticket


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drop_at_global_y(get_global_rect().position.y + at_position.y, data)


func _get_card_drag_data(_at_position: Vector2, card: TicketCard) -> Variant:
	var preview := Label.new()
	preview.text = card.ticket.get_title()
	set_drag_preview(preview)
	return {"ticket": card.ticket}


func _can_drop_on_card(at_position: Vector2, data: Variant, _card: TicketCard) -> bool:
	return _can_drop_data(at_position, data)


func _drop_on_card(at_position: Vector2, data: Variant, card: TicketCard) -> void:
	_drop_at_global_y(card.get_global_rect().position.y + at_position.y, data)


func _drop_at_global_y(global_y: float, data: Variant) -> void:
	var ticket: Ticket = (data as Dictionary)["ticket"]
	ticket_dropped.emit(ticket, section, _index_at_global_y(global_y))


## Number of cards whose midpoint is above the drop point.
func _index_at_global_y(global_y: float) -> int:
	var index: int = 0
	for card: Control in _cards.get_children():
		if card.get_global_rect().get_center().y < global_y:
			index += 1
	return index
