class_name TicketCard
extends PanelContainer
## One ticket as shown on the rack HUD.

var ticket: Ticket = null

@onready var _title: Label = %Title
@onready var _status: Label = %Status


func show_ticket(p_ticket: Ticket) -> void:
	ticket = p_ticket
	_title.text = ticket.get_title()
	if ticket.ready:
		_status.text = "Ready"
	elif ticket.is_in_progress():
		_status.text = "In progress"
	else:
		_status.text = "Waiting"
