extends CanvasLayer
class_name PauseMenu

## Pause menu overlay with resume and return-to-title options.

# =============================================================================
# SIGNALS
# =============================================================================

signal resume_requested
signal return_to_title_requested

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _overlay: ColorRect = $Overlay
@onready var _resume_button: Button = $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var _return_button: Button = $Panel/MarginContainer/VBoxContainer/ReturnToTitleButton

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_resume_button.pressed.connect(_on_resume_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause_game"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		# Let the focused button handle Enter/Space
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_pause_menu() -> void:
	show()
	_resume_button.grab_focus()


func close_pause_menu() -> void:
	hide()
	resume_requested.emit()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_resume_pressed() -> void:
	close_pause_menu()


func _on_return_pressed() -> void:
	hide()
	return_to_title_requested.emit()
