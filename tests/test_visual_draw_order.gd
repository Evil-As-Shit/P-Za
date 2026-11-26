extends SceneTree
## Draw order around stations, checked on rendered pixels (needs a window, so the runner
## starts it without --headless).
##
## Each station is drawn at 1x zoom in a view of its own. A probe (a pawn-sized box whose
## arms reach a little past its cell, like a pawn carrying something) then stands in every
## cell up to two away from it. Wherever the probe and the station overlap on screen, the
## right one must be on top: the probe is in front when it's past the station's footprint
## along either grid axis (further down-right or further down-left), and behind otherwise.
## Diagonal neighbors (past it along one axis, short of it along the other) count as in
## front, as they do for one-cell stations. Each multi-cell station is also checked for
## gaps or doubled pixels where its strips meet.
##
## Stations: the template test boxes in tests/draw_order/ (1x1, low and tall 2x1 at both
## facings, 2x2, 3x3), and the real long table, register, prep table (3x2, lids open with
## boxes on it, both facings), box rack (full, all four facings) and pizza oven (both facings).

const STATION_SCENE := preload("res://scenes/stations/station.tscn")
const FLOOR_SCENE := preload("res://scenes/world/shop_floor.tscn")
const ITEM_SCENE := preload("res://scenes/items/item.tscn")
const BOXES := "res://tests/draw_order/"
const VIEW_SIZE := Vector2i(512, 384)
const ORIGIN := Vector2i(5, 5)
const RING: int = 2
## Probe frame: the cell's center is this far from its top-left corner.
const PROBE_CENTER := Vector2(19, 56)
## Real seconds before the test gives up (rendering can stall, e.g. with no frames drawn).
const TIMEOUT_SECONDS: float = 90.0

var _view: SubViewport
var _floor: ShopFloor
var _entities: Node2D
var _camera: Camera2D
var _probe_image: Image
var _probe: Node2D
var _failures: PackedStringArray = []
var _checked_overlaps: int = 0


func _initialize() -> void:
	_view = SubViewport.new()
	_view.size = VIEW_SIZE
	_view.disable_3d = true
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_floor = FLOOR_SCENE.instantiate()
	_floor.visible = false
	_view.add_child(_floor)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	_view.add_child(_entities)
	# The view's only camera, so it's the current one.
	_camera = Camera2D.new()
	_view.add_child(_camera)
	_camera.global_position = _floor.cell_to_global(ORIGIN + Vector2i(1, 1)).round()

	_probe_image = _load_image("probe.png")
	_probe = Node2D.new()
	var probe_sprite := Sprite2D.new()
	probe_sprite.texture = ImageTexture.create_from_image(_probe_image)
	probe_sprite.centered = false
	probe_sprite.offset = -PROBE_CENTER
	_probe.add_child(probe_sprite)
	_run.call_deferred()


## Gives up if the frames it waits for never come, so a stall fails instead of hanging.
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() / 1000.0 > TIMEOUT_SECONDS:
		print("FAIL timed out after %d s waiting for frames to draw" % TIMEOUT_SECONDS)
		quit(1)
	return false


func _run() -> void:
	var cases: Array = [
		["box 1x1", _box_data("box_1x1.png", Vector2i(1, 1), 32), 0],
		["box 2x1 low", _box_data("box_2x1_low.png", Vector2i(2, 1), 48), 0],
		["box 2x1 low", _box_data("box_2x1_low.png", Vector2i(2, 1), 48), 1],
		["box 2x1 tall", _box_data("box_2x1_tall.png", Vector2i(2, 1), 48), 0],
		["box 2x1 tall", _box_data("box_2x1_tall.png", Vector2i(2, 1), 48), 1],
		["box 2x2", _box_data("box_2x2.png", Vector2i(2, 2), 64), 0],
		["box 3x3", _box_data("box_3x3.png", Vector2i(3, 3), 96), 0],
		["long table", load("res://resources/stations/long_table.tres"), 0],
		["long table", load("res://resources/stations/long_table.tres"), 1],
		["register", load("res://resources/stations/register.tres"), 0],
		["prep table", load("res://resources/stations/pizza_prep_table.tres"), 0],
		["prep table", load("res://resources/stations/pizza_prep_table.tres"), 1],
		["box rack", load("res://resources/stations/box_rack.tres"), 3],
		["box rack", load("res://resources/stations/box_rack.tres"), 0],
		["box rack", load("res://resources/stations/box_rack.tres"), 1],
		["box rack", load("res://resources/stations/box_rack.tres"), 2],
		["pizza oven", load("res://resources/stations/pizza_oven.tres"), 0],
		["pizza oven", load("res://resources/stations/pizza_oven.tres"), 1],
	]
	var background: Image = await _capture()
	for case: Array in cases:
		await _check_station(case[0], case[1], case[2], background)
	_probe.free()
	if _failures.is_empty():
		print("PASS %d stations, %d probe overlaps checked, all in the right order" % [
			cases.size(), _checked_overlaps])
		quit(0)
	else:
		for failure: String in _failures.slice(0, 20):
			print("  ", failure)
		print("FAIL %d of %d probe overlaps in the wrong order or broken strips" % [
			_failures.size(), _checked_overlaps])
		quit(1)


func _check_station(label: String, data: StationData, facing: int, background: Image) -> void:
	var station: Station = STATION_SCENE.instantiate()
	station.data = data
	station.cell = ORIGIN
	station.facing = facing
	if label == "box rack":
		station.role = load("res://resources/station_roles/storage.tres")
	_entities.add_child(station)
	station.place(_floor)
	if label == "box rack":
		# Box storage starts empty; fill it.
		var box: StorageKind = load("res://resources/storage_kinds/box.tres")
		station.allowed_kinds = [box] as Array[StorageKind]
		while station.has_room(box):
			station.claim_room(box)
			station.add_stock(box)
	if label == "long table" or label == "prep table":
		for spot: int in station.get_spot_count():
			var box: Item = ITEM_SCENE.instantiate()
			_entities.add_child(box)
			box.set_texture(load("res://resources/items/box/closed.tres"))
			station.put_item(spot, box)
	var name: String = "%s (facing %d)" % [label, facing]
	var alone: Image = await _capture()
	if station._canvas != null:
		_check_strips(name, station, alone, background)

	var cells: Array[Vector2i] = station.get_footprint_cells()
	var low := Vector2i(cells[0])
	var high := Vector2i(cells[0])
	for c: Vector2i in cells:
		low = low.min(c)
		high = high.max(c)
	for x: int in range(low.x - RING, high.x + RING + 1):
		for y: int in range(low.y - RING, high.y + RING + 1):
			var probe_cell := Vector2i(x, y)
			if cells.has(probe_cell):
				continue
			var in_front: bool = x > high.x or y > high.y
			_entities.add_child(_probe)
			_probe.global_position = _floor.cell_to_global(probe_cell)
			var both: Image = await _capture()
			_entities.remove_child(_probe)
			_compare(name, probe_cell, in_front, alone, background, both)
	station.queue_free()
	await process_frame


## Pixels where the probe and the station overlap must show whichever is in front.
func _compare(
	name: String, probe_cell: Vector2i, in_front: bool, alone: Image, background: Image,
	both: Image
) -> void:
	var top_left: Vector2i = _to_view(_floor.cell_to_global(probe_cell)) - Vector2i(PROBE_CENTER)
	var wrong: int = 0
	var overlap: int = 0
	for py: int in _probe_image.get_height():
		for px: int in _probe_image.get_width():
			var probe_color: Color = _probe_image.get_pixel(px, py)
			if probe_color.a < 0.5:
				continue
			var at := top_left + Vector2i(px, py)
			if at.x < 0 or at.y < 0 or at.x >= VIEW_SIZE.x or at.y >= VIEW_SIZE.y:
				continue
			if alone.get_pixelv(at) == background.get_pixelv(at):
				continue
			overlap += 1
			var expected: Color = probe_color if in_front else alone.get_pixelv(at)
			if not both.get_pixelv(at).is_equal_approx(expected):
				wrong += 1
	if overlap == 0:
		return
	_checked_overlaps += 1
	if wrong > 0:
		_failures.append("%s: probe at %s should be %s, %d of %d overlapping pixels wrong" % [
			name, probe_cell, "in front" if in_front else "behind", wrong, overlap])


## The strips must show the station's canvas exactly: no gaps, nothing doubled.
func _check_strips(name: String, station: Station, alone: Image, background: Image) -> void:
	var canvas: Image = station._canvas.get_texture().get_image()
	var origin: Vector2i = _to_view(station._canvas_origin)
	var wrong: int = 0
	for y: int in canvas.get_height():
		for x: int in canvas.get_width():
			var at := origin + Vector2i(x, y)
			if at.x < 0 or at.y < 0 or at.x >= VIEW_SIZE.x or at.y >= VIEW_SIZE.y:
				continue
			var color: Color = canvas.get_pixel(x, y)
			var expected: Color = background.get_pixelv(at) if color.a < 0.5 else color
			if not alone.get_pixelv(at).is_equal_approx(Color(expected, 1.0)):
				wrong += 1
	_checked_overlaps += 1
	if wrong > 0:
		_failures.append("%s: %d pixels differ from its canvas where the strips meet" % [name, wrong])


## A test box station: one frame per facing, `frame_width` wide, from a template sheet.
func _box_data(file: String, footprint: Vector2i, frame_width: int) -> StationData:
	var sheet := ImageTexture.create_from_image(_load_image(file))
	var data := StationData.new()
	data.display_name = file.get_basename()
	data.footprint = footprint
	for facing: int in 4:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(facing * frame_width, 0, frame_width, sheet.get_height())
		data.facing_textures.append(frame)
	return data


func _load_image(file: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(BOXES + file))


func _to_view(world: Vector2) -> Vector2i:
	return Vector2i((world - _camera.global_position).round()) + VIEW_SIZE / 2


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _view.get_texture().get_image()
