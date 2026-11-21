class_name TicketCard
extends PanelContainer
## One ticket as shown on the rack HUD: title, status and how long it's been waiting.
## Turns yellow once half the customer's patience is used, and red near the end.

const LATE_AT: float = 0.5
const VERY_LATE_AT: float = 0.8
const LATE_COLOR := Color(0.5, 0.4, 0.08)
const VERY_LATE_COLOR := Color(0.55, 0.13, 0.1)

var ticket: Ticket = null

var _late_style := StyleBoxFlat.new()

@onready var _title: Label = %Title
@onready var _status: Label = %Status


## `now_minutes` is the current shop time (ShopClock.get_open_minutes()).
func show_ticket(p_ticket: Ticket, now_minutes: int) -> void:
	ticket = p_ticket
	_title.text = ticket.get_title()
	update_time(now_minutes)


## Refreshes the status, minutes waited and lateness color.
func update_time(now_minutes: int) -> void:
	var status: String = "Waiting"
	if ticket.ready:
		status = "Ready"
	elif ticket.is_in_progress():
		status = "In progress"
	var count: int = ticket.order_items.size()
	if count > 1 and not ticket.ready:
		status += " · %d/%d boxed" % [ticket.get_finished_count(), count]
	_status.text = "%s · %d min" % [status, ticket.get_age(now_minutes)]

	var used: float = ticket.get_patience_used(now_minutes)
	if ticket.ready or used < LATE_AT:
		remove_theme_stylebox_override(&"panel")
		return
	_late_style.bg_color = VERY_LATE_COLOR if used >= VERY_LATE_AT else LATE_COLOR
	add_theme_stylebox_override(&"panel", _late_style)
