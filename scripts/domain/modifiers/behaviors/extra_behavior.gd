class_name ExtraBehavior
extends ModifierBehavior

## ExtraBehavior: Additive bonus to tile score.
## Bronze +2, Silver +5, Gold +10. Priority 10 (applies after reset check).

const BONUS: Dictionary = {
	ModifierTypes.Tier.BRONZE: 2,
	ModifierTypes.Tier.SILVER: 5,
	ModifierTypes.Tier.GOLD: 10,
}


func get_priority() -> int:
	return 10


func compute(base_score: int, tier: ModifierTypes.Tier) -> int:
	return base_score + BONUS.get(tier, 0)
