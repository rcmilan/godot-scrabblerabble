## DiagonalBossHooks: Implements the Diagonal boss mechanic.
##
## Rewards placing tiles on the main diagonal (top-left to bottom-right).
## Diagonal cells score 2x, but the target score is 1.25x harder.
## Background shows a gold-to-white gradient along the diagonal.
##
## Pure logic -- no Godot node references.
class_name DiagonalBossHooks
extends BossHooks


## Returns 2.0 for tiles on the main diagonal (row == col), 1.0 otherwise.
func get_tile_multiplier(position: Vector2i) -> float:
	if position.x == position.y:
		return 2.0
	return 1.0


## Target score is 25% harder to push players toward the diagonal.
func get_target_score_multiplier() -> float:
	return 1.25


## Returns all cells on the main diagonal for golden highlighting.
func get_highlighted_cells(rows: int, cols: int) -> Array:
	var cells: Array = []
	var count: int = mini(rows, cols)
	for i in count:
		cells.append(Vector2i(i, i))
	return cells


## Gold-to-white gradient along the main diagonal.
func get_background_gradient() -> Dictionary:
	return {
		"primary_color": Color(1.0, 0.84, 0.0, 1.0),
		"secondary_color": Color(1.0, 1.0, 1.0, 1.0),
		"direction": "main_diagonal"
	}
