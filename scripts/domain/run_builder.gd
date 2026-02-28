extends RefCounted
class_name RunBuilder

## RunBuilder: Fluent builder for constructing Run objects.
## Applies defaults for any fields not explicitly set.

# =============================================================================
# STATE
# =============================================================================

var _bag_config: BagDistribution = null
var _deck: DeckDefinition = null
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


## set_deck: Selects a deck for this run.
## Postcondition: build() uses deck.create_distribution() as bag_config.
## Postcondition: if deck.create_bundled_quality() != null, quality is added to run.qualities.
## Invariant    : deck takes precedence over set_bag() when both are called.
func set_deck(deck: DeckDefinition) -> RunBuilder:
	_deck = deck
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
	var id := quality.get_quality_id()
	for existing in _qualities:
		if existing.get_quality_id() == id:
			push_warning("[RunBuilder] Quality '%s' already added; duplicate ignored." % id)
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
	if _deck:
		run.bag_config = _deck.create_distribution()
		var bundled := _deck.create_bundled_quality()
		if bundled != null:
			add_quality(bundled)
	elif _bag_config:
		run.bag_config = _bag_config
	else:
		var default_bag := load("res://data/bag_distribution/bag_default.tres") as BagDistribution
		if default_bag == null:
			push_error("[RunBuilder] Failed to load default bag distribution")
		run.bag_config = default_bag

	if _progression_config:
		run.progression_config = _progression_config
	else:
		var default_prog := load("res://data/progression/progression_default.tres") as ProgressionConfig
		if default_prog == null:
			push_error("[RunBuilder] Failed to load default progression config")
		run.progression_config = default_prog

	run.hand_size = _hand_size if _hand_size > 0 else run.progression_config.default_hand_size
	run.plays_per_round = _plays_per_round if _plays_per_round > 0 else run.progression_config.default_plays_per_round

	# Transfer qualities and reset all builder state so build() is safe to call again.
	## Postcondition: every field returns to its sentinel/null value after build().
	run.qualities = _qualities.duplicate()
	_bag_config = null
	_deck = null
	_hand_size = -1
	_plays_per_round = -1
	_progression_config = null
	_qualities.clear()

	return run
