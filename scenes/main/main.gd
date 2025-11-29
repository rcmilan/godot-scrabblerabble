extends Node

# Main scene script that initializes the game
# This script is attached to the root node of the Main scene

func _ready():
	# Start the game when the scene is ready
	GameManager.start_game()