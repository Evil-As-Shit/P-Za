extends SceneTree
## Generates isometric storage items: supply cases, cheese bags, #10 cans.
## Run: godot --headless --path . --script res://Assets/Sprites/placeholder/gen_iso_items.gd
## Each frame is a 32x32 cell; the item's base center sits at (16, 24).

const CELL := Vector2i(32, 32)
const ANCHOR := Vector2(16.0, 24.0)
const OUT := "res://Assets/Sprites/placeholder/"

const BOX := [Color8(138, 106, 72), Color8(176, 138, 98), Color8(208, 170, 135), Color8(232, 207, 160)]
const CHEESE := [Color8(176, 122, 30), Color8(232, 176, 48), Color8(255, 217, 90), Color8(255, 244, 194)]
const STEEL := [Color8(107, 111, 128), Color8(155, 173, 183), Color8(188, 198, 207), Color8(223, 231, 234)]
const SAUCE := [Color8(74, 8, 8), Color8(129, 0, 0), Color8(165, 62, 46), Color8(240, 122, 90)]
const LEAF := [Color8(24, 69, 42), Color8(47, 122, 52), Color8(95, 176, 74), Color8(168, 224, 122)]
const STONE := [Color8(100, 89, 73), Color8(123, 112, 93), Color8(170, 154, 128), Color8(221, 210, 184)]
const BLUE := [Color8(27, 63, 110), Color8(40, 120, 170), Color8(99, 155, 255), Color8(203, 219, 252)]
const DOUGH := [Color8(168, 100, 46), Color8(217, 148, 78), Color8(243, 192, 144), Color8(245, 230, 200)]
const WOOD := [Color8(86, 54, 28), Color8(118, 74, 38), Color8(147, 95, 50), Color8(174, 122, 68)]
const WHITE := Color8(255, 255, 255)

var _shape: Callable  # (Vector3) -> float, <= 0 inside
var _paint: Callable  # (Vector3 hit, Vector3 normal, int shade) -> Color


func _init() -> void:
	_cases()
	_cheese_bag()
	_cans()
	quit()


# --- rendering ---------------------------------------------------------------

func _render(img: Image, cell: Vector2i) -> void:
	var hits := {}
	for py: int in CELL.y:
		for px: int in CELL.x:
			var dx: float = px + 0.5 - ANCHOR.x
			var dy: float = py + 0.5 - ANCHOR.y
			# Screen pixel = line (u0+t, t, z0+t); the viewer is at +t.
			var u0: float = dx
			var z0: float = dx * 0.5 - dy
			var t: float = 30.0
			while t > -30.0:
				var p := Vector3(u0 + t, t, z0 + t)
				if _shape.call(p) <= 0.0:
					hits[Vector2i(px, py)] = p
					break
				t -= 0.02
	# Drop lone pixels hanging off the bottom of the silhouette.
	for key: Vector2i in hits.keys():
		if not (hits.has(key + Vector2i.LEFT) or hits.has(key + Vector2i.RIGHT) or hits.has(key + Vector2i.DOWN)):
			hits.erase(key)
	for key: Vector2i in hits:
		var p: Vector3 = hits[key]
		var n := _normal(p)
		var shade: int
		if n.z > 0.6:
			shade = 3
		else:
			var light: float = Vector2(n.x, n.y).normalized().dot(Vector2(0.35, 1.0).normalized())
			shade = 2 if light > 0.25 else 1
		var c: Color = _paint.call(p, n, shade)
		# Outline the silhouette's lower and side edges with the darkest shade.
		var edge := false
		for off: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			if not hits.has(key + off):
				edge = true
		if edge and c.a > 0.0:
			c = c.darkened(0.3)
		img.set_pixel(cell.x * CELL.x + key.x, cell.y * CELL.y + key.y, c)


func _normal(p: Vector3) -> Vector3:
	var e: float = 0.15
	var n := Vector3(
		_shape.call(p + Vector3(e, 0, 0)) - _shape.call(p - Vector3(e, 0, 0)),
		_shape.call(p + Vector3(0, e, 0)) - _shape.call(p - Vector3(0, e, 0)),
		_shape.call(p + Vector3(0, 0, e)) - _shape.call(p - Vector3(0, 0, e)))
	return n.normalized()


func _new_sheet(frames: int, rows: int = 1) -> Image:
	return Image.create_empty(CELL.x * frames, CELL.y * rows, false, Image.FORMAT_RGBA8)


static func _hash(x: int, y: int, seed: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + seed * 982451653) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 1000.0


# --- supply case ------------------------------------------------------------
# A taped cardboard case, 16x8 footprint (a quarter cell), 9 px tall.
# One frame per supply band: cheese, flat boxes, sauce, dough.

const CASE_U := 4.0
const CASE_V := 4.0
const CASE_H := 9.0


func _cases() -> void:
	var bands := [CHEESE, WOOD, SAUCE, STEEL]
	var img := _new_sheet(bands.size())
	_shape = func(p: Vector3) -> float:
		return maxf(maxf(absf(p.x) - CASE_U, absf(p.y) - CASE_V), maxf(p.z - CASE_H, -p.z))
	for i: int in bands.size():
		var band: Array = bands[i]
		_paint = func(p: Vector3, n: Vector3, shade: int) -> Color:
			if shade == 3:
				# Tape seam along the top, and the flap seam across it.
				if absf(p.y) < 0.9:
					return BOX[1]
				return BOX[3]
			var top_edge: bool = p.z > CASE_H - 1.0
			if top_edge and absf(p.y) < 0.9:
				return BOX[1]  # tape runs down the end
			if p.z > 3.0 and p.z < 6.0:
				return band[shade]
			if top_edge:
				return BOX[shade + 1] if shade < 3 else BOX[3]
			return BOX[shade]
		_render(img, Vector2i(i, 0))
	img.save_png(OUT + "supply_case_sheet.png")


# --- cheese bag -------------------------------------------------------------
# A pillowy bag of shredded cheese lying flat, 20x10 footprint, 4 px tall,
# with clear crimped seals at both ends and a blue label.

const BAG_U := 7.5
const BAG_V := 4.5
const BAG_H := 5.0


func _cheese_bag() -> void:
	var img := _new_sheet(1)
	_shape = func(p: Vector3) -> float:
		var zn: float = clampf(p.z / BAG_H, 0.0, 1.0)
		var shrink: float = 1.0 - 0.35 * pow(absf(zn * 2.0 - 1.0), 2.0)
		var ru: float = p.x / (BAG_U * shrink)
		var rv: float = p.y / (BAG_V * shrink)
		var d: float = pow(pow(absf(ru), 4.0) + pow(absf(rv), 4.0), 0.25) - 1.0
		return maxf(d * 3.0, maxf(p.z - BAG_H, -p.z))
	_paint = func(p: Vector3, n: Vector3, shade: int) -> Color:
		if absf(p.x) > BAG_U - 1.3:
			return STEEL[mini(shade, 3)]  # crimped seal
		if shade == 3:
			if p.x > -3.5 and p.x < 1.5 and absf(p.y) < 3.0:
				if absf(p.y) < 0.9:
					return WHITE
				return BLUE[2]
			var r: float = _hash(roundi(p.x * 2.0), roundi(p.y * 2.0), 7)
			if r < 0.25:
				return CHEESE[1]
			if r < 0.6:
				return CHEESE[2]
			return CHEESE[3]
		return CHEESE[shade]
	_render(img, Vector2i(0, 0))
	img.save_png(OUT + "cheese_bag.png")


# --- #10 cans ---------------------------------------------------------------
# Large food-service cans, 14x7 footprint, 12 px tall, steel rims and lid.
# One frame per label color: red, green, tan, yellow.

const CAN_R := 5.0
const CAN_H := 12.0


func _cans() -> void:
	var labels := [SAUCE, LEAF, STONE, CHEESE]
	var img := _new_sheet(labels.size())
	_shape = func(p: Vector3) -> float:
		return maxf(Vector2(p.x, p.y).length() - CAN_R, maxf(p.z - CAN_H, -p.z))
	for i: int in labels.size():
		var label: Array = labels[i]
		_paint = func(p: Vector3, n: Vector3, shade: int) -> Color:
			if shade == 3:
				var r: float = Vector2(p.x, p.y).length()
				if r > CAN_R - 0.9:
					return STEEL[3]  # rim
				if r > CAN_R - 1.7:
					return STEEL[1]  # lid groove
				return STEEL[2]
			if p.z > CAN_H - 1.5 or p.z < 1.2:
				return STEEL[shade]
			# The label: a cream panel facing front-left, color elsewhere.
			var ang: float = atan2(p.y, p.x)  # 0 = down-right, PI/2 = down-left
			if p.z > 4.0 and p.z < 9.0 and ang > PI * 0.15 and ang < PI * 0.55:
				return WHITE if shade == 2 else DOUGH[3]
			var lit: float = Vector2(n.x, n.y).normalized().dot(Vector2(0.35, 1.0).normalized())
			var tone: int = 3 if lit > 0.85 else (2 if lit > 0.1 else 1)
			if p.z > 9.8 or p.z < 2.6:
				return label[maxi(tone - 1, 0)]
			return label[tone]
		_render(img, Vector2i(i, 0))
	img.save_png(OUT + "can_10_sheet.png")

