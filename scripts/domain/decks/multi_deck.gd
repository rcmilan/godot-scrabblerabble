extends DeckDefinition
class_name MultiDeck

## MultiDeck: Standard distribution with AllMultiQuality bundled.
## Every tile drawn will carry the MULTI modifier each round.
##
## Postcondition: create_distribution() returns bag_default.tres distribution.
## Postcondition: create_bundled_quality() returns a valid AllMultiQuality instance.

func get_id() -> StringName:
	return &"multi"


func get_display_name() -> String:
	return "Multi"


func get_description() -> String:
	return "Familiar letters, multiplied power. All tiles carry the Multi modifier every round."


func create_distribution() -> BagDistribution:
	return load("res://data/bag_distribution/bag_default.tres") as BagDistribution


func create_bundled_quality() -> RunQuality:
	return AllMultiQuality.new()
