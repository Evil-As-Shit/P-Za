class_name TicketCard
extends PanelContainer
## One ticket as shown on the rack HUD: title, status and how long it's been waiting.

var ticket: Ticket = null

@onready var _title: Label = %Title
@onready var _status: Label = %Status


## `now_minutes` is the current shop time (ShopClock.get_open_minutes()).
func show_ticket(p_ticket: Ticket, now_minutes: int) -> void:
	ticket = p_ticket
	_title.text = ticket.get_title()
	update_time(now_minutes)


## Refreshes the status and minutes waited.
func update_time(now_minutes: int) -> void:
	var status: String = "Waiting"
	if ticket.ready:
		status = "Ready"
	elif ticket.is_in_progress():
		status = "In progress"
	_status.text = "%s · %d min" % [status, maxi(now_minutes - ticket.printed_at, 0)]
