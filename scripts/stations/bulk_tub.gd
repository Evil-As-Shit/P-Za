class_name BulkTub
extends Resource
## Makes a station a bulk tub (e.g. the bulk sauce bucket): it holds portions in bulk, a
## pawn fills a dish there (see Dish.filled_at) and deliveries pour cases into it. Its level
## is kept by the station (see Station.get_bulk_left()).

## Portions it holds when full (placeholder).
@export var capacity: int = 100
## Portions one fill takes (e.g. one sauce bucket's 20).
@export var per_fill: int = 20
