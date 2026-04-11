## DropTileAnimation: Animation strategy for gravity drop effect.
##
## Defines the motion profile, easing, and stagger for tiles dropping downward
## to their final positions. Extends TileAnimationStrategy to integrate with
## the existing animation system.
##
## Duration: ~0.5s per tile
## Easing: TRANS_QUAD, EASE_IN (accelerating fall)
## Stagger: ~0.03s between tiles to create a cascade effect
class_name DropTileAnimation
extends TileAnimationStrategy


## Constructor: initialize motion parameters
func _init() -> void:
	super._init()
	duration = 0.5
	ease_type = Tween.EASE_IN
	trans_type = Tween.TRANS_QUAD
	stagger_delay = 0.03


## Called before animation starts
func on_animation_start(tile: Tile) -> void:
	# Disable mouse interaction during drop (prevent placement while animating)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Raise z-index to ensure tile appears above others during drop
	tile.z_index = 50


## Called when animation completes
func on_animation_complete(tile: Tile) -> void:
	# Re-enable mouse interaction
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	# Reset z-index to normal
	tile.z_index = 0
