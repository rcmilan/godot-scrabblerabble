class_name ModifierVisualPipeline
extends RefCounted

## ModifierVisualPipeline: Determines visual representation for tile modifiers.
## Uses ModifierPipeline.execution_order for consistent badge ordering.
## Reset dominates everything (invert, no badges).

static func compute_tile_visual(modifiers: Dictionary) -> Dictionary:
	if modifiers.is_empty():
		return {"tint": Color.WHITE, "invert": false, "badges": []}

	# Reset dominates everything
	if modifiers.has(ModifierTypes.Type.RESET):
		return {"tint": Color.WHITE, "invert": true, "badges": []}

	# Tint: first non-white tint in pipeline order
	var tint: Color = Color.WHITE
	for type in ModifierPipeline.execution_order:
		if type == ModifierTypes.Type.RESET:
			continue
		if not modifiers.has(type):
			continue
		var mod: ModifierInstance = modifiers[type]
		if mod.behavior == null:
			continue
		var mod_tint: Color = mod.behavior.get_visual(mod.tier).tint
		if mod_tint != Color.WHITE:
			tint = mod_tint
			break

	# Badges in pipeline order (skip Reset, skip empty symbols)
	var badges: Array[Dictionary] = []
	for type in ModifierPipeline.execution_order:
		if type == ModifierTypes.Type.RESET:
			continue
		if not modifiers.has(type):
			continue
		var mod: ModifierInstance = modifiers[type]
		if mod.behavior == null:
			continue
		var symbol: String = mod.behavior.get_badge_symbol()
		if not symbol.is_empty():
			badges.append({"symbol": symbol, "tier": mod.tier, "type": type})

	return {"tint": tint, "invert": false, "badges": badges}
