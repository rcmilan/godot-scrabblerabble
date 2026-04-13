class_name AnimationCategorizer
extends RefCounted

## Pure service that categorizes tiles by animation type using a data-driven mapping.
## Default mapping: EXTRA/MULTI/EXPO → "spin"; all others → "stomp".
## Mapping is provided by caller (HypeConfig) rather than hardcoded.

## Modifier types that trigger spin animation (fallback when mapping not provided).
const SPIN_TYPES: Array[int] = [
	ModifierTypes.Type.EXTRA,
	ModifierTypes.Type.MULTI,
	ModifierTypes.Type.EXPO,
]


## Categorizes tiles into animation groups based on provided mapping.
## If mapping is empty, uses legacy hardcoded categorization (SPIN_TYPES -> "spin", others -> default).
## mapping: Dictionary mapping modifier type strings to animation preset names (e.g., {"EXTRA": "spin"})
## default_animation: Fallback animation type for tiles without explicit mapping
## Returns: Dictionary with animation type keys mapping to Array[Tile] (e.g., {"spin": [...], "stomp": [...]})
static func categorize(tiles: Array[Tile], mapping: Dictionary = {}, default_animation: String = "stomp") -> Dictionary:
	# If no mapping provided, use legacy categorization for backward compatibility
	if mapping.is_empty():
		return categorize_legacy(tiles)

	var result: Dictionary = {}

	for tile in tiles:
		var animation_type: String = _get_animation_type(tile, mapping, default_animation)

		if not result.has(animation_type):
			result[animation_type] = []
		result[animation_type].append(tile)

	return result


## Determines the animation type for a single tile.
## Uses mapping if provided, falls back to modifier-based categorization if not.
static func _get_animation_type(tile: Tile, mapping: Dictionary, default_animation: String) -> String:
	# tile.modifiers is a Dictionary; iterating it yields int enum keys directly
	for modifier_type in tile.modifiers:
		var modifier_name: String = _get_modifier_type_name(modifier_type)
		if mapping.has(modifier_name):
			return mapping[modifier_name]

	# Fallback: use default animation
	return default_animation


## Converts a ModifierTypes.Type enum value to its string name.
static func _get_modifier_type_name(type: int) -> String:
	match type:
		ModifierTypes.Type.EXTRA:
			return "EXTRA"
		ModifierTypes.Type.MULTI:
			return "MULTI"
		ModifierTypes.Type.EXPO:
			return "EXPO"
		ModifierTypes.Type.RESET:
			return "RESET"
		ModifierTypes.Type.LOCKED:
			return "LOCKED"
		_:
			return "NONE"


## Legacy method: Categorizes tiles into spin/stomp groups using hardcoded rules.
## Kept for backward compatibility. Prefer categorize() with mapping parameter.
static func categorize_legacy(tiles: Array[Tile]) -> Dictionary:
	var spin: Array[Tile] = []
	var stomp: Array[Tile] = []

	for tile in tiles:
		if _should_spin_legacy(tile):
			spin.append(tile)
		else:
			stomp.append(tile)

	return {spin = spin, stomp = stomp}


## Legacy: A tile spins if it has any spin-type modifier and no RESET.
static func _should_spin_legacy(tile: Tile) -> bool:
	if tile.has_modifier(ModifierTypes.Type.RESET):
		return false
	for type in SPIN_TYPES:
		if tile.has_modifier(type):
			return true
	return false
