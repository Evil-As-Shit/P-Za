class_name TicketCard
extends PanelContainer
## One ticket as shown on the rack HUD.

var ticket: Ticket = null

@onready var _title: Label = %Title
@onready var _status: Label = %Status


func show_ticket(p_ticket: Ticket) -> void:
	ticket = p_ticket
	_title.text = ticket.get_title()
	_status.text = "In progress" if ticket.is_in_progress() else "Waiting"
