extends RunQuality
class_name AllExpoQuality

## AllExpoQuality: Applies EXPO/PER_ROUND modifier to every bag tile at round start.
## Bundled by ExpoDeck; NOT registered in QualityRegistry (not shown in UI quality list).
##
## on_round_started:
##   Precondition : TileBag._available_tiles is populated.
##   Postcondition: every tile in TileBag._available_tiles carries a EXPO/PER_ROUND modifier.
##   Invariant    : tile.add_modifier() replaces by type — no duplicates possible.

# =============================================================================
# IDENTITY
# =============================================================================

func get_quality_id() -> StringName:
	return &"all_expo"


func get_quality_name() -> String:
	return "Expo Tiles"


func get_description() -> String:
	return "All tiles carry the Expo modifier each round."

# =============================================================================
# LIFECYCLE
# =============================================================================

func on_round_started(_round_number: int) -> void:
	_apply_expo_to_all_bag_tiles()

# =============================================================================
# PRIVATE
# =============================================================================

func _apply_expo_to_all_bag_tiles() -> void:
	for tile in TileBag.get_available_tiles():
		var modifier: ModifierInstance = ModifierRegistry.create_modifier(
			ModifierTypes.Type.EXPO,
			ModifierTypes.Tier.BRONZE,
			ModifierTypes.Lifetime.PER_ROUND
		)
		tile.add_modifier(modifier)
	print("[AllExpoQuality] Applied EXPO to %d bag tiles" % TileBag.tiles_remaining())
