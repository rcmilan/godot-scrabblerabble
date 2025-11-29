extends Node2D

signal tile_selected(tile: Node2D)
signal tile_placed(board_pos: Vector2i)

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $LetterLabel

var tile_model: TileModel
var is_selected: bool = false

const CELL_SIZE: int = 64
var current_pos: Vector2i = Vector2i(7, 7)

func _ready() -> void:
	if tile_model:
		update_visuals()


func select_tile() -> void:
	is_selected = true
	scale = Vector2(1.2, 1.2)
	current_pos = Vector2i(7, 7)
	position = current_pos * CELL_SIZE
	emit_signal("tile_selected", self)

func deselect_tile() -> void:
	is_selected = false
	scale = Vector2(1, 1)

func set_tile_model(model: TileModel) -> void:
	tile_model = model
	update_visuals()

func update_visuals() -> void:
	if is_instance_valid(label) and tile_model:
		label.text = tile_model.letter
	elif is_instance_valid(label):
		label.text = ""
