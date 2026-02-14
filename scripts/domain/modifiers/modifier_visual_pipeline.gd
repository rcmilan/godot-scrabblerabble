class_name ModifierVisualPipeline
extends RefCounted

## ModifierVisualPipeline: Determines visual representation for tile modifiers.
## Uses the same priority-sorted pipeline as ModifierScoring.
## The highest-priority modifier present determines the visual output.
## Reset (0) → Extra (10) → Multi (20).

## Default visual when no modifiers are present.
const DEFAULT_VISUAL: Dictionary = {"tint": Color.WHITE, "invert": false}


static func compute_tile_visual(modifiers: Dictionary) -> Dictionary:
	if modifiers.is_empty():
		return DEFAULT_VISUAL

	# Collect modifier instances and sort by behavior priority (same as scoring)
	var sorted: Array[ModifierInstance] = []
	for mod in modifiers.values():
		if mod is ModifierInstance and mod.behavior != null:
			sorted.append(mod)

	if sorted.is_empty():
		return DEFAULT_VISUAL

	sorted.sort_custom(func(a: ModifierInstance, b: ModifierInstance) -> bool:
		return a.behavior.get_priority() < b.behavior.get_priority()
	)

	# The highest-priority modifier determines the visual
	var primary: ModifierInstance = sorted[sorted.size() - 1]
	return primary.behavior.get_visual()
