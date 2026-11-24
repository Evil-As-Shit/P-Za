class_name WorkSchedule
extends Resource
## A pawn's shifts: each half hour of the day is Work or Off, the same every day. Off, they
## go home (see WorkManager.update_shifts()).

const SLOT_MINUTES: int = 30
const SLOTS: int = 48

## One entry per half hour from midnight: 1 is Work, 0 is Off.
@export var slots: PackedByteArray = PackedByteArray()


## A schedule working from `start_minute` to `end_minute` (half hours), off otherwise.
static func make(start_minute: int, end_minute: int) -> WorkSchedule:
	var schedule := WorkSchedule.new()
	for slot: int in range(start_minute / SLOT_MINUTES, end_minute / SLOT_MINUTES):
		schedule.set_working(slot, true)
	return schedule


func is_working(slot: int) -> bool:
	return slot >= 0 and slot < slots.size() and slots[slot] != 0


func set_working(slot: int, on: bool) -> void:
	if slot < 0 or slot >= SLOTS:
		return
	if slots.size() < SLOTS:
		slots.resize(SLOTS)
	if is_working(slot) == on:
		return
	slots[slot] = 1 if on else 0
	emit_changed()


func is_working_at(minute_of_day: int) -> bool:
	return is_working(floori(minute_of_day / float(SLOT_MINUTES)))


## Minutes of work in a day.
func get_work_minutes() -> int:
	var count: int = 0
	for slot: int in SLOTS:
		if is_working(slot):
			count += 1
	return count * SLOT_MINUTES


## When the first shift starts (minutes since midnight), or -1 with none.
func get_first_minute() -> int:
	for slot: int in SLOTS:
		if is_working(slot):
			return slot * SLOT_MINUTES
	return -1


## When the last shift ends (minutes since midnight), or -1 with none.
func get_last_minute() -> int:
	for slot: int in range(SLOTS - 1, -1, -1):
		if is_working(slot):
			return (slot + 1) * SLOT_MINUTES
	return -1


## When the shift under way at `minute_of_day` ends (`minute_of_day` itself if off then).
func get_shift_end(minute_of_day: int) -> int:
	var slot: int = floori(minute_of_day / float(SLOT_MINUTES))
	if not is_working(slot):
		return minute_of_day
	while is_working(slot):
		slot += 1
	return slot * SLOT_MINUTES
