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

var _wait: Array[Ticket] = []
var _make: Array[Ticket] = []
var _next_order_number: int = 1


func _exit_tree() -> void:
	# Ticket and Job reference each other; break the cycle so unfinished tickets are freed.
	for ticket: Ticket in _wait + _make:
		ticket.current_job = null


func print_ticket(recipe: Recipe) -> Ticket:
	var ticket := Ticket.new(_next_order_number, recipe)
	_next_order_number += 1
	_wait.append(ticket)
	changed.emit()
	return ticket


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
	if pulled_from_make and ticket.is_in_progress():
		job_withdrawn.emit(ticket.current_job)
	changed.emit()
	jobs_changed.emit()


func get_tickets(section: Ticket.Section) -> Array[Ticket]:
	return _list(section).duplicate()


## Unclaimed jobs from Make tickets, in rack order.
func get_open_jobs() -> Array[Job]:
	var jobs: Array[Job] = []
	for ticket: Ticket in _make:
		if ticket.current_job != null and ticket.current_job.claimed_by == null:
			jobs.append(ticket.current_job)
	return jobs


## Call when a ticket's job finishes. After the last one the ticket is marked ready and
## stays on the rack until send_out().
func complete_job(job: Job) -> void:
	var ticket: Ticket = job.ticket
	ticket.advance()
	if ticket.is_complete():
		ticket.ready = true
	changed.emit()
	jobs_changed.emit()


## The ready order has gone out: the ticket leaves the rack.
func send_out(ticket: Ticket) -> void:
	_list(ticket.section).erase(ticket)
	ticket_completed.emit(ticket)
	changed.emit()
	jobs_changed.emit()


## Call when a job is claimed or released, so the HUD can update ticket status.
func notify_job_state_changed() -> void:
	changed.emit()


func _list(section: Ticket.Section) -> Array[Ticket]:
	return _wait if section == Ticket.Section.WAIT else _make
