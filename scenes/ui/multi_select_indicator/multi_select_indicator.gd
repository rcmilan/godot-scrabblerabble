extends Control

## MultiSelectIndicator: Visual indicator for multi-select mode status.
## Shows current mode and selection count.

@onready var background: Panel = $Background
@onready var mode_label: Label = $Background/ModeLabel

# Colors for different states
const COLOR_MULTI_ACTIVE: Color = Color(0.2, 0.6, 0.3, 0.9)
const COLOR_SINGLE: Color = Color(0.3, 0.3, 0.3, 0.5)

var _selection: SelectionManager = null


## Sets the SelectionManager reference (injected by Main).
func set_selection_manager(sm: SelectionManager) -> void:
	_selection = sm
	_selection.mode_changed.connect(_on_mode_changed)
	_selection.selection_changed.connect(_on_selection_changed)
	_update_display()


func _on_mode_changed(_is_multi: bool) -> void:
	_update_display()


func _on_selection_changed(_tiles: Array) -> void:
	_update_display()


func _update_display() -> void:
	if not _selection:
		return

	var is_multi: bool = _selection.is_multi_select_enabled()
	var count: int = _selection.get_selection_count()

	if is_multi:
		background.modulate = COLOR_MULTI_ACTIVE
		if count == 0:
			mode_label.text = "MULTI [Q]"
		else:
			mode_label.text = "MULTI [%d]" % count
	else:
		background.modulate = COLOR_SINGLE
		mode_label.text = "Multi [Q]"
