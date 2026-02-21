class_name RandomModifiersQuality
extends RunQuality

## RandomModifiersQuality: Randomly assigns modifiers to tiles at round start.
## Each tile in the bag has a chance to receive a weighted random modifier.

# =============================================================================
# CONFIGURATION
# =============================================================================

const MODIFIER_CHANCE: float = 0.5

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
	return &"random_modifiers"


func get_quality_name() -> String:
	return "Random Modifiers"


func get_description() -> String:
	return "Tiles may carry random scoring modifiers each round."

# =============================================================================
# LIFECYCLE
# =============================================================================

func on_round_started(_round_number: int) -> void:
	_assign_modifiers_to_bag()


# =============================================================================
# PRIVATE
# =============================================================================

func _assign_modifiers_to_bag() -> void:
	var count: int = 0
	for tile in TileBag.get_available_tiles():
		if randf() < MODIFIER_CHANCE:
			var type: ModifierTypes.Type = _pick_weighted_type()
			var tier: ModifierTypes.Tier = _pick_weighted_tier()
			var modifier: ModifierInstance = ModifierRegistry.create_modifier(
				type, tier, ModifierTypes.Lifetime.PER_ROUND
			)
			tile.add_modifier(modifier)
			count += 1
	print("[RandomModifiers] Assigned %d modifiers to %d available tiles" % [
		count, TileBag.tiles_remaining()
	])


## Picks a random key from a weights dictionary {key: int_weight}.
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
