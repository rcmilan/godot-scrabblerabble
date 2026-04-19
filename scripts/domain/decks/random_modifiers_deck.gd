extends DeckDefinition
class_name RandomModifiersDeck

## RandomModifiersDeck: Standard distribution with AllRandomModifiersQuality bundled.
## Every tile drawn will carry a random scoring modifier each round.
##
## Postcondition: create_distribution() returns bag_default.tres distribution.
## Postcondition: create_bundled_quality() returns a valid AllRandomModifiersQuality instance.

func get_id() -> StringName:
	return &"random_modifiers"


func get_display_name() -> String:
	return "Random Modifiers"


func get_description() -> String:
	return "Every tile carries a random modifier each round. Chaos reigns."


func create_distribution() -> BagDistribution:
	return load("res://data/bag_distribution/bag_default.tres") as BagDistribution


func create_bundled_quality() -> RunQuality:
	return AllRandomModifiersQuality.new()
