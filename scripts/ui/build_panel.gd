class_name BuildPanel
extends PanelContainer
## HUD menu for build mode: one button per station type, and how to place and move them.

signal station_chosen(data: StationData)
signal sell_requested
signal close_requested

@onready var _buttons: VBoxContainer = %Buttons
@onready var _sell: Button = %Sell
@onready var _close: Button = %Close


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)
	_sell.pressed.connect(sell_requested.emit)
	set_can_sell(false)


## The Sell button works while an existing station is picked up.
func set_can_sell(can_sell: bool) -> void:
	_sell.disabled = not can_sell


func show_catalog(catalog: Array[StationData]) -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for data: StationData in catalog:
		var button := Button.new()
		button.text = data.display_name
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(station_chosen.emit.bind(data))
		_buttons.add_child(button)
