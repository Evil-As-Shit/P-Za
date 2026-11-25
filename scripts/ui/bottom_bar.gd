class_name BottomBar
extends PanelContainer
## The bar along the bottom of the screen: buttons that open the main windows (Priorities,
## Schedule, Build, Supplies, Hiring), one at a time, and one that reopens the last day report.
## Reports the player's clicks; the HUD decides what opens.

## A window button was pressed on (`on`) or off.
signal tab_toggled(tab: StringName, on: bool)
signal report_requested

const PRIORITIES := &"priorities"
const SCHEDULE := &"schedule"
const BUILD := &"build"
const SUPPLIES := &"supplies"
const HIRING := &"hiring"

@onready var _buttons: Dictionary[StringName, Button] = {
	PRIORITIES: %Priorities, SCHEDULE: %Schedule, BUILD: %Build, SUPPLIES: %Supplies,
	HIRING: %Hiring,
}
@onready var _report: Button = %Report


func _ready() -> void:
	for tab: StringName in _buttons:
		_buttons[tab].toggled.connect(func(on: bool) -> void: tab_toggled.emit(tab, on))
	_report.pressed.connect(report_requested.emit)
	_report.disabled = true


## Shows `tab`'s button pressed and the others not (none for &"").
func show_open(tab: StringName) -> void:
	for each: StringName in _buttons:
		_buttons[each].set_pressed_no_signal(each == tab)


## The Hiring button shows how many resumes are waiting.
func show_resume_count(count: int) -> void:
	_buttons[HIRING].text = "Hiring (%d)" % count if count > 0 else "Hiring"


## The Report button works once there's a day report to reopen.
func set_report_available(available: bool) -> void:
	_report.disabled = not available


func get_button(tab: StringName) -> Button:
	return _buttons[tab]
