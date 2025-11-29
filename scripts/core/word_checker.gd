extends Node

# WordChecker class responsible for validating words in the Scrabble game
# References DictionaryLoader autoload for word validity checks

# Validates a word by checking if it exists in the dictionary
# @param word: The word to validate as a String
# @return: True if the word is valid, false otherwise
func validate_word(word: String) -> bool:
	return DictionaryLoader.is_valid_word(word)

# TODO: Add validation for word length (e.g., minimum 2 letters, maximum based on board)
# TODO: Add validation for special rules (e.g., proper nouns, abbreviations)
# TODO: Consider case sensitivity or normalization rules