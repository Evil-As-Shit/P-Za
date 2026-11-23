class_name DishSink
extends Resource
## Makes a station a dish sink (see StationData.dish_sink): which spots are its dirty
## drainboard, its basins and its clean drainboard, and how many dishes each board holds.
## Dishes are washed in batches: every dish on the dirty board (as many as fit on the clean
## board) is washed, then rinsed, then sanitized, one basin after another.

## Spot whose drainboard holds dishes waiting to be washed.
@export var dirty_spot: int = 0
## Basin spots in the order a batch goes through them (wash, rinse, sanitize).
@export var basin_spots: Array[int] = [1, 2, 3]
## Spot whose drainboard holds washed dishes until they're put away.
@export var clean_spot: int = 4
## Dishes each drainboard holds (placeholder).
@export var board_capacity: int = 6
## Pixels each dish in a drainboard pile sits above the one below it.
@export var pile_step: float = 2.0
