extends Control
class_name DebugRoundConfigPopup

## Debug popup for overriding next round configuration.
## Accessible from the Shop scene.
## Designed to be easily extensible for future options.

# =============================================================================
# SIGNALS
# =============================================================================

signal config_applied(rows: int, cols: int)
signal popup_closed

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _rows_spinbox: SpinBox = $Panel/MarginContainer/VBoxContainer/RowsContainer/RowsSpinBox
@onready var _cols_spinbox: SpinBox = $Panel/MarginContainer/VBoxContainer/ColsContainer/ColsSpinBox
@onready var _apply_button: Button = $Panel/MarginContainer/VBoxContainer/ApplyButton
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_apply_button.pressed.connect(_on_apply)
	_close_button.pressed.connect(_on_close)
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_popup(current_rows: int, current_cols: int) -> void:
	_rows_spinbox.value = current_rows
	_cols_spinbox.value = current_cols
	show()
	_rows_spinbox.get_line_edit().grab_focus()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_apply() -> void:
	var rows: int = int(_rows_spinbox.value)
	var cols: int = int(_cols_spinbox.value)
	RunManager.set_debug_board_override(Vector2i(cols, rows))
	config_applied.emit(rows, cols)
	hide()
	popup_closed.emit()


func _on_close() -> void:
	hide()
	popup_closed.emit()
