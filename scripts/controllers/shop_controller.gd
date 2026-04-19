class_name ShopController
extends Node

# Input routing and drag-drop orchestration for shop interactions

var shop_overlay: ShopOverlay = null
var shop_session: ShopSession = null

# Drag-drop state
var _dragging_modifier: Variant = null  # Stores ModifierTypes.Type or null
var _dragging_tile_index: int = -1  # Stores tile index when dragging tile
var _ghost_node: Control = null
var _selected_modifier_index: int = -1
var _selected_tile_index: int = -1
var _used_modifier_indices: Array[int] = []  # Tracks consumed modifier cards

# UI references (created dynamically)
var _modifier_cards: Array[Control] = []
var _tile_displays: Array[Control] = []
var _revert_button: Button = null
var _commit_button: Button = null

func _ready() -> void:
	pass

# Debug visualization
var _debug_rects: Array[Control] = []
var _show_debug_zones: bool = false

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
	if _show_debug_zones:
		_draw_debug_zones()
	print("[Shop] Setup completed")

func _setup_ui() -> void:
	if not shop_overlay:
		print("[Shop] ERROR: No shop_overlay reference")
		return

	print("[Shop] Building UI...")

	# Clean up any previous shop UI from earlier shop sessions
	# Remove all ShopUI and debug children to prevent duplicates
	for child in shop_overlay.get_children():
		if child.name == "ShopUI" or child.name.begins_with("DebugRect_"):
			shop_overlay.remove_child(child)
			child.queue_free()

	# Clean up debug rect tracking
	_debug_rects.clear()
	print("[Shop] Cleaned up previous shop UI")

	# Clear all UI tracking arrays (reset for new shop session)
	_modifier_cards.clear()
	_tile_displays.clear()
	_used_modifier_indices.clear()

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
		var mod_name = _get_modifier_name(shop_session.available_modifiers[i])
		print("[Shop] Created modifier card %d: %s" % [i, mod_name])

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

	# Apply existing modifier visuals for tiles that were already modified in prior shops
	for i in range(shop_session.available_tiles.size()):
		if shop_session.available_tiles[i].get_active_modifier() != null:
			_apply_modifier_visual_to_tile(i)

	_scatter_tiles()

	print("[Shop] UI setup complete")

func _create_modifier_card(index: int, mod_type: ModifierTypes.Type) -> Control:
	var card = Panel.new()
	card.name = "ModifierCard_%d" % index
	card.custom_minimum_size = Vector2(140, 50)
	card.modulate = Color.WHITE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
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
	label.text = _get_modifier_name(mod_type)
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

	if not tile_data:
		print("[Shop] WARNING: Failed to load LetterTileData for letter '%s' at path: %s" % [letter, tile_data_path])
	else:
		if not tile_data.texture:
			print("[Shop] WARNING: LetterTileData loaded but texture is null for letter '%s'" % letter)
		else:
			print("[Shop] Successfully loaded texture for letter '%s'" % letter)

	# Create a container control to hold the texture and interaction layer
	var display = Control.new()
	display.name = "TileDisplay_%d" % index
	display.custom_minimum_size = Vector2(64, 64)
	display.mouse_filter = Control.MOUSE_FILTER_STOP
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
	# Simple grid-with-jitter layout: 2 rows x 5 cols, centered within container
	# With overlap validation (SC-004: 100% success required)
	var grid_cols = 5
	var grid_rows = 2
	var col_spacing = 150.0
	var row_spacing = 200.0
	var jitter_range = 15.0
	var tile_size = Vector2(64.0, 64.0)

	# Calculate total grid width to center it
	var total_grid_width = (grid_cols - 1) * col_spacing + tile_size.x

	# Get the tiles container from the shop overlay
	var tiles_container = shop_overlay.find_child("TilesSection", true, false)
	# Use viewport width as fallback, adjusted for shop UI margins (anchor 0.1 to 0.9 = 80% of viewport)
	var container_width = tiles_container.size.x if tiles_container and tiles_container.size.x > 0 else get_viewport().get_visible_rect().size.x * 0.8
	var offset_x = (container_width - total_grid_width) / 2.0
	var offset_y = 10.0  # Small top padding

	# Calculate base positions (centered)
	for i in range(_tile_displays.size()):
		var col = i % grid_cols
		var row = i / grid_cols
		var x = offset_x + col * col_spacing + randf_range(-jitter_range, jitter_range)
		var y = offset_y + row * row_spacing + randf_range(-jitter_range, jitter_range)
		_tile_displays[i].position = Vector2(x, y)

	# Validate no overlaps using Rect2.intersects()
	var overlap_detected = false
	for i in range(_tile_displays.size()):
		var rect_i = Rect2(_tile_displays[i].position, tile_size)
		for j in range(i + 1, _tile_displays.size()):
			var rect_j = Rect2(_tile_displays[j].position, tile_size)
			if rect_i.intersects(rect_j):
				overlap_detected = true
				print("[Shop] WARNING: Tile overlap detected at indices %d and %d" % [i, j])

	if overlap_detected:
		print("[Shop] WARNING: Layout has overlaps - consider reducing jitter or increasing spacing")

func _connect_signals() -> void:
	# Signals will be set up as needed
	pass


func _mark_modifier_used(index: int) -> void:
	if index >= 0 and index not in _used_modifier_indices:
		_used_modifier_indices.append(index)
		# Visually dim the card to show it's been used
		_modifier_cards[index].modulate = Color(0.4, 0.4, 0.4, 0.8)
		print("[Shop] Modifier %d consumed" % index)


func _get_modifier_name(mod_type: ModifierTypes.Type) -> String:
	# Convert enum value to readable name
	match mod_type:
		ModifierTypes.Type.NONE: return "None"
		ModifierTypes.Type.EXTRA: return "Extra"
		ModifierTypes.Type.MULTI: return "Multi"
		ModifierTypes.Type.RESET: return "Reset"
		ModifierTypes.Type.EXPO: return "Expo"
		ModifierTypes.Type.LOCKED: return "Locked"
		_: return "Unknown"

func _on_modifier_card_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			# Only allow selecting modifier if no tile is being dragged
			if _dragging_tile_index < 0:
				_select_modifier(index)
				_modifier_cards[index].accept_event()
		else:
			# Drop on mouse release
			if _dragging_tile_index >= 0:
				_attempt_drop_tile_on_modifier(index)
				_modifier_cards[index].accept_event()

func _on_tile_display_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			# Select tile and start dragging it
			if _dragging_modifier == null:
				_select_tile(index)
		else:
			# Drop on mouse release
			if _dragging_modifier != null:
				_attempt_drop(index)
				_tile_displays[index].accept_event()
			elif _dragging_tile_index >= 0:
				# This is a release on the tile we started dragging from - ignore
				pass

func _select_modifier(index: int) -> void:
	if index in _used_modifier_indices:
		print("[Shop] Modifier %d already used - ignoring" % index)
		return
	if index >= 0 and index < shop_session.available_modifiers.size():
		_selected_modifier_index = index
		_dragging_modifier = shop_session.available_modifiers[index]
		var mod_name = _get_modifier_name(_dragging_modifier)
		print("[Shop] Selected modifier: %s (index %d) - now dragging" % [mod_name, index])
		_create_ghost()
		_modifier_cards[index].modulate = Color(1.0, 0.8, 0.0, 1.0)  # Golden highlight


func _select_tile(index: int) -> void:
	if index >= 0 and index < shop_session.available_tiles.size():
		_selected_tile_index = index
		_dragging_tile_index = index
		var tile = shop_session.available_tiles[index]
		print("[Shop] Selected tile: %s (index %d) - now dragging" % [tile.get_letter(), index])
		_create_tile_ghost(index)
		_tile_displays[index].modulate = Color(1.0, 0.8, 0.0, 1.0)  # Golden highlight

func _create_ghost() -> void:
	if _ghost_node:
		_ghost_node.queue_free()

	_ghost_node = Control.new()
	_ghost_node.name = "ModifierGhost"
	_ghost_node.custom_minimum_size = Vector2(140, 50)
	_ghost_node.modulate = Color(1, 1, 1, 0.8)
	_ghost_node.z_index = 100
	_ghost_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	label.text = _get_modifier_name(_dragging_modifier)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	ghost_panel.add_child(label)

	shop_overlay.add_child(_ghost_node)


func _create_tile_ghost(tile_index: int) -> void:
	if _ghost_node:
		_ghost_node.queue_free()

	var tile_state = shop_session.available_tiles[tile_index]

	_ghost_node = Control.new()
	_ghost_node.name = "TileGhost"
	_ghost_node.custom_minimum_size = Vector2(64, 64)
	_ghost_node.modulate = Color(1, 1, 1, 0.8)
	_ghost_node.z_index = 100
	_ghost_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load and display the tile texture
	var letter = tile_state.get_letter()
	var tile_data_path = "res://data/tile_data/tiles/tile_%s.tres" % letter.to_lower()
	var tile_data: LetterTileData = load(tile_data_path) as LetterTileData

	var texture_rect = TextureRect.new()
	texture_rect.name = "TextureRect"
	texture_rect.custom_minimum_size = Vector2(64, 64)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tile_data and tile_data.texture:
		texture_rect.texture = tile_data.texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost_node.add_child(texture_rect)

	shop_overlay.add_child(_ghost_node)


func _attempt_drop(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= shop_session.available_tiles.size():
		print("[Shop] Drop attempt on invalid tile index: %d" % tile_index)
		return

	var tile = shop_session.available_tiles[tile_index]
	var mod_name = _get_modifier_name(_dragging_modifier)
	print("[Shop] Drop attempt: modifier '%s' on tile '%s' (index %d)" % [mod_name, tile.get_letter(), tile_index])

	if shop_session.can_apply_modifier(tile):
		var mod_instance = ModifierRegistry.create_modifier(_dragging_modifier, ModifierTypes.Tier.BRONZE, ModifierTypes.Lifetime.PERMANENT)
		shop_session = shop_session.apply_modifier(tile, mod_instance)
		print("[Shop] Modifier Applied | Tile: '%s' (index %d) | Modifier: %s" % [tile.get_letter(), tile_index, mod_name])
		_mark_modifier_used(_selected_modifier_index)
		_show_badge(tile_index)
		_end_drag()
	else:
		print("[Shop] Drop failed: tile '%s' cannot accept modifier (already has one?)" % tile.get_letter())
		_show_invalid_drop(tile_index)

func _restore_tile_visual(tile_index: int) -> void:
	var final_tiles = shop_session.get_final_tiles()
	if tile_index >= final_tiles.size():
		_tile_displays[tile_index].modulate = Color.WHITE
		return
	var tile_state: TileState = final_tiles[tile_index]
	if tile_state.get_active_modifier() != null:
		_apply_modifier_visual_to_tile(tile_index)
	else:
		_tile_displays[tile_index].modulate = Color.WHITE


func _apply_modifier_visual_to_tile(tile_index: int) -> void:
	var display = _tile_displays[tile_index]
	var final_tiles = shop_session.get_final_tiles()
	if tile_index >= final_tiles.size():
		return
	var tile_state: TileState = final_tiles[tile_index]
	var modifiers_dict: Dictionary = tile_state.get_modifiers().to_dictionary()
	var visual: Dictionary = ModifierVisualPipeline.compute_tile_visual(modifiers_dict)

	# Apply tint to the whole display
	display.modulate = visual.tint

	# Apply invert shader to TextureRect
	var texture_rect = display.get_node_or_null("TextureRect")
	if texture_rect:
		if visual.invert:
			var shader: Shader = load("res://scenes/tile/invert.gdshader")
			var mat := ShaderMaterial.new()
			mat.shader = shader
			texture_rect.material = mat
		else:
			texture_rect.material = null

	# Add badge container with symbols
	var existing_badges = display.get_node_or_null("BadgeContainer")
	if existing_badges:
		existing_badges.queue_free()

	if visual.has("badges") and not visual.badges.is_empty():
		var badge_container := HBoxContainer.new()
		badge_container.name = "BadgeContainer"
		badge_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_container.position = Vector2(0, 0)
		badge_container.z_index = 10
		display.add_child(badge_container)
		for badge_info in visual.badges:
			var label := Label.new()
			label.text = badge_info.symbol
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_container.add_child(label)


func _show_badge(tile_index: int) -> void:
	_apply_modifier_visual_to_tile(tile_index)

func _show_invalid_drop(tile_index: int) -> void:
	var display = _tile_displays[tile_index]
	display.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Error red
	await get_tree().create_timer(0.2).timeout
	_restore_tile_visual(tile_index)
	_end_drag()

func _end_drag() -> void:
	print("[Shop] Drag ended - cleared state")
	if _modifier_cards and _selected_modifier_index >= 0:
		_modifier_cards[_selected_modifier_index].modulate = Color.WHITE

	if _ghost_node:
		_ghost_node.queue_free()
		_ghost_node = null

	_dragging_modifier = null
	_selected_modifier_index = -1


func _attempt_drop_tile_on_modifier(modifier_index: int) -> void:
	if modifier_index < 0 or modifier_index >= shop_session.available_modifiers.size():
		print("[Shop] Drop attempt on invalid modifier index: %d" % modifier_index)
		return

	if _dragging_tile_index < 0:
		return

	if modifier_index in _used_modifier_indices:
		print("[Shop] Drop attempt: modifier %d already consumed - ignoring" % modifier_index)
		_show_invalid_tile_drop()
		return

	var tile = shop_session.available_tiles[_dragging_tile_index]
	var mod_type = shop_session.available_modifiers[modifier_index]
	var mod_name = _get_modifier_name(mod_type)
	print("[Shop] Drop attempt: tile '%s' on modifier '%s' (modifier index %d)" % [tile.get_letter(), mod_name, modifier_index])

	if shop_session.can_apply_modifier(tile):
		var mod_instance = ModifierRegistry.create_modifier(mod_type, ModifierTypes.Tier.BRONZE, ModifierTypes.Lifetime.PERMANENT)
		shop_session = shop_session.apply_modifier(tile, mod_instance)
		print("[Shop] Modifier Applied | Tile: '%s' (index %d) | Modifier: %s" % [tile.get_letter(), _dragging_tile_index, mod_name])
		_mark_modifier_used(modifier_index)
		_show_tile_badge(_dragging_tile_index)
		_end_tile_drag()
	else:
		print("[Shop] Drop failed: tile '%s' cannot accept modifier (already has one?)" % tile.get_letter())
		_show_invalid_tile_drop()


func _show_tile_badge(tile_index: int) -> void:
	_apply_modifier_visual_to_tile(tile_index)


func _show_invalid_tile_drop() -> void:
	if _dragging_tile_index >= 0:
		var display = _tile_displays[_dragging_tile_index]
		display.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Error red
		await get_tree().create_timer(0.2).timeout
	_end_tile_drag()


func _end_tile_drag() -> void:
	print("[Shop] Tile drag ended - cleared state")
	if _tile_displays and _selected_tile_index >= 0:
		_restore_tile_visual(_selected_tile_index)

	if _ghost_node:
		_ghost_node.queue_free()
		_ghost_node = null

	_dragging_tile_index = -1
	_selected_tile_index = -1


func _draw_debug_zones() -> void:
	# Draw semi-transparent rectangles around drop zones for debugging
	for i in range(_modifier_cards.size()):
		var card = _modifier_cards[i]
		var debug_rect = Control.new()
		debug_rect.name = "DebugRect_Modifier_%d" % i
		debug_rect.modulate = Color(0, 1, 0, 0.3)  # Green semi-transparent
		debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_rect.global_position = card.global_position
		debug_rect.custom_minimum_size = card.custom_minimum_size
		debug_rect.size = card.custom_minimum_size
		shop_overlay.add_child(debug_rect)
		_debug_rects.append(debug_rect)
		print("[Shop] Debug zone created for modifier %d at %s" % [i, card.global_position])

	for i in range(_tile_displays.size()):
		var tile = _tile_displays[i]
		var debug_rect = Control.new()
		debug_rect.name = "DebugRect_Tile_%d" % i
		debug_rect.modulate = Color(1, 0, 0, 0.3)  # Red semi-transparent
		debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		debug_rect.global_position = tile.global_position
		debug_rect.custom_minimum_size = tile.custom_minimum_size
		debug_rect.size = tile.custom_minimum_size
		shop_overlay.add_child(debug_rect)
		_debug_rects.append(debug_rect)
		print("[Shop] Debug zone created for tile %d at %s" % [i, tile.global_position])


func _revert_session() -> void:
	# Revert all player-applied modifiers, preserve pre-loaded ones
	print("[Shop] Revert: clearing session changes")
	shop_session = shop_session.revert_all()
	_used_modifier_indices.clear()
	_refresh_ui_after_revert()


func _refresh_ui_after_revert() -> void:
	# Clear all session badges and reset modifier card visuals
	for i in range(_modifier_cards.size()):
		_modifier_cards[i].modulate = Color.WHITE
	for i in range(_tile_displays.size()):
		_restore_tile_visual(i)
	print("[Shop] UI refreshed after revert")


func _commit_session() -> void:
	# Finalize assignments and trigger shop continue (animation + hand integration)
	print("[Shop] Commit: finalizing tile assignments")
	var final_tiles = shop_session.get_final_tiles()
	print("[Shop] Final tiles: %d tiles with applied modifiers" % final_tiles.size())
	# Update shop_session so Main can access it via shop_controller
	shop_session = ShopSession.new(shop_session.round_number, shop_session.is_boss_round, final_tiles, shop_session.available_modifiers)
	# Emit continue signal which triggers Main to handle exit animation + finalize
	shop_overlay.continue_requested.emit()
	print("[Shop] Committed changes, continue signal emitted")


func _input(event: InputEvent) -> void:
	# Only handle motion here - use _unhandled_input for releases so GUI controls get first shot
	if event is InputEventMouseMotion and _ghost_node:
		var mouse_pos = event.position
		_ghost_node.global_position = mouse_pos - Vector2(70, 25)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard-driven shop interaction
	if event.is_action_pressed("ui_cancel"):
		# ESC: Revert all changes and proceed to next round (same as ENTER but without applying modifiers)
		print("[Shop] ESC pressed - reverting changes and proceeding to next round")
		_revert_session()
		# Skip applying modifiers and go straight to round continuation
		shop_overlay.continue_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		# ENTER: Commit changes and proceed to next round
		print("[Shop] ENTER pressed - committing changes")
		_commit_session()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if _dragging_modifier != null and _ghost_node:
			print("[Shop] Fallback release: modifier drag cancelled (not over any tile)")
			_end_drag()
		elif _dragging_tile_index >= 0 and _ghost_node:
			print("[Shop] Fallback release: tile drag cancelled (not over any modifier)")
			_end_tile_drag()
