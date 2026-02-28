extends RefCounted
class_name HandFanLayout

## HandFanLayout: Positions hand tiles in a fan arrangement with parabolic arc.
## Tiles are positioned using ArcLayoutComputer for elevation and rotation.
## Hovered tiles scale up, push neighbors aside, and render above them.

# =============================================================================
# CONFIGURATION
# =============================================================================

## Visual tile width in pixels.
const TILE_WIDTH: float = 64.0

## Hover effect constants.
const HOVER_SCALE: Vector2 = Vector2(1.1, 1.1)
const HOVER_Z_INDEX: int = 50
const HOVER_TWEEN_DURATION: float = 0.1

## Pixels the hovered tile rises above the arc.
const HOVER_LIFT: float = 10.0

## Push force applied to neighbors during hover (in pixels per index distance).
## Adjacent tiles (distance=1) pushed by 12px. Falloff: push = HOVER_PUSH / distance.
const HOVER_PUSH: float = 12.0

## Duration of reflow tweens when tiles are added/removed.
const REFLOW_DURATION: float = 0.15

# =============================================================================
# STATE
# =============================================================================

var _container: Control = null
var _managed_tiles: Array[Tile] = []
var _hovered_tile: Tile = null

## Arc layout computer for parabolic positioning and rotation.
var _computer: ArcLayoutComputer = null

## Cached base transforms calculated by update_layout().
## Keyed by Tile → TileArcTransform. Used as anchor for hover effects.
var _base_transforms: Dictionary[Tile, TileArcTransform] = {}

## One tween per tile — handles position + scale in parallel.
var _tile_tweens: Dictionary[Tile, Tween] = {}

## Reflow tweens for smooth position/rotation transitions when tiles are added/removed.
var _reflow_tweens: Dictionary[Tile, Tween] = {}

## Stored callbacks for safe signal disconnection (prevents Callable recreation).
var _tile_callbacks: Dictionary[Tile, Dictionary] = {}  # Tile -> {entered, exited}

# =============================================================================
# PUBLIC API
# =============================================================================

## Binds the layout to the tile container and creates the ArcLayoutComputer.
func setup(container: Control) -> void:
	_container = container
	_computer = ArcLayoutComputer.new()


## Recalculates base transforms for every tile in the container using ArcLayoutComputer.
## If a tile is currently hovered, the push offsets are reapplied.
func update_layout() -> void:
	if _container == null:
		return

	var tiles := _get_tiles()
	_sync_managed_tiles(tiles)

	var count := tiles.size()
	if count == 0:
		_base_transforms.clear()
		return

	# Compute arc transforms via ArcLayoutComputer
	var container_width := _container.size.x
	var base_y := (_container.size.y - TILE_WIDTH) / 2.0
	var arc_transforms := _computer.compute(count, container_width, base_y)

	_base_transforms.clear()
	for i in count:
		var tile := tiles[i]
		var transform := arc_transforms[i]

		# Set size and pivot
		tile.size = Vector2(TILE_WIDTH, TILE_WIDTH)
		tile.pivot_offset = Vector2(32, 32)
		tile.z_index = i
		tile.rotation = transform.rotation_rad

		# NEW: new tiles get position set directly (draw animation handles entry)
		# EXISTING: tiles tween to new position over REFLOW_DURATION
		if tile not in _base_transforms:
			# New tile: set directly (no tween)
			tile.position = transform.position
		else:
			# Existing tile: tween for smooth reflow
			_kill_reflow_tween(tile)
			var tween := _container.create_tween().set_parallel(true)
			tween.tween_property(tile, "position", transform.position, REFLOW_DURATION) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(tile, "rotation", transform.rotation_rad, REFLOW_DURATION) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_reflow_tweens[tile] = tween

		# Save transform
		_base_transforms[tile] = transform

		# Apply select/normal scale (don't touch hovered tiles here)
		if tile != _hovered_tile:
			tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE

	# Reapply hover push if something is hovered (handles tile add/remove)
	if _hovered_tile and _managed_tiles.has(_hovered_tile):
		_apply_hover_push(false)


## Disconnects all managed tiles and resets state.
func cleanup() -> void:
	for tile in _managed_tiles.duplicate():
		_unregister_tile(tile)
	_managed_tiles.clear()
	_hovered_tile = null
	_base_transforms.clear()
	_tile_tweens.clear()
	_reflow_tweens.clear()
	_tile_callbacks.clear()


## Triggers the hover push effect for the given tile as if it were mouse-hovered.
## Called by FocusCursor for keyboard/controller navigation.
func apply_hover_effect(tile: Tile) -> void:
	_on_tile_mouse_entered(tile)


## Removes the hover push effect for the given tile.
## Called by FocusCursor when cursor moves away.
func remove_hover_effect(tile: Tile) -> void:
	_on_tile_mouse_exited(tile)

# =============================================================================
# TILE REGISTRATION (hover signal wiring)
# =============================================================================

func _sync_managed_tiles(current_tiles: Array[Tile]) -> void:
	# Unregister tiles no longer in the container.
	var to_remove: Array[Tile] = []
	for tile in _managed_tiles:
		if not current_tiles.has(tile):
			to_remove.append(tile)
	for tile in to_remove:
		_unregister_tile(tile)

	# Register new tiles.
	for tile in current_tiles:
		if not _managed_tiles.has(tile):
			_register_tile(tile)


func _register_tile(tile: Tile) -> void:
	_managed_tiles.append(tile)
	tile.external_scale_management = true
	var entered_cb := _on_tile_mouse_entered.bind(tile)
	var exited_cb := _on_tile_mouse_exited.bind(tile)
	tile.mouse_entered.connect(entered_cb)
	tile.mouse_exited.connect(exited_cb)
	# Store callbacks for safe disconnection (avoids Callable recreation)
	if not _tile_callbacks.has(tile):
		_tile_callbacks[tile] = {}
	_tile_callbacks[tile]["entered"] = entered_cb
	_tile_callbacks[tile]["exited"] = exited_cb


func _unregister_tile(tile: Tile) -> void:
	_managed_tiles.erase(tile)
	_kill_tween(tile)

	# Disconnect signals FIRST (safe even for invalid tiles)
	if _tile_callbacks.has(tile):
		var cbs = _tile_callbacks[tile]
		# Only try to disconnect if tile is still valid
		if is_instance_valid(tile):
			if tile.mouse_entered.is_connected(cbs["entered"]):
				tile.mouse_entered.disconnect(cbs["entered"])
			if tile.mouse_exited.is_connected(cbs["exited"]):
				tile.mouse_exited.disconnect(cbs["exited"])
		_tile_callbacks.erase(tile)

	if not is_instance_valid(tile):
		if _hovered_tile == tile:
			_hovered_tile = null
		return

	tile.external_scale_management = false
	tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
	tile.z_index = 0

	if _hovered_tile == tile:
		_hovered_tile = null

# =============================================================================
# HOVER HANDLERS
# =============================================================================

func _on_tile_mouse_entered(tile: Tile) -> void:
	if not tile.can_interact() or tile.location != Tile.TileLocation.IN_HAND:
		return

	# Clean up previous hover in case mouse_exited was missed.
	if _hovered_tile and _hovered_tile != tile and is_instance_valid(_hovered_tile):
		_restore_single_tile(_hovered_tile)
		# Kill all lingering tweens from previous hover
		for t in _tile_tweens.keys():
			_kill_tween(t)

	_hovered_tile = tile
	tile.z_index = HOVER_Z_INDEX
	_apply_hover_push(true)


func _on_tile_mouse_exited(tile: Tile) -> void:
	# Only act if this tile is actually the hovered one.
	if _hovered_tile != tile:
		return
	_hovered_tile = null
	_restore_all_tiles()

# =============================================================================
# HOVER PUSH EFFECT
# =============================================================================

## Applies the push offset to all tiles based on the currently hovered tile.
## When animate=true, positions and scales are tweened smoothly.
## Hovered tile rises 10px above its arc position.
func _apply_hover_push(animate: bool) -> void:
	var tiles := _get_tiles()
	var count := tiles.size()
	if count == 0 or _hovered_tile == null:
		return

	var hover_idx := _hovered_tile.get_index()
	if hover_idx < 0 or hover_idx >= count:
		return

	for i in count:
		var tile := tiles[i]
		var base_transform := _base_transforms.get(tile)
		if not base_transform:
			continue

		if tile == _hovered_tile:
			# Hovered tile: scale up AND rise 10px above its arc position
			var lifted_pos := Vector2(base_transform.position.x, base_transform.position.y - HOVER_LIFT)
			var target_scale := HOVER_SCALE
			if animate:
				_tween_tile(tile, lifted_pos, target_scale)
			else:
				tile.position = lifted_pos
				tile.scale = target_scale
			continue

		# Push neighbors away in x-direction only (preserve arc y position)
		var distance := i - hover_idx
		var push := HOVER_PUSH / maxf(absf(float(distance)), 1.0)
		var offset_x := signf(float(distance)) * push
		var target_pos := Vector2(base_transform.position.x + offset_x, base_transform.position.y)
		var target_scale := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE

		if animate:
			_tween_tile(tile, target_pos, target_scale)
		else:
			tile.position = target_pos
			tile.scale = target_scale


## Restores all tiles to their base arc positions and resting scale.
func _restore_all_tiles() -> void:
	var tiles := _get_tiles()
	for i in tiles.size():
		var tile := tiles[i]
		var transform := _base_transforms.get(tile)
		if not transform:
			continue
		tile.z_index = i
		var target_scale := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
		_tween_tile(tile, transform.position, target_scale)


## Restores a single tile that lost hover (safety fallback).
func _restore_single_tile(tile: Tile) -> void:
	var idx := tile.get_index()
	tile.z_index = idx
	var transform := _base_transforms.get(tile)
	if transform:
		var target_scale := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
		_tween_tile(tile, transform.position, target_scale)

# =============================================================================
# TWEENING
# =============================================================================

## Tweens a tile's position and scale in parallel. Kills any previous tween
## for this tile to avoid conflicts.
func _tween_tile(tile: Tile, target_pos: Vector2, target_scale: Vector2) -> void:
	_kill_tween(tile)
	var tween := _container.create_tween().set_parallel(true)
	tween.tween_property(tile, "position", target_pos, HOVER_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(tile, "scale", target_scale, HOVER_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tile_tweens[tile] = tween


func _kill_tween(tile: Tile) -> void:
	if _tile_tweens.has(tile):
		var old: Tween = _tile_tweens[tile]
		if old and old.is_valid():
			old.kill()
		_tile_tweens.erase(tile)


func _kill_reflow_tween(tile: Tile) -> void:
	if _reflow_tweens.has(tile):
		var old: Tween = _reflow_tweens[tile]
		if old and old.is_valid():
			old.kill()
		_reflow_tweens.erase(tile)

# =============================================================================
# HELPERS
# =============================================================================

func _get_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for child in _container.get_children():
		if child is Tile:
			tiles.append(child)
	return tiles
