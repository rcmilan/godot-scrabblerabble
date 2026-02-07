extends Resource
class_name ProgressionConfig

## ProgressionConfig: Data resource for progression scaling parameters.
## Edit in inspector or create multiple .tres files for different difficulties.

@export var base_target_score: int = 100
@export var target_score_increment: int = 50

## Board size thresholds: processed in order, first match wins.
## Each entry: {"up_to_round": int, "size": Vector2i}
@export var board_size_thresholds: Array[Dictionary] = [
	{"up_to_round": 1, "size": Vector2i(6, 6)},
	{"up_to_round": 2, "size": Vector2i(7, 7)},
]
@export var max_board_size: Vector2i = Vector2i(8, 8)

@export var default_plays_per_round: int = 2
@export var default_hand_size: int = 10
