extends Control
class_name BoardCell

## Individual cell on the game board.
## Manages tile placement, visual overlays, and user interactions.

# === Signals ===
signal cell_clicked(cell: BoardCell)
signal cell_hovered(cell: BoardCell)
signal cell_unhovered(cell: BoardCell)

# === Visual Feedback Colors ===
const COLOR_VALID_HOVER: Color = Color(0, 1, 0, 0.45)
const COLOR_INVALID_HOVER: Color = Color(1, 0, 0, 0.65)
const COLOR_SPECIAL_MULTIPLIER: Color = Color(1, 0.84, 0, 0.3)  # Gold for special cells
const COLOR_WORD_HIGHLIGHT: Color = Color(0.2, 0.9, 0.3, 0.35)  # Green for valid word member
const COLOR_TYPING_CURSOR: Color = Color(0.3, 0.6, 1.0, 0.55)  # Blue for typing cursor

# === Node References ===
@onready var visual: TextureRect = $ContentLayer/CenterContainer/Sprite2D
@onready var hover_overlay: ColorRect = $OverlayLayer/HoverOverlay
@onready var tile_anchor: Control = $ContentLayer/TileAnchor

# === State ===
var tile: Tile = null
var grid_position: Vector2i = Vector2i.ZERO
var _word_highlight_active: bool = false  # True when cell is part of a valid word
var _typing_cursor_active: bool = false

# === Cell Type (multiplier logic implemented; special cells not yet assigned in level design) ===
enum CellType {
	NORMAL,
	DOUBLE_LETTER,
	TRIPLE_LETTER,
	DOUBLE_WORD,
	TRIPLE_WORD,
	STAR  # Center cell
}

@export var cell_type: CellType = CellType.NORMAL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hover_overlay.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			cell_clicked.emit(self)


# === Public API ===

## Returns true if this cell has a tile placed on it.
func is_occupied() -> bool:
	return tile != null


## Returns true if a tile can be placed on this cell.
func can_place_tile() -> bool:
	return not is_occupied()


## Places a tile on this cell.
func place_tile(new_tile: Tile) -> bool:
	if is_occupied():
		return false

	tile = new_tile
	return true


## Removes and returns the tile from this cell.
func remove_tile() -> Tile:
	var removed_tile: Tile = tile
	tile = null
	return removed_tile


## Clears the tile reference without returning it.
func clear_tile() -> void:
	if tile != null:
		tile.queue_free()
	tile = null


## Shows a valid placement hover indicator.
func show_valid_hover() -> void:
	_show_overlay(COLOR_VALID_HOVER)


## Shows an invalid placement hover indicator.
func show_invalid_hover() -> void:
	_show_overlay(COLOR_INVALID_HOVER)


## Clears the hover indicator.
func clear_hover() -> void:
	if _typing_cursor_active:
		_show_overlay(COLOR_TYPING_CURSOR)
		return
	if _word_highlight_active:
		_show_overlay(COLOR_WORD_HIGHLIGHT)
		return
	hover_overlay.visible = false


## Shows the valid-word highlight (persistent until cleared).
func show_word_highlight() -> void:
	_word_highlight_active = true
	_show_overlay(COLOR_WORD_HIGHLIGHT)


## Clears the valid-word highlight.
func clear_word_highlight() -> void:
	_word_highlight_active = false
	hover_overlay.visible = false


func show_typing_cursor() -> void:
	_typing_cursor_active = true
	_show_overlay(COLOR_TYPING_CURSOR)


func clear_typing_cursor() -> void:
	_typing_cursor_active = false
	if _word_highlight_active:
		_show_overlay(COLOR_WORD_HIGHLIGHT)
		return
	hover_overlay.visible = false


## Returns the score multiplier for letters on this cell.
func get_letter_multiplier() -> int:
	match cell_type:
		CellType.DOUBLE_LETTER:
			return 2
		CellType.TRIPLE_LETTER:
			return 3
		_:
			return 1


## Returns the word multiplier for words using this cell.
func get_word_multiplier() -> int:
	match cell_type:
		CellType.DOUBLE_WORD, CellType.STAR:
			return 2
		CellType.TRIPLE_WORD:
			return 3
		_:
			return 1


# === Private Methods ===

func _show_overlay(color: Color) -> void:
	hover_overlay.color = color
	hover_overlay.visible = true
	hover_overlay.move_to_front()


# === Signal Handlers (connected in scene) ===

func _on_mouse_entered() -> void:
	if not is_occupied():
		visual.modulate = Color(0.9, 0.9, 0.9)
	cell_hovered.emit(self)


func _on_mouse_exited() -> void:
	visual.modulate = Color.WHITE
	cell_unhovered.emit(self)
