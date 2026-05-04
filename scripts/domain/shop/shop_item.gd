extends RefCounted
class_name ShopItem

## Represents one purchasable slot in the shop grid.
## Pure value object with no Godot node base (per Constitution Principle I).
## Immutable after construction (per Principle III).

enum Type { EXE = 0, DLL = 1, BAT = 2 }

var type: Type
var index: int

func _init(p_type: Type, p_index: int) -> void:
	type = p_type
	index = p_index

static func create(p_type: Type, p_index: int) -> ShopItem:
	return ShopItem.new(p_type, p_index)
