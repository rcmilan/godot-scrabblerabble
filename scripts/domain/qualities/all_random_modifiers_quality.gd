class_name AllRandomModifiersQuality
extends RunQuality

## AllRandomModifiersQuality: Assigns a weighted random modifier to EVERY bag tile at round start.
## Bundled by RandomModifiersDeck; NOT registered in QualityRegistry (not shown in UI quality list).
##
## on_round_started:
##   Precondition : TileBag._available_tiles is populated.
##   Postcondition: every tile in TileBag._available_tiles carries a random PER_ROUND modifier.
##   Invariant    : tile.add_modifier() replaces by type -- no duplicates possible.

# =============================================================================
# CONFIGURATION
# =============================================================================

const TYPE_WEIGHTS: Dictionary = {
	ModifierTypes.Type.EXTRA: 45,
	ModifierTypes.Type.MULTI: 30,
	ModifierTypes.Type.RESET: 10,
	ModifierTypes.Type.EXPO: 15,
}

const TIER_WEIGHTS: Dictionary = {
	ModifierTypes.Tier.BRONZE: 60,
	ModifierTypes.Tier.SILVER: 30,
	ModifierTypes.Tier.GOLD: 10,
}

# =============================================================================
# IDENTITY
# =============================================================================

func get_quality_id() -> StringName:
	return &"all_random_modifiers"


func get_quality_name() -> String:
	return "Random Modifiers"


func get_description() -> String:
	return "Every tile carries a random modifier each round."

# =============================================================================
# LIFECYCLE
# =============================================================================

func on_round_started(_round_number: int) -> void:
	_assign_modifiers_to_all_bag_tiles()

# =============================================================================
# PRIVATE
# =============================================================================

func _assign_modifiers_to_all_bag_tiles() -> void:
	for tile in TileBag.get_available_tiles():
		var type: ModifierTypes.Type = _pick_weighted_type()
		var tier: ModifierTypes.Tier = _pick_weighted_tier()
		var modifier: ModifierInstance = ModifierRegistry.create_modifier(
			type, tier, ModifierTypes.Lifetime.PER_ROUND
		)
		tile.add_modifier(modifier)
	print("[AllRandomModifiers] Assigned modifiers to %d bag tiles" % TileBag.tiles_remaining())


func _pick_weighted(weights: Dictionary) -> Variant:
	var total: int = 0
	for w in weights.values():
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for key in weights:
		cumulative += weights[key]
		if roll < cumulative:
			return key
	return weights.keys()[0]


func _pick_weighted_type() -> ModifierTypes.Type:
	return _pick_weighted(TYPE_WEIGHTS)


func _pick_weighted_tier() -> ModifierTypes.Tier:
	return _pick_weighted(TIER_WEIGHTS)
