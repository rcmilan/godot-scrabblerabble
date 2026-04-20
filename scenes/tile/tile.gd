extends Control
class_name Tile

## A letter tile that can be placed on the board or held in hand.
## Supports click-to-select and drag-and-drop interactions.
## Manages its own visual state and emits signals for game events.
## Drag state machine is delegated to TileDragHelper.

# === Signals ===
signal tile_selected(tile: Tile)
signal tile_right_clicked(tile: Tile)
signal tile_drag_started(tile: Tile)
signal tile_drag_ended(tile: Tile)

# === Constants ===
const DRAG_Z_INDEX: int = 100      # Z-index while dragging
const SELECTED_SCALE: Vector2 = Vector2(1.05, 1.05)
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)
const SCALE_TWEEN_DURATION: float = 0.1

# === Enums ===

## Where the tile currently resides
enum TileLocation {
	IN_BAG,      # Not yet drawn
	IN_HAND,     # Player's hand
	ON_BOARD,    # Placed on board
	IN_DISCARD   # Discarded
}

# === Domain State ===
var _state: TileState = null
var _event_bus: DomainEventBus = null

# === Tile Data (from LetterTileData resource) ===
var tile_data: LetterTileData = null

# === Passthroughs (backward compat, read from _state) ===
var letter: String:
	get: return _state.get_letter() if _state else ""
var base_points: int:
	get: return _state.get_base_points() if _state else 0
var is_locked: bool:
	get: return _state.is_locked() if _state else false
var modifiers: Dictionary:
	get: return _state.get_modifiers().to_dictionary() if _state else {}

# === Composable Modifiers (visual) ===
var _spark_effect: TileSparkEffect = null

const EXPO_SPARK_COLORS: Dictionary = {
	ModifierTypes.Tier.BRONZE: Color(1.0, 0.3, 0.2),
	ModifierTypes.Tier.SILVER: Color(1.0, 0.6, 0.1),
	ModifierTypes.Tier.GOLD: Color(0.3, 0.5, 1.0),
}

# === Location State ===
var location: TileLocation = TileLocation.IN_BAG
var current_cell: BoardCell = null  # Only valid when ON_BOARD
var _cell_binding_suspended: bool = false  # True during drag operations

# === Selection State ===
var is_selected: bool = false
var allow_hover_feedback: bool = true
var selection_order: int = -1  # -1 = not selected
var external_scale_management: bool = false  # When true, fan layout controls scale
var _is_cursor_highlighted: bool = false  # Set by FocusCursor when navigating hand

# === Drag State (delegated to TileDragHelper) ===
var _drag: TileDragHelper = null
var _original_z_index: int = 0

# === Animation state tracking ===
var _is_animating: bool = false

# === Pending initialization (applied in _ready) ===
var _pending_texture: Texture2D = null

# === Node References ===
@onready var border: Panel = $Border
@onready var locked_border: Panel = $LockedBorder
@onready var texture_rect: TextureRect = $TextureRect
@onready var badge_container: HBoxContainer = $BadgeContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Initialize default state if not yet set (e.g. before initialize() is called)
	if _state == null:
		_state = TileState.create("", 0)

	_drag = TileDragHelper.new()
	_drag.drag_threshold_reached.connect(_on_drag_threshold_reached)
	_drag.drag_ended.connect(_on_drag_ended)

	# Apply pending texture if initialize() was called before _ready()
	if _pending_texture and texture_rect:
		texture_rect.texture = _pending_texture
		_pending_texture = null

	_update_visual()

	# Connect to animation lifecycle signals
	TileAnimator.animation_started.connect(_on_tile_animator_animation_started)
	TileAnimator.animation_completed.connect(_on_tile_animator_animation_completed)


func _process(_delta: float) -> void:
	# Only update position if we're the lead tile (directly dragged)
	# DragManager handles positioning for follower tiles
	if _drag.is_dragging() and _drag.is_lead_tile:
		global_position = get_global_mouse_position() - _drag.drag_offset


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


# === Public API ===

## Set the DomainEventBus for this tile.
func set_event_bus(event_bus: DomainEventBus) -> void:
	_event_bus = event_bus


## Get the current domain state.
func get_state() -> TileState:
	return _state


## Update the tile's domain state. Publishes TileStateChanged event.
func update_state(new_state: TileState) -> void:
	var old_state: TileState = _state
	_state = new_state
	if _event_bus:
		var event := TileStateChanged.new(get_instance_id(), old_state, new_state)
		_event_bus.publish_tile_state_changed(event)
	_on_state_changed(old_state, new_state)


## Initialize tile with data from a LetterTileData resource.
func initialize(data: LetterTileData) -> void:
	if data == null:
		push_error("[Tile] initialize() called with null data!")
		name = "Tile_ERROR_NULL_%d" % get_instance_id()
		return

	# Strip whitespace from letter to handle data inconsistencies
	var clean_letter: String = data.letter.strip_edges() if data.letter else ""

	if clean_letter.is_empty():
		push_error("[Tile] LetterTileData has empty letter! Raw value: '%s'" % data.letter)
		name = "Tile_ERROR_EMPTY_%d" % get_instance_id()
		return

	tile_data = data
	_state = TileState.create(clean_letter, data.base_points)

	# Set unique name using instance ID to avoid Godot auto-renaming duplicates
	name = "Tile_%s_%d" % [clean_letter, get_instance_id()]

	# Apply texture now if node is ready, otherwise store for _ready()
	if data.texture:
		if texture_rect:
			texture_rect.texture = data.texture
		else:
			_pending_texture = data.texture
	else:
		push_warning("[Tile] Letter '%s' is missing texture" % clean_letter)

	print("[Tile] Initialized: %s (%d pts)" % [clean_letter, data.base_points])


## Set the selected state of this tile.
func set_selected(value: bool) -> void:
	is_selected = value
	_update_visual()
	_animate_selection_scale()


## Set the selection order for multi-select.
func set_selection_order(order: int) -> void:
	selection_order = order


func _animate_selection_scale() -> void:
	if external_scale_management:
		return
	var target_scale: Vector2 = SELECTED_SCALE if is_selected else NORMAL_SCALE
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, SCALE_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT)


## Get the total point value including modifiers.
func get_points() -> int:
	return base_points


## Check if this tile can be interacted with.
func can_interact() -> bool:
	return not is_locked and location != TileLocation.IN_BAG


# =============================================================================
# PLACEMENT STATE MANAGEMENT (DDD: Single responsibility for tile-cell binding)
# =============================================================================

## Atomically attaches this tile to a board cell.
## Updates both tile.current_cell and cell.tile to maintain consistency.
func attach_to_cell(cell: BoardCell) -> void:
	if cell == null:
		push_error("[Tile] Cannot attach to null cell")
		return

	# Detach from any existing cell first
	if current_cell != null and current_cell != cell:
		detach_from_cell()

	current_cell = cell
	cell.tile = self
	location = TileLocation.ON_BOARD
	_cell_binding_suspended = false
	print("[Tile] %s attached to cell %s" % [name, cell.name])


## Atomically detaches this tile from its current cell.
## Clears both tile.current_cell and cell.tile.
func detach_from_cell() -> void:
	if current_cell != null:
		var cell_name: String = current_cell.name
		current_cell.tile = null
		current_cell = null
		_cell_binding_suspended = false
		print("[Tile] %s detached from cell %s" % [name, cell_name])


## Suspends the cell binding during drag operations.
## Clears cell.tile but preserves current_cell reference for potential restoration.
func suspend_cell_binding() -> void:
	if current_cell != null and not _cell_binding_suspended:
		current_cell.tile = null
		_cell_binding_suspended = true
		print("[Tile] %s suspended binding from cell %s" % [name, current_cell.name])


## Restores the cell binding after a cancelled drag.
## Restores cell.tile from the preserved current_cell reference.
func restore_cell_binding() -> void:
	if current_cell != null and _cell_binding_suspended:
		current_cell.tile = self
		_cell_binding_suspended = false
		print("[Tile] %s restored binding to cell %s" % [name, current_cell.name])


## Checks if this tile has a valid, active cell binding.
func has_active_cell_binding() -> bool:
	return current_cell != null and not _cell_binding_suspended


## Moves tile to hand location, clearing any cell binding.
func move_to_hand() -> void:
	detach_from_cell()
	location = TileLocation.IN_HAND


## Moves tile to discard location.
func move_to_discard() -> void:
	detach_from_cell()
	location = TileLocation.IN_DISCARD


# =============================================================================
# MODIFIER MANAGEMENT (delegates to TileState, keeps backward compat)
# =============================================================================

## Adds a modifier to this tile (one per type).
func add_modifier(modifier: ModifierInstance) -> void:
	update_state(_state.with_modifier(modifier))
	EventBus.modifier_applied.emit(self, modifier)


## Removes a modifier by type.
func remove_modifier(type: ModifierTypes.Type) -> void:
	update_state(_state.without_modifier(type))


## Clears all modifiers.
func clear_modifiers() -> void:
	update_state(_state.with_modifiers(ModifierCollection.empty()))


## Removes CONSUMABLE modifiers only (called after a play).
func consume_modifiers() -> void:
	var old_mods: ModifierCollection = _state.get_modifiers()
	var new_state: TileState = _state.with_consumed_modifiers()
	if old_mods.size() != new_state.get_modifiers().size():
		# Emit consumed events for each removed modifier
		for mod in old_mods.get_all():
			if mod.lifetime == ModifierTypes.Lifetime.CONSUMABLE:
				EventBus.modifier_consumed.emit(self, mod.type)
		update_state(new_state)


## Removes CONSUMABLE and PER_ROUND modifiers (called at round end).
func clear_round_modifiers() -> void:
	update_state(_state.with_cleared_round_modifiers())


## Checks if the tile has a specific modifier type.
func has_modifier(type: ModifierTypes.Type) -> bool:
	return _state.has_modifier(type)


## Returns the ModifierCollection from the current state.
func get_modifiers() -> ModifierCollection:
	return _state.get_modifiers()


## Derives the tile's primary modifier type from the visual pipeline (invert/tint).
func get_primary_modifier_type() -> ModifierTypes.Type:
	var visual: Dictionary = ModifierVisualPipeline.compute_tile_visual(modifiers)
	if visual.invert:
		return ModifierTypes.Type.RESET
	for type in modifiers.keys():
		var mod: ModifierInstance = modifiers[type]
		if mod.behavior and mod.behavior.get_visual(mod.tier).tint == visual.tint:
			return mod.type
	return ModifierTypes.Type.NONE


# =============================================================================
# RESET
# =============================================================================

## Reset tile to initial state (for recycling).
func reset() -> void:
	detach_from_cell()
	is_selected = false
	_state = _state.with_cleared_round_modifiers()
	if not _state.has_modifier(ModifierTypes.Type.EXPO):
		_remove_spark_effect()
	location = TileLocation.IN_BAG
	selection_order = -1
	scale = NORMAL_SCALE
	rotation = 0.0
	if _drag:
		_drag.force_end()
	_cell_binding_suspended = false
	_apply_invert(false)
	_update_visual()


## Sets this tile as a follower in a multi-drag (not directly dragged).
## Returns false if the tile cannot be dragged (locked or non-interactable).
func set_as_drag_follower() -> bool:
	if not can_interact():
		return false

	if not _drag.set_as_follower():
		return false

	allow_hover_feedback = false
	return true


## Force-resets all drag state (called by DragManager for all tiles when drag ends).
func force_end_drag() -> void:
	_drag.force_end()
	allow_hover_feedback = true
	_apply_modifier_visual()
	z_index = 0


## Sets locked state through the modifier system.
## Backward-compatible: any code calling set_locked(true) now adds a LOCKED modifier.
func set_locked(value: bool) -> void:
	if value and not has_modifier(ModifierTypes.Type.LOCKED):
		var locked_mod: ModifierInstance = ModifierRegistry.create_modifier(
			ModifierTypes.Type.LOCKED,
			ModifierTypes.Tier.BRONZE,
			ModifierTypes.Lifetime.PER_ROUND
		)
		add_modifier(locked_mod)
	elif not value and has_modifier(ModifierTypes.Type.LOCKED):
		remove_modifier(ModifierTypes.Type.LOCKED)


# === Private: State Change Handler ===

## Reacts to domain state changes — updates visuals based on modifier diff.
func _on_state_changed(old_state: TileState, new_state: TileState) -> void:
	var old_mods: ModifierCollection = old_state.get_modifiers()
	var new_mods: ModifierCollection = new_state.get_modifiers()

	# Handle EXPO spark effect add/remove
	var had_expo: bool = old_mods.has(ModifierTypes.Type.EXPO)
	var has_expo: bool = new_mods.has(ModifierTypes.Type.EXPO)
	if has_expo and not had_expo:
		var expo_mod: ModifierInstance = new_mods.get_modifier(ModifierTypes.Type.EXPO)
		_add_spark_effect(expo_mod.tier)
	elif had_expo and not has_expo:
		_remove_spark_effect()

	_update_modifier_visual()


# === Private: Input Handling ===

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if can_interact():
					_drag.on_press(event.position, get_global_mouse_position(), global_position)
			else:
				if _drag.on_release():
					# Was a click, not a drag
					tile_selected.emit(self)
				allow_hover_feedback = true
				_apply_modifier_visual()
		MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				tile_right_clicked.emit(self)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# on_motion returns true if drag threshold was just reached
	_drag.on_motion(event.position)


# === Private: Drag Signal Handlers ===

func _on_drag_threshold_reached() -> void:
	# Safety check - should have been caught in on_press but double-check
	if not can_interact():
		_drag.force_end()
		return

	allow_hover_feedback = false

	_original_z_index = z_index
	z_index = DRAG_Z_INDEX

	var visual: Dictionary = _get_modifier_visual()
	modulate = visual.tint * Color(1.2, 1.2, 1.2)

	var cell_info: String = String(current_cell.name) if current_cell else "none"
	print("[Tile] Drag start: %s | Location: %s | Cell: %s | Locked: %s" % [
		name, TileLocation.keys()[location], cell_info, is_locked
	])

	tile_drag_started.emit(self)


func _on_drag_ended() -> void:
	z_index = _original_z_index

	var cell_info: String = String(current_cell.name) if current_cell else "none"
	print("[Tile] Drag end: %s | Location: %s | Cell: %s" % [
		name, TileLocation.keys()[location], cell_info
	])

	tile_drag_ended.emit(self)


# === Private: Visual Updates ===

## Invert shader material (lazy-loaded, shared across tiles)
static var _invert_material: ShaderMaterial = null

static func _get_invert_material() -> ShaderMaterial:
	if _invert_material == null:
		var shader: Shader = load("res://scenes/tile/invert.gdshader")
		_invert_material = ShaderMaterial.new()
		_invert_material.shader = shader
	return _invert_material


## Returns the modifier visual from the pipeline: {tint: Color, invert: bool}.
func _get_modifier_visual() -> Dictionary:
	return ModifierVisualPipeline.compute_tile_visual(modifiers)


## Applies the full modifier visual (tint + invert shader + badges) to this tile.
## This is the single source of truth for modifier appearance.
func _apply_modifier_visual() -> void:
	var visual: Dictionary = _get_modifier_visual()
	modulate = visual.tint * Color(1.1, 1.1, 1.1) if _is_cursor_highlighted else visual.tint
	_apply_invert(visual.invert)
	if visual.has("badges"):
		_update_badges(visual.badges)


## Applies or removes the invert shader on the TextureRect.
func _apply_invert(invert: bool) -> void:
	if not texture_rect:
		return
	if invert:
		texture_rect.material = _get_invert_material()
	else:
		texture_rect.material = null


func _update_badges(badges: Array) -> void:
	if not badge_container:
		return
	for child in badge_container.get_children():
		child.queue_free()
	for badge_info in badges:
		var label := Label.new()
		label.text = badge_info.symbol
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_container.add_child(label)


## Sets cursor highlight (FocusCursor navigating over this tile in hand).
## Postcondition: hover brightness applied when value is true. Border is unaffected.
func set_cursor_highlighted(value: bool) -> void:
	_is_cursor_highlighted = value
	_update_visual()


## Unified highlight update from a TileHighlightState value object.
## Replaces the dual cursor/selection highlight logic with a single entry point.
func update_highlight(highlight: TileHighlightState) -> void:
	_is_cursor_highlighted = highlight.is_cursor_hovered()
	is_selected = highlight.is_selected()
	selection_order = highlight.get_selection_order()
	_update_visual()
	_animate_selection_scale()


func _update_visual() -> void:
	if border:
		border.visible = is_selected
	if locked_border:
		locked_border.visible = is_locked

	if _drag == null or not _drag.is_dragging():
		_apply_modifier_visual()


func _add_spark_effect(tier: ModifierTypes.Tier) -> void:
	_remove_spark_effect()
	_spark_effect = TileSparkEffect.new()
	_spark_effect.spark_color = EXPO_SPARK_COLORS.get(tier, Color.RED)
	add_child(_spark_effect)


func _remove_spark_effect() -> void:
	if _spark_effect and is_instance_valid(_spark_effect):
		_spark_effect.queue_free()
	_spark_effect = null


func _update_modifier_visual() -> void:
	if locked_border:
		locked_border.visible = is_locked
	_apply_modifier_visual()


# === Signal Handlers (connected in scene) ===

func _on_mouse_entered() -> void:
	if allow_hover_feedback and can_interact():
		var visual: Dictionary = _get_modifier_visual()
		modulate = visual.tint * Color(1.1, 1.1, 1.1)


func _on_mouse_exited() -> void:
	if allow_hover_feedback:
		_update_visual()


func _on_tile_animator_animation_started(tiles: Array[Tile]) -> void:
	if self in tiles:
		_is_animating = true


func _on_tile_animator_animation_completed(tiles: Array[Tile]) -> void:
	if self in tiles:
		_is_animating = false


func is_animating() -> bool:
	return _is_animating
