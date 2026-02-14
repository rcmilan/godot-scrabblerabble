class_name ModifierBehavior
extends RefCounted

## ModifierBehavior: Strategy base class for modifier scoring behaviors.
## Subclasses override compute() for scoring and get_visual() for display.

func compute(base_score: int, _tier: ModifierTypes.Tier) -> int:
	return base_score


## Returns visual properties for this modifier type.
## Override in subclasses to define tint color and effects.
func get_visual(_tier: ModifierTypes.Tier) -> Dictionary:
	return {"tint": Color.WHITE, "invert": false}


## Returns the badge symbol for this modifier type.
## Override in subclasses. Empty string = no badge.
func get_badge_symbol() -> String:
	return ""
