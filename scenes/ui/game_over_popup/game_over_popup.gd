extends CanvasLayer
class_name GameOverPopup

## Game Over popup with option to return to title screen.
## Displays final score and a single action button.

# =============================================================================
# SIGNALS
# =============================================================================

signal return_to_title_requested

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _overlay: ColorRect = $Overlay
@onready var _message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var _score_label: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabel
@onready var _return_button: Button = $Panel/MarginContainer/VBoxContainer/ReturnButton

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_return_button.pressed.connect(_on_return_pressed)
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_return_pressed()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_game_over(total_score: int) -> void:
	_message_label.text = "Game Over"
	_score_label.text = "Final Score: %d" % total_score
	show()
	_return_button.grab_focus()


func show_victory(total_score: int) -> void:
	_message_label.text = "Victory!"
	_score_label.text = "Final Score: %d" % total_score
	show()
	_return_button.grab_focus()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_return_pressed() -> void:
	hide()
	return_to_title_requested.emit()
