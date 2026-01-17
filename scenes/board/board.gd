extends Control
class_name Board

@export var debug_hover := false
@export var debug_interval_frames := 30

var _debug_frame_counter := 0

@onready var grid := $GridContainer
var hovered_cell: BoardCell = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var cell := get_cell_at_position(mouse_pos)
	
	# Debug snapshot
	if debug_hover:
		_debug_frame_counter += 1
		if _debug_frame_counter % debug_interval_frames == 0:
			if cell:
				print(
					"[BOARD HOVER DEBUG]",
					"Mouse: ", mouse_pos,
					"| Cell: ", cell.name,
					"| Occupied: ", cell.occupied
				)
			else:
				print(
					"[BOARD HOVER DEBUG]",
					"Mouse: ", mouse_pos,
					"| No cell under cursor"
				)
	
	if cell != hovered_cell:
		if hovered_cell:
			hovered_cell.clear_hover()
			
		hovered_cell = cell
		
		if hovered_cell:
			update_cell_hover(hovered_cell)
			

func get_cell_at_position(pos: Vector2) -> BoardCell:
	for cell in grid.get_children():
		if cell.get_global_rect().has_point(pos):
			return cell
	
	return null


func update_cell_hover(cell: BoardCell) -> void:
	if get_node("/root/Main").selected_tile == null:
		return
		
	if cell.occupied:
		cell.show_invalid_hover()
	else:
		cell.show_valid_hover()
