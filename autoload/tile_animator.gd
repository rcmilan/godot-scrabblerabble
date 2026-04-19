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
# CONFIGURATION
# =============================================================================

var hype_config: HypeConfig = null

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
var _lift_animation: LiftTileAnimation = null
var _slide_left_animation: SlideLeftAnimation = null
var _slide_in_from_right_animation: SlideInFromRightAnimation = null
var _slide_up_animation: SlideUpAnimation = null
var _slide_down_animation: SlideDownAnimation = null
var _slide_right_animation: SlideRightAnimation = null
var _slide_in_from_top_animation: SlideInFromTopAnimation = null
var _slide_in_from_bottom_animation: SlideInFromBottomAnimation = null
var _slide_in_from_left_animation: SlideInFromLeftAnimation = null

# =============================================================================
# EXECUTORS (lazy-loaded)
# =============================================================================

var _batch_executor: BatchAnimationExecutor = null
var _return_executor: ReturnAnimationExecutor = null
var _shake_executor: ShakeAnimationExecutor = null
var _stomp_executor: StompAnimationExecutor = null
var _spin_executor: SpinAnimationExecutor = null
var _drop_animation: DropTileAnimation = null
var _drop_executor: DropAnimationExecutor = null
var _lift_executor: BatchAnimationExecutor = null


func _ready() -> void:
	_setup_context()
	_load_hype_config()


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


## Animates a lift phase for all tiles (anticipation beat before main animations).
## All tiles scale up and move upward simultaneously, then return to normal.
func animate_lift_batch(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	_ensure_lift_resources()
	_lift_executor.execute(tiles, _lift_animation)


## Animates gravity drop effect for a batch of tiles.
## movements: Array[Dictionary] - each dict contains {tile: Tile, from_cell: BoardCell, to_cell: BoardCell}
func animate_drop_batch(movements: Array) -> void:
	if movements.is_empty():
		return

	_ensure_drop_resources()
	_drop_executor.execute(movements, _drop_animation)


## Animates tiles returning to hand from a cancelled drag.
func animate_cancel_to_hand(tiles: Array[Tile], hand: Node, restore_fn: Callable = Callable()) -> void:
	if tiles.is_empty() or hand == null:
		return

	_ensure_glide_resources()
	_return_executor.execute_cancel_batch(tiles, hand, _glide_animation, restore_fn)


## Slides a node off-screen to the left.
## Used for board exit during pause transitions.
func animate_slide_left(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_left_resources()
	return _slide_left_animation.animate(node, on_complete)


## Slides a node in from the right side of the screen.
## Used for pause menu entrance and board re-entrance during transitions.
func animate_slide_in_from_right(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_in_from_right_resources()
	return _slide_in_from_right_animation.animate(node, on_complete)


## Slides a node up off-screen.
## Used for UI elements during pause transitions.
func animate_slide_up(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_up_resources()
	return _slide_up_animation.animate(node, on_complete)


## Slides a node down off-screen.
## Used for UI elements during pause transitions.
func animate_slide_down(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_down_resources()
	return _slide_down_animation.animate(node, on_complete)


## Slides a node right off-screen.
## Used for UI elements during pause transitions.
func animate_slide_right(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_right_resources()
	return _slide_right_animation.animate(node, on_complete)


## Slides a node in from the top of the screen.
## Used for UI elements returning during resume transitions.
func animate_slide_in_from_top(node: Node, original_y: float, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_in_from_top_resources()
	return _slide_in_from_top_animation.animate(node, original_y, on_complete)


## Slides a node in from the bottom of the screen.
## Used for UI elements returning during resume transitions.
func animate_slide_in_from_bottom(node: Node, original_y: float, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_in_from_bottom_resources()
	return _slide_in_from_bottom_animation.animate(node, original_y, on_complete)


## Slides a node in from the left of the screen.
## Used for UI elements returning during resume transitions.
func animate_slide_in_from_left(node: Node, original_x: float, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	_ensure_slide_in_from_left_resources()
	return _slide_in_from_left_animation.animate(node, original_x, on_complete)


## Animates a batch of tiles gliding from hand positions to their board cells.
## Call AFTER all tiles have been placed (reparented to their cells).
## start_positions: Dictionary mapping Tile -> Vector2 captured BEFORE placement.
func animate_place_batch_to_board(tiles: Array[Tile], start_positions: Dictionary) -> void:
	if tiles.is_empty():
		return
	_ensure_glide_resources()
	_return_executor.execute_place_batch_to_board(tiles, start_positions, _glide_animation)


## Animates a tile gliding from its hand position to a board cell.
## Call AFTER place_tile_on_cell_silent() has reparented the tile.
## start_global_pos: tile.global_position captured BEFORE placement.
func animate_place_to_board(tile: Tile, start_global_pos: Vector2) -> void:
	if tile == null:
		return
	_ensure_glide_resources()
	_return_executor.execute_place_to_board(tile, start_global_pos, _glide_animation)


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


func _ensure_slide_left_resources() -> void:
	if _slide_left_animation == null:
		_slide_left_animation = SlideLeftAnimation.new()


func _ensure_slide_in_from_right_resources() -> void:
	if _slide_in_from_right_animation == null:
		_slide_in_from_right_animation = SlideInFromRightAnimation.new()


func _ensure_slide_up_resources() -> void:
	if _slide_up_animation == null:
		_slide_up_animation = SlideUpAnimation.new()


func _ensure_slide_down_resources() -> void:
	if _slide_down_animation == null:
		_slide_down_animation = SlideDownAnimation.new()


func _ensure_slide_right_resources() -> void:
	if _slide_right_animation == null:
		_slide_right_animation = SlideRightAnimation.new()


func _ensure_slide_in_from_top_resources() -> void:
	if _slide_in_from_top_animation == null:
		_slide_in_from_top_animation = SlideInFromTopAnimation.new()


func _ensure_slide_in_from_bottom_resources() -> void:
	if _slide_in_from_bottom_animation == null:
		_slide_in_from_bottom_animation = SlideInFromBottomAnimation.new()


func _ensure_slide_in_from_left_resources() -> void:
	if _slide_in_from_left_animation == null:
		_slide_in_from_left_animation = SlideInFromLeftAnimation.new()


func _ensure_drop_resources() -> void:
	_drop_animation = _ensure_strategy(_drop_animation, DropTileAnimation)
	_drop_executor = _ensure_executor(_drop_executor, DropAnimationExecutor)


func _ensure_lift_resources() -> void:
	_lift_animation = _ensure_strategy(_lift_animation, LiftTileAnimation)
	_lift_executor = _ensure_executor(_lift_executor, BatchAnimationExecutor)


## Ensures stomp and spin animation strategies are initialized.
## Call this before inspecting or modifying animation durations for scaling,
## so that strategies are not null on the first play of a run.
func prepare_play_animations() -> void:
	_ensure_stomp_resources()
	_ensure_spin_resources()


func _load_hype_config() -> void:
	hype_config = load("res://scripts/animation/hype/hype_config.tres")
	if hype_config == null:
		push_error("[TileAnimator] Failed to load hype_config.tres")
	else:
		if hype_config.debug_logging_enabled:
			print("[TileAnimator] Loaded HypeConfig from res://scripts/animation/hype/hype_config.tres")
