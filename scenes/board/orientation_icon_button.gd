extends TextureButton
class_name OrientationIconButton

## Small UI button (32x32px) in top-left corner of board.
## Shows current orientation (letter_H.png for horizontal, letter_V.png for vertical).
## Emits orientation_toggled when clicked. Listens to orientation_changed to update visuals.

signal orientation_toggled(new_state: RunOrientationState)

@onready var _icon_h: Texture2D = preload("res://Assets/Tiles/letter_H.png")
@onready var _icon_v: Texture2D = preload("res://Assets/Tiles/letter_V.png")

var _orientation_state: RunOrientationState = null


func _ready() -> void:
	pressed.connect(_on_pressed)
	_set_orientation(RunOrientationState.horizontal())


func set_orientation_state(new_state: RunOrientationState) -> void:
	if new_state == null:
		return
	_orientation_state = new_state
	_set_orientation(new_state)


func _set_orientation(state: RunOrientationState) -> void:
	if state.is_horizontal():
		texture_normal = _icon_h
	else:
		texture_normal = _icon_v


func _on_pressed() -> void:
	if _orientation_state == null:
		return
	var new_state := _orientation_state.toggled()
	orientation_toggled.emit(new_state)
