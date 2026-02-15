class_name ResetBehavior
extends ModifierBehavior

## ResetBehavior: Denies all other modifiers — tile scores its base points only.
## Runs first in pipeline; when present, all subsequent modifiers are skipped.

func compute(base_score: int, _tier: ModifierTypes.Tier) -> int:
	return base_score


func get_visual(_tier: ModifierTypes.Tier) -> Dictionary:
	return {"tint": Color.WHITE, "invert": true}
