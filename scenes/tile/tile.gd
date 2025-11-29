extends Node2D

signal tile_selected(index: int)
signal tile_placed(board_pos: Vector2i)

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $LetterLabel

var tile_model: TileModel
var is_selected: bool = false
var index: int = -1

const CELL_SIZE: int = 64
var current_pos: Vector2i = Vector2i(7, 7)

func _ready() -> void:
	if tile_model:
		update_visuals()


func select_tile() -> void:
	print("Tile select_tile called on ", name)
	is_selected = true
	scale = Vector2(1.2, 1.2)
	z_index = 10
	modulate = Color(0.7, 0.7, 1.0)
	emit_signal("tile_selected", index)

func deselect_tile() -> void:
	print("Tile deselect_tile called on ", name)
	is_selected = false
	scale = Vector2(1, 1)
	z_index = 0
	modulate = Color.WHITE

func set_tile_model(model: TileModel) -> void:
	tile_model = model
	update_visuals()

func update_visuals() -> void:
	print("Tile update_visuals: letter ", tile_model.letter if tile_model else "null")
	if is_instance_valid(label) and tile_model:
		label.text = tile_model.letter
	elif is_instance_valid(label):
		label.text = ""
