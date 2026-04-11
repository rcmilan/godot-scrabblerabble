## GravityBossHooks: Implements the Gravity boss drop mechanic.
##
## When Play is pressed, all newly placed tiles animate downward to the lowest
## empty cell in their column, or to the first occupied cell below them.
## Locked tiles from previous plays are NOT affected.
##
## Pure logic -- no Godot node references. Controllers resolve domain positions
## back to scene tile/cell references for animation.
class_name GravityBossHooks
extends BossHooks


## Calculates drop targets for all unplayed tiles.
##
## For each unplayed position, finds the lowest row in the same column where
## grid_occupancy is false (empty). Processes columns bottom-to-top to handle
## stacking correctly (if tile A drops to row 5, tile B in the same column
## above it should drop to row 4, not overlap).
##
## Args:
##   grid_occupancy: Array - 2D bool array (true = occupied, false = empty)
##   unplayed_positions: Array[Vector2i] - positions of tiles just placed
##   board_rows: int - total board rows (e.g., 6)
##   board_cols: int - total board columns (e.g., 6)
##
## Returns: Array[Dictionary] - list of movements
##   [{from: Vector2i, to: Vector2i}, ...]
##   Empty array if no tiles need to drop.
func get_post_play_movements(
	grid_occupancy: Array,
	unplayed_positions: Array,
	board_rows: int,
	board_cols: int
) -> Array:
	if unplayed_positions.is_empty():
		return []

	var movements: Array[Dictionary] = []

	# For each unplayed position, calculate where it should drop to
	for from_pos in unplayed_positions:
		var col = from_pos.x
		var from_row = from_pos.y

		# Skip positions already at the bottom row
		if from_row >= board_rows - 1:
			continue

		# Find the lowest empty row in this column (scan from bottom up)
		var target_row = from_row  # Default to current row
		for row in range(board_rows - 1, from_row, -1):
			if not grid_occupancy[row][col]:
				target_row = row
				break

		# Only add movement if target differs from current position
		if target_row != from_row:
			movements.append({
				"from": from_pos,
				"to": Vector2i(col, target_row)
			})

	return movements
