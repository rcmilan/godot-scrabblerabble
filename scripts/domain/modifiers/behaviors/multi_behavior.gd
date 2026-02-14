class_name MultiBehavior
extends ModifierBehavior

## MultiBehavior: Multiplicative bonus to tile score.
## Bronze x2, Silver x3, Gold x5. Priority 20 (applies last).

const MULTIPLIER: Dictionary = {
	ModifierTypes.Tier.BRONZE: 2,
	ModifierTypes.Tier.SILVER: 3,
	ModifierTypes.Tier.GOLD: 5,
}


func get_priority() -> int:
	return 20


func compute(base_score: int, tier: ModifierTypes.Tier) -> int:
	return base_score * MULTIPLIER.get(tier, 1)


func get_visual() -> Dictionary:
	return {"tint": Color(0.6, 0.8, 1.0), "invert": false}
