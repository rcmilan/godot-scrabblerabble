extends CanvasLayer

# HUD: Displays game information like score, turn, etc.

# Node references (to be assigned in the editor)
@onready var plays_label: Label = $TurnLabel  # Reusing TurnLabel as PlaysLabel
@onready var score_label: Label = $ScoreLabel
@onready var target_label: Label = $TargetLabel
@onready var rack_label: Label = $RackLabel
@onready var game_over_label: Label = $GameOverLabel

func _ready():
	EventBus.connect("score_updated", Callable(self, "_on_score_updated"))
	
	# Connect to TileBag for rack count updates
	if TileBag:
		TileBag.connect("rack_count_changed", Callable(self, "_on_rack_count_changed"))
		# Set initial rack count
		_on_rack_count_changed(TileBag.get_remaining_tile_count())
	
	game_over_label.hide()
	
	# Find and connect to round manager if it exists
	call_deferred("_connect_round_manager")

func _connect_round_manager():
	var word_test = get_tree().get_current_scene().get_node_or_null("WordTest")
	if word_test:
		var rm = word_test.get_node_or_null("RoundManager")
		if rm:
			rm.connect("round_started", Callable(self, "_on_round_started"))
			rm.connect("play_completed", Callable(self, "_on_play_completed"))
			rm.connect("game_won", Callable(self, "_on_game_won"))
			rm.connect("game_lost", Callable(self, "_on_game_lost"))
			print("[hud] Connected to RoundManager")
			# Initial display
			_on_round_started(rm.get_current_round())
			_on_play_completed(rm.get_plays_remaining())
			set_target_score(rm.get_target_score())

func _on_round_started(round_number: int):
	game_over_label.hide()

func _on_play_completed(plays_remaining: int):
	plays_label.text = "Plays: %d" % plays_remaining

func _on_score_updated(new_score: int):
	score_label.text = "Score: %d" % new_score

func _on_rack_count_changed(count: int):
	rack_label.text = "Rack: %d" % count

func _on_game_won():
	game_over_label.show()
	game_over_label.text = "You Win!\nTarget Reached!"

func _on_game_lost():
	game_over_label.show()
	game_over_label.text = "Game Over\nOut of Plays"

func set_target_score(target: int):
	target_label.text = "Target: %d" % target
