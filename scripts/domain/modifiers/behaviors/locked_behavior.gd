class_name LockedBehavior
extends ModifierBehavior

## LockedBehavior: Locks a tile to its board cell.
## No scoring effect, no visual tint, no badge.
## Visual (black border) is handled by Tile._update_visual() via is_locked.


func compute(base_score: int, _tier: ModifierTypes.Tier) -> int:
	return base_score


func get_visual(_tier: ModifierTypes.Tier) -> Dictionary:
	return {"tint": Color.WHITE, "invert": false}


func get_badge_symbol() -> String:
	return ""
