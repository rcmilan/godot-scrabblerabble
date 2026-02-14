class_name ResetBehavior
extends ModifierBehavior

## ResetBehavior: Short-circuits tile score to 0.
## Priority 0 (runs first, before extra and multi).

func get_priority() -> int:
	return 0


func compute(_base_score: int, _tier: ModifierTypes.Tier) -> int:
	return 0


func get_visual() -> Dictionary:
	return {"tint": Color.WHITE, "invert": true}
