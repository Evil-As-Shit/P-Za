class_name BuildPanel
extends PanelContainer
## HUD menu for build mode: category buttons down the left, and a grid of tiles for the
## chosen category's stations (sprite, name and price, greyed out while the shop can't
## afford it).

signal station_chosen(data: StationData)
signal sell_requested
signal close_requested

const TILE_SCENE: PackedScene = preload("res://scenes/ui/build_tile.tscn")
const OTHER_NAME: String = "Other"

var _cash: float = 0.0
var _buttons_by_data: Dictionary[StationData, BuildTile] = {}
## One grid of tiles per category, shown one at a time.
var _grids: Array[GridContainer] = []
var _category_group := ButtonGroup.new()

@onready var _categories: VBoxContainer = %Categories
@onready var _tiles: Control = %Tiles
@onready var _sell: Button = %Sell
@onready var _close: Button = %Close


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)
	_sell.pressed.connect(sell_requested.emit)
	set_can_sell(false)


## The Sell button works while an existing station is picked up.
func set_can_sell(can_sell: bool) -> void:
	_sell.disabled = not can_sell


## Lists the catalog's stations under their categories, in the order each category first
## appears in it.
func show_catalog(catalog: Array[StationData]) -> void:
	for parent: Node in [_categories, _tiles]:
		for child: Node in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_buttons_by_data.clear()
	_grids.clear()
	var grid_by_name: Dictionary[String, GridContainer] = {}
	for data: StationData in catalog:
		var category_name: String = OTHER_NAME
		if data.build_category != null:
			category_name = data.build_category.display_name
		if not grid_by_name.has(category_name):
			grid_by_name[category_name] = _add_category(category_name)
		var tile: BuildTile = TILE_SCENE.instantiate()
		grid_by_name[category_name].add_child(tile)
		tile.show_station(data)
		tile.pressed.connect(station_chosen.emit.bind(data))
		_buttons_by_data[data] = tile
	if not _grids.is_empty():
		_show_category(0)
	_refresh_affordable()


## The shop's cash changed: stations it can't afford are greyed out.
func show_cash(cash: float) -> void:
	_cash = cash
	_refresh_affordable()


func _add_category(category_name: String) -> GridContainer:
	var index: int = _grids.size()
	var button := Button.new()
	button.text = category_name
	button.toggle_mode = true
	button.button_group = _category_group
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggled.connect(_on_category_toggled.bind(index))
	_categories.add_child(button)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.visible = false
	_tiles.add_child(grid)
	_grids.append(grid)
	return grid


func _on_category_toggled(on: bool, index: int) -> void:
	if on:
		_show_category(index)


func _show_category(index: int) -> void:
	for i: int in _grids.size():
		_grids[i].visible = i == index
	(_categories.get_child(index) as Button).set_pressed_no_signal(true)


func _refresh_affordable() -> void:
	for data: StationData in _buttons_by_data:
		_buttons_by_data[data].set_affordable(_cash >= data.price)
