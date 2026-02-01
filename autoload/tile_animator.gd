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
var _return_animation: ReturnToHandAnimation = null
var _shake_animation: ShakeTileAnimation = null
var _stomp_animation: StompTileAnimation = null


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


## Animates a tile returning from the board to the hand.
## Call this BEFORE moving the tile to the hand - this method handles the move.
## Parameters:
##   tile: The tile to animate
##   hand: The Hand node to add the tile to
##   cell: The BoardCell the tile is currently on
func animate_return_to_hand(tile: Tile, hand: Node, cell: Node) -> void:
	if tile == null or hand == null:
		return

	if _return_animation == null:
		_return_animation = ReturnToHandAnimation.new()

	_animate_return_single(tile, hand, cell, _return_animation)


## Plays a shake animation on a tile to indicate an illegal action.
## The tile shakes left-right quickly and returns to its original position.
func animate_shake(tile: Tile) -> void:
	if tile == null:
		return

	if _shake_animation == null:
		_shake_animation = ShakeTileAnimation.new()

	_animate_shake_single(tile, _shake_animation)


## Animates a batch of tiles with a stomp effect to confirm placement.
## Tiles scale up briefly then return to normal size with staggered timing.
func animate_stomp_batch(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	if _stomp_animation == null:
		_stomp_animation = StompTileAnimation.new()

	_animate_stomp_batch(tiles, _stomp_animation)


## Animates tiles returning to hand from a cancelled drag.
## Tiles smoothly glide from their current position to the hand.
## Call this BEFORE restoring tiles to hand via DragManager.
func animate_cancel_to_hand(tiles: Array[Tile], hand: Node) -> void:
	if tiles.is_empty() or hand == null:
		return

	if _return_animation == null:
		_return_animation = ReturnToHandAnimation.new()

	_animate_cancel_batch(tiles, hand, _return_animation)


## Returns true if any animations are currently playing.
func is_animating() -> bool:
	return _is_animating


## Cancels all active animations immediately.
func cancel_all() -> void:
	for tile in _active_tweens.keys():
		var tween: Tween = _active_tweens[tile]
		if is_instance_valid(tween):
			tween.kill()
	_active_tweens.clear()
	_is_animating = false


## Cancels animation for a specific tile.
func cancel_tile_animation(tile: Tile) -> void:
	if _active_tweens.has(tile):
		var tween: Tween = _active_tweens[tile]
		if is_instance_valid(tween):
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

		# Set starting state
		var start_offset: Vector2 = strategy.get_start_position_offset()
		var start_props: Dictionary = strategy.get_start_properties()

		tile.position = final_position + start_offset
		_apply_properties(tile, start_props)

		# Notify strategy of animation start
		strategy.on_animation_start(tile)

		# Create staggered animation (parallel tween with per-property delays)
		var tween: Tween = create_tween()
		tween.set_parallel(true)

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


## Animates a single tile returning from board to hand.
## Captures board position, moves to hand, then animates from old to new position.
func _animate_return_single(tile: Tile, hand: Node, cell: Node, strategy: TileAnimationStrategy) -> void:
	_is_animating = true
	var tiles_array: Array[Tile] = [tile]
	animation_started.emit(tiles_array)

	# Capture the tile's current global position (on the board)
	var start_global_pos: Vector2 = tile.global_position

	# Apply start properties and notify strategy
	var start_props: Dictionary = strategy.get_start_properties()
	_apply_properties(tile, start_props)
	strategy.on_animation_start(tile)

	# Clear the cell's tile reference
	if cell:
		cell.tile = null

	# Remove tile from its current parent (the cell's tile_anchor)
	var current_parent: Node = tile.get_parent()
	if current_parent:
		current_parent.remove_child(tile)

	# Add to hand (this triggers HBoxContainer layout)
	hand.add_tile(tile)

	# Update tile state
	tile.current_cell = null
	tile.location = Tile.TileLocation.IN_HAND

	# Wait for layout to calculate the new hand position
	await get_tree().process_frame

	# Capture the final position in hand (local to parent)
	var final_position: Vector2 = tile.position
	var final_global_pos: Vector2 = tile.global_position

	# Calculate where the tile should start (in local coordinates)
	# to appear at its old board position
	var global_offset: Vector2 = start_global_pos - final_global_pos
	tile.position = final_position + global_offset

	# Create the animation tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Position animation
	tween.tween_property(tile, "position", final_position, strategy.duration) \
		.set_ease(strategy.ease_type) \
		.set_trans(strategy.trans_type)

	# Property animations (scale, modulate, etc.)
	var end_props: Dictionary = strategy.get_end_properties()
	for prop_name in end_props.keys():
		tween.tween_property(tile, prop_name, end_props[prop_name], strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type)

	_active_tweens[tile] = tween

	# Track completion
	tween.finished.connect(func():
		strategy.on_animation_complete(tile)
		single_tile_animated.emit(tile)
		_active_tweens.erase(tile)
		_is_animating = _active_tweens.size() > 0
		animation_completed.emit(tiles_array)
	)

	print("[TileAnimator] Started return-to-hand animation for tile: %s" % tile.name)


## Animates a batch of tiles returning to hand from a cancelled drag.
func _animate_cancel_batch(tiles: Array[Tile], hand: Node, strategy: TileAnimationStrategy) -> void:
	_is_animating = true
	animation_started.emit(tiles)

	# Step 1: Capture all tiles' current global positions
	var start_positions: Dictionary = {}  # Tile -> Vector2
	for tile in tiles:
		if is_instance_valid(tile):
			start_positions[tile] = tile.global_position

	# Step 2: Restore tiles to hand via DragManager
	DragManager.restore_tiles_to_parents()

	# Step 3: Wait for layout to calculate new hand positions
	await get_tree().process_frame

	# Step 4: Animate each tile from old position to new position
	var total_tiles: int = tiles.size()
	var completed_count: int = 0

	for i in tiles.size():
		var tile: Tile = tiles[i]
		if not is_instance_valid(tile):
			completed_count += 1
			continue

		var start_global_pos: Vector2 = start_positions.get(tile, tile.global_position)
		var final_position: Vector2 = tile.position
		var final_global_pos: Vector2 = tile.global_position

		# Calculate starting local position to match old global position
		var global_offset: Vector2 = start_global_pos - final_global_pos
		tile.position = final_position + global_offset

		# Apply start properties
		var start_props: Dictionary = strategy.get_start_properties()
		_apply_properties(tile, start_props)
		strategy.on_animation_start(tile)

		# Calculate stagger delay
		var delay: float = i * strategy.stagger_delay

		# Create animation tween
		var tween: Tween = create_tween()
		tween.set_parallel(true)

		# Position animation
		tween.tween_property(tile, "position", final_position, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type) \
			.set_delay(delay)

		# Property animations
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

	print("[TileAnimator] Started cancel-to-hand animation for %d tiles" % tiles.size())


## Animates a shake effect on a tile to indicate an illegal action.
func _animate_shake_single(tile: Tile, strategy: ShakeTileAnimation) -> void:
	# Cancel any existing animation on this tile
	cancel_tile_animation(tile)

	_is_animating = true
	var tiles_array: Array[Tile] = [tile]
	animation_started.emit(tiles_array)

	# Store original position
	var original_position: Vector2 = tile.position

	# Notify strategy of animation start
	strategy.on_animation_start(tile)

	# Create sequential shake animation
	var tween: Tween = create_tween()

	# Shake left-right multiple times
	for i in strategy.shake_count:
		# Move right
		tween.tween_property(tile, "position:x", original_position.x + strategy.shake_distance, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type)
		# Move left
		tween.tween_property(tile, "position:x", original_position.x - strategy.shake_distance, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type)

	# Return to original position
	tween.tween_property(tile, "position:x", original_position.x, strategy.duration) \
		.set_ease(strategy.ease_type) \
		.set_trans(strategy.trans_type)

	_active_tweens[tile] = tween

	# Track completion
	tween.finished.connect(func():
		strategy.on_animation_complete(tile)
		single_tile_animated.emit(tile)
		_active_tweens.erase(tile)
		_is_animating = _active_tweens.size() > 0
		animation_completed.emit(tiles_array)
	)

	print("[TileAnimator] Started shake animation for tile: %s" % tile.name)


## Animates a dramatic stomp effect on a batch of tiles with staggered timing.
## Tiles rise up, slam down, squish on impact, and spawn particles.
func _animate_stomp_batch(tiles: Array[Tile], strategy: StompTileAnimation) -> void:
	_is_animating = true
	animation_started.emit(tiles)

	var completed_count: int = 0
	var total_tiles: int = tiles.size()

	for i in tiles.size():
		var tile: Tile = tiles[i]
		var delay: float = i * strategy.stagger_delay
		var original_position: Vector2 = tile.position

		# Notify strategy of animation start
		strategy.on_animation_start(tile)

		# Create sequential stomp animation
		var tween: Tween = create_tween()

		# Delay before starting
		if delay > 0:
			tween.tween_interval(delay)

		# Phase 1: Rise up (scale up + move up)
		tween.set_parallel(true)
		tween.tween_property(tile, "scale", strategy.rise_scale, strategy.rise_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_BACK)
		tween.tween_property(tile, "position:y", original_position.y + strategy.rise_offset, strategy.rise_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)

		# Phase 2: Slam down (scale down + move down fast)
		tween.set_parallel(false)
		tween.tween_property(tile, "scale", strategy.squish_scale, strategy.slam_duration) \
			.set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(tile, "position:y", original_position.y, strategy.slam_duration) \
			.set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_QUAD)

		# Spawn particles on impact
		tween.tween_callback(func(): _spawn_impact_particles(tile, strategy))

		# Phase 3: Recover (bounce back to normal)
		tween.tween_property(tile, "scale", Vector2.ONE, strategy.recover_duration) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_ELASTIC)

		_active_tweens[tile] = tween

		# Track completion
		tween.finished.connect(func():
			strategy.on_animation_complete(tile)
			single_tile_animated.emit(tile)
			_active_tweens.erase(tile)
			completed_count += 1

			if completed_count >= total_tiles:
				_is_animating = _active_tweens.size() > 0
				animation_completed.emit(tiles)
		)

	print("[TileAnimator] Started stomp animation for %d tiles" % tiles.size())


## Spawns impact particles around a tile's edges when it slams down.
func _spawn_impact_particles(tile: Tile, strategy: StompTileAnimation) -> void:
	var tile_size: Vector2 = tile.size if tile.size != Vector2.ZERO else Vector2(64, 64)

	# Spawn particles at each edge (bottom, left, right)
	var edge_configs: Array = [
		# [position, direction, spread]
		[Vector2(tile_size.x / 2, tile_size.y), Vector2(0, 1), 60.0],      # Bottom center - burst down/out
		[Vector2(0, tile_size.y), Vector2(-1, 0.5), 45.0],                 # Bottom-left corner
		[Vector2(tile_size.x, tile_size.y), Vector2(1, 0.5), 45.0],        # Bottom-right corner
		[Vector2(0, tile_size.y / 2), Vector2(-1, 0), 30.0],               # Left edge
		[Vector2(tile_size.x, tile_size.y / 2), Vector2(1, 0), 30.0],      # Right edge
	]

	var particles_per_edge: int = maxi(strategy.particle_count / edge_configs.size(), 2)

	for config in edge_configs:
		var pos: Vector2 = config[0]
		var dir: Vector2 = config[1]
		var spread: float = config[2]

		var particles: CPUParticles2D = CPUParticles2D.new()

		# Configure particle behavior
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.9
		particles.amount = particles_per_edge
		particles.lifetime = strategy.particle_lifetime

		# Particle movement - burst outward from edges
		particles.direction = dir
		particles.spread = spread
		particles.initial_velocity_min = strategy.particle_speed * 0.6
		particles.initial_velocity_max = strategy.particle_speed
		particles.gravity = Vector2(0, 150)  # Gentle fall

		# Particle appearance - much larger and visible
		particles.scale_amount_min = strategy.particle_size_min
		particles.scale_amount_max = strategy.particle_size_max

		# Color with fade out
		var gradient: Gradient = Gradient.new()
		gradient.add_point(0.0, strategy.particle_color)
		gradient.add_point(0.3, strategy.particle_color)
		gradient.add_point(1.0, Color(strategy.particle_color.r, strategy.particle_color.g, strategy.particle_color.b, 0.0))
		particles.color_ramp = gradient

		# Size curve - start big, shrink
		var scale_curve: Curve = Curve.new()
		scale_curve.add_point(Vector2(0.0, 1.0))
		scale_curve.add_point(Vector2(0.5, 0.7))
		scale_curve.add_point(Vector2(1.0, 0.2))
		particles.scale_amount_curve = scale_curve

		# Position at edge
		particles.position = pos

		# Add to tile
		tile.add_child(particles)

		# Auto-cleanup after particles finish
		get_tree().create_timer(strategy.particle_lifetime + 0.2).timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)
