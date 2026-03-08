class_name AnimationCategorizer
extends RefCounted

## Pure service that categorizes tiles by animation type using a lookup table.
## Replaces the if/elif chain in PlayHandler._categorize_tiles_by_animation().

## Modifier types that trigger spin animation.
const SPIN_TYPES: Array[int] = [
	ModifierTypes.Type.EXTRA,
	ModifierTypes.Type.MULTI,
	ModifierTypes.Type.EXPO,
]


## Categorizes tiles into spin and stomp groups based on their modifiers.
## RESET and plain tiles → stomp. EXTRA/MULTI/EXPO → spin.
static func categorize(tiles: Array[Tile]) -> Dictionary:
	var spin: Array[Tile] = []
	var stomp: Array[Tile] = []

	for tile in tiles:
		if _should_spin(tile):
			spin.append(tile)
		else:
			stomp.append(tile)

	return {spin = spin, stomp = stomp}


## A tile spins if it has any spin-type modifier and no RESET (which denies spin).
static func _should_spin(tile: Tile) -> bool:
	if tile.has_modifier(ModifierTypes.Type.RESET):
		return false
	for type in SPIN_TYPES:
		if tile.has_modifier(type):
			return true
	return false
