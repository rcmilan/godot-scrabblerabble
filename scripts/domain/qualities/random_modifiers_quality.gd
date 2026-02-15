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
	for tile in TileBag.available_tiles:
		if randf() < MODIFIER_CHANCE:
			var type: ModifierTypes.Type = _pick_weighted_type()
			var tier: ModifierTypes.Tier = _pick_weighted_tier()
			var modifier: ModifierInstance = ModifierRegistry.create_modifier(
				type, tier, ModifierTypes.Lifetime.PER_ROUND
			)
			tile.add_modifier(modifier)
			count += 1
	print("[RandomModifiers] Assigned %d modifiers to %d available tiles" % [
		count, TileBag.available_tiles.size()
	])


func _pick_weighted_type() -> ModifierTypes.Type:
	var total: int = 0
	for w in TYPE_WEIGHTS.values():
		total += w

	var roll: int = randi() % total
	var cumulative: int = 0
	for type in TYPE_WEIGHTS.keys():
		cumulative += TYPE_WEIGHTS[type]
		if roll < cumulative:
			return type

	return ModifierTypes.Type.EXTRA


func _pick_weighted_tier() -> ModifierTypes.Tier:
	var total: int = 0
	for w in TIER_WEIGHTS.values():
		total += w

	var roll: int = randi() % total
	var cumulative: int = 0
	for tier in TIER_WEIGHTS.keys():
		cumulative += TIER_WEIGHTS[tier]
		if roll < cumulative:
			return tier

	return ModifierTypes.Tier.BRONZE
