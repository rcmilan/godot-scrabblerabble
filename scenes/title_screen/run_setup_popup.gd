extends Control
class_name RunSetupView

## RunSetupView: Full-screen view for selecting run settings before starting.
## Shown by swapping visibility with MenuView; simple button-based layout.
## Dynamically populates quality checkboxes from QualityRegistry.

# =============================================================================
# CONFIGURATION
# =============================================================================

const VISIBLE_QUALITIES: Array[StringName] = [&"auto_win"]

# =============================================================================
# SIGNALS
# =============================================================================

signal run_confirmed(run: Run)
signal back_requested()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _deck_option: OptionButton = $ContentContainer/DeckOption
@onready var _deck_desc_label: Label = $ContentContainer/DeckDescription
@onready var _quality_list: VBoxContainer = $ContentContainer/QualityList
@onready var _start_button: Button = $ContentContainer/ButtonContainer/StartButton
@onready var _back_button: Button = $ContentContainer/ButtonContainer/BackButton

# =============================================================================
# STATE
# =============================================================================

var _quality_checkboxes: Dictionary = {}  # StringName -> CheckBox
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

	# Forward WASD/arrow keys as ui_* for focus traversal
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

	# ESC goes back
	if event.is_action_pressed(KeyAction.CANCEL) or event.is_action_pressed(&"ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
		return

	# Block gameplay actions from leaking through
	if event.is_action_pressed(KeyAction.TOGGLE_MULTI) or \
	   event.is_action_pressed(KeyAction.DISCARD_TILES) or \
	   event.is_action_pressed(KeyAction.PLAY_HAND) or \
	   event.is_action_pressed(KeyAction.DRAW_TILES) or \
	   event.is_action_pressed(KeyAction.PAUSE_GAME):
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_view() -> void:
	show()
	_start_button.grab_focus()


func hide_view() -> void:
	hide()

# =============================================================================
# PRIVATE
# =============================================================================

func _populate_deck_selector() -> void:
	_deck_ids = DeckRegistry.get_all_deck_ids()
	for id in _deck_ids:
		var deck := DeckRegistry.create_default(id)
		_deck_option.add_item(deck.get_display_name())
	_deck_option.item_selected.connect(_on_deck_selected)

	var default_index := _deck_ids.find(&"standard")
	_on_deck_selected(maxi(default_index, 0))


func _on_deck_selected(index: int) -> void:
	if index < 0 or index >= _deck_ids.size():
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
	for child in _quality_list.get_children():
		child.queue_free()
	_quality_checkboxes.clear()

	var ids := QualityRegistry.get_all_quality_ids()
	for i in ids.size():
		var id := ids[i]
		if id not in VISIBLE_QUALITIES:
			continue
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

		_quality_list.add_child(container)
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
	hide_view()
	run_confirmed.emit(run)


func _on_back_pressed() -> void:
	hide_view()
	back_requested.emit()
