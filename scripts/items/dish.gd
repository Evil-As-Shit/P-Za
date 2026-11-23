class_name Dish
extends Resource
## Something that gets dirty and is washed at a dish sink (e.g. an empty dough container).
## On the sink it's only counted and drawn in the drainboard piles; while carried it's an
## item.

@export var display_name: String
## Pile art on the drainboards, in the item frame layout: drawn under and over (e.g. a
## container's back and front).
@export var back_texture: Texture2D
@export var front_texture: Texture2D
## Tint while dirty (placeholder until dirty art).
@export var dirty_tint: Color = Color(0.75, 0.66, 0.55)
## Where a clean one is put away; it's stored there as a full unit (e.g. a dough container
## goes back to Dough storage, refilled).
@export var put_away_kind: StorageKind
## Station type it's filled at on its way to storage (e.g. a sauce bucket at the bulk sauce
## bucket), or null if it goes straight there.
@export var filled_at: StationData
