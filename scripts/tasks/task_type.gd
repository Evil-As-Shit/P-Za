class_name TaskType
extends Resource
## A kind of work pawns can do (assembly, oven, boxing...).

@export var id: StringName
@export var display_name: String
## Seconds of work at normal speed. Skill and mood will scale this later.
@export var base_work_time: float = 5.0
## Optional art drawn under and over the item while this task is worked (e.g. an open
## box around the pizza). Same frame layout as the item's own textures.
@export var item_under_texture: Texture2D
@export var item_over_texture: Texture2D
