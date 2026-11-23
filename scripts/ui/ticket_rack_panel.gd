class_name TicketRackPanel
extends PanelContainer
## HUD view of the ticket rack. Shows both sections and reports drag-and-drop moves.

signal move_requested(ticket: Ticket, section: Ticket.Section, index: int)

@onready var _wait_column: TicketColumn = %WaitColumn
@onready var _make_column: TicketColumn = %MakeColumn
@onready var _register_label: Label = %RegisterLabel
@onready var _manager_label: Label = %ManagerLabel


func _ready() -> void:
	_wait_column.ticket_dropped.connect(move_requested.emit)
	_make_column.ticket_dropped.connect(move_requested.emit)


## `now_minutes` is the current shop time, for showing how long each ticket has waited.
func show_rack(
	wait_tickets: Array[Ticket], make_tickets: Array[Ticket], now_minutes: int
) -> void:
	_wait_column.show_tickets(wait_tickets, now_minutes)
	_make_column.show_tickets(make_tickets, now_minutes)


## Shows how many customers are waiting at the register for their order to be taken.
func show_waiting_orders(count: int) -> void:
	_register_label.visible = count > 0
	_register_label.text = "%d waiting at the register" % count


## Shows the warning that the shop takes no orders without a manager.
func show_no_manager(shown: bool) -> void:
	_manager_label.visible = shown


func update_times(now_minutes: int) -> void:
	_wait_column.update_times(now_minutes)
	_make_column.update_times(now_minutes)
