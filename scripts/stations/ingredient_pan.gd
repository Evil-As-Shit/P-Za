class_name IngredientPan
extends Resource
## An ingredient pan built into a station (e.g. the prep table's cheese pan). A task takes
## portions from it (see PanBehavior); when it runs low, a pawn refills it in place from a
## bag in storage (see RefillPanBehavior). How much is left is kept by the station.

@export var display_name: String
## Portions in a full pan (placeholder).
@export var portions: int = 10
## Refilled once this many portions or fewer are left (placeholder).
@export var refill_at: int = 3
## Storage the bags come from (e.g. Cheese). One bag fills it.
@export var bag_kind: StorageKind
## A bag while carried, in the item frame layout.
@export var bag_texture: Texture2D
## Shop minutes to refill it (placeholder).
@export var refill_minutes: float = 0.25
