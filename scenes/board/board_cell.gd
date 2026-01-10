extends Control
class_name BoardCell

@onready var visual := $ContentLayer/CenterContainer/Sprite2D
@onready var hover_overlay := $OverlayLayer/HoverOverlay
@onready var tile_anchor := $ContentLayer/TileAnchor
@export var occupied := false

signal cell_clicked(cell)
signal cell_hovered(cell)
signal cell_unhovered(cell)

var tile: Tile = null
var placed_tile: Control = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#hover_overlay.color = Color(1, 0, 0, 0.8)
	#hover_overlay.visible = true
	#hover_overlay.move_to_front()
	print("Overlay size:", hover_overlay.size)
	pass # Replace with function body.

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		print("BoardCell clicked: ", name)
		cell_clicked.emit(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mouse_entered() -> void:
	visual.modulate = Color(0.8, 0.8, 0.8) # Replace with function body.
	cell_hovered.emit(self)


func _on_mouse_exited() -> void:
	visual.modulate = Color(1,1,1) # Replace with function body.
	cell_unhovered.emit(self)
	
	

func is_occupied() -> bool:
	return placed_tile != null
	
	
func show_valid_hover() -> void:
	hover_overlay.color = Color(0, 1, 0, 0.45)
	hover_overlay.visible = true
	hover_overlay.move_to_front()
	
func show_invalid_hover() -> void:
	hover_overlay.color = Color(1, 0, 0, 0.65)
	hover_overlay.visible = true
	hover_overlay.move_to_front()
	
func clear_hover() -> void:
	hover_overlay.visible = false
	
func show_invalid_overlay():
	$OverlayLayer/HoverOverlay.color = Color(1, 0, 0, 0.65)
	$OverlayLayer.visible = true
	$OverlayLayer.move_to_front()

func show_valid_overlay():
	$OverlayLayer/HoverOverlay.color = Color(0, 1, 0, 0.45)
	$OverlayLayer.visible = true
	$OverlayLayer.move_to_front()

func hide_overlay():
	$OverlayLayer.visible = false
	
func can_place_tile(tile: Tile, cell: BoardCell) -> bool:
	if cell.occupied:
		return false
	return true
