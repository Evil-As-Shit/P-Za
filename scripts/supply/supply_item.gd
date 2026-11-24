class_name SupplyItem
extends Resource
## Something the shop buys by delivery (e.g. cheese bags): what a case of it holds, where
## it's put away and what it costs. Deliveries top it up to the player's target (see
## Deliveries).

@export var display_name: String
## What its stock is counted in, plural (e.g. "bags", "portions").
@export var unit_name: String
## Storage a case is put away in (e.g. Cheese), one unit at a time. Leave empty for a bulk
## supply.
@export var storage_kind: StorageKind
## Station type a case is poured into (e.g. the bulk sauce bucket; see BulkTub). Leave
## empty for one that's stored.
@export var bulk_station: StationData
## Units in one delivered case (placeholder).
@export var units_per_case: int = 1
## Portions in one unit (e.g. 10 in a cheese bag), for its price.
@export var portions_per_unit: int = 1
## Price of one portion (placeholder).
@export var price_per_portion: float = 0.0
## A case's art, in the item frame layout.
@export var case_texture: Texture2D


## What one delivered case costs.
func get_case_price() -> float:
	return units_per_case * portions_per_unit * price_per_portion


## True if `station` is where this supply's units are kept (its storage or its bulk tub).
func is_kept_at(station: Station) -> bool:
	if bulk_station != null:
		return station.data == bulk_station
	return storage_kind != null and station.get_stored_kind() == storage_kind


## Units of it kept at `station` (stored units, or portions in its bulk tub).
func get_units_at(station: Station) -> int:
	if not is_kept_at(station):
		return 0
	return station.get_bulk_left() if bulk_station != null else station.get_stock()


## Units `station` holds when full.
func get_capacity_at(station: Station) -> int:
	if not is_kept_at(station):
		return 0
	return station.get_bulk_capacity() if bulk_station != null else station.get_capacity()


## True if `station` has unpromised room for one whole case.
func has_room_for_case(station: Station) -> bool:
	if not is_kept_at(station):
		return false
	if bulk_station != null:
		return station.get_bulk_room() >= units_per_case
	return station.get_free_room() >= units_per_case
