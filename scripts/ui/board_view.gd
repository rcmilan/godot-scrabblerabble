extends Control

signal cell_clicked(pos)
signal cell_right_clicked(pos)

@export var cols: int = 11
@export var rows: int = 11
@export var cell_size: int = 48

@onready var grid_container: GridContainer = null
# Avoid shadowing the global `TileModel` class_name; use a different variable name
var TileModelClass = preload("res://scripts/core/tile_model.gd")

func _ready():
	size = Vector2(cols * cell_size, rows * cell_size)
	# Do not auto-center here; let the parent (debug UI) decide placement.
	grid_container = GridContainer.new()
	grid_container.columns = cols
	add_child(grid_container)
	_build_cells()

func _build_cells() -> void:
	# remove existing children if any
	for c in grid_container.get_children():
		c.queue_free()
	
	for y in range(rows):
		for x in range(cols):
			var btn = Button.new()
			btn.name = str(x) + "," + str(y)
			btn.text = ""
			btn.toggle_mode = false
			btn.custom_minimum_size = Vector2(cell_size, cell_size)
			# connect pressed with bound position
			var c_pressed = Callable(self, "_on_cell_pressed").bind(Vector2i(x, y))
			btn.connect("pressed", c_pressed)
			var c_gui = Callable(self, "_on_cell_gui_input").bind(Vector2i(x, y))
			btn.connect("gui_input", c_gui)
			grid_container.add_child(btn)

func _on_cell_pressed(pos: Vector2i) -> void:
	emit_signal("cell_clicked", pos)

func _on_cell_gui_input(event: InputEvent, pos: Vector2i) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("cell_right_clicked", pos)

func show_combined_grid(grid_view: Array, temp_positions: Array = []) -> void:
	# grid_view is a 2D array [row][col]
	# temp_positions is an array of Vector2i
	var temp_set = {}
	for p in temp_positions:
		temp_set[str(p.x) + "," + str(p.y)] = true
	
	var idx = 0
	for y in range(rows):
		for x in range(cols):
			var btn = grid_container.get_child(idx)
			var tile = null
			if y < grid_view.size() and x < grid_view[y].size():
				tile = grid_view[y][x]
			if tile != null:
				# show letter on button
					if typeof(tile) == TYPE_OBJECT and tile is TileModel:
						btn.text = str(tile.letter)
					else:
						btn.text = str(tile)
			else:
				btn.text = ""
			# highlight temp placements
			var key = str(x) + "," + str(y)
			if temp_set.has(key):
				btn.modulate = Color(0.8, 1.0, 0.8)
			else:
				btn.modulate = Color(1, 1, 1)
			idx += 1
