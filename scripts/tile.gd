# res://scripts/tile.gd
class_name Tile
extends Panel

@export var letter: String = "A"

@onready var letter_label: Label = $LetterLabel
@onready var point_label: Label = $PointLabel

# Where this tile currently lives. Used by the rack/board to remove/return it.
# "rack" or "board". When on board, board_pos stores the (x,y) cell.
var location: String = "rack"
var board_pos: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	_refresh_visual()
	# We want to be a drag source AND clickable.
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_letter(new_letter: String) -> void:
	letter = new_letter.to_upper()
	if is_inside_tree():
		_refresh_visual()

func _refresh_visual() -> void:
	letter_label.text = letter
	point_label.text = str(GameData.score_for_letter(letter))

# --- Drag and drop source ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	# Cannot drag a tile that is already locked on the board.
	if location == "board":
		return null
	# Build a visual preview that follows the mouse.
	var preview := duplicate() as Control
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	# The data we pass to the drop target is this Tile node itself.
	return self
