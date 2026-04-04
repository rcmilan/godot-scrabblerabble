extends Node
class_name SlideInFromTopAnimation

## Animation that slides a node in from the top of the screen.
## Inverse of slide_up_animation.

# =============================================================================
# CONFIGURATION
# =============================================================================

var duration: float = 0.4  # 400ms
var ease_type: Tween.EaseType = Tween.EASE_OUT
var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC

# =============================================================================
# PUBLIC API
# =============================================================================

## Animates a node sliding in from the top of the screen to its original y.
## node: The node to animate
## original_y: The original y position to return to
## on_complete: Optional callback when animation finishes
func animate(node: Node, original_y: float, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	# Get screen height from the node's viewport
	var viewport = node.get_viewport()
	if viewport == null:
		return null

	var screen_height: float = viewport.get_visible_rect().size.y

	# Set starting position (off-screen to the top)
	if node is CanvasLayer:
		node.offset.y = -screen_height
	else:
		node.position.y = -screen_height

	# Create tween
	var tween: Tween = node.get_tree().create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)

	# Animate position y (or offset:y for CanvasLayer) from off-screen top to original position
	var property_path: String = "offset:y" if node is CanvasLayer else "position:y"
	tween.tween_property(node, property_path, original_y, duration)

	# Call completion callback if provided
	if on_complete.is_valid():
		tween.tween_callback(on_complete)

	return tween
