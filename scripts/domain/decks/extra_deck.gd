extends DeckDefinition
class_name ExtraDeck

## ExtraDeck: Standard distribution with AllExtraQuality bundled.
## Every tile drawn will carry the EXTRA modifier each round.
##
## Postcondition: create_distribution() returns bag_default.tres distribution.
## Postcondition: create_bundled_quality() returns a valid AllExtraQuality instance.

func get_id() -> StringName:
	return &"extra"


func get_display_name() -> String:
	return "Extra"


func get_description() -> String:
	return "Familiar letters, extra opportunities. All tiles carry the Extra modifier every round."


func create_distribution() -> BagDistribution:
	return load("res://data/bag_distribution/bag_default.tres") as BagDistribution


func create_bundled_quality() -> RunQuality:
	return AllExtraQuality.new()
