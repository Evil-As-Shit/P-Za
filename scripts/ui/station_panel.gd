class_name StationPanel
extends PanelContainer
## HUD panel for the selected station: its name, and for stations that take a role, one button per
## role (plus None) and reports the player's pick. A storage station also shows its filter: a
## checklist of the kinds it can keep, grouped (see StorageGroup), with Allow all and Clear
## all. Also shows how full its ingredient pans are (see StationData.pans), a bulk tub's
## level, a delivery pallet's cases and how dirty it is, kept up to date while it's open.

signal role_change_requested(station: Station, role: StationRole)
## The player let `kinds` into the storage filter, or kept them out.
signal filter_change_requested(station: Station, kinds: Array[StorageKind], allowed: bool)
signal close_requested

## Room left around the filter's rows, in pixels.
const FILTER_PADDING: float = 8.0

var station: Station = null

@onready var _title: Label = %Title
@onready var _roles: VBoxContainer = %Roles
@onready var _close: Button = %Close
@onready var _contents: Label = %Contents
@onready var _hint: Label = $Margin/Lines/Hint
@onready var _filter: VBoxContainer = %Filter
@onready var _kinds: Tree = %Kinds
@onready var _allow_all: Button = %AllowAll
@onready var _clear_all: Button = %ClearAll


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)
	_kinds.item_edited.connect(_on_kind_edited)
	_allow_all.pressed.connect(_request_all.bind(true))
	_clear_all.pressed.connect(_request_all.bind(false))


func _process(_delta: float) -> void:
	if visible and station != null and is_instance_valid(station):
		_show_contents()


## How dirty it is, then one line per pan, e.g. "Cheese: 6/10".
func _show_contents() -> void:
	var lines: PackedStringArray = ["Dirt: %d%%" % roundi(station.get_dirt() * 100.0)]
	for pan: IngredientPan in station.data.pans:
		lines.append("%s: %d/%d" % [pan.display_name, station.get_pan_left(pan), pan.portions])
	if station.data.bulk_tub != null:
		lines.append("Portions: %d/%d" % [station.get_bulk_left(), station.get_bulk_capacity()])
	var cases: DockCases = station.get_dock_cases()
	if cases != null:
		lines.append("Cases: %d/%d" % [station.data.delivery_dock.capacity - cases.get_room(),
			station.data.delivery_dock.capacity])
	_contents.text = "\n".join(lines)
	_contents.visible = not lines.is_empty()


func show_station(p_station: Station) -> void:
	station = p_station
	_title.text = station.data.display_name
	for child: Node in _roles.get_children():
		_roles.remove_child(child)
		child.queue_free()
	# Stations without roles (e.g. an oven) just show their name and contents.
	_hint.visible = station.has_roles()
	_roles.visible = station.has_roles()
	var choices: Array[StationRole] = [null]
	choices.append_array(station.get_available_roles())
	for choice: StationRole in choices:
		var button := Button.new()
		button.text = choice.display_name if choice != null else "None (unused)"
		button.toggle_mode = true
		button.button_pressed = choice == station.role
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(role_change_requested.emit.bind(station, choice))
		_roles.add_child(button)
	_build_filter()
	_show_contents()
	show()


#region Storage filter

## One row per group, with a checkbox row under it for each kind the station can list. A kind
## it can't keep where it stands (e.g. dough outside a walk-in) is greyed out.
func _build_filter() -> void:
	_filter.visible = station.is_storage()
	_kinds.clear()
	if not station.is_storage():
		return
	var root: TreeItem = _kinds.create_item()
	var groups: Dictionary[StorageGroup, TreeItem] = {}
	var rows: int = 0
	for kind: StorageKind in station.get_storable_kinds():
		if not groups.has(kind.group):
			var heading: TreeItem = _kinds.create_item(root)
			heading.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			heading.set_text(0, kind.group.display_name)
			heading.set_editable(0, true)
			heading.set_metadata(0, kind.group)
			groups[kind.group] = heading
			rows += 1
		var row: TreeItem = _kinds.create_item(groups[kind.group])
		row.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		var walk_in_only: bool = not station.can_store(kind)
		row.set_text(0, kind.display_name + (" (walk-in only)" if walk_in_only else ""))
		row.set_editable(0, not walk_in_only)
		row.set_metadata(0, kind)
		if walk_in_only:
			row.set_custom_color(0, Color(1.0, 1.0, 1.0, 0.4))
		rows += 1
	_update_checks()
	# A Tree doesn't size itself to its rows.
	var font: Font = _kinds.get_theme_font(&"font")
	var row_height: float = maxf(
		font.get_height(_kinds.get_theme_font_size(&"font_size")),
		float(_kinds.get_theme_icon(&"checked").get_height())
	) + _kinds.get_theme_constant(&"v_separation")
	_kinds.custom_minimum_size.y = rows * row_height + FILTER_PADDING


## Ticks each kind its filter allows; a group is ticked when all its kinds are, and shown
## part-ticked when only some are.
func _update_checks() -> void:
	var root: TreeItem = _kinds.get_root()
	if root == null:
		return
	for heading: TreeItem in root.get_children():
		var allowed: int = 0
		for row: TreeItem in heading.get_children():
			var on: bool = station.allowed_kinds.has(row.get_metadata(0) as StorageKind)
			row.set_checked(0, on)
			if on:
				allowed += 1
		var count: int = heading.get_child_count()
		heading.set_checked(0, allowed == count)
		heading.set_indeterminate(0, allowed > 0 and allowed < count)


## A checkbox was clicked: a kind's, or a group's (all its kinds the station can keep).
func _on_kind_edited() -> void:
	var edited: TreeItem = _kinds.get_edited()
	if edited == null:
		return
	var allowed: bool = edited.is_checked(0)
	var kinds: Array[StorageKind] = []
	if edited.get_metadata(0) is StorageKind:
		kinds.append(edited.get_metadata(0) as StorageKind)
	else:
		for row: TreeItem in edited.get_children():
			if row.is_editable(0):
				kinds.append(row.get_metadata(0) as StorageKind)
	filter_change_requested.emit(station, kinds, allowed)
	# Shown from the station's filter, so the boxes match what was actually allowed.
	_update_checks.call_deferred()


func _request_all(allowed: bool) -> void:
	var kinds: Array[StorageKind] = []
	for kind: StorageKind in station.get_storable_kinds():
		if station.can_store(kind):
			kinds.append(kind)
	filter_change_requested.emit(station, kinds, allowed)
	_update_checks()

#endregion
