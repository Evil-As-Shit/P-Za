class_name StationPanel
extends PanelContainer
## HUD panel for the selected station. For stations that take a role, shows one button per
## role (plus None) and reports the player's pick.

signal role_change_requested(station: Station, role: StationRole)
signal close_requested

var station: Station = null

@onready var _title: Label = %Title
@onready var _roles: VBoxContainer = %Roles
@onready var _close: Button = %Close


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)


func show_station(p_station: Station) -> void:
	station = p_station
	_title.text = station.data.display_name
	for child: Node in _roles.get_children():
		_roles.remove_child(child)
		child.queue_free()
	var choices: Array[StationRole] = [null]
	choices.append_array(station.data.roles)
	for choice: StationRole in choices:
		var button := Button.new()
		button.text = choice.display_name if choice != null else "None (unused)"
		button.toggle_mode = true
		button.button_pressed = choice == station.role
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(role_change_requested.emit.bind(station, choice))
		_roles.add_child(button)
	show()
