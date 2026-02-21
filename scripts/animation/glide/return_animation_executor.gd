extends AnimationExecutor
class_name ReturnAnimationExecutor

## Executes glide animations for tile transitions.
## Handles return-to-hand, cancel, discard, and place-to-board animations.


## Animates a single tile returning from board to hand.
func execute_single(tile: Tile, hand: Node, cell: Node, strategy: TileAnimationStrategy) -> void:
	_context.is_animating = true
	var tiles_array: Array[Tile] = [tile]
	_context.emit_animation_started(tiles_array)

	# Capture the tile's current global position (on the board)
	var start_global_pos: Vector2 = tile.global_position

	# Apply start properties and notify strategy
	var start_props: Dictionary = strategy.get_start_properties()
	_apply_properties(tile, start_props)
	strategy.on_animation_start(tile)

	# Remove tile from its current parent
	var current_parent: Node = tile.get_parent()
	if current_parent:
		current_parent.remove_child(tile)

	# Add to hand (triggers layout)
	hand.add_tile(tile)

	# Update tile state atomically (clears cell binding and sets location)
	tile.move_to_hand()

	# Wait for layout
	await _context.get_tree().process_frame

	# Animate from old position to new
	_animate_position_transition(tile, start_global_pos, strategy)

	print("[ReturnAnimationExecutor] Started return animation for: %s" % tile.name)


## Animates a batch of tiles returning to hand from a cancelled drag.
func execute_cancel_batch(tiles: Array[Tile], hand: Node, strategy: TileAnimationStrategy, restore_fn: Callable = Callable()) -> void:
	_context.is_animating = true
	_context.emit_animation_started(tiles)

	# Step 1: Capture all tiles' current global positions
	var start_positions: Dictionary = {}
	for tile in tiles:
		if is_instance_valid(tile):
			start_positions[tile] = tile.global_position

	# Step 2: Restore tiles to hand via provided callable
	if restore_fn.is_valid():
		restore_fn.call()

	# Step 3: Wait for layout
	await _context.get_tree().process_frame

	# Step 4: Animate each tile
	var total_tiles: int = tiles.size()
	var completed_count_ref: Array = [0]

	for i in tiles.size():
		var tile: Tile = tiles[i]
		if not is_instance_valid(tile):
			completed_count_ref[0] += 1
			continue

		var start_global_pos: Vector2 = start_positions.get(tile, tile.global_position)
		var delay: float = i * strategy.stagger_delay

		_animate_position_transition_with_delay(tile, start_global_pos, strategy, delay, tiles, completed_count_ref, total_tiles)

	print("[ReturnAnimationExecutor] Started cancel animation for %d tiles" % tiles.size())


## Animates a tile from its old global position to its new position.
func _animate_position_transition(tile: Tile, start_global_pos: Vector2, strategy: TileAnimationStrategy) -> void:
	var final_position: Vector2 = tile.position
	var final_global_pos: Vector2 = tile.global_position

	# Calculate starting local position
	var global_offset: Vector2 = start_global_pos - final_global_pos
	tile.position = final_position + global_offset

	# Create animation
	var tween: Tween = _context.create_tween()
	tween.set_parallel(true)

	tween.tween_property(tile, "position", final_position, strategy.duration) \
		.set_ease(strategy.ease_type) \
		.set_trans(strategy.trans_type)

	var end_props: Dictionary = strategy.get_end_properties()
	for prop_name in end_props.keys():
		tween.tween_property(tile, prop_name, end_props[prop_name], strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type)

	_register_tween(tile, tween)
	tween.finished.connect(_create_single_completion_callback(tile, strategy))


## Animates with delay for batch operations.
func _animate_position_transition_with_delay(
	tile: Tile,
	start_global_pos: Vector2,
	strategy: TileAnimationStrategy,
	delay: float,
	tiles: Array[Tile],
	completed_count_ref: Array,
	total_tiles: int
) -> void:
	var final_position: Vector2 = tile.position
	var final_global_pos: Vector2 = tile.global_position

	var global_offset: Vector2 = start_global_pos - final_global_pos
	tile.position = final_position + global_offset

	var start_props: Dictionary = strategy.get_start_properties()
	_apply_properties(tile, start_props)
	strategy.on_animation_start(tile)

	var tween: Tween = _context.create_tween()
	tween.set_parallel(true)

	tween.tween_property(tile, "position", final_position, strategy.duration) \
		.set_ease(strategy.ease_type) \
		.set_trans(strategy.trans_type) \
		.set_delay(delay)

	var end_props: Dictionary = strategy.get_end_properties()
	for prop_name in end_props.keys():
		tween.tween_property(tile, prop_name, end_props[prop_name], strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type) \
			.set_delay(delay)

	_register_tween(tile, tween)
	tween.finished.connect(
		_create_batch_completion_callback(tile, tiles, strategy, completed_count_ref, total_tiles)
	)


## Animates tiles moving to discard pile and calls callback when complete.
func execute_discard_batch(
	tiles: Array[Tile],
	target_global_pos: Vector2,
	strategy: TileAnimationStrategy,
	on_complete: Callable
) -> void:
	_context.is_animating = true
	_context.emit_animation_started(tiles)

	var total_tiles: int = tiles.size()
	var completed_count_ref: Array = [0]

	for i in tiles.size():
		var tile: Tile = tiles[i]
		if not is_instance_valid(tile):
			completed_count_ref[0] += 1
			continue

		var delay: float = i * strategy.stagger_delay
		_animate_discard_tile(tile, target_global_pos, strategy, delay, tiles, completed_count_ref, total_tiles, on_complete)

	print("[ReturnAnimationExecutor] Started discard animation for %d tiles" % tiles.size())


## Animates a single tile to discard pile with shrink effect.
func _animate_discard_tile(
	tile: Tile,
	target_global_pos: Vector2,
	strategy: TileAnimationStrategy,
	delay: float,
	tiles: Array[Tile],
	completed_count_ref: Array,
	total_tiles: int,
	on_complete: Callable
) -> void:
	strategy.on_animation_start(tile)

	# Calculate target position in tile's local space
	var tile_parent: Node = tile.get_parent()
	var target_local_pos: Vector2 = tile.position
	if tile_parent and tile_parent.has_method("to_local"):
		target_local_pos = tile_parent.to_local(target_global_pos)
	else:
		# Fallback: estimate based on global offset
		var offset: Vector2 = target_global_pos - tile.global_position
		target_local_pos = tile.position + offset

	var tween: Tween = _context.create_tween()
	tween.set_parallel(true)

	# Position animation - move to discard pile
	tween.tween_property(tile, "position", target_local_pos, strategy.duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_delay(delay)

	# Scale animation - shrink as it moves
	tween.tween_property(tile, "scale", Vector2(0.3, 0.3), strategy.duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_delay(delay)

	# Fade out
	tween.tween_property(tile, "modulate:a", 0.0, strategy.duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_delay(delay)

	_register_tween(tile, tween)
	tween.finished.connect(
		_create_discard_completion_callback(tile, tiles, strategy, completed_count_ref, total_tiles, on_complete)
	)


## Creates completion callback for discard animations.
func _create_discard_completion_callback(
	tile: Tile,
	tiles: Array[Tile],
	strategy: TileAnimationStrategy,
	completed_count_ref: Array,
	total_tiles: int,
	on_complete: Callable
) -> Callable:
	return func():
		strategy.on_animation_complete(tile)
		_context.emit_single_tile_animated(tile)
		_unregister_tween(tile)
		completed_count_ref[0] += 1

		if completed_count_ref[0] >= total_tiles:
			_context.is_animating = _context.active_tweens.size() > 0
			_context.emit_animation_completed(tiles)
			if on_complete.is_valid():
				on_complete.call()


## Animates a tile gliding from a captured hand position to its board cell.
## Pre-condition: tile has already been placed on the cell (reparented to
## cell_anchor, position = Vector2.ZERO) by place_tile_on_cell() (via place_tile_on_cell_animated()).
## start_global_pos: tile.global_position captured BEFORE placement.
func execute_place_to_board(
	tile: Tile,
	start_global_pos: Vector2,
	strategy: TileAnimationStrategy
) -> void:
	_context.is_animating = true
	var tiles_array: Array[Tile] = [tile]
	_context.emit_animation_started(tiles_array)

	var start_props: Dictionary = strategy.get_start_properties()
	_apply_properties(tile, start_props)
	strategy.on_animation_start(tile)

	await _context.get_tree().process_frame

	_animate_position_transition(tile, start_global_pos, strategy)
	print("[ReturnAnimationExecutor] Started place-to-board animation for: %s" % tile.name)
