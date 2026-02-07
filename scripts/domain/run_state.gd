extends RefCounted
class_name RunState

## RunState: Mutable aggregate tracking the entire run.
## Persists across rounds. Reset when starting a new run.

var current_round: int = 0
var total_score: int = 0
var rounds_completed: int = 0
var is_run_active: bool = false
var round_scores: Array[int] = []

# Configuration (set at run start, modifiable by shop effects)
var plays_per_round: int = 2
var hand_size: int = 10
var bag_config: BagDistribution = null


func start_run(config_plays: int, config_hand_size: int, config_bag: BagDistribution) -> void:
	current_round = 0
	total_score = 0
	rounds_completed = 0
	is_run_active = true
	round_scores.clear()
	plays_per_round = config_plays
	hand_size = config_hand_size
	bag_config = config_bag


func advance_round() -> void:
	current_round += 1


func complete_round(round_score: int) -> void:
	rounds_completed += 1
	total_score += round_score
	round_scores.append(round_score)


func end_run() -> void:
	is_run_active = false


func get_next_round_number() -> int:
	return current_round + 1
