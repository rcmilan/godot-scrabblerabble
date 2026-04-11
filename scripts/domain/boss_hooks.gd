## BossHooks: Base class providing no-op defaults for boss customization.
##
## Each boss subclass overrides only the hooks it uses. All methods are pure
## (no side effects, no Godot node dependencies). Parameters are primitive types
## (Vector2i, Array, int, float, bool, Dictionary) to keep the domain layer
## independent of Godot's scene tree.
##
## Controllers translate between domain data and scene references.
class_name BossHooks
extends RefCounted


## Returns cells where tiles cannot be placed during this boss round.
## Default: no unavailable cells.
##
## Args:
##   rows: int - total board rows
##   cols: int - total board columns
##
## Returns: Array[Vector2i] - list of unavailable cell positions
func get_unavailable_cells(rows: int, cols: int) -> Array:
	return []


## Returns the score multiplier for a tile at a given position.
## Default: 1.0 (no multiplier).
##
## Args:
##   position: Vector2i - grid position of the tile
##
## Returns: float - multiplier (1.0 = normal, 2.0 = double, etc.)
func get_tile_multiplier(position: Vector2i) -> float:
	return 1.0


## Determines whether the Play button should be enabled.
## Default: true (always available).
##
## Called before each play attempt to check if constraints are satisfied.
##
## Args:
##   hand_count: int - number of tiles currently in hand
##   board_unplayed_count: int - number of unplayed tiles on board
##   play_number: int - which play in the round (1-indexed)
##
## Returns: bool - true if Play is allowed, false otherwise
func can_play(hand_count: int, board_unplayed_count: int, play_number: int) -> bool:
	return true


## Returns tile movement instructions for post-play effects (e.g., gravity drop).
## Default: no movements (tiles stay in place).
##
## Args:
##   grid_occupancy: Array - 2D array of bools (true = cell occupied, false = empty)
##   unplayed_positions: Array[Vector2i] - positions of tiles just placed
##   board_rows: int - total board rows
##   board_cols: int - total board columns
##
## Returns: Array[Dictionary] - list of movements [{from: Vector2i, to: Vector2i}, ...]
##   Empty array means no movements; tiles stay in place.
func get_post_play_movements(
	grid_occupancy: Array,
	unplayed_positions: Array,
	board_rows: int,
	board_cols: int
) -> Array:
	return []


## Overrides the default plays per round.
## Default: -1 (use default plays count).
##
## Returns: int - plays per round (>0), or -1 for "use default"
func get_plays_override() -> int:
	return -1


## Overrides the default target score for the round.
## Default: -1 (use default target score).
##
## Returns: int - target score (>0), or -1 for "use default"
func get_target_score_override() -> int:
	return -1


## Returns hand tile modifications at round start (e.g., duplicate tiles, remove tiles).
## Default: no modifications.
##
## Returns: Array[Dictionary] - modification instructions
##   Empty array means no hand changes.
func get_hand_modifications() -> Array:
	return []


## Returns time attack configuration (countdown timer, per-play limits).
## Default: no time attack (empty dict).
##
## Returns: Dictionary - time attack config
##   Empty dict means no timer; normal play mode.
func get_time_attack_config() -> Dictionary:
	return {}
