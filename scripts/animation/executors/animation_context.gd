extends RefCounted
class_name AnimationContext

## Shared context for animation executors.
## Contains state and signal emission callbacks.

# =============================================================================
# STATE
# =============================================================================

var active_tweens: Dictionary = {}  # Tile -> Tween
var is_animating: bool = false

# =============================================================================
# SIGNAL CALLBACKS (set by TileAnimator)
# =============================================================================

var _on_animation_started: Callable
var _on_animation_completed: Callable
var _on_single_tile_animated: Callable
var _create_tween: Callable
var _get_tree: Callable


func setup(
	on_started: Callable,
	on_completed: Callable,
	on_single: Callable,
	create_tween: Callable,
	get_tree: Callable
) -> void:
	_on_animation_started = on_started
	_on_animation_completed = on_completed
	_on_single_tile_animated = on_single
	_create_tween = create_tween
	_get_tree = get_tree


# =============================================================================
# SIGNAL EMISSION
# =============================================================================

func emit_animation_started(tiles: Array[Tile]) -> void:
	if _on_animation_started.is_valid():
		_on_animation_started.call(tiles)


func emit_animation_completed(tiles: Array[Tile]) -> void:
	if _on_animation_completed.is_valid():
		_on_animation_completed.call(tiles)


func emit_single_tile_animated(tile: Tile) -> void:
	if _on_single_tile_animated.is_valid():
		_on_single_tile_animated.call(tile)


# =============================================================================
# UTILITIES
# =============================================================================

func create_tween() -> Tween:
	if _create_tween.is_valid():
		return _create_tween.call()
	return null


func get_tree() -> SceneTree:
	if _get_tree.is_valid():
		return _get_tree.call()
	return null


func cancel_tile_animation(tile: Tile) -> void:
	if active_tweens.has(tile):
		var tween: Tween = active_tweens[tile]
		if is_instance_valid(tween):
			tween.kill()
		active_tweens.erase(tile)

		if active_tweens.is_empty():
			is_animating = false
