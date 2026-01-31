extends Node

## TileAnimator: Coordinates tile animations across the game.
## Uses strategy pattern for flexible animation types.
## Handles batch animations with staggered timing.

# =============================================================================
# SIGNALS
# =============================================================================

signal animation_started(tiles: Array[Tile])
signal animation_completed(tiles: Array[Tile])
signal single_tile_animated(tile: Tile)

# =============================================================================
# STATE
# =============================================================================

var _active_tweens: Dictionary = {}  # tile -> Tween
var _is_animating: bool = false

# =============================================================================
# STRATEGIES (lazy-loaded)
# =============================================================================

var _draw_animation: DrawTileAnimation = null


func _ready() -> void:
	pass


# =============================================================================
# PUBLIC API
# =============================================================================

## Animates a batch of tiles using the draw animation strategy.
## Tiles animate from below screen to their final hand positions.
func animate_draw_batch(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	if _draw_animation == null:
		_draw_animation = DrawTileAnimation.new()

	_animate_batch(tiles, _draw_animation)


## Returns true if any animations are currently playing.
func is_animating() -> bool:
	return _is_animating


## Cancels all active animations immediately.
func cancel_all() -> void:
	for tile in _active_tweens.keys():
		var tween: Tween = _active_tweens[tile]
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	_is_animating = false


## Cancels animation for a specific tile.
func cancel_tile_animation(tile: Tile) -> void:
	if _active_tweens.has(tile):
		var tween: Tween = _active_tweens[tile]
		if tween and tween.is_valid():
			tween.kill()
		_active_tweens.erase(tile)

		if _active_tweens.is_empty():
			_is_animating = false


# =============================================================================
# PRIVATE: ANIMATION EXECUTION
# =============================================================================

func _animate_batch(tiles: Array[Tile], strategy: TileAnimationStrategy) -> void:
	_is_animating = true
	animation_started.emit(tiles)

	# Wait for layout to calculate final positions
	await get_tree().process_frame

	var completed_count: int = 0
	var total_tiles: int = tiles.size()

	for i in tiles.size():
		var tile: Tile = tiles[i]
		var delay: float = i * strategy.stagger_delay

		# Capture final position after layout
		var final_position: Vector2 = tile.position
		var final_global_position: Vector2 = tile.global_position

		# Set starting state
		var start_offset: Vector2 = strategy.get_start_position_offset()
		var start_props: Dictionary = strategy.get_start_properties()

		tile.position = final_position + start_offset
		_apply_properties(tile, start_props)

		# Notify strategy of animation start
		strategy.on_animation_start(tile)

		# Create staggered animation
		var tween: Tween = create_tween()
		tween.set_parallel(true)

		# Apply delay if needed
		if delay > 0:
			tween.tween_interval(delay)

		# Position animation
		tween.tween_property(tile, "position", final_position, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type) \
			.set_delay(delay)

		# Property animations (scale, modulate, etc.)
		var end_props: Dictionary = strategy.get_end_properties()
		for prop_name in end_props.keys():
			tween.tween_property(tile, prop_name, end_props[prop_name], strategy.duration) \
				.set_ease(strategy.ease_type) \
				.set_trans(strategy.trans_type) \
				.set_delay(delay)

		_active_tweens[tile] = tween

		# Track completion
		tween.finished.connect(func():
			strategy.on_animation_complete(tile)
			single_tile_animated.emit(tile)
			_active_tweens.erase(tile)
			completed_count += 1

			if completed_count >= total_tiles:
				_is_animating = false
				animation_completed.emit(tiles)
		)

	print("[TileAnimator] Started batch animation for %d tiles" % tiles.size())


func _apply_properties(tile: Tile, properties: Dictionary) -> void:
	for prop_name in properties.keys():
		tile.set(prop_name, properties[prop_name])
