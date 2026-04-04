extends Node
class_name SlideLeftAnimation

## Animation that slides a node off-screen to the left.
## Used for board exit and pause menu exit during pause transitions.
## Duration: 400ms (must complete within 500ms threshold per FR-004/SC-001)

# =============================================================================
# CONFIGURATION
# =============================================================================

var duration: float = 0.4  # 400ms
var ease_type: Tween.EaseType = Tween.EASE_OUT
var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC

# =============================================================================
# PUBLIC API
# =============================================================================

## Animates a node sliding left off-screen.
## node: The node to animate (typically Board or PauseMenu Control)
## on_complete: Optional callback when animation finishes
func animate(node: Node, on_complete: Callable = Callable()) -> Tween:
	if node == null:
		return null

	# Get screen width from the node's viewport
	var viewport = node.get_viewport()
	if viewport == null:
		return null

	var screen_width: float = viewport.get_visible_rect().size.x
	var target_x: float = -screen_width

	# Create tween
	var tween: Tween = node.get_tree().create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)

	# Animate position x to off-screen left
	tween.tween_property(node, "position:x", target_x, duration)

	# Call completion callback if provided
	if on_complete.is_valid():
		tween.tween_callback(on_complete)

	return tween
