class_name WallStyle
extends Resource
## Art for one kind of wall. Walls sit on the edges between floor cells. Each texture comes
## with the position of its top-left corner relative to the center of the cell it borders.
## Back walls are the cell's back-left and back-right edges; front walls its front edges.

@export_group("Back")
@export var back_left: Texture2D
@export var back_left_offset: Vector2
@export var back_right: Texture2D
@export var back_right_offset: Vector2
## Both back edges of one cell, joined.
@export var back_corner: Texture2D
@export var back_corner_offset: Vector2

@export_group("Front")
@export var front_left: Texture2D
@export var front_left_offset: Vector2
@export var front_right: Texture2D
@export var front_right_offset: Vector2
## Both front edges of one cell, joined.
@export var front_corner: Texture2D
@export var front_corner_offset: Vector2

@export_group("Front, cut away")
## Short front walls, so the room behind them can be seen.
@export var front_left_cut: Texture2D
@export var front_left_cut_offset: Vector2
@export var front_right_cut: Texture2D
@export var front_right_cut_offset: Vector2
