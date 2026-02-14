class_name ModifierScoring
extends RefCounted

## ModifierScoring: Pure scoring pipeline for tile modifiers.
## Iterates through ModifierPipeline.execution_order to apply modifiers.

static func compute_tile_score(base_score: int, modifiers: Dictionary) -> Dictionary:
	if modifiers.is_empty():
		return {"score": base_score, "modifiers_applied": []}

	var score: int = base_score
	var applied: Array[Dictionary] = []

	for type in ModifierPipeline.execution_order:
		if not modifiers.has(type):
			continue
		var mod: ModifierInstance = modifiers[type]
		if mod.behavior == null:
			continue
		var before: int = score
		score = mod.behavior.compute(score, mod.tier)
		applied.append({"type": mod.type, "tier": mod.tier, "before": before, "after": score})

	return {"score": score, "modifiers_applied": applied}
