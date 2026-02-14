class_name ModifierBehavior
extends RefCounted

## ModifierBehavior: Strategy base class for modifier scoring behaviors.
## Subclasses override compute() to apply their effect to a tile's base score.

func get_priority() -> int:
	return 0


func compute(base_score: int, _tier: ModifierTypes.Tier) -> int:
	return base_score
