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
## Pile positions drawn under the station's cover. x and y are map-grid offsets from the
## origin cell's floor center at facing 0 (in cells, rotated with the station, like
## StationSpot cells); z is the height in pixels above the floor. Drawn back to front
## whatever the order.
@export var piles: Array[Vector3] = []
## Pile positions drawn over the cover (e.g. on a top shelf), given like `piles`.
@export var piles_on_top: Array[Vector3] = []
@export var per_pile: int = 3
## Optional units per pile, in pile order (inside piles, then on-top piles). Overrides
## per_pile for piles it covers.
@export var pile_sizes: Array[int] = []
## Pixels each stacked unit sits above the one below it.
@export var pile_step: float = 2.0
## The starting shop's stations open with this storage full (see Station.stock_up()).
## Storage built or assigned later starts empty and is filled by deliveries or pawns.
@export var stocked_at_start: bool = false
## Units are dishes of different kinds (e.g. Empty Dishes), each drawn with its own dish's
## art (see Dish) instead of `textures`.
@export var holds_dishes: bool = false
## The station is cleared the moment it fills up (no layout uses this since the dish sink).
@export var clears_when_full: bool = false


## Units pile `pile` holds (inside piles first, then on-top piles).
func get_pile_size(pile: int) -> int:
	return pile_sizes[pile] if pile < pile_sizes.size() else per_pile
