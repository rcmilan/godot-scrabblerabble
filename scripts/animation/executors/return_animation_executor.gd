extends AnimationExecutor
class_name ReturnAnimationExecutor

## Executes return-to-hand animations.
## Handles both single tile returns from board and batch cancel animations.


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

	# Clear the cell's tile reference
	if cell:
		cell.tile = null

	# Remove tile from its current parent
	var current_parent: Node = tile.get_parent()
	if current_parent:
		current_parent.remove_child(tile)

	# Add to hand (triggers layout)
	hand.add_tile(tile)

	# Update tile state
	tile.current_cell = null
	tile.location = Tile.TileLocation.IN_HAND

	# Wait for layout
	await _context.get_tree().process_frame

	# Animate from old position to new
	_animate_position_transition(tile, start_global_pos, strategy)

	print("[ReturnAnimationExecutor] Started return animation for: %s" % tile.name)


## Animates a batch of tiles returning to hand from a cancelled drag.
func execute_cancel_batch(tiles: Array[Tile], hand: Node, strategy: TileAnimationStrategy) -> void:
	_context.is_animating = true
	_context.emit_animation_started(tiles)

	# Step 1: Capture all tiles' current global positions
	var start_positions: Dictionary = {}
	for tile in tiles:
		if is_instance_valid(tile):
			start_positions[tile] = tile.global_position

	# Step 2: Restore tiles to hand via DragManager
	DragManager.restore_tiles_to_parents()

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
