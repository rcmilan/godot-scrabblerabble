class_name TileState
extends RefCounted

## Immutable value object representing a tile's domain state.
## All mutations return new instances.

var _letter: String
var _base_points: int
var _modifiers: ModifierCollection
var _location: int  # Tile.TileLocation enum value


func _init(letter: String, base_points: int, modifiers: ModifierCollection, location: int = 0) -> void:
	_letter = letter
	_base_points = base_points
	_modifiers = modifiers if modifiers else ModifierCollection.empty()
	_location = location


static func create(letter: String, base_points: int) -> TileState:
	return TileState.new(letter, base_points, ModifierCollection.empty())


# === Getters ===

func get_letter() -> String:
	return _letter


func get_base_points() -> int:
	return _base_points


func get_modifiers() -> ModifierCollection:
	return _modifiers


func get_location() -> int:
	return _location


# === Derived Queries ===

func is_locked() -> bool:
	return _modifiers.has(ModifierTypes.Type.LOCKED)


func get_points() -> int:
	var result: Dictionary = ModifierScoring.compute_tile_score(_base_points, _modifiers.to_dictionary())
	return result.score


func has_modifier(type: ModifierTypes.Type) -> bool:
	return _modifiers.has(type)


# === Immutable Mutations ===

func with_modifier(modifier: ModifierInstance) -> TileState:
	return TileState.new(_letter, _base_points, _modifiers.with_added(modifier), _location)


func without_modifier(type: ModifierTypes.Type) -> TileState:
	return TileState.new(_letter, _base_points, _modifiers.without(type), _location)


func with_location(new_location: int) -> TileState:
	return TileState.new(_letter, _base_points, _modifiers, new_location)


func with_consumed_modifiers() -> TileState:
	return TileState.new(_letter, _base_points, _modifiers.without_consumables(), _location)


func with_cleared_round_modifiers() -> TileState:
	return TileState.new(_letter, _base_points, _modifiers.without_round_modifiers(), _location)


func with_modifiers(new_modifiers: ModifierCollection) -> TileState:
	return TileState.new(_letter, _base_points, new_modifiers, _location)
