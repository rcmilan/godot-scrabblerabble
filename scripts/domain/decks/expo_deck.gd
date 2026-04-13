extends DeckDefinition
class_name ExpoDeck

## ExpoDeck: Standard distribution with AllExpoQuality bundled.
## Every tile drawn will carry the EXPO modifier each round.
##
## Postcondition: create_distribution() returns bag_default.tres distribution.
## Postcondition: create_bundled_quality() returns a valid AllExpoQuality instance.

func get_id() -> StringName:
	return &"expo"


func get_display_name() -> String:
	return "Expo"


func get_description() -> String:
	return "Familiar letters, exponential growth. All tiles carry the Expo modifier every round."


func create_distribution() -> BagDistribution:
	return load("res://data/bag_distribution/bag_default.tres") as BagDistribution


func create_bundled_quality() -> RunQuality:
	return AllExpoQuality.new()
