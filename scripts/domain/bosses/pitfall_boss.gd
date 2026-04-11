## PitfallBossHooks: Implements the Pitfall boss mechanic.
##
## Makes ~22% of board cells unavailable. The player cannot place tiles
## on blocked cells, making it harder to form long words.
##
## Pure logic -- no Godot node references. Controllers read the unavailable
## positions and apply visual/placement restrictions.
class_name PitfallBossHooks
extends BossHooks


## Returns a list of cell positions that are unavailable for tile placement.
##
## Selects ~22% of the board randomly, with a safety check to ensure
## no row or column is fully blocked.
func get_unavailable_cells(rows: int, cols: int) -> Array:
	var count: int = int(rows * cols * 0.22)
	var all_positions: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			all_positions.append(Vector2i(c, r))
	all_positions.shuffle()
	var selected: Array = all_positions.slice(0, count)
	return _ensure_no_full_blockage(selected, rows, cols)


## Removes cells from the selection if any row or column is fully blocked.
func _ensure_no_full_blockage(cells: Array, rows: int, cols: int) -> Array:
	var row_counts: Dictionary = {}
	var col_counts: Dictionary = {}
	for pos in cells:
		var r: int = pos.y
		var c: int = pos.x
		row_counts[r] = row_counts.get(r, 0) + 1
		col_counts[c] = col_counts.get(c, 0) + 1

	# Remove one cell from any fully blocked row
	var to_remove: Array[Vector2i] = []
	for r in row_counts:
		if row_counts[r] >= cols:
			for pos in cells:
				if pos.y == r and pos not in to_remove:
					to_remove.append(pos)
					break

	# Remove one cell from any fully blocked column
	for c in col_counts:
		if col_counts[c] >= rows:
			for pos in cells:
				if pos.x == c and pos not in to_remove:
					to_remove.append(pos)
					break

	var result: Array = []
	for pos in cells:
		if pos not in to_remove:
			result.append(pos)
	return result
