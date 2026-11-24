class_name TicketRack
extends Node
## The ticket rack: printed tickets in two ordered sections, Wait and Make.
## Pawns only work Make tickets, top to bottom.

## Anything about the rack changed (for the HUD).
signal changed
## The set or order of workable jobs changed; idle pawns should look for work.
signal jobs_changed
## A ticket's job was being worked when the ticket left Make.
signal job_withdrawn(job: Job)
signal ticket_completed(ticket: Ticket)
## The customer gave up waiting: the ticket left the rack unfinished. Its claimed jobs were
## withdrawn first.
signal ticket_cancelled(ticket: Ticket)

## Moving a finished item onto its order's stack.
@export var stack_task: TaskType
## Carrying an order's finished stack to hand it off.
@export var hand_off_task: TaskType
## Shop minutes past the manager's quote a customer waits before giving up.
@export var patience_past_quote: int = 20
## Shop minutes a customer waits for an unquoted order (e.g. the debug hotkey) before giving up.
@export var patience_minutes: int = 45

var _wait: Array[Ticket] = []
var _make: Array[Ticket] = []
var _next_order_number: int = 1
## Current shop time (ShopClock.get_open_minutes()), kept up to date by the owner. New
## tickets are stamped with it.
var now_minutes: int = 0


func _exit_tree() -> void:
	# Tickets, their items and jobs reference each other; break the cycles so they're freed.
	for ticket: Ticket in _wait + _make:
		ticket.release()


## Prints an order for `recipes` (one entry per item, e.g. three pizzas) into Wait.
## `placed_at` is when the customer ordered (their patience runs from then); -1 means now.
## `quoted` is the manager's quoted wait in shop minutes (-1 if none).
func print_ticket(recipes: Array[Recipe], placed_at: int = -1, quoted: int = -1) -> Ticket:
	var ticket := Ticket.new(_next_order_number, recipes, stack_task, hand_off_task)
	ticket.printed_at = now_minutes if placed_at < 0 else placed_at
	ticket.patience = get_patience(quoted)
	ticket.quoted_minutes = quoted
	_next_order_number += 1
	_wait.append(ticket)
	changed.emit()
	return ticket


## Shop minutes a customer waits from ordering before giving up, given the manager's
## `quoted` wait (-1 if none).
func get_patience(quoted: int) -> int:
	return quoted + patience_past_quote if quoted >= 0 else patience_minutes


## Moves a ticket to `index` in `section` (index counted before the ticket is removed).
func move_ticket(ticket: Ticket, section: Ticket.Section, index: int) -> void:
	var from_list: Array[Ticket] = _list(ticket.section)
	var old_index: int = from_list.find(ticket)
	if old_index == -1:
		return
	from_list.remove_at(old_index)

	var to_list: Array[Ticket] = _list(section)
	if section == ticket.section and index > old_index:
		index -= 1
	to_list.insert(clampi(index, 0, to_list.size()), ticket)

	var pulled_from_make: bool = ticket.section == Ticket.Section.MAKE and section == Ticket.Section.WAIT
	ticket.section = section
	if pulled_from_make:
		for job: Job in ticket.get_active_jobs():
			if job.claimed_by != null:
				job_withdrawn.emit(job)
	changed.emit()
	jobs_changed.emit()


## Tickets on the rack, both sections.
func get_ticket_count() -> int:
	return _wait.size() + _make.size()


func get_tickets(section: Ticket.Section) -> Array[Ticket]:
	return _list(section).duplicate()


## The order item being made as `item` (or as an item `item` is inside, e.g. a pizza's box),
## or null. A box in an order's stack is its own order item's, not the base's.
func find_order_item(item: Item) -> OrderItem:
	var tickets: Array[Ticket] = _wait + _make
	var each: Item = item
	while each != null:
		for ticket: Ticket in tickets:
			for order_item: OrderItem in ticket.order_items:
				if order_item.item == each or order_item.container == each:
					return order_item
		each = each.container
	return null


## Unclaimed jobs from Make tickets, in rack order.
func get_open_jobs() -> Array[Job]:
	var jobs: Array[Job] = []
	for ticket: Ticket in _make:
		for job: Job in ticket.get_active_jobs():
			if job.claimed_by == null:
				jobs.append(job)
	return jobs


## Call when a ticket's job finishes. After the hand-off the ticket is ready and stays on
## the rack until send_out().
func complete_job(job: Job) -> void:
	job.ticket.finish_job(job)
	changed.emit()
	jobs_changed.emit()


## The ready order has gone out: the ticket leaves the rack.
func send_out(ticket: Ticket) -> void:
	_list(ticket.section).erase(ticket)
	ticket_completed.emit(ticket)
	ticket.release()
	changed.emit()
	jobs_changed.emit()


## Cancels every ticket whose customer has run out of patience (see Ticket.is_overdue()).
func cancel_overdue() -> void:
	for ticket: Ticket in _wait + _make:
		if ticket.is_overdue(now_minutes):
			_cancel(ticket)


func _cancel(ticket: Ticket) -> void:
	_list(ticket.section).erase(ticket)
	for job: Job in ticket.get_active_jobs():
		if job.claimed_by != null:
			job_withdrawn.emit(job)
	ticket_cancelled.emit(ticket)
	ticket.release()
	changed.emit()
	jobs_changed.emit()


## Call when a job is claimed or released, so the HUD can update ticket status.
func notify_job_state_changed() -> void:
	changed.emit()


func _list(section: Ticket.Section) -> Array[Ticket]:
	return _wait if section == Ticket.Section.WAIT else _make
