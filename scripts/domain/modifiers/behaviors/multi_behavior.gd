class_name MultiBehavior
extends ModifierBehavior

## MultiBehavior: Multiplicative bonus to tile score.
## Bronze x2, Silver x5, Gold x10.

const MULTIPLIER: Dictionary = {
	ModifierTypes.Tier.BRONZE: 2,
	ModifierTypes.Tier.SILVER: 5,
	ModifierTypes.Tier.GOLD: 10,
}

const TINTS: Dictionary = {
	ModifierTypes.Tier.BRONZE: Color(0.6, 0.8, 1.0),
	ModifierTypes.Tier.SILVER: Color(0.5, 0.65, 1.0),
	ModifierTypes.Tier.GOLD: Color(0.35, 0.5, 1.0),
}


func compute(base_score: int, tier: ModifierTypes.Tier) -> int:
	return base_score * MULTIPLIER.get(tier, 1)


func get_visual(tier: ModifierTypes.Tier) -> Dictionary:
	return {"tint": TINTS.get(tier, Color.WHITE), "invert": false}


func get_badge_symbol() -> String:
	return "x"
