extends Node2D

# Main: Initializes the game and connects the primary scenes.

@onready var board = $Board
@onready var rack = $Rack
@onready var hud = $HUD

func _ready():
	# The GameManager will start the first turn automatically.
	# The Rack listens for the 'turn_started' signal to draw tiles.
	pass

# TODO: Implement input handling for tile movement and placement,
# possibly by connecting signals from the Board and Rack to a central
# input handler in this script or in the GameManager.
