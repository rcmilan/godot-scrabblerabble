extends RefCounted
class_name HandFanLayout

## HandFanLayout: Positions hand tiles in a fan arrangement.
## Below FAN_THRESHOLD tiles are spaced normally. Above it, spacing
## decreases progressively and tiles begin to overlap.
## Hovered tiles scale up, push neighbors aside, and render above them.

# =============================================================================
# CONFIGURATION
# =============================================================================

## Tile count at or below which no overlap occurs.
const FAN_THRESHOLD: int = 5

## Visual tile width in pixels.
const TILE_WIDTH: float = 64.0

## Gap between tiles when count <= FAN_THRESHOLD.
const BASE_SPACING: float = 4.0

## Smallest allowed distance between tile left-edges (limits max overlap).
const MIN_STEP: float = 20.0

## Maximum width the tile layout may occupy (forces earlier overlap).
## Tiles are still centered within the full container.
const MAX_LAYOUT_WIDTH: float = 400.0

## Hover effect constants.
const HOVER_SCALE: Vector2 = Vector2(1.1, 1.1)
const HOVER_Z_INDEX: int = 50
const HOVER_TWEEN_DURATION: float = 0.1

## Pixels the hovered tile rises above the hand.
const HOVER_LIFT: float = 12.0

## How many pixels immediate neighbors are pushed away on hover.
## Falls off with distance: push = HOVER_PUSH / abs(distance).
const HOVER_PUSH: float = 24.0

# =============================================================================
# STATE
# =============================================================================

var _container: Control = null
var _managed_tiles: Array[Tile] = []
var _hovered_tile: Tile = null

## Cached base positions calculated by update_layout().
## Index matches tile child order. Used as anchor for hover push offsets.
var _base_positions: Array[Vector2] = []

## One tween per tile — handles position + scale in parallel.
var _tile_tweens: Dictionary = {}  # Tile -> Tween

# =============================================================================
# PUBLIC API
# =============================================================================

## Binds the layout to the tile container.
func setup(container: Control) -> void:
	_container = container


## Recalculates base positions for every tile in the container.
## If a tile is currently hovered, the push offsets are reapplied.
func update_layout() -> void:
	if _container == null:
		return

	var tiles := _get_tiles()
	_sync_managed_tiles(tiles)

	var count := tiles.size()
	if count == 0:
		_base_positions.clear()
		return

	var step := _calculate_step(count)
	var total_width := (count - 1) * step + TILE_WIDTH
	var container_width := _container.size.x
	var start_x := (container_width - total_width) / 2.0
	var y_offset := (_container.size.y - TILE_WIDTH) / 2.0

	_base_positions.clear()
	for i in count:
		var tile := tiles[i]
		var pos := Vector2(start_x + i * step, y_offset)
		_base_positions.append(pos)
		tile.position = pos
		tile.size = Vector2(TILE_WIDTH, TILE_WIDTH)
		tile.pivot_offset = Vector2(TILE_WIDTH / 2.0, TILE_WIDTH / 2.0)
		if tile != _hovered_tile:
			tile.z_index = i
			tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE

	# Reapply push if something is hovered (e.g. tiles were added/removed).
	if _hovered_tile and _managed_tiles.has(_hovered_tile):
		_apply_hover_push(false)


## Disconnects all managed tiles and resets state.
func cleanup() -> void:
	for tile in _managed_tiles.duplicate():
		_unregister_tile(tile)
	_managed_tiles.clear()
	_hovered_tile = null
	_base_positions.clear()
	_tile_tweens.clear()

# =============================================================================
# SPACING ALGORITHM
# =============================================================================

## Returns the horizontal distance between the left edges of consecutive tiles.
## - At or below FAN_THRESHOLD: full tile width + gap (no overlap).
## - Above FAN_THRESHOLD: smoothly compresses to fit MAX_LAYOUT_WIDTH.
## - Never goes below MIN_STEP to keep tiles recognisable.
func _calculate_step(count: int) -> float:
	if count <= 1:
		return 0.0

	var ideal_step := TILE_WIDTH + BASE_SPACING  # 68 px

	if count <= FAN_THRESHOLD:
		return ideal_step

	var available_width := minf(_container.size.x, MAX_LAYOUT_WIDTH)
	var needed := (count - 1) * ideal_step + TILE_WIDTH

	if needed <= available_width:
		return ideal_step

	# Compress to fit within MAX_LAYOUT_WIDTH.
	var step := (available_width - TILE_WIDTH) / float(count - 1)
	return maxf(step, MIN_STEP)

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
	tile.mouse_entered.connect(_on_tile_mouse_entered.bind(tile))
	tile.mouse_exited.connect(_on_tile_mouse_exited.bind(tile))


func _unregister_tile(tile: Tile) -> void:
	_managed_tiles.erase(tile)
	_kill_tween(tile)

	if not is_instance_valid(tile):
		if _hovered_tile == tile:
			_hovered_tile = null
		return

	tile.external_scale_management = false
	tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
	tile.z_index = 0

	var entered_cb := _on_tile_mouse_entered.bind(tile)
	if tile.mouse_entered.is_connected(entered_cb):
		tile.mouse_entered.disconnect(entered_cb)

	var exited_cb := _on_tile_mouse_exited.bind(tile)
	if tile.mouse_exited.is_connected(exited_cb):
		tile.mouse_exited.disconnect(exited_cb)

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
func _apply_hover_push(animate: bool) -> void:
	var tiles := _get_tiles()
	var count := tiles.size()
	if count == 0 or _hovered_tile == null:
		return

	var hover_idx := _hovered_tile.get_index()
	if hover_idx < 0 or hover_idx >= _base_positions.size():
		return

	for i in count:
		if i >= _base_positions.size():
			break
		var tile := tiles[i]
		var base_pos := _base_positions[i]

		if tile == _hovered_tile:
			var lifted_pos := Vector2(base_pos.x, base_pos.y - HOVER_LIFT)
			var target_scale := HOVER_SCALE
			if animate:
				_tween_tile(tile, lifted_pos, target_scale)
			else:
				tile.position = lifted_pos
				tile.scale = target_scale
			continue

		# Push neighbors away. Amount falls off with distance.
		var distance := i - hover_idx
		var push := HOVER_PUSH / maxf(absf(float(distance)), 1.0)
		var offset_x := signf(float(distance)) * push
		var target_pos := Vector2(base_pos.x + offset_x, base_pos.y)
		var target_scale := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE

		if animate:
			_tween_tile(tile, target_pos, target_scale)
		else:
			tile.position = target_pos
			tile.scale = target_scale


## Restores all tiles to their base positions and resting scale.
func _restore_all_tiles() -> void:
	var tiles := _get_tiles()
	for i in tiles.size():
		if i >= _base_positions.size():
			break
		var tile := tiles[i]
		tile.z_index = i
		var target_scale := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
		_tween_tile(tile, _base_positions[i], target_scale)


## Restores a single tile that lost hover (safety fallback).
func _restore_single_tile(tile: Tile) -> void:
	var idx := tile.get_index()
	tile.z_index = idx
	if idx >= 0 and idx < _base_positions.size():
		var target_scale := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
		_tween_tile(tile, _base_positions[idx], target_scale)

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

# =============================================================================
# HELPERS
# =============================================================================

func _get_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for child in _container.get_children():
		if child is Tile:
			tiles.append(child)
	return tiles
