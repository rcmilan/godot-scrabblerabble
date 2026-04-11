## DropAnimationExecutor: Executes batch gravity drop animations.
##
## Handles reparenting tiles to new cells and animating them downward.
## Each movement contains {tile, from_cell, to_cell} resolved references.
##
## Pre-condition: movements array contains resolved tile/cell references (not Vector2i).
## Post-condition: tiles are reparented to their target cells and positioned correctly.
class_name DropAnimationExecutor
extends AnimationExecutor


## Executes drop animation for a batch of movements.
##
## Args:
##   movements: Array[Dictionary] - each dict contains {tile: Tile, from_cell: BoardCell, to_cell: BoardCell}
##   strategy: DropTileAnimation - motion profile and timing
func execute(movements: Array, strategy: DropTileAnimation) -> void:
	if movements.is_empty():
		return

	_context.is_animating = true
	var tiles: Array[Tile] = []
	for movement in movements:
		tiles.append(movement["tile"])

	_context.emit_animation_started(tiles)

	var total_tiles: int = movements.size()
	var completed_count_ref: Array = [0]

	for i in movements.size():
		var movement: Dictionary = movements[i]
		var tile: Tile = movement["tile"]
		var from_cell: BoardCell = movement["from_cell"]
		var to_cell: BoardCell = movement["to_cell"]

		if not is_instance_valid(tile):
			completed_count_ref[0] += 1
			continue

		var delay: float = i * strategy.stagger_delay
		_animate_drop_tile(tile, from_cell, to_cell, strategy, delay, tiles, completed_count_ref, total_tiles)

	print("[DropAnimationExecutor] Started drop animation for %d tiles" % movements.size())


## Animates a single tile dropping to its target cell.
func _animate_drop_tile(
	tile: Tile,
	from_cell: BoardCell,
	to_cell: BoardCell,
	strategy: DropTileAnimation,
	delay: float,
	tiles: Array[Tile],
	completed_count_ref: Array,
	total_tiles: int
) -> void:
	# Notify strategy of animation start
	strategy.on_animation_start(tile)

	# Capture current global position before reparenting
	var start_global_pos: Vector2 = tile.global_position

	# Reparent tile to target cell's anchor
	var from_parent: Node = tile.get_parent()
	if from_parent:
		from_parent.remove_child(tile)
	var target_anchor: Node = to_cell.tile_anchor
	target_anchor.add_child(tile)

	# Wait one frame for layout to settle
	await _context.get_tree().process_frame

	# Calculate target position (should be at origin in new parent after reparenting)
	var target_local_pos: Vector2 = Vector2.ZERO
	var target_global_pos: Vector2 = to_cell.tile_anchor.global_position

	# Calculate starting position offset in new parent's space
	var global_offset: Vector2 = start_global_pos - target_global_pos
	tile.position = target_local_pos + global_offset

	# Create tween for drop animation
	var tween: Tween = _context.create_tween()
	tween.set_parallel(true)

	tween.tween_property(tile, "position", target_local_pos, strategy.duration) \
		.set_ease(strategy.ease_type) \
		.set_trans(strategy.trans_type) \
		.set_delay(delay)

	_register_tween(tile, tween)
	tween.finished.connect(
		_create_batch_completion_callback(tile, tiles, strategy, completed_count_ref, total_tiles)
	)
