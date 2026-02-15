extends TileAnimationStrategy
class_name SpinTileAnimation

## Animation strategy for tiles with EXTRA, MULTI, or EXPO modifiers.
## Tiles perform a scale pulse + 360 rotation.

# =============================================================================
# CONFIGURATION
# =============================================================================

## Scale during the spin peak
@export var peak_scale: Vector2 = Vector2(1.25, 1.25)

## Duration of the spin-up phase (scale + rotation start)
@export var spin_up_duration: float = 0.15

## Duration of the spin-down phase (return to normal)
@export var spin_down_duration: float = 0.20


func _init() -> void:
	duration = 0.35
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
	}


func get_end_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
	}


func on_animation_start(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.z_index = 50
	var tile_size: Vector2 = tile.size if tile.size != Vector2.ZERO else Vector2(64, 64)
	tile.pivot_offset = tile_size / 2.0


func on_animation_complete(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.z_index = 0
	tile.pivot_offset = Vector2.ZERO
	tile.rotation = 0.0
	# Restore visual state (locked tint, modifier tint, etc.)
	tile._update_visual()
