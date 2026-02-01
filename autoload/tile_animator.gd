extends Node

## TileAnimator: Coordinates tile animations across the game.
## Uses strategy pattern with executor composition for flexibility.
## Acts as a thin facade delegating to specialized executors.

# =============================================================================
# SIGNALS
# =============================================================================

signal animation_started(tiles: Array[Tile])
signal animation_completed(tiles: Array[Tile])
signal single_tile_animated(tile: Tile)

# =============================================================================
# SHARED CONTEXT
# =============================================================================

var _context: AnimationContext = null

# =============================================================================
# STRATEGIES (lazy-loaded)
# =============================================================================

var _draw_animation: DrawTileAnimation = null
var _return_animation: ReturnToHandAnimation = null
var _shake_animation: ShakeTileAnimation = null
var _stomp_animation: StompTileAnimation = null

# =============================================================================
# EXECUTORS (lazy-loaded)
# =============================================================================

var _batch_executor: BatchAnimationExecutor = null
var _return_executor: ReturnAnimationExecutor = null
var _shake_executor: ShakeAnimationExecutor = null
var _stomp_executor: StompAnimationExecutor = null


func _ready() -> void:
	_setup_context()


func _setup_context() -> void:
	_context = AnimationContext.new()
	_context.setup(
		func(tiles: Array[Tile]): animation_started.emit(tiles),
		func(tiles: Array[Tile]): animation_completed.emit(tiles),
		func(tile: Tile): single_tile_animated.emit(tile),
		create_tween,
		get_tree
	)


# =============================================================================
# PUBLIC API
# =============================================================================

## Animates a batch of tiles using the draw animation strategy.
## Tiles animate from below screen to their final hand positions.
func animate_draw_batch(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	_ensure_draw_resources()
	_batch_executor.execute(tiles, _draw_animation)


## Animates a tile returning from the board to the hand.
## Call this BEFORE moving the tile to the hand - this method handles the move.
func animate_return_to_hand(tile: Tile, hand: Node, cell: Node) -> void:
	if tile == null or hand == null:
		return

	_ensure_return_resources()
	_return_executor.execute_single(tile, hand, cell, _return_animation)


## Plays a shake animation on a tile to indicate an illegal action.
func animate_shake(tile: Tile) -> void:
	if tile == null:
		return

	_ensure_shake_resources()
	_shake_executor.execute(tile, _shake_animation)


## Animates a batch of tiles with a stomp effect to confirm placement.
func animate_stomp_batch(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	_ensure_stomp_resources()
	_stomp_executor.execute(tiles, _stomp_animation)


## Animates tiles returning to hand from a cancelled drag.
func animate_cancel_to_hand(tiles: Array[Tile], hand: Node) -> void:
	if tiles.is_empty() or hand == null:
		return

	_ensure_return_resources()
	_return_executor.execute_cancel_batch(tiles, hand, _return_animation)


## Returns true if any animations are currently playing.
func is_animating() -> bool:
	return _context.is_animating


## Cancels all active animations immediately.
func cancel_all() -> void:
	for tile in _context.active_tweens.keys():
		var tween: Tween = _context.active_tweens[tile]
		if is_instance_valid(tween):
			tween.kill()
	_context.active_tweens.clear()
	_context.is_animating = false


## Cancels animation for a specific tile.
func cancel_tile_animation(tile: Tile) -> void:
	_context.cancel_tile_animation(tile)


# =============================================================================
# PRIVATE: LAZY INITIALIZATION
# =============================================================================

func _ensure_draw_resources() -> void:
	if _draw_animation == null:
		_draw_animation = DrawTileAnimation.new()
	if _batch_executor == null:
		_batch_executor = BatchAnimationExecutor.new(_context)


func _ensure_return_resources() -> void:
	if _return_animation == null:
		_return_animation = ReturnToHandAnimation.new()
	if _return_executor == null:
		_return_executor = ReturnAnimationExecutor.new(_context)


func _ensure_shake_resources() -> void:
	if _shake_animation == null:
		_shake_animation = ShakeTileAnimation.new()
	if _shake_executor == null:
		_shake_executor = ShakeAnimationExecutor.new(_context)


func _ensure_stomp_resources() -> void:
	if _stomp_animation == null:
		_stomp_animation = StompTileAnimation.new()
	if _stomp_executor == null:
		_stomp_executor = StompAnimationExecutor.new(_context)
