extends Node

# WordChecker: Validates words against the loaded dictionary.

var _dictionary = {}
var _loader = preload("res://scripts/util/dictionary_loader.gd").new()

func _ready():
	_dictionary = _loader.load_dictionary()

func is_valid_word(word: String) -> bool:
	return _dictionary.has(word.to_lower())
