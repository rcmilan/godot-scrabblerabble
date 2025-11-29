extends Node

# Main scene script that initializes the game
# This script is attached to the root node of the Main scene

func _ready():
	# Center the board, rack, and HUD based on viewport size with optional scaling
	var screen_size = get_viewport().size
	var scale_factor = clamp(min(screen_size.x / 1220.0, screen_size.y / 1060.0), 0.5, 1.0)
	
	# Apply scaling
	$Board.scale = Vector2(scale_factor, scale_factor)
	$Rack.scale = Vector2(scale_factor, scale_factor)
	$CanvasLayer/HUD.scale = Vector2(scale_factor, scale_factor)
	
	# Adjust positions with scaling
	$Board.position = Vector2((screen_size.x - 960 * scale_factor) / 2, (screen_size.y - 960 * scale_factor - 100 * scale_factor) / 2)
	$Rack.position = Vector2((screen_size.x - 720 * scale_factor) / 2, $Board.position.y + 960 * scale_factor + 20)
	$CanvasLayer/HUD.position = Vector2($Board.position.x + 960 * scale_factor + 20, $Board.position.y)

	# Start the game when the scene is ready
	GameManager.start_game()
