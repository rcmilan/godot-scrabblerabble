extends Control

## DiscardPile: Visual representation of the discard pile.
## Acts as a drop zone for drag-and-drop discard operations.
## Future: will support peeking to see discarded tiles.

signal tiles_dropped(tiles: Array)
signal peek_requested

# Visual state
const COLOR_NORMAL: Color = Color(0.3, 0.3, 0.35, 0.8)
const COLOR_HOVER: Color = Color(0.4, 0.4, 0.5, 0.9)
const COLOR_DROP_VALID: Color = Color(0.3, 0.6, 0.4, 0.9)
const COLOR_DROP_INVALID: Color = Color(0.6, 0.3, 0.3, 0.9)

@onready var background: Panel = $Background
@onready var count_label: Label = $Background/CountLabel
@onready var title_label: Label = $Background/TitleLabel
@onready var drop_zone: Control = $DropZone

var _is_drag_hovering: bool = false
var _discard_count: int = 0
var _is_drag_active: bool = false


func _ready() -> void:
	# Connect to EventBus for discard count updates
	EventBus.discard_count_changed.connect(_on_discard_count_changed)
	EventBus.multi_drag_started.connect(_on_multi_drag_started)
	EventBus.multi_drag_ended.connect(_on_multi_drag_ended)

	# Initialize display
	_update_display()

	# Connect mouse events for drop zone
	drop_zone.mouse_entered.connect(_on_drop_zone_mouse_entered)
	drop_zone.mouse_exited.connect(_on_drop_zone_mouse_exited)


func _process(_delta: float) -> void:
	# Update hover state during drag operations
	if _is_drag_active:
		var is_over: bool = _is_mouse_over_pile()
		if is_over != _is_drag_hovering:
			_is_drag_hovering = is_over
			_update_display()


func _input(event: InputEvent) -> void:
	# Handle click for peeking (future feature)
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _is_mouse_over_pile() and not _is_drag_hovering:
				peek_requested.emit()


func _on_discard_count_changed(count: int) -> void:
	_discard_count = count
	_update_display()


func _on_multi_drag_started(_tiles: Array) -> void:
	_is_drag_active = true
	# Highlight drop zone when dragging starts
	if _is_mouse_over_pile():
		_is_drag_hovering = true
		_show_drop_valid()


func _on_multi_drag_ended(_tiles: Array, _success: bool) -> void:
	_is_drag_active = false
	_is_drag_hovering = false
	_update_display()


func _on_drop_zone_mouse_entered() -> void:
	if SelectionManager.has_selection():
		_is_drag_hovering = true
		_show_drop_valid()
	else:
		background.modulate = COLOR_HOVER


func _on_drop_zone_mouse_exited() -> void:
	_is_drag_hovering = false
	_update_display()


## Checks if a drop at the current mouse position should be handled by this pile.
func is_drop_target(global_pos: Vector2) -> bool:
	return drop_zone.get_global_rect().has_point(global_pos)


## Called when tiles are dropped on this pile.
func handle_drop(tiles: Array) -> void:
	if tiles.is_empty():
		return
	tiles_dropped.emit(tiles)


func _update_display() -> void:
	count_label.text = str(_discard_count)

	if _is_drag_hovering:
		_show_drop_valid()
	else:
		background.modulate = COLOR_NORMAL


func _show_drop_valid() -> void:
	background.modulate = COLOR_DROP_VALID


func _is_mouse_over_pile() -> bool:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	return drop_zone.get_global_rect().has_point(mouse_pos)


## Returns the current discard count.
func get_discard_count() -> int:
	return _discard_count
