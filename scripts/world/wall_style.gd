class_name WallStyle
extends Resource
## Art for one kind of wall. Walls sit on the edges between floor cells: a cell's back-left
## and back-right edges are back walls, its front edges front walls. Every piece comes in a
## full-height and a short version (for cutaway views).

@export_group("Full height")
@export var back_left: WallPiece
@export var back_right: WallPiece
## Both back edges of one cell, joined.
@export var back_corner: WallPiece
@export var front_left: WallPiece
@export var front_right: WallPiece
## Both front edges of one cell, joined.
@export var front_corner: WallPiece
## Front-left wall where it meets a back-left wall (the room's left corner), with a cap.
@export var left_corner: WallPiece
## Front-right wall where it meets a back-right wall (the room's right corner), with a cap.
@export var right_corner: WallPiece

@export_group("Short")
@export var back_left_short: WallPiece
@export var back_right_short: WallPiece
@export var back_corner_short: WallPiece
@export var front_left_short: WallPiece
@export var front_right_short: WallPiece
@export var front_corner_short: WallPiece
@export var left_corner_short: WallPiece
@export var right_corner_short: WallPiece
