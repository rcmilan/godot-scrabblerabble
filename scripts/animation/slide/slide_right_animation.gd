extends Node
class_name SlideRightAnimation

## Animation that slides a node right off-screen.
## Used for UI elements to exit during pause transitions.

# =============================================================================
# CONFIGURATION
# =============================================================================

var duration: float = 0.4  # 400ms
var ease_type: Tween.EaseType = Tween.EASE_OUT
var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC

# =============================================================================
# PUBLIC API
# =============================================================================

## Animates a node sliding right off-screen.
## node: The node to animate (typically HUD elements)
## on_complete: Optional callback when animation finishes
func animate(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	# Get screen width from the node's viewport
	var viewport = node.get_viewport()
	if viewport == null:
		return null

	var screen_width: float = viewport.get_visible_rect().size.x
	var target_x: float = screen_width

	# Create tween
	var tween: Tween = node.get_tree().create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)

	# Animate position x (or offset:x for CanvasLayer) to off-screen right
	var property_path: String = "offset:x" if node is CanvasLayer else "position:x"
	tween.tween_property(node, property_path, target_x, duration)

	# Call completion callback if provided
	if on_complete.is_valid():
		tween.tween_callback(on_complete)

	return tween
