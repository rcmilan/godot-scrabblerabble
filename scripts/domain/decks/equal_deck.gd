extends DeckDefinition
class_name EqualDeck

## EqualDeck: One of each letter (26 tiles total).
## No bundled quality.
##
## Postcondition: create_distribution() loads bag_equal.tres successfully.

func get_id() -> StringName:
	return &"equal"


func get_display_name() -> String:
	return "Equal"


func get_description() -> String:
	return "One of every letter. Each tile is equally likely — plan your words carefully."


func create_distribution() -> BagDistribution:
	return load("res://data/bag_distribution/bag_equal.tres") as BagDistribution
