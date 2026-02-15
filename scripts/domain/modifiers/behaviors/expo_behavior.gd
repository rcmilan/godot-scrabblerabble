class_name ExpoBehavior
extends ModifierBehavior

## ExpoBehavior: Exponential bonus to tile score.
## Bronze ^2, Silver ^3, Gold ^5.

const EXPONENT: Dictionary = {
	ModifierTypes.Tier.BRONZE: 2,
	ModifierTypes.Tier.SILVER: 3,
	ModifierTypes.Tier.GOLD: 5,
}


func compute(base_score: int, tier: ModifierTypes.Tier) -> int:
	var exp: int = EXPONENT.get(tier, 2)
	return int(pow(base_score, exp))


const TINTS: Dictionary = {
	ModifierTypes.Tier.BRONZE: Color(1.0, 0.55, 0.55),
	ModifierTypes.Tier.SILVER: Color(1.0, 0.7, 0.4),
	ModifierTypes.Tier.GOLD: Color(0.6, 0.4, 1.0),
}


func get_visual(tier: ModifierTypes.Tier) -> Dictionary:
	return {"tint": TINTS.get(tier, Color.WHITE), "invert": false}


func get_badge_symbol() -> String:
	return "^"
