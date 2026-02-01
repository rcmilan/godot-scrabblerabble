extends Control
class_name OptionsPopup

## Options menu popup with mocked settings.
## Displays a checklist and slider as placeholders.

# =============================================================================
# SIGNALS
# =============================================================================

signal closed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel: Panel = $Panel
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton
@onready var _fullscreen_check: CheckBox = $Panel/MarginContainer/VBoxContainer/SettingsContainer/FullscreenCheck
@onready var _vsync_check: CheckBox = $Panel/MarginContainer/VBoxContainer/SettingsContainer/VsyncCheck
@onready var _volume_slider: HSlider = $Panel/MarginContainer/VBoxContainer/SettingsContainer/VolumeSlider
@onready var _volume_label: Label = $Panel/MarginContainer/VBoxContainer/SettingsContainer/VolumeValueLabel

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)

	# Setup keyboard shortcut (ESC to close)
	set_process_input(true)

	# Mock initial values
	_fullscreen_check.button_pressed = false
	_vsync_check.button_pressed = true
	_volume_slider.value = 80
	_update_volume_label()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):  # ESC key
		close_popup()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_popup() -> void:
	"""Display the options popup and grab focus."""
	show()
	_close_button.grab_focus()


func close_popup() -> void:
	"""Hide the options popup."""
	hide()
	closed.emit()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_close_pressed() -> void:
	close_popup()


func _on_volume_changed(value: float) -> void:
	"""Update volume label when slider changes."""
	_update_volume_label()


func _update_volume_label() -> void:
	"""Update the volume display label."""
	_volume_label.text = "Volume: %d%%" % int(_volume_slider.value)
