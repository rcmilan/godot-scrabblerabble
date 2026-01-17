extends Node

# RoundManager: Tracks round/stage state and progression.
# Manages the gameplay loop: plays per round, score targets, win/loss conditions.

signal round_started(round_number)
signal round_ended(round_number, success)
signal play_completed(plays_remaining)
signal game_won()
signal game_lost()

const DEFAULT_PLAYS_PER_ROUND = 10
const DEFAULT_TARGET_SCORE = 100

var current_round: int = 1
var plays_remaining: int = DEFAULT_PLAYS_PER_ROUND
var target_score: int = DEFAULT_TARGET_SCORE
var plays_per_round: int = DEFAULT_PLAYS_PER_ROUND

func _ready():
	print("[round_manager] Ready - Round ", current_round, ", Plays: ", plays_remaining, ", Target: ", target_score)
	emit_signal("round_started", current_round)

func start_round(round_num: int = 1, target: int = DEFAULT_TARGET_SCORE, plays: int = DEFAULT_PLAYS_PER_ROUND):
	current_round = round_num
	target_score = target
	plays_per_round = plays
	plays_remaining = plays
	print("[round_manager] Starting round ", current_round, " with target ", target_score, " and ", plays_remaining, " plays")
	emit_signal("round_started", current_round)

func complete_play(_score_earned: int, current_total_score: int) -> void:
	# Called after a successful evaluate/commit
	plays_remaining -= 1
	print("[round_manager] Play completed. Plays remaining: ", plays_remaining, " | Score: ", current_total_score, "/", target_score)
	emit_signal("play_completed", plays_remaining)
	
	# Check win condition
	if current_total_score >= target_score:
		print("[round_manager] TARGET REACHED! Round won!")
		emit_signal("round_ended", current_round, true)
		emit_signal("game_won")
		return
	
	# Check loss condition
	if plays_remaining <= 0:
		print("[round_manager] Out of plays. Round failed.")
		emit_signal("round_ended", current_round, false)
		emit_signal("game_lost")
		return

func reset_round() -> void:
	# Reset for retry or next round
	plays_remaining = plays_per_round
	print("[round_manager] Round reset. Plays: ", plays_remaining)

func get_plays_remaining() -> int:
	return plays_remaining

func get_target_score() -> int:
	return target_score

func get_current_round() -> int:
	return current_round
