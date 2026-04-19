extends RefCounted
class_name RunState

## RunState: Mutable aggregate tracking the entire run.
## Persists across rounds. Reset when starting a new run.
## All fields private — accessed via getters, modified via methods.

var _current_round: int = 0
var _total_score: int = 0
var _rounds_completed: int = 0
var _is_run_active: bool = false
var _round_scores: Array[int] = []

# Configuration (set at run start, modifiable by quality effects)
var _plays_per_round: int = 2
var _hand_size: int = 10
var _bag_config: BagDistribution = null
var _boss_pool: BossPool = null
var _bosses_defeated: int = 0


func start_run(config_plays: int, config_hand_size: int, config_bag: BagDistribution) -> void:
	_current_round = 0
	_total_score = 0
	_rounds_completed = 0
	_bosses_defeated = 0
	_is_run_active = true
	_round_scores.clear()
	_plays_per_round = config_plays
	_hand_size = config_hand_size
	_bag_config = config_bag

	# Initialize boss pool from registry
	var boss_registry = BossRegistry.new()
	var all_bosses = boss_registry.get_all_bosses()
	print("[RunState] Boss registry returned %d bosses: %s" % [all_bosses.size(), all_bosses.map(func(b): return b.display_name)])
	_boss_pool = BossPool.new(all_bosses)
	print("[RunState] BossPool initialized with %d bosses | Pool ready: has_next=%s" % [_boss_pool.get_total_count(), _boss_pool.has_next()])


func advance_round() -> void:
	_current_round += 1


func complete_round(round_score: int) -> void:
	_rounds_completed += 1
	_total_score += round_score
	_round_scores.append(round_score)


func end_run() -> void:
	_is_run_active = false


func record_boss_defeat() -> void:
	_bosses_defeated += 1
	print("[RunState] Boss defeated | Total bosses defeated: %d" % _bosses_defeated)


func get_next_round_number() -> int:
	return _current_round + 1


# === Getters ===

var current_round: int:
	get: return _current_round

var total_score: int:
	get: return _total_score

var rounds_completed: int:
	get: return _rounds_completed

var is_run_active: bool:
	get: return _is_run_active

var plays_per_round: int:
	get: return _plays_per_round
	set(value): _plays_per_round = value

var hand_size: int:
	get: return _hand_size
	set(value): _hand_size = value

var bosses_defeated: int:
	get: return _bosses_defeated

var bag_config: BagDistribution:
	get: return _bag_config

## Returns the boss pool for this run (tracks boss selection).
func get_boss_pool() -> BossPool:
	return _boss_pool

## Returns a duplicate of round scores to prevent external mutation.
func get_round_scores() -> Array[int]:
	return _round_scores.duplicate()
