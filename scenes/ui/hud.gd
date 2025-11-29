extends Control

## HUD script for displaying game information
## Manages turn, scores, tiles remaining, and game over messages

# Node references
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var tiles_remaining_label: Label = $VBoxContainer/TilesRemainingLabel
@onready var provisional_score_label: Label = $VBoxContainer/ProvisionalScoreLabel
@onready var total_score_label: Label = $VBoxContainer/TotalScoreLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOverLabel

# Game state variables
var current_turn: int = 1
var tiles_remaining: int = 100
var provisional_score: int = 0
var total_score: int = 0

func _ready() -> void:
	# Connect to EventBus signals
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.game_over.connect(_on_game_over)
	
	# Initialize labels
	_update_turn_label()
	_update_tiles_remaining_label()
	_update_provisional_score_label()
	_update_total_score_label()

## Signal handler for turn started
func _on_turn_started(turn_num: int) -> void:
	current_turn = turn_num
	_update_turn_label()

## Signal handler for turn ended
func _on_turn_ended(turn_num: int, score_added: int) -> void:
	total_score += score_added
	_update_total_score_label()

## Signal handler for game over
func _on_game_over(won: bool) -> void:
	game_over_panel.visible = true
	game_over_label.text = "Game Over: You Win!" if won else "Game Over: You Lose!"

## Updates the provisional score display
func update_provisional_score(score: int) -> void:
	provisional_score = score
	_update_provisional_score_label()

## Updates the tiles remaining display
func update_tiles_remaining(count: int) -> void:
	tiles_remaining = count
	_update_tiles_remaining_label()

## Helper function to update turn label
func _update_turn_label() -> void:
	turn_label.text = "Turn: %d" % current_turn

## Helper function to update tiles remaining label
func _update_tiles_remaining_label() -> void:
	tiles_remaining_label.text = "Tiles Remaining: %d" % tiles_remaining

## Helper function to update provisional score label
func _update_provisional_score_label() -> void:
	provisional_score_label.text = "Provisional Score: %d" % provisional_score

## Helper function to update total score label
func _update_total_score_label() -> void:
	total_score_label.text = "Total Score: %d" % total_score