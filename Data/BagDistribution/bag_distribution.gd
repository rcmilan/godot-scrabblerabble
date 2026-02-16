extends Resource

class_name BagDistribution

##Defines tile distribution for tile bag
##Dictionary format Letter: Count

@export var distribution: Dictionary = {}

func get_total_tiles() -> int:
	var total = 0
	for count in distribution.values():
		total += count
	return total

func is_valid() -> bool:
	if distribution.is_empty():
		return false

	for letter in distribution.keys():
		if not distribution[letter] is int or distribution[letter] < 0:
			return false

	return true
