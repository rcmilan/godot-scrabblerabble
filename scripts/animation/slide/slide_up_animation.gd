extends Node
class_name SlideUpAnimation

## Animation that slides a node up off-screen.
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

## Animates a node sliding up off-screen.
## node: The node to animate (typically Hand or other UI elements)
## on_complete: Optional callback when animation finishes
func animate(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	# Get screen height from the node's viewport
	var viewport = node.get_viewport()
	if viewport == null:
		return null

	var screen_height: float = viewport.get_visible_rect().size.y
	var target_y: float = -screen_height

	# Create tween
	var tween: Tween = node.get_tree().create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)

	# Animate position y (or offset:y for CanvasLayer) to off-screen up
	var property_path: String = "offset:y" if node is CanvasLayer else "position:y"
	tween.tween_property(node, property_path, target_y, duration)

	# Call completion callback if provided
	if on_complete.is_valid():
		tween.tween_callback(on_complete)

	return tween
