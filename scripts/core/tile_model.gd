class_name TileModel

## Represents a Scrabble tile with a letter and point value

# The letter on the tile (e.g., "A", "B", etc.)
var letter: String

# The point value of the tile
var point_value: int

# Constructor to initialize the tile
func _init(p_letter: String = "", p_point_value: int = 0) -> void:
	letter = p_letter
	point_value = p_point_value

# Returns a string representation of the tile
func get_display_string() -> String:
	return "%s (%d)" % [letter, point_value]

# Checks if the tile is blank (no letter assigned)
func is_blank() -> bool:
	return letter == ""