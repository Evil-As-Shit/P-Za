class_name ItemPanel
extends PanelContainer
## HUD panel for the selected item: its name and food quality, kept up to date while it's
## open. A pizza being made shows its tier so far (see QualityRules), a finished one its
## tier; an ingredient shows the ingredients' quality. A container also shows what's left.

signal close_requested

var item: Item = null
## Returns the OrderItem being made as an item (see TicketRack.find_order_item()).
var _find_order_item: Callable
var _rules: QualityRules = null

@onready var _title: Label = %Title
@onready var _close: Button = %Close
@onready var _details: Label = %Details


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)


func setup(find_order_item: Callable, rules: QualityRules) -> void:
	_find_order_item = find_order_item
	_rules = rules


func _process(_delta: float) -> void:
	if not visible:
		return
	if item == null or not is_instance_valid(item):
		# It's gone (e.g. thrown out, or carried out by its customer).
		close_requested.emit()
		return
	_show_details()


func show_item(p_item: Item) -> void:
	item = p_item
	_show_details()
	show()


func _show_details() -> void:
	_title.text = item.get_display_name()
	var lines: PackedStringArray = []
	var order_item: OrderItem = null
	if _find_order_item.is_valid():
		order_item = _find_order_item.call(item) as OrderItem
	if order_item != null and _shows_food(order_item):
		_title.text = order_item.recipe.display_name
		lines.append(get_food_quality(order_item, _rules))
	elif _rules != null and _has_ingredients():
		lines.append("Quality: %s" % QualityRules.get_tier_name(_rules.get_tier(_rules.ingredient_score)))
	if item.ingredient != null:
		var kind: StorageKind = item.ingredient.full_kind
		lines.append("%s: %d left" % [kind.display_name if kind != null else "Units", item.get_units().size()])
	if item.portions != null:
		var kind: StorageKind = item.portions.full_kind
		lines.append("%s: %d/%d" % [
			kind.display_name if kind != null else "Portions", item.portions_left, item.portions.portions
		])
	_details.text = "\n".join(lines)
	_details.visible = not lines.is_empty()


## The order item's quality: its tier once finished, else its tier so far.
static func get_food_quality(order_item: OrderItem, rules: QualityRules) -> String:
	if order_item.quality_tier >= 0:
		return "Quality: %s" % QualityRules.get_tier_name(order_item.quality_tier)
	if rules == null:
		return "Quality so far: ?"
	return "Quality so far: %s" % QualityRules.get_tier_name(rules.get_tier(rules.get_score(order_item)))


## True if the selected item is the food (or holds it, or is inside it), not just its
## empty box.
func _shows_food(order_item: OrderItem) -> bool:
	var food: Item = order_item.item
	return food != null and (_is_in(item, food) or _is_in(food, item))


## True if `inner` is `outer` or inside it.
static func _is_in(inner: Item, outer: Item) -> bool:
	var each: Item = inner
	while each != null:
		if each == outer:
			return true
		each = each.container
	return false


func _has_ingredients() -> bool:
	if item.is_ingredient:
		return true
	if item.ingredient != null:
		return not item.get_units().is_empty()
	return item.portions != null and item.portions_left > 0
