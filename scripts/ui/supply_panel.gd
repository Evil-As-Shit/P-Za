class_name SupplyPanel
extends PanelContainer
## Supplies: each item's stock in the shop and the target deliveries top it up to, with
## buttons to lower or raise the target by one case, and the day of the next delivery.
## Reports the player's target changes.

signal target_change_requested(supply: SupplyItem, target: int)

@onready var _rows: GridContainer = %Rows
@onready var _next: Label = %NextDelivery

var _deliveries: Deliveries
var _stock_labels: Dictionary[SupplyItem, Label] = {}


## One row per supply in the catalog.
func setup(deliveries: Deliveries) -> void:
	_deliveries = deliveries
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_stock_labels.clear()
	for supply: SupplyItem in deliveries.catalog.items:
		var name_label := Label.new()
		name_label.text = supply.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(name_label)
		var stock := Label.new()
		stock.custom_minimum_size = Vector2(120, 0)
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stock.tooltip_text = "In the shop / target (%s)" % supply.unit_name
		stock.mouse_filter = Control.MOUSE_FILTER_PASS
		_rows.add_child(stock)
		_stock_labels[supply] = stock
		for step: int in [-1, 1]:
			var button := Button.new()
			button.text = "-" if step < 0 else "+"
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(22, 0)
			button.tooltip_text = "%s the target by one case (%d %s)" % [
				"Lower" if step < 0 else "Raise", supply.units_per_case, supply.unit_name]
			button.pressed.connect(_on_step_pressed.bind(supply, step))
			_rows.add_child(button)


## Shows each supply's stock and target, and the next delivery after `day`.
func refresh(day: int) -> void:
	if _deliveries == null:
		return
	for supply: SupplyItem in _stock_labels:
		_stock_labels[supply].text = "%d / %d %s" % [
			_deliveries.get_stock(supply), _deliveries.get_target(supply), supply.unit_name]
	var next_day: int = _deliveries.get_next_delivery_day(day)
	_next.text = "Next delivery: %s, Day %d" % [ShopClock.get_weekday_name(next_day), next_day] \
		if next_day > 0 else "No deliveries"


func _on_step_pressed(supply: SupplyItem, step: int) -> void:
	var target: int = _deliveries.get_target(supply) + step * supply.units_per_case
	target_change_requested.emit(supply, maxi(target, 0))
