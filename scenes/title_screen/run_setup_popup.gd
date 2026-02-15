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

# =============================================================================
# STATE
# =============================================================================

var _quality_checkboxes: Dictionary = {}  # StringName -> CheckBox

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	set_process_input(true)
	_populate_quality_list()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
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
	builder.set_bag(load("res://Data/BagDistribution/bag_default.tres"))

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
