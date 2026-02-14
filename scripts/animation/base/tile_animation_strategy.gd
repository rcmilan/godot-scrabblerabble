extends Resource
class_name TileAnimationStrategy

## Base class for tile animation strategies.
## Extend this to create different animation types (draw, discard, place, etc.)

# =============================================================================
# ANIMATION PROPERTIES
# =============================================================================

@export var duration: float = 0.3
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var stagger_delay: float = 0.05

# =============================================================================
# VIRTUAL METHODS - Override in subclasses
# =============================================================================

## Returns the starting position offset relative to the tile's final position.
## Override this to define where the animation begins.
func get_start_position_offset() -> Vector2:
	return Vector2.ZERO


## Returns the starting properties for the tile (scale, alpha, rotation, etc.)
## Override this to define initial visual state.
func get_start_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


## Returns the ending properties for the tile.
## Override this to define final visual state.
func get_end_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


## Called when the animation starts for a tile.
## Override for setup logic.
func on_animation_start(_tile: Tile) -> void:
	pass


## Called when the animation completes for a tile.
## Override for cleanup logic.
func on_animation_complete(_tile: Tile) -> void:
	pass
