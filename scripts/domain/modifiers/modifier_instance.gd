class_name ModifierInstance
extends RefCounted

## ModifierInstance: Value object representing a modifier attached to a tile.

var type: ModifierTypes.Type = ModifierTypes.Type.NONE
var tier: ModifierTypes.Tier = ModifierTypes.Tier.BRONZE
var lifetime: ModifierTypes.Lifetime = ModifierTypes.Lifetime.CONSUMABLE
var behavior: ModifierBehavior = null


func _init(
	p_type: ModifierTypes.Type = ModifierTypes.Type.NONE,
	p_tier: ModifierTypes.Tier = ModifierTypes.Tier.BRONZE,
	p_lifetime: ModifierTypes.Lifetime = ModifierTypes.Lifetime.CONSUMABLE,
	p_behavior: ModifierBehavior = null
) -> void:
	type = p_type
	tier = p_tier
	lifetime = p_lifetime
	behavior = p_behavior
