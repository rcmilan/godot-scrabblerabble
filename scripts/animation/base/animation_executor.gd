extends RefCounted
class_name AnimationExecutor

## Base class for animation executors.
## Executors encapsulate the logic for executing specific animation types.
## They share state with the parent TileAnimator via the context.

# =============================================================================
# CONTEXT (shared state with TileAnimator)
# =============================================================================

var _context: AnimationContext = null


func _init(context: AnimationContext) -> void:
	_context = context


# =============================================================================
# PROTECTED HELPERS
# =============================================================================

## Applies a dictionary of properties to a tile.
func _apply_properties(tile: Tile, properties: Dictionary) -> void:
	for prop_name in properties.keys():
		tile.set(prop_name, properties[prop_name])


## Registers a tween for a tile in the shared context.
func _register_tween(tile: Tile, tween: Tween) -> void:
	_context.active_tweens[tile] = tween


## Unregisters a tween for a tile.
func _unregister_tween(tile: Tile) -> void:
	_context.active_tweens.erase(tile)


## Creates a completion callback for batch animations.
func _create_batch_completion_callback(
	tile: Tile,
	tiles: Array[Tile],
	strategy: TileAnimationStrategy,
	completed_count_ref: Array,  # Using array as reference wrapper
	total_tiles: int
) -> Callable:
	return func():
		strategy.on_animation_complete(tile)
		_context.emit_single_tile_animated(tile)
		_unregister_tween(tile)
		completed_count_ref[0] += 1

		if completed_count_ref[0] >= total_tiles:
			_context.is_animating = _context.active_tweens.size() > 0
			_context.emit_animation_completed(tiles)


## Creates a completion callback for single tile animations.
func _create_single_completion_callback(
	tile: Tile,
	strategy: TileAnimationStrategy
) -> Callable:
	var tiles_array: Array[Tile] = [tile]
	return func():
		strategy.on_animation_complete(tile)
		_context.emit_single_tile_animated(tile)
		_unregister_tween(tile)
		_context.is_animating = _context.active_tweens.size() > 0
		_context.emit_animation_completed(tiles_array)
