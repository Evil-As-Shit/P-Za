class_name IngredientContainer
extends Resource
## A container that holds several units of one ingredient (e.g. a tub of dough balls).
## Full ones are stored with lids on, set out on a work station, and emptied one unit at a
## time; empty ones go to storage for empties.

@export var display_name: String
## Storage kind for full containers (e.g. Dough).
@export var full_kind: StorageKind
## Storage kind for empty containers (e.g. Empty Dough), the overflow while no dish sink
## has room.
@export var empty_kind: StorageKind
## An empty one as a dish: washed at a dish sink, then put away full again.
@export var dish: Dish
## Container art, in the item frame layout: drawn under the units, over them, and the lid.
@export var back_texture: Texture2D
@export var front_texture: Texture2D
@export var lid_texture: Texture2D
## How one unit looks while it's in the container.
@export var unit_texture: Texture2D
## Where each unit sits, relative to the container, back to front. One unit per entry.
@export var unit_offsets: Array[Vector2] = []
