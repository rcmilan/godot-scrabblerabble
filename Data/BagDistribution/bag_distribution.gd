extends Resource

class_name BagDistribution

##Defines tile distribution for tile bag
##Dictionary format Letter: Count

@export var distribution: Dictionary = {}

#Gets total count
func get_total_tiles() -> int:
	var total = 0
	for count in distribution.values():
		total += count
	return total
	
#validate data
func is_valid() -> bool:
	if distribution.is_empty():
		return false
	
	#check that values are non-negative integers
	for letter in distribution.keys():
		if not distribution[letter] is int or distribution[letter] < 0:
			return false
	
	return true
