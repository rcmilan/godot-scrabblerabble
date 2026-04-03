extends Node
class_name OrientationIcon

## OrientationIcon: Manages positioning of the orientation indicator (H/V marker).
## Anchors the icon to board grid coordinate (0,0) and updates position on board resize.
## The button itself (OrientationIconButton) is created by GameplayController.

var _board: Board = null


func _ready() -> void:
	# Get reference to parent Board
	_board = get_parent() as Board
	if _board == null:
		push_error("OrientationIcon: Parent is not a Board node")
		return

	# Subscribe to board resize events (button will exist by the time this fires deferred)
	EventBus.board_resized.connect(_on_board_resized)


## Positions the icon at the center of cell (0,0) on the board.
## Formula: icon_position = board_local_top_left + (cell_size * 0.5)
func position_at_cell(cell_0_0_position: Vector2, cell_size: Vector2) -> void:
	var icon_node: OrientationIconButton = _board.get_orientation_button()
	if icon_node == null:
		return

	# Center the icon within the cell (using local coordinates relative to Board)
	var icon_position = cell_0_0_position + (cell_size * 0.5)
	icon_node.position = icon_position

	print("[OrientationIcon] Positioned at %s (cell_0_0=%s, cell_size=%s)" % [
		icon_position, cell_0_0_position, cell_size
	])


## Handles board_resized signal: recalculates and updates icon position.
func _on_board_resized(board_state: BoardState) -> void:
	if _board == null:
		return

	var board_offset: Vector2 = _board.get_top_left_local_position()
	var cell_size: Vector2 = _board.get_cell_size_pixels()

	position_at_cell(board_offset, cell_size)
