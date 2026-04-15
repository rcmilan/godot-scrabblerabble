class_name RunOrientationState extends RefCounted

## Immutable value object representing typing mode orientation.
## Horizontal: tiles placed left-to-right, wrap to next row
## Vertical: tiles placed top-to-bottom, wrap to next column

var orientation: Vector2i  # Vector2i(1, 0) = horizontal, Vector2i(0, 1) = vertical


static func horizontal() -> RunOrientationState:
	var state := RunOrientationState.new()
	state.orientation = Vector2i(1, 0)
	return state


static func vertical() -> RunOrientationState:
	var state := RunOrientationState.new()
	state.orientation = Vector2i(0, 1)
	return state


func is_horizontal() -> bool:
	return orientation == Vector2i(1, 0)


func is_vertical() -> bool:
	return orientation == Vector2i(0, 1)


func toggled() -> RunOrientationState:
	if is_horizontal():
		return vertical()
	else:
		return horizontal()


func _to_string() -> String:
	return "RunOrientationState(%s)" % ("horizontal" if is_horizontal() else "vertical")
