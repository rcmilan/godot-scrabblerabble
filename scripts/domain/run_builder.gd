extends RefCounted
class_name RunBuilder

## RunBuilder: Fluent builder for constructing Run objects.
## Applies defaults for any fields not explicitly set.

# =============================================================================
# STATE
# =============================================================================

var _bag_config: BagDistribution = null
var _hand_size: int = -1
var _plays_per_round: int = -1
var _progression_config: ProgressionConfig = null
var _qualities: Array[RunQuality] = []

# =============================================================================
# FLUENT API
# =============================================================================

func set_bag(bag: BagDistribution) -> RunBuilder:
	_bag_config = bag
	return self


func set_hand_size(size: int) -> RunBuilder:
	_hand_size = size
	return self


func set_plays_per_round(plays: int) -> RunBuilder:
	_plays_per_round = plays
	return self


func set_progression(config: ProgressionConfig) -> RunBuilder:
	_progression_config = config
	return self


func add_quality(quality: RunQuality) -> RunBuilder:
	# Prevent duplicate qualities by ID
	var id := quality.get_quality_id()
	for existing in _qualities:
		if existing.get_quality_id() == id:
			return self
	_qualities.append(quality)
	return self


func remove_quality(quality_id: StringName) -> RunBuilder:
	for i in range(_qualities.size() - 1, -1, -1):
		if _qualities[i].get_quality_id() == quality_id:
			_qualities.remove_at(i)
	return self

# =============================================================================
# BUILD
# =============================================================================

func build() -> Run:
	var run := Run.new()

	# Apply defaults for missing fields
	if _bag_config:
		run.bag_config = _bag_config
	else:
		run.bag_config = load("res://Data/BagDistribution/bag_default.tres")

	if _progression_config:
		run.progression_config = _progression_config
	else:
		run.progression_config = load("res://Data/Progression/progression_default.tres")

	run.hand_size = _hand_size if _hand_size > 0 else run.progression_config.default_hand_size
	run.plays_per_round = _plays_per_round if _plays_per_round > 0 else run.progression_config.default_plays_per_round

	# Copy qualities
	run.qualities = _qualities.duplicate()

	return run
