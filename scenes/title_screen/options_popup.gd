extends Control
class_name OptionsPopup

## Options menu popup with game settings and mocked display settings.
## Provides plays-per-round config and debug auto-win toggle.

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
@onready var _plays_spinbox: SpinBox = $Panel/MarginContainer/VBoxContainer/SettingsContainer/PlaysSpinBox
@onready var _auto_win_check: CheckBox = $Panel/MarginContainer/VBoxContainer/SettingsContainer/AutoWinCheck

# =============================================================================
# STATE
# =============================================================================

var _plays_per_round: int = 2
var _auto_win: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_plays_spinbox.value_changed.connect(_on_plays_changed)
	_auto_win_check.toggled.connect(_on_auto_win_toggled)

	# Setup keyboard shortcut (ESC to close)
	set_process_input(true)

	# Mock initial values
	_fullscreen_check.button_pressed = false
	_vsync_check.button_pressed = true
	_volume_slider.value = 80
	_update_volume_label()

	# Game settings defaults
	_plays_spinbox.value = _plays_per_round
	_auto_win_check.button_pressed = _auto_win


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
	show()
	_close_button.grab_focus()


func close_popup() -> void:
	hide()
	closed.emit()


func get_plays_per_round() -> int:
	return _plays_per_round


func get_auto_win() -> bool:
	return _auto_win

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_close_pressed() -> void:
	close_popup()


func _on_volume_changed(value: float) -> void:
	_update_volume_label()


func _on_plays_changed(value: float) -> void:
	_plays_per_round = int(value)


func _on_auto_win_toggled(enabled: bool) -> void:
	_auto_win = enabled
	RunManager.set_debug_auto_win(enabled)


func _update_volume_label() -> void:
	_volume_label.text = "Volume: %d%%" % int(_volume_slider.value)
