class_name TicketRackPanel
extends PanelContainer
## HUD view of the ticket rack. Shows both sections and reports drag-and-drop moves.

signal move_requested(ticket: Ticket, section: Ticket.Section, index: int)

@onready var _wait_column: TicketColumn = %WaitColumn
@onready var _make_column: TicketColumn = %MakeColumn


func _ready() -> void:
	_wait_column.ticket_dropped.connect(move_requested.emit)
	_make_column.ticket_dropped.connect(move_requested.emit)


## `now_minutes` is the current shop time, for showing how long each ticket has waited.
func show_rack(
	wait_tickets: Array[Ticket], make_tickets: Array[Ticket], now_minutes: int
) -> void:
	_wait_column.show_tickets(wait_tickets, now_minutes)
	_make_column.show_tickets(make_tickets, now_minutes)


func update_times(now_minutes: int) -> void:
	_wait_column.update_times(now_minutes)
	_make_column.update_times(now_minutes)
