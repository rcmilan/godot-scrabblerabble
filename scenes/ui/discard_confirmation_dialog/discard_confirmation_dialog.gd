extends CanvasLayer

## DiscardConfirmationDialog: Confirmation popup for discarding selected tiles.
## Shows count of tiles to be discarded and Yes/No options.

signal confirmed
signal cancelled

@onready var panel: Panel = $CenterContainer/Panel
@onready var message_label: Label = $CenterContainer/Panel/VBoxContainer/MessageLabel
@onready var yes_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonContainer/YesButton
@onready var no_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonContainer/NoButton

var _tile_count: int = 0


func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Close on Escape
	if event.is_action_pressed("ui_cancel"):
		_on_no_pressed()
		get_viewport().set_input_as_handled()

	# Confirm on Enter
	if event.is_action_pressed("ui_accept"):
		_on_yes_pressed()
		get_viewport().set_input_as_handled()


## Shows the confirmation dialog with the number of tiles to discard.
func show_confirmation(tile_count: int) -> void:
	if tile_count <= 0:
		return

	_tile_count = tile_count

	if tile_count == 1:
		message_label.text = "Discard 1 tile?"
	else:
		message_label.text = "Discard %d tiles?" % tile_count

	show()
	yes_button.grab_focus()


func _on_yes_pressed() -> void:
	hide()
	confirmed.emit()


func _on_no_pressed() -> void:
	hide()
	cancelled.emit()
