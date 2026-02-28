extends DeckDefinition
class_name CursedDeck

## CursedDeck: Standard distribution with AllResetQuality bundled.
## Every tile drawn will carry the RESET modifier each round.
##
## Postcondition: create_distribution() returns bag_default.tres distribution.
## Postcondition: create_bundled_quality() returns a valid AllResetQuality instance.

func get_id() -> StringName:
	return &"cursed"


func get_display_name() -> String:
	return "Cursed"


func get_description() -> String:
	return "Familiar letters, dark magic. All tiles carry the Reset modifier every round."


func create_distribution() -> BagDistribution:
	return load("res://data/bag_distribution/bag_default.tres") as BagDistribution


func create_bundled_quality() -> RunQuality:
	return AllResetQuality.new()
