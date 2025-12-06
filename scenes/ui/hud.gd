extends CanvasLayer

# HUD: Displays game information like score, turn, etc.

# Node references (to be assigned in the editor)
@onready var turn_label: Label = $TurnLabel
@onready var score_label: Label = $ScoreLabel
@onready var target_label: Label = $TargetLabel
@onready var game_over_label: Label = $GameOverLabel

func _ready():
	EventBus.connect("turn_started", Callable(self, "_on_turn_started"))
	EventBus.connect("score_updated", Callable(self, "_on_score_updated"))
	EventBus.connect("game_over", Callable(self, "_on_game_over"))
	
	game_over_label.hide()

func _on_turn_started(turn_number: int):
	turn_label.text = "Turn: %d" % turn_number
	game_over_label.hide()

func _on_score_updated(new_score: int):
	score_label.text = "Score: %d" % new_score

func _on_game_over(final_score: int, did_win: bool):
	game_over_label.show()
	if did_win:
		game_over_label.text = "You Win!\nFinal Score: %d" % final_score
	else:
		game_over_label.text = "Game Over\nFinal Score: %d" % final_score

func set_target_score(target: int):
	target_label.text = "Target: %d" % target
