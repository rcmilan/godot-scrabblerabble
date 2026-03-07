extends AnimationExecutor
class_name StompAnimationExecutor

## Executes stomp animations for tile placement confirmation.
## Tiles rise up, slam down with squish effect, and spawn impact particles.


## Animates a batch of tiles with a stomp effect.
func execute(tiles: Array[Tile], strategy: StompTileAnimation) -> void:
	# Block if any tile is already animating
	for tile in tiles:
		if tile.is_animating():
			print("[StompAnimationExecutor] Animation blocked: %s already animating" % tile.name)
			return

	_context.is_animating = true
	_context.emit_animation_started(tiles)

	var completed_count_ref: Array = [0]
	var total_tiles: int = tiles.size()

	for i in tiles.size():
		var tile: Tile = tiles[i]
		var delay: float = i * strategy.stagger_delay
		var original_position: Vector2 = tile.position

		strategy.on_animation_start(tile)

		var tween: Tween = _context.create_tween()

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
			.set_trans(Tween.TRANS_CUBIC)

		_register_tween(tile, tween)
		tween.finished.connect(
			_create_batch_completion_callback(tile, tiles, strategy, completed_count_ref, total_tiles)
		)

	print("[StompAnimationExecutor] Started stomp for %d tiles" % tiles.size())


## Spawns impact particles around a tile's edges when it slams down.
func _spawn_impact_particles(tile: Tile, strategy: StompTileAnimation) -> void:
	var tile_size: Vector2 = tile.size if tile.size != Vector2.ZERO else Vector2(64, 64)

	# Spawn particles at each edge (bottom, left, right)
	var edge_configs: Array = [
		# [position, direction, spread]
		[Vector2(tile_size.x / 2, tile_size.y), Vector2(0, 1), 60.0],      # Bottom center
		[Vector2(0, tile_size.y), Vector2(-1, 0.5), 45.0],                 # Bottom-left corner
		[Vector2(tile_size.x, tile_size.y), Vector2(1, 0.5), 45.0],        # Bottom-right corner
		[Vector2(0, tile_size.y / 2), Vector2(-1, 0), 30.0],               # Left edge
		[Vector2(tile_size.x, tile_size.y / 2), Vector2(1, 0), 30.0],      # Right edge
	]

	# Distribute particles evenly across edges
	var particles_distribution: Array[int] = _distribute_particles(strategy.particle_count, edge_configs.size())

	for i in edge_configs.size():
		var config: Array = edge_configs[i]
		var pos: Vector2 = config[0]
		var dir: Vector2 = config[1]
		var spread: float = config[2]
		var particle_count: int = particles_distribution[i]

		if particle_count <= 0:
			continue

		var particles: CPUParticles2D = _create_particle_emitter(particle_count, dir, spread, strategy)
		particles.position = pos
		tile.add_child(particles)

		_schedule_particle_cleanup(particles, strategy.particle_lifetime)


## Creates a configured CPUParticles2D emitter.
func _create_particle_emitter(count: int, direction: Vector2, spread: float, strategy: StompTileAnimation) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()

	# Basic settings
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = count
	particles.lifetime = strategy.particle_lifetime

	# Movement
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = strategy.particle_speed * 0.6
	particles.initial_velocity_max = strategy.particle_speed
	particles.gravity = Vector2(0, 150)

	# Appearance
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

	return particles


## Schedules particle cleanup using WeakRef for safe handling.
func _schedule_particle_cleanup(particles: CPUParticles2D, lifetime: float) -> void:
	var particles_ref: WeakRef = weakref(particles)
	var tree: SceneTree = _context.get_tree()
	if tree == null:
		return

	tree.create_timer(lifetime + 0.2).timeout.connect(func():
		var p: Node = particles_ref.get_ref()
		if p != null and is_instance_valid(p):
			p.queue_free()
	)


## Distributes a total count evenly across a number of buckets.
func _distribute_particles(total: int, bucket_count: int) -> Array[int]:
	if bucket_count <= 0:
		return []

	var result: Array[int] = []
	var base_count: int = total / bucket_count
	var remainder: int = total % bucket_count

	for i in bucket_count:
		var count: int = base_count + (1 if i < remainder else 0)
		result.append(maxi(count, 1))

	return result
