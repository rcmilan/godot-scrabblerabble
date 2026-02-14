class_name ExtraBehavior
extends ModifierBehavior

## ExtraBehavior: Additive bonus to tile score.
## Bronze +2, Silver +5, Gold +10. Priority 10 (applies after reset check).

const BONUS: Dictionary = {
	ModifierTypes.Tier.BRONZE: 2,
	ModifierTypes.Tier.SILVER: 5,
	ModifierTypes.Tier.GOLD: 10,
}


func compute(base_score: int, tier: ModifierTypes.Tier) -> int:
	return base_score + BONUS.get(tier, 0)


const TINTS: Dictionary = {
	ModifierTypes.Tier.BRONZE: Color(0.85, 0.72, 0.53),
	ModifierTypes.Tier.SILVER: Color(0.75, 0.75, 0.85),
	ModifierTypes.Tier.GOLD: Color(1.0, 0.84, 0.0),
}


func get_visual(tier: ModifierTypes.Tier) -> Dictionary:
	return {"tint": TINTS.get(tier, Color.WHITE), "invert": false}


func get_badge_symbol() -> String:
	return "+"
