extends AnimationExecutor
class_name SpinAnimationExecutor

## Executes spin animations for tiles with MULTI modifiers.
## Tiles scale up, rotate 360 degrees with a glow, then return to normal.


## Animates a batch of tiles with a spin effect.
func execute(tiles: Array[Tile], strategy: SpinTileAnimation) -> void:
	_context.is_animating = true
	_context.emit_animation_started(tiles)

	var completed_count_ref: Array = [0]
	var total_tiles: int = tiles.size()

	for i in tiles.size():
		var tile: Tile = tiles[i]
		var delay: float = i * strategy.stagger_delay

		strategy.on_animation_start(tile)

		var tween: Tween = _context.create_tween()

		# Delay before starting
		if delay > 0:
			tween.tween_interval(delay)

		# Phase 1: Spin up — scale up + start rotation + glow
		tween.set_parallel(true)
		tween.tween_property(tile, "scale", strategy.peak_scale, strategy.spin_up_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_BACK)
		tween.tween_property(tile, "rotation", TAU, strategy.spin_up_duration + strategy.spin_down_duration) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(tile, "modulate", strategy.glow_color, strategy.spin_up_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)

		# Phase 2: Spin down — return scale + fade glow
		tween.set_parallel(false)
		tween.tween_property(tile, "scale", Vector2.ONE, strategy.spin_down_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)
		tween.parallel().tween_property(tile, "modulate", Color.WHITE, strategy.spin_down_duration) \
			.set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_QUAD)

		_register_tween(tile, tween)
		tween.finished.connect(
			_create_batch_completion_callback(tile, tiles, strategy, completed_count_ref, total_tiles)
		)

	print("[SpinAnimationExecutor] Started spin for %d tiles" % tiles.size())
