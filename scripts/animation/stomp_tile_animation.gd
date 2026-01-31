extends TileAnimationStrategy
class_name StompTileAnimation

## Animation strategy for confirming tile placement ("playing" tiles).
## Tiles perform a dramatic stomp effect: rise up high, then slam down
## with particle effects on impact.

# =============================================================================
# CONFIGURATION
# =============================================================================

## How high the tile rises (scale factor)
@export var rise_scale: Vector2 = Vector2(1.35, 1.35)

## How much the tile "squishes" on impact
@export var squish_scale: Vector2 = Vector2(1.1, 0.9)

## Vertical offset when rising (pixels up)
@export var rise_offset: float = -15.0

## Duration of the rise phase
@export var rise_duration: float = 0.15

## Duration of the slam down phase
@export var slam_duration: float = 0.08

## Duration of the squish/recover phase
@export var recover_duration: float = 0.12

## Particle configuration
@export var particle_count: int = 12
@export var particle_speed: float = 80.0
@export var particle_lifetime: float = 0.5
@export var particle_size_min: float = 6.0
@export var particle_size_max: float = 10.0
@export var particle_color: Color = Color(1.0, 0.85, 0.5, 1.0)


func _init() -> void:
	duration = 0.35  # Total duration (rise + slam + recover)
	ease_type = Tween.EASE_OUT
	trans_type = Tween.TRANS_BACK
	stagger_delay = 0.06


# =============================================================================
# OVERRIDES
# =============================================================================

func get_start_position_offset() -> Vector2:
	return Vector2.ZERO


func get_start_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


func get_end_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


func on_animation_start(tile: Tile) -> void:
	# Disable interaction during animation
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Raise z-index so tile appears above others during animation
	tile.z_index = 50
	# Set pivot to center so scaling happens from center
	var tile_size: Vector2 = tile.size if tile.size != Vector2.ZERO else Vector2(64, 64)
	tile.pivot_offset = tile_size / 2.0


func on_animation_complete(tile: Tile) -> void:
	# Re-enable interaction after animation (though tile will be locked)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	# Reset z-index
	tile.z_index = 0
	# Reset pivot offset
	tile.pivot_offset = Vector2.ZERO
