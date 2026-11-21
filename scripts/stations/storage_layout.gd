class_name StorageLayout
extends Resource
## How one kind of stored thing (e.g. boxes, dough containers) is stacked on a station type:
## where its piles stand, how tall they get and how each unit looks.

## Kind stored, matching StationRole.stores (e.g. Boxes).
@export var kind: StorageKind
## One unit's art, drawn in order (e.g. a container's back, front and lid), in the item
## frame layout.
@export var textures: Array[Texture2D] = []
## If true, there's one pile on each spot, where items sit (tables). Otherwise the piles
## stand at `piles` and `piles_on_top` (racks).
@export var piles_at_spots: bool = false
## Pile positions drawn under the station's cover, back to front, relative to the origin
## cell's floor center.
@export var piles: Array[Vector2] = []
## Pile positions drawn over the cover (e.g. on a top shelf), back to front.
@export var piles_on_top: Array[Vector2] = []
@export var per_pile: int = 3
## Optional units per pile, in pile order (inside piles, then on-top piles). Overrides
## per_pile for piles it covers.
@export var pile_sizes: Array[int] = []
## Pixels each stacked unit sits above the one below it.
@export var pile_step: float = 2.0
## Placeholder until deliveries: the station starts full when assigned this storage, and
## refills the moment it runs out.
@export var starts_full: bool = false
## Placeholder until a cleaning station: the station is cleared the moment it fills up.
@export var clears_when_full: bool = false


## Units pile `pile` holds (inside piles first, then on-top piles).
func get_pile_size(pile: int) -> int:
	return pile_sizes[pile] if pile < pile_sizes.size() else per_pile
