class_name PawnCard
extends PanelContainer
## One pawn in the pawn bar: portrait, name, a mood bar colored by mood band and their most
## pressing status, with details on hover. Reports clicks; it doesn't select anything itself.

## Clicked; `focus` is true on a double-click (center the camera on them too).
signal pressed(pawn: Pawn, focus: bool)

const BAND_COLORS: Array[Color] = [
	Color(0.9, 0.25, 0.2), Color(0.95, 0.6, 0.2), Color(0.85, 0.8, 0.3), Color(0.4, 0.85, 0.4),
]
const NORMAL_BORDER := Color(0.25, 0.25, 0.28)
const SELECTED_BORDER := Color(1.0, 0.9, 0.4)

var pawn: Pawn = null

var _style := StyleBoxFlat.new()
var _fill := StyleBoxFlat.new()

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %Name
@onready var _mood_bar: ProgressBar = %MoodBar
@onready var _status: Label = %Status


func _ready() -> void:
	_style.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	_style.set_border_width_all(1)
	_style.set_content_margin_all(3)
	add_theme_stylebox_override(&"panel", _style)
	_mood_bar.add_theme_stylebox_override(&"fill", _fill)
	set_selected(false)


func show_pawn(p_pawn: Pawn) -> void:
	pawn = p_pawn
	_portrait.texture = pawn.get_portrait()
	_name.text = pawn.display_name
	refresh()


func set_selected(selected: bool) -> void:
	_style.border_color = SELECTED_BORDER if selected else NORMAL_BORDER


## Brings the mood bar, status and tooltip up to date.
func refresh() -> void:
	var mood: PawnMood = pawn.mood
	if mood == null:
		_mood_bar.value = 0.0
		_status.text = ""
		tooltip_text = pawn.display_name
		return
	_mood_bar.value = mood.mood
	_fill.bg_color = BAND_COLORS[mood.get_band()]
	_status.text = get_status(pawn)
	var trait_names: PackedStringArray = []
	for each: PawnTrait in pawn.traits:
		trait_names.append(each.display_name)
	tooltip_text = "%s\nMood %d (%s)\nStress %d\nEnergy %d\nSocial %d\nTraits: %s" % [
		pawn.display_name, roundi(mood.mood), mood.get_band_name(), roundi(mood.stress),
		roundi(mood.energy), roundi(mood.social),
		", ".join(trait_names) if not trait_names.is_empty() else "none",
	]


## The pawn's most pressing status, or "" if nothing stands out.
static func get_status(of: Pawn) -> String:
	var mood: PawnMood = of.mood
	if mood == null:
		return ""
	if mood.is_on_breakdown():
		return "Breakdown"
	if of.is_resting() or mood.is_on_standing_break():
		return "On break"
	if mood.energy < mood.rules.exhausted_below:
		return "Exhausted"
	if mood.energy < mood.rules.tired_below:
		return "Tired"
	if mood.get_band() <= PawnMood.Band.STRESSED:
		return "Stressed"
	if mood.is_lonely():
		return "Lonely"
	return ""


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	pressed.emit(pawn, click.double_click)
