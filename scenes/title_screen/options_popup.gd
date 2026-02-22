extends Control
class_name OptionsPopup

## Options popup with Display and Controls tabs.
## Controls tab allows key rebinding via KeybindingConfig.

signal closed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _close_button: Button       = $Panel/MarginContainer/VBoxContainer/CloseButton
@onready var _tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var _fullscreen_check: CheckBox = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/FullscreenCheck
@onready var _vsync_check: CheckBox      = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/VsyncCheck
@onready var _volume_slider: HSlider     = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/VolumeSlider
@onready var _volume_label: Label        = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/VolumeValueLabel
@onready var _reset_button: Button       = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ResetButton
@onready var _reset_cancel_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ResetCancelButton
@onready var _action_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer/ActionList

# =============================================================================
# REBIND STATE
# =============================================================================

var _listening_action: StringName = &""
var _listening_button: Button = null

var _guard: ModalInputGuard

var _reset_confirming: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_reset_button.pressed.connect(_on_reset_defaults_pressed)
	_reset_cancel_button.pressed.connect(_on_reset_cancel_pressed)
	_guard = ModalInputGuard.new().setup(self)
	set_process_input(true)

	_fullscreen_check.button_pressed = false
	_vsync_check.button_pressed = true
	_volume_slider.value = 80
	_update_volume_label()
	_populate_controls_tab()


func _input(event: InputEvent) -> void:
	# Capture rebind — takes full priority while listening (before guard)
	if _listening_action != &"":
		if not visible:
			return
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				_listening_button.text = KeybindingConfig.get_event_display_text(_listening_action)
			else:
				KeybindingConfig.save_binding(_listening_action, event)
				_listening_button.text = KeybindingConfig.get_event_display_text(_listening_action)
			_listening_action = &""
			_listening_button = null
			get_viewport().set_input_as_handled()
		return

	if _guard.handle(event):
		return

	# Tab switching: 1/2 keys or L1/R1 controller
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_1:
			_tab_container.current_tab = 0
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_2:
			_tab_container.current_tab = 1
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_tab_container.current_tab = max(0, _tab_container.current_tab - 1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_tab_container.current_tab = min(_tab_container.tab_count - 1, _tab_container.current_tab + 1)
			get_viewport().set_input_as_handled()
			return

	# Close on cancel (Backspace/Delete/ESC/B-button)
	if event.is_action_pressed(KeyAction.CANCEL) or event.is_action_pressed(&"ui_cancel"):
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

# =============================================================================
# CONTROLS TAB
# =============================================================================

func _populate_controls_tab() -> void:
	for child in _action_list.get_children():
		child.queue_free()

	for category in KeybindingConfig.CATEGORIES:
		# Category header label
		var header := Label.new()
		header.text = category["label"]
		header.add_theme_font_size_override("font_size", 14)
		_action_list.add_child(header)

		# One row per action in the category
		for action in category["actions"]:
			_action_list.add_child(_build_action_row(action))

		# Spacer between categories
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		_action_list.add_child(spacer)


func _build_action_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = KeybindingConfig.get_display_name(action)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = KeybindingConfig.get_event_display_text(action)
	btn.custom_minimum_size = Vector2(130, 0)
	btn.pressed.connect(_on_rebind_pressed.bind(action, btn))
	row.add_child(btn)

	return row


func _on_rebind_pressed(action: StringName, button: Button) -> void:
	if _listening_action != &"":
		return
	_listening_action = action
	_listening_button = button
	button.text = "Press any key\u2026"


func _on_reset_defaults_pressed() -> void:
	if not _reset_confirming:
		_reset_confirming = true
		_reset_button.text = "Confirm reset"
		_reset_cancel_button.show()
		return
	# Second press — execute reset
	_reset_confirming = false
	_reset_button.text = "Reset to Defaults"
	_reset_cancel_button.hide()
	KeybindingConfig.reset_to_defaults()
	_populate_controls_tab()


func _on_reset_cancel_pressed() -> void:
	_reset_confirming = false
	_reset_button.text = "Reset to Defaults"
	_reset_cancel_button.hide()

# =============================================================================
# DISPLAY TAB CALLBACKS
# =============================================================================

func _on_close_pressed() -> void:
	close_popup()


func _on_volume_changed(_value: float) -> void:
	_update_volume_label()


func _update_volume_label() -> void:
	_volume_label.text = "Volume: %d%%" % int(_volume_slider.value)
