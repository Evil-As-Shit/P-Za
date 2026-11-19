class_name TicketRackPanel
extends PanelContainer
## HUD view of the ticket rack. Shows both sections and reports drag-and-drop moves.

signal move_requested(ticket: Ticket, section: Ticket.Section, index: int)

@onready var _wait_column: TicketColumn = %WaitColumn
@onready var _make_column: TicketColumn = %MakeColumn


func _ready() -> void:
	_wait_column.ticket_dropped.connect(move_requested.emit)
	_make_column.ticket_dropped.connect(move_requested.emit)


func show_rack(wait_tickets: Array[Ticket], make_tickets: Array[Ticket]) -> void:
	_wait_column.show_tickets(wait_tickets)
	_make_column.show_tickets(make_tickets)
