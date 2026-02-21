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
var _glide_animation: GlideTileAnimation = null
var _shake_animation: ShakeTileAnimation = null
var _stomp_animation: StompTileAnimation = null
var _spin_animation: SpinTileAnimation = null

# =============================================================================
# EXECUTORS (lazy-loaded)
# =============================================================================

var _batch_executor: BatchAnimationExecutor = null
var _return_executor: ReturnAnimationExecutor = null
var _shake_executor: ShakeAnimationExecutor = null
var _stomp_executor: StompAnimationExecutor = null
var _spin_executor: SpinAnimationExecutor = null


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

	_ensure_glide_resources()
	_return_executor.execute_single(tile, hand, cell, _glide_animation)


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


## Animates a batch of tiles with a spin effect for modifier tiles (EXTRA, MULTI, EXPO).
func animate_spin_batch(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	_ensure_spin_resources()
	_spin_executor.execute(tiles, _spin_animation)


## Animates tiles returning to hand from a cancelled drag.
func animate_cancel_to_hand(tiles: Array[Tile], hand: Node, restore_fn: Callable = Callable()) -> void:
	if tiles.is_empty() or hand == null:
		return

	_ensure_glide_resources()
	_return_executor.execute_cancel_batch(tiles, hand, _glide_animation, restore_fn)


## Animates tiles moving from hand to discard pile.
## Tiles glide to the discard pile position, then the discard callback is invoked.
func animate_discard_batch(tiles: Array[Tile], target_position: Vector2, on_complete: Callable) -> void:
	if tiles.is_empty():
		if on_complete.is_valid():
			on_complete.call()
		return

	_ensure_glide_resources()
	_return_executor.execute_discard_batch(tiles, target_position, _glide_animation, on_complete)


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

## Lazy-initializes a strategy (no constructor args).
func _ensure_strategy(current: Variant, klass: GDScript) -> Variant:
	return current if current != null else klass.new()


## Lazy-initializes an executor (takes _context as constructor arg).
func _ensure_executor(current: Variant, klass: GDScript) -> Variant:
	return current if current != null else klass.new(_context)


func _ensure_draw_resources() -> void:
	_draw_animation = _ensure_strategy(_draw_animation, DrawTileAnimation)
	_batch_executor = _ensure_executor(_batch_executor, BatchAnimationExecutor)


func _ensure_glide_resources() -> void:
	_glide_animation = _ensure_strategy(_glide_animation, GlideTileAnimation)
	_return_executor = _ensure_executor(_return_executor, ReturnAnimationExecutor)


func _ensure_shake_resources() -> void:
	_shake_animation = _ensure_strategy(_shake_animation, ShakeTileAnimation)
	_shake_executor = _ensure_executor(_shake_executor, ShakeAnimationExecutor)


func _ensure_stomp_resources() -> void:
	_stomp_animation = _ensure_strategy(_stomp_animation, StompTileAnimation)
	_stomp_executor = _ensure_executor(_stomp_executor, StompAnimationExecutor)


func _ensure_spin_resources() -> void:
	_spin_animation = _ensure_strategy(_spin_animation, SpinTileAnimation)
	_spin_executor = _ensure_executor(_spin_executor, SpinAnimationExecutor)
