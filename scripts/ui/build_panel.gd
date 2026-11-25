class_name BuildPanel
extends PanelContainer
## HUD menu for build mode: one button per station type with its price (greyed out while
## the shop can't afford it), and how to place and move them.

signal station_chosen(data: StationData)
signal sell_requested
signal close_requested

var _cash: float = 0.0
var _buttons_by_data: Dictionary[StationData, Button] = {}

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
	_buttons_by_data.clear()
	for data: StationData in catalog:
		var button := Button.new()
		button.text = "%s  %s" % [data.display_name, ShopFinances.format_money(data.price)]
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(station_chosen.emit.bind(data))
		_buttons.add_child(button)
		_buttons_by_data[data] = button
	_refresh_affordable()


## The shop's cash changed: stations it can't afford are greyed out.
func show_cash(cash: float) -> void:
	_cash = cash
	_refresh_affordable()


func _refresh_affordable() -> void:
	for data: StationData in _buttons_by_data:
		_buttons_by_data[data].disabled = _cash < data.price
