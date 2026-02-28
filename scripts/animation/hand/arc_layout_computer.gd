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
@export var default_step: float = 72.0
@export var min_step: float = 20.0


## Compute tile positions and rotations in parabolic arc layout.
##
## Pure math, no side effects. Returns array of TileArcTransform objects.
##
## Algorithm:
## For i in 0...count-1:
##   1. Normalize position t: -1...+1 (left to right)
##   2. Calculate step size with compression for many tiles
##   3. Center arc horizontally in container_w
##   4. For each tile:
##      - x = start_x + i * step
##      - y = base_y - elevation_px * (1 - t²)  (parabola)
##      - rot = deg_to_rad(t * max_rotation_deg)  (left CCW, right CW)
func compute(count: int, container_w: float, base_y: float) -> Array[TileArcTransform]:
	if count == 0:
		return []

	if count == 1:
		# Single tile: centered, no rotation, no elevation
		var center_x = (container_w - TILE_WIDTH) / 2.0
		return [TileArcTransform.new(Vector2(center_x, base_y), 0.0)]

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
	var natural_total_width = (count - 1) * default_step + TILE_WIDTH

	if natural_total_width <= container_w:
		# Tiles fit naturally with default_step
		return default_step

	# Compress step to fit container
	var compressed_step = (container_w - TILE_WIDTH) / float(count - 1)

	# Clamp to minimum
	return maxf(compressed_step, min_step)
