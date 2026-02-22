extends Control
class_name RunSetupPopup

## RunSetupPopup: Modal overlay for selecting run qualities before starting.
## Dynamically populates quality checkboxes from QualityRegistry.

# =============================================================================
# SIGNALS
# =============================================================================

signal run_confirmed(run: Run)
signal cancelled()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _quality_list: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/QualityList
@onready var _start_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/StartButton
@onready var _back_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/BackButton
@onready var _content_vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer

# =============================================================================
# STATE
# =============================================================================

var _quality_checkboxes: Dictionary = {}  # StringName -> CheckBox

var _deck_option: OptionButton = null
var _deck_desc_label: Label = null
var _deck_ids: Array[StringName] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	set_process_input(true)
	_populate_deck_selector()
	_populate_quality_list()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Forward WASD (navigate_*) as ui_* so Godot's focus traversal picks them up.
	# Safe from loops: the re-injected InputEventAction("ui_up") is not matched by
	# is_action_pressed("navigate_up") because ui_up is not in navigate_up's bindings.
	var nav_map: Dictionary = {
		KeyAction.NAVIGATE_UP:    &"ui_up",
		KeyAction.NAVIGATE_DOWN:  &"ui_down",
		KeyAction.NAVIGATE_LEFT:  &"ui_left",
		KeyAction.NAVIGATE_RIGHT: &"ui_right",
	}
	for game_action: StringName in nav_map:
		if event.is_action_pressed(game_action):
			var fake := InputEventAction.new()
			fake.action = nav_map[game_action]
			fake.pressed = true
			Input.parse_input_event(fake)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_popup() -> void:
	show()
	_start_button.grab_focus()


func close_popup() -> void:
	hide()
	cancelled.emit()

# =============================================================================
# PRIVATE
# =============================================================================

func _populate_deck_selector() -> void:
	var deck_label := Label.new()
	deck_label.text = "Deck"
	deck_label.add_theme_font_size_override("font_size", 14)

	_deck_option = OptionButton.new()
	_deck_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_ids = DeckRegistry.get_all_deck_ids()
	for id in _deck_ids:
		var deck := DeckRegistry.create_default(id)
		_deck_option.add_item(deck.get_display_name())
	_deck_option.item_selected.connect(_on_deck_selected)

	_deck_desc_label = Label.new()
	_deck_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_desc_label.add_theme_font_size_override("font_size", 12)
	_deck_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(deck_label)
	section.add_child(_deck_option)
	section.add_child(_deck_desc_label)

	var sep := HSeparator.new()

	_content_vbox.add_child(section)
	_content_vbox.add_child(sep)
	_content_vbox.move_child(section, 0)
	_content_vbox.move_child(sep, 1)

	var default_index := _deck_ids.find(&"standard")
	_on_deck_selected(maxi(default_index, 0))


func _on_deck_selected(index: int) -> void:
	if _deck_desc_label == null or index < 0 or index >= _deck_ids.size():
		return
	var deck := DeckRegistry.create_default(_deck_ids[index])
	if deck:
		_deck_desc_label.text = deck.get_description()


func _get_selected_deck() -> DeckDefinition:
	var index := _deck_option.selected if _deck_option else 0
	if index < 0 or index >= _deck_ids.size():
		return DeckRegistry.create_default(&"standard")
	return DeckRegistry.create_default(_deck_ids[index])


func _populate_quality_list() -> void:
	# Clear existing children
	for child in _quality_list.get_children():
		child.queue_free()
	_quality_checkboxes.clear()

	# Create two columns
	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 12)
	_quality_list.add_child(left_column)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 12)
	_quality_list.add_child(right_column)

	var ids := QualityRegistry.get_all_quality_ids()
	for i in ids.size():
		var id := ids[i]
		var quality := QualityRegistry.create_default(id)
		if quality == null:
			continue

		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 2)

		var checkbox := CheckBox.new()
		checkbox.text = quality.get_quality_name()
		container.add_child(checkbox)

		var desc_label := Label.new()
		desc_label.text = quality.get_description()
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(desc_label)

		var column := left_column if i % 2 == 0 else right_column
		column.add_child(container)
		_quality_checkboxes[id] = checkbox


func _build_run() -> Run:
	var builder := RunBuilder.new()
	builder.set_deck(_get_selected_deck())

	for id in _quality_checkboxes:
		var checkbox: CheckBox = _quality_checkboxes[id]
		if checkbox.button_pressed:
			var quality := QualityRegistry.create_default(id)
			if quality:
				builder.add_quality(quality)

	return builder.build()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_start_pressed() -> void:
	var run := _build_run()
	hide()
	run_confirmed.emit(run)


func _on_back_pressed() -> void:
	close_popup()
