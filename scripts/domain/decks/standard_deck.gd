extends DeckDefinition
class_name StandardDeck

## StandardDeck: Scrabble-style distribution (frequency-weighted letters).
## No bundled quality.
##
## Postcondition: create_distribution() loads bag_default.tres successfully.

func get_id() -> StringName:
	return &"standard"


func get_display_name() -> String:
	return "Standard"


func get_description() -> String:
	return "Classic Scrabble-style distribution. Common letters appear more often."


func create_distribution() -> BagDistribution:
	return load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
