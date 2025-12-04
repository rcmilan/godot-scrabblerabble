extends Node

# DictionaryLoader: Loads the english_words.txt file into a HashSet for fast lookups.

const DICTIONARY_PATH = "res://data/english_words.txt"

func load_dictionary() -> Dictionary:
	var dictionary = {}
	var file = FileAccess.open(DICTIONARY_PATH, FileAccess.READ)
	if not file:
		printerr("Dictionary file not found at path: ", DICTIONARY_PATH)
		return dictionary

	while not file.eof_reached():
		var word = file.get_line().strip_edges()
		if not word.is_empty():
			dictionary[word] = true
	
	file.close()
	return dictionary
