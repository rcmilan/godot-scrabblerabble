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
## stacking correctly: when multiple unplayed tiles are in the same column,
## the lowest one drops first, and upper tiles stack above it (not overlap).
##
## Algorithm:
## 1. Group unplayed positions by column
## 2. For each column, sort positions bottom-to-top
## 3. Simulate grid as we process each tile: after calculating target row,
##    mark that row as "will be occupied" for subsequent tiles in the column
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

	# Create a working copy of grid_occupancy to simulate drops
	var simulated_grid: Array = []
	for row in grid_occupancy:
		simulated_grid.append(row.duplicate())

	# Group unplayed positions by column
	var positions_by_column: Dictionary = {}
	for pos in unplayed_positions:
		var col = pos.x
		if not positions_by_column.has(col):
			positions_by_column[col] = []
		positions_by_column[col].append(pos)

	var movements: Array[Dictionary] = []

	# Process each column, sorting positions bottom-to-top
	for col in positions_by_column.keys():
		var col_positions = positions_by_column[col]
		# Sort by row descending (bottom-to-top)
		col_positions.sort_custom(func(a, b): return a.y > b.y)

		# For each tile in this column (bottom-first)
		for from_pos in col_positions:
			var from_row = from_pos.y

			# Skip positions already at the bottom row
			if from_row >= board_rows - 1:
				continue

			# Find the lowest empty row in simulated grid
			var target_row = from_row  # Default to current row
			for row in range(board_rows - 1, from_row, -1):
				if not simulated_grid[row][col]:
					target_row = row
					break

			# Only add movement if target differs from current position
			if target_row != from_row:
				movements.append({
					"from": from_pos,
					"to": Vector2i(col, target_row)
				})

			# Update simulated grid: clear old position, mark new position
			simulated_grid[from_row][col] = false
			simulated_grid[target_row][col] = true

	return movements
