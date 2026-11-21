class_name WorkSpot
extends RefCounted
## A station spot a job could be done at.

var station: Station
var index: int


func _init(p_station: Station, p_index: int) -> void:
	station = p_station
	index = p_index


func is_same(other: WorkSpot) -> bool:
	return other != null and other.station == station and other.index == index
