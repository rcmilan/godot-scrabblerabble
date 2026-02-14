extends RefCounted
class_name HandFanLayout

## HandFanLayout: Positions hand tiles in a fan arrangement.
## Below FAN_THRESHOLD tiles are spaced normally. Above it, spacing
## decreases progressively and tiles begin to overlap.
## Hovered tiles scale up and render above neighbors.

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

## Hover effect constants.
const HOVER_SCALE: Vector2 = Vector2(1.1, 1.1)
const HOVER_Z_INDEX: int = 50
const SCALE_TWEEN_DURATION: float = 0.1

# =============================================================================
# STATE
# =============================================================================

var _container: Control = null
var _managed_tiles: Array[Tile] = []
var _hovered_tile: Tile = null
var _hover_tweens: Dictionary = {}  # Tile -> Tween

# =============================================================================
# PUBLIC API
# =============================================================================

## Binds the layout to the tile container.
func setup(container: Control) -> void:
	_container = container


## Recalculates and applies positions for every tile in the container.
## Call after tiles are added, removed, or the container resizes.
func update_layout() -> void:
	if _container == null:
		return

	var tiles := _get_tiles()
	_sync_managed_tiles(tiles)

	var count := tiles.size()
	if count == 0:
		return

	var step := _calculate_step(count)
	var total_width := (count - 1) * step + TILE_WIDTH
	var container_width := _container.size.x
	var start_x := (container_width - total_width) / 2.0
	var y_offset := (_container.size.y - TILE_WIDTH) / 2.0

	for i in count:
		var tile := tiles[i]
		tile.position = Vector2(start_x + i * step, y_offset)
		tile.size = Vector2(TILE_WIDTH, TILE_WIDTH)
		tile.pivot_offset = Vector2(TILE_WIDTH / 2.0, TILE_WIDTH / 2.0)
		# Default z-ordering follows hand order; hover overrides temporarily.
		if tile != _hovered_tile:
			tile.z_index = i


## Disconnects all managed tiles and resets state.
func cleanup() -> void:
	for tile in _managed_tiles.duplicate():
		_unregister_tile(tile)
	_managed_tiles.clear()
	_hovered_tile = null
	_hover_tweens.clear()

# =============================================================================
# SPACING ALGORITHM
# =============================================================================

## Returns the horizontal distance between the left edges of consecutive tiles.
## - At or below FAN_THRESHOLD: full tile width + gap (no overlap).
## - Above FAN_THRESHOLD: smoothly compresses to fit the container width.
## - Never goes below MIN_STEP to keep tiles recognisable.
func _calculate_step(count: int) -> float:
	if count <= 1:
		return 0.0

	var ideal_step := TILE_WIDTH + BASE_SPACING  # 68 px

	if count <= FAN_THRESHOLD:
		return ideal_step

	var available_width := _container.size.x
	var needed := (count - 1) * ideal_step + TILE_WIDTH

	if needed <= available_width:
		return ideal_step

	# Compress to fit.
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

	# Kill any active tween for this tile.
	if _hover_tweens.has(tile):
		var tw: Tween = _hover_tweens[tile]
		if tw and tw.is_valid():
			tw.kill()
		_hover_tweens.erase(tile)

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
	if not tile.allow_hover_feedback or not tile.can_interact():
		return
	_hovered_tile = tile
	tile.z_index = HOVER_Z_INDEX
	_tween_tile_scale(tile, HOVER_SCALE)


func _on_tile_mouse_exited(tile: Tile) -> void:
	if _hovered_tile == tile:
		_hovered_tile = null

	# Restore z-index to hand-order position.
	var idx := tile.get_index()
	tile.z_index = idx

	var target := Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
	_tween_tile_scale(tile, target)


func _tween_tile_scale(tile: Tile, target: Vector2) -> void:
	# Kill any existing tween for this tile to avoid conflicts.
	if _hover_tweens.has(tile):
		var old: Tween = _hover_tweens[tile]
		if old and old.is_valid():
			old.kill()

	var tween := _container.create_tween()
	tween.tween_property(tile, "scale", target, SCALE_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT)
	_hover_tweens[tile] = tween

# =============================================================================
# HELPERS
# =============================================================================

func _get_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for child in _container.get_children():
		if child is Tile:
			tiles.append(child)
	return tiles
