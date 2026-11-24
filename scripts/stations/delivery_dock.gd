class_name DeliveryDock
extends Resource
## Makes a station a delivery drop-off (e.g. the delivery pallet): deliveries set supply
## cases on it and Hauling pawns put them away (see HaulCaseBehavior). Its cases are kept
## by the station's DockCases node.

## Cases it holds (placeholder).
@export var capacity: int = 12
## Pile positions, given like StorageLayout.piles: map-grid offsets from the origin cell's
## floor center at facing 0 (in cells), and z the height in pixels above the floor.
@export var piles: Array[Vector3] = [Vector3.ZERO]
## Pixels each stacked case sits above the one below it.
@export var pile_step: float = 4.0


## Cases per pile, so `capacity` cases fill the piles evenly.
func get_per_pile() -> int:
	return ceili(float(capacity) / maxf(piles.size(), 1.0))
