extends RefCounted
class_name DeckDefinition

## DeckDefinition: Abstract base for player-selectable tile decks.
## A deck defines the tile pool (via create_distribution()) and may bundle
## a RunQuality that modifies tile state each round (via create_bundled_quality()).
##
## Precondition : get_id() returns a non-empty, unique StringName.
## Precondition : create_distribution() returns a non-null BagDistribution where is_valid() == true.
## Invariant    : create_bundled_quality() returns null or a valid RunQuality instance.
## Invariant    : all methods are pure (no side-effects, no global state).

# =============================================================================
# IDENTITY  (override in subclasses)
# =============================================================================

func get_id() -> StringName:
	return &""


func get_display_name() -> String:
	return ""


func get_description() -> String:
	return ""

# =============================================================================
# FACTORY  (override in subclasses)
# =============================================================================

## Returns the tile distribution for this deck.
## Postcondition: result != null and result.is_valid() == true.
func create_distribution() -> BagDistribution:
	return null


## Returns a RunQuality to auto-bundle with the run, or null if none.
func create_bundled_quality() -> RunQuality:
	return null
