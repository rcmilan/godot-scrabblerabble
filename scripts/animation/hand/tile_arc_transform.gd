class_name TileArcTransform extends RefCounted

var position: Vector2
var rotation_rad: float

func _init(pos: Vector2, rot: float) -> void:
	position = pos
	rotation_rad = rot
