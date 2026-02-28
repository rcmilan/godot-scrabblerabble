## Pure geometry computation for parabolic arc tile layout.
##
## Calculates tile positions and rotations in a parabolic arc.
## No side effects, no node references, suitable for testing.
class_name ArcLayoutComputer

# Structural constant (NOT exported, defines tile width for layout)
const TILE_WIDTH: float = 64.0

# Inspector-tweakable parameters
@export var max_rotation_deg: float = 25.0
@export var elevation_px: float = 40.0
@export var ideal_step_px: float = 72.0
@export var min_step: float = 20.0


## Compute tile positions and rotations in parabolic arc layout.
##
## Pure math, no side effects. Returns array of TileArcTransform objects.
##
## Algorithm:
## 1. One-time setup:
##    - Calculate step size with compression for many tiles
##    - Center arc horizontally in container_w
## 2. Per-tile calculations:
##    - Normalize position t: -1...+1 (left to right)
##    - x = start_x + i * step (linear spacing)
##    - y = base_y - elevation_px * (1 - t²)  (parabola: center elevated)
##    - rot = deg_to_rad(t * max_rotation_deg)  (left CCW, right CW)
func compute(count: int, container_w: float, base_y: float) -> Array[TileArcTransform]:
	assert(container_w > 0, "container_w must be positive")
	assert(count >= 0, "count must be non-negative")
	if count == 0:
		return []

	if count == 1:
		# Single tile: centered, no rotation, but with elevation for consistency
		var center_x = (container_w - TILE_WIDTH) / 2.0
		var elevated_y = base_y - elevation_px
		return [TileArcTransform.new(Vector2(center_x, elevated_y), 0.0)]

	# Calculate step size (with compression for many tiles)
	var step = _calculate_step(count, container_w)

	# Calculate starting x to center the arc
	var total_width = (count - 1) * step + TILE_WIDTH
	var start_x = (container_w - total_width) / 2.0

	# Build transforms
	var transforms: Array[TileArcTransform] = []
	for i in range(count):
		# Normalize position to -1...+1 (left to right)
		var t = (2.0 * i / (count - 1)) - 1.0

		# Calculate position
		var x = start_x + i * step
		var y = base_y - elevation_px * (1.0 - t * t)  # Parabola

		# Calculate rotation
		var rot = deg_to_rad(t * max_rotation_deg)

		transforms.append(TileArcTransform.new(Vector2(x, y), rot))

	return transforms


## Calculate step size, compressing if tiles don't fit naturally.
##
## Returns step >= min_step.
func _calculate_step(count: int, container_w: float) -> float:
	# Natural step if tiles fit without compression
	var natural_total_width = (count - 1) * ideal_step_px + TILE_WIDTH

	if natural_total_width <= container_w:
		# Tiles fit naturally with ideal_step_px
		return ideal_step_px

	# Compress step to fit container
	var compressed_step = (container_w - TILE_WIDTH) / float(count - 1)

	# Clamp to minimum
	return maxf(compressed_step, min_step)
