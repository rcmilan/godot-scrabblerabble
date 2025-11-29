extends Node

# Dictionary to store valid words for fast lookup
var word_dict: Dictionary[String, bool] = {}

func _ready() -> void:
	# Load the English words file
	var file: FileAccess = FileAccess.open("res://data/english_words.txt", FileAccess.READ)
	if file:
		var content: String = file.get_as_text()
		var words: PackedStringArray = content.split("\n")
		for word in words:
			var trimmed_word: String = word.strip_edges()
			if trimmed_word != "":
				word_dict[trimmed_word.to_lower()] = true
		file.close()
		print("Dictionary loaded with %d words" % word_dict.size())
	else:
		push_error("Failed to load english_words.txt")

# Check if a word is valid
func is_valid_word(word: String) -> bool:
	return word_dict.has(word.to_lower())