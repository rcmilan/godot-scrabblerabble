class_name ModifierScoring
extends RefCounted

## ModifierScoring: Pure scoring pipeline for tile modifiers.
## Sorts modifiers by priority and applies them in order.
## Reset (0) → Extra (10) → Multi (20).

static func compute_tile_score(base_score: int, modifiers: Dictionary) -> Dictionary:
	if modifiers.is_empty():
		return {"score": base_score, "modifiers_applied": []}

	# Collect modifier instances and sort by behavior priority
	var sorted: Array[ModifierInstance] = []
	for mod in modifiers.values():
		if mod is ModifierInstance and mod.behavior != null:
			sorted.append(mod)

	sorted.sort_custom(func(a: ModifierInstance, b: ModifierInstance) -> bool:
		return a.behavior.get_priority() < b.behavior.get_priority()
	)

	var score: int = base_score
	var applied: Array[Dictionary] = []

	for mod in sorted:
		var before: int = score
		score = mod.behavior.compute(score, mod.tier)
		applied.append({
			"type": mod.type,
			"tier": mod.tier,
			"before": before,
			"after": score,
		})

	return {"score": score, "modifiers_applied": applied}
