class_name BuildTile
extends Button
## One station in the build menu: its sprite, name and price. Greyed out while the shop
## can't afford it.

const UNAFFORDABLE_ALPHA: float = 0.4

@onready var _art: TextureRect = %Art
@onready var _cover: TextureRect = %Cover
@onready var _name: Label = %Name
@onready var _price: Label = %Price
@onready var _content: Control = %Content


func show_station(data: StationData) -> void:
	var facing: int = data.default_facing
	var mirrored: bool = data.is_mirrored(facing)
	var art: Texture2D = data.get_texture(facing)
	if art == null and data.walk_in != null:
		art = data.walk_in.floor_texture
	_art.texture = art
	_art.flip_h = mirrored
	_cover.texture = data.get_cover_texture(facing)
	_cover.flip_h = mirrored
	_name.text = data.display_name
	_price.text = ShopFinances.format_money(data.price)
	tooltip_text = "%s  %s" % [data.display_name, _price.text]


func set_affordable(affordable: bool) -> void:
	disabled = not affordable
	_content.modulate.a = 1.0 if affordable else UNAFFORDABLE_ALPHA
