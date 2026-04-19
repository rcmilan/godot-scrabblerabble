class_name ShopController
extends Node

# Input routing and drag-drop orchestration for shop interactions

var shop_overlay: ShopOverlay = null
var shop_session: ShopSession = null

# Drag-drop state
var _dragging_modifier: Variant = null  # Stores ModifierTypes.Type or null
var _ghost_node: Control = null
var _selected_modifier_index: int = -1

# UI references (created dynamically)
var _modifier_cards: Array[Control] = []
var _tile_displays: Array[Control] = []

func _ready() -> void:
	pass

func setup(overlay: ShopOverlay, session: ShopSession) -> void:
	shop_overlay = overlay
	shop_session = session
	print("[Shop] Setup started - Round: %d | Boss: %s | Tiles: %d | Modifiers: %d" % [
		shop_session.round_number,
		"Yes" if shop_session.is_boss_round else "No",
		shop_session.available_tiles.size(),
		shop_session.available_modifiers.size()
	])
	_setup_ui()
	_connect_signals()
	print("[Shop] Setup completed")

func _setup_ui() -> void:
	if not shop_overlay:
		print("[Shop] ERROR: No shop_overlay reference")
		return

	print("[Shop] Building UI...")

	# Hide the existing content (round label, score, etc.)
	var content_container = shop_overlay.find_child("ContentContainer", true, false)
	if content_container:
		content_container.hide()
		print("[Shop] Hidden ContentContainer")

	# Create a main container for shop UI
	var shop_ui = VBoxContainer.new()
	shop_ui.name = "ShopUI"
	shop_ui.anchor_left = 0.1
	shop_ui.anchor_top = 0.15
	shop_ui.anchor_right = 0.9
	shop_ui.anchor_bottom = 0.85
	shop_ui.add_theme_constant_override("separation", 20)
	shop_overlay.add_child(shop_ui)
	print("[Shop] Created main UI container")

	# Upgrades section (modifiers)
	var upgrades_label = Label.new()
	upgrades_label.text = "AVAILABLE UPGRADES"
	upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_ui.add_child(upgrades_label)

	var upgrades_container = HBoxContainer.new()
	upgrades_container.name = "UpgradesSection"
	upgrades_container.add_theme_constant_override("separation", 10)
	upgrades_container.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_ui.add_child(upgrades_container)

	# Create modifier cards
	print("[Shop] Creating %d modifier cards..." % shop_session.available_modifiers.size())
	for i in range(shop_session.available_modifiers.size()):
		var card = _create_modifier_card(i, shop_session.available_modifiers[i])
		upgrades_container.add_child(card)
		_modifier_cards.append(card)
		print("[Shop] Created modifier card %d: %s" % [i, shop_session.available_modifiers[i]])

	# Tiles section
	var tiles_label = Label.new()
	tiles_label.text = "SELECT TILES TO UPGRADE"
	tiles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_ui.add_child(tiles_label)

	var tiles_container = Control.new()
	tiles_container.name = "TilesSection"
	tiles_container.custom_minimum_size = Vector2(0, 250)
	shop_ui.add_child(tiles_container)

	# Create tile displays (initially positioned in a grid, will be scattered)
	print("[Shop] Creating %d tile displays..." % shop_session.available_tiles.size())
	for i in range(shop_session.available_tiles.size()):
		var tile_display = _create_tile_display(i, shop_session.available_tiles[i])
		tiles_container.add_child(tile_display)
		_tile_displays.append(tile_display)
		print("[Shop] Created tile display %d: %s" % [i, shop_session.available_tiles[i].get_letter()])

	_scatter_tiles()
	print("[Shop] UI setup complete")

func _create_modifier_card(index: int, mod_type: ModifierTypes.Type) -> Control:
	var card = Panel.new()
	card.name = "ModifierCard_%d" % index
	card.custom_minimum_size = Vector2(140, 50)
	card.modulate = Color.WHITE
	card.gui_input.connect(func(event: InputEvent) -> void:
		_on_modifier_card_input(index, event)
	)

	# Apply a themed style for modifier cards
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.7, 1.0, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	card.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = str(mod_type)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	card.add_child(label)

	return card

func _create_tile_display(index: int, tile_state: TileState) -> Control:
	# Load the LetterTileData for this tile to get the actual texture
	var letter: String = tile_state.get_letter()
	var tile_data_path: String = "res://data/tile_data/tiles/tile_%s.tres" % letter.to_lower()
	var tile_data: LetterTileData = load(tile_data_path) as LetterTileData

	# Create a container control to hold the texture and interaction layer
	var display = Control.new()
	display.name = "TileDisplay_%d" % index
	display.custom_minimum_size = Vector2(64, 64)
	display.gui_input.connect(func(event: InputEvent) -> void:
		_on_tile_display_input(index, event)
	)

	# Create TextureRect with the actual tile asset
	var texture_rect = TextureRect.new()
	texture_rect.name = "TextureRect"
	texture_rect.custom_minimum_size = Vector2(64, 64)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tile_data and tile_data.texture:
		texture_rect.texture = tile_data.texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.add_child(texture_rect)

	# Optional: Add a subtle background panel for contrast
	var bg_panel = Panel.new()
	bg_panel.name = "Background"
	bg_panel.custom_minimum_size = Vector2(64, 64)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_panel.z_index = -1
	display.add_child(bg_panel)
	display.move_child(bg_panel, 0)

	return display

func _scatter_tiles() -> void:
	# Simple grid-with-jitter layout: 2 rows x 5 cols
	var grid_cols = 5
	var grid_rows = 2
	var col_spacing = 150.0
	var row_spacing = 200.0
	var jitter_range = 15.0

	for i in range(_tile_displays.size()):
		var col = i % grid_cols
		var row = i / grid_cols
		var x = col * col_spacing + randf_range(-jitter_range, jitter_range)
		var y = row * row_spacing + randf_range(-jitter_range, jitter_range)
		_tile_displays[i].position = Vector2(x, y)

func _connect_signals() -> void:
	# Signals will be set up as needed
	pass

func _on_modifier_card_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_select_modifier(index)
		else:
			if _dragging_modifier != null:
				_end_drag()

func _on_tile_display_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _dragging_modifier != null:
			_attempt_drop(index)

func _select_modifier(index: int) -> void:
	if index >= 0 and index < shop_session.available_modifiers.size():
		_selected_modifier_index = index
		_dragging_modifier = shop_session.available_modifiers[index]
		_create_ghost()
		_modifier_cards[index].modulate = Color(1.0, 0.8, 0.0, 1.0)  # Golden highlight

func _create_ghost() -> void:
	if _ghost_node:
		_ghost_node.queue_free()

	_ghost_node = Control.new()
	_ghost_node.name = "ModifierGhost"
	_ghost_node.custom_minimum_size = Vector2(140, 50)
	_ghost_node.modulate = Color(1, 1, 1, 0.8)
	_ghost_node.z_index = 100

	var ghost_panel = Panel.new()
	ghost_panel.custom_minimum_size = Vector2(140, 50)

	# Apply matching style to ghost
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.9, 1.0, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	ghost_panel.add_theme_stylebox_override("panel", style)
	_ghost_node.add_child(ghost_panel)

	var label = Label.new()
	label.text = str(_dragging_modifier)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	ghost_panel.add_child(label)

	shop_overlay.add_child(_ghost_node)

func _attempt_drop(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= shop_session.available_tiles.size():
		return

	var tile = shop_session.available_tiles[tile_index]
	if shop_session.can_apply_modifier(tile):
		# Create modifier instance and apply
		var mod_instance = ModifierInstance.new(_dragging_modifier)
		shop_session = shop_session.apply_modifier(tile, mod_instance)
		_show_badge(tile_index)
		_end_drag()
	else:
		_show_invalid_drop(tile_index)

func _show_badge(tile_index: int) -> void:
	var display = _tile_displays[tile_index]
	display.modulate = Color(0.3, 1.0, 0.3, 1.0)  # Success green

func _show_invalid_drop(tile_index: int) -> void:
	var display = _tile_displays[tile_index]
	# Flash red and return to normal
	display.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Error red
	await get_tree().create_timer(0.2).timeout
	display.modulate = Color.WHITE

func _end_drag() -> void:
	if _modifier_cards and _selected_modifier_index >= 0:
		_modifier_cards[_selected_modifier_index].modulate = Color.WHITE

	if _ghost_node:
		_ghost_node.queue_free()
		_ghost_node = null

	_dragging_modifier = null
	_selected_modifier_index = -1

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _ghost_node:
		var mouse_pos = event.position
		_ghost_node.global_position = mouse_pos - Vector2(60, 20)
