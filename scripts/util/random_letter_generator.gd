extends Node

## RandomLetterGenerator
## Generates random letters for the Scrabble game.
## Currently uses uniform distribution, but weighted distribution is planned.

## Returns a random uppercase letter (A-Z)
func get_random_letter() -> String:
	return String.chr(randi_range(65, 90))

# TODO: Implement weighted letter distribution based on Scrabble letter frequencies