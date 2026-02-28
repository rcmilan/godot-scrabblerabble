## Immutable value object representing a tile's position and rotation in an arc layout.
## Returned by ArcLayoutComputer for each tile's computed transform.
## This is read-only post-construction; do not modify position or rotation_rad after creation.
class_name TileArcTransform extends RefCounted

var position: Vector2
var rotation_rad: float

func _init(pos: Vector2, rot: float) -> void:
	position = pos
	rotation_rad = rot

func _to_string() -> String:
	return "TileArcTransform(pos: %s, rot: %.2f)" % [position, rotation_rad]
