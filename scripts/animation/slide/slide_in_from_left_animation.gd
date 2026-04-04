extends Node
class_name SlideInFromLeftAnimation

## Animation that slides a node in from the left of the screen.
## Inverse of slide_right_animation.

# =============================================================================
# CONFIGURATION
# =============================================================================

var duration: float = 0.4  # 400ms
var ease_type: Tween.EaseType = Tween.EASE_OUT
var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC

# =============================================================================
# PUBLIC API
# =============================================================================

## Animates a node sliding in from the left of the screen to its original x.
## node: The node to animate
## original_x: The original x position to return to
## on_complete: Optional callback when animation finishes
func animate(node: Node, original_x: float, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	# Get screen width from the node's viewport
	var viewport = node.get_viewport()
	if viewport == null:
		return null

	var screen_width: float = viewport.get_visible_rect().size.x

	# Set starting position (off-screen to the left)
	if node is CanvasLayer:
		node.offset.x = -screen_width
	else:
		node.position.x = -screen_width

	# Create tween
	var tween: Tween = node.get_tree().create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)

	# Animate position x (or offset:x for CanvasLayer) from off-screen left to original position
	var property_path: String = "offset:x" if node is CanvasLayer else "position:x"
	tween.tween_property(node, property_path, original_x, duration)

	# Call completion callback if provided
	if on_complete.is_valid():
		tween.tween_callback(on_complete)

	return tween
