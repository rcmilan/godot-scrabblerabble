extends Node

## BackgroundManager: Global background color state holder and animator.
## Persists background color across scene changes.
## Resets to default on new game start.

# Constants
const DEFAULT_COLOR: Color = Color(0, 0.502, 0.502, 1.0)  # Win95 teal (#008080)
const BOSS_COLOR: Color = Color(1.0, 0.85, 0.85, 1.0)      # Light red
const TRANSITION_DURATION: float = 1.0                       # seconds

# State
var _current_color: Color = DEFAULT_COLOR
var _bg_tween: Tween = null

# Signals
signal color_changed(new_color: Color)


func _ready() -> void:
	print("[BackgroundManager] Ready. Default color: %s" % DEFAULT_COLOR)


## Set background color with smooth 1.0s transition.
func set_color(target_color: Color) -> void:
	if _current_color == target_color:
		return

	# Kill any active tween
	if _bg_tween:
		_bg_tween.kill()

	# Create new tween for all subscribers
	# Note: This does NOT animate a ColorRect directly.
	# Subscribers receive the color_changed signal and update their own ColorRects.
	_current_color = target_color
	emit_signal("color_changed", target_color)
	print("[BackgroundManager] Color changed to %s" % target_color)


## Reset to default blue-gray color.
func reset_to_default() -> void:
	set_color(DEFAULT_COLOR)


## Get current background color without triggering a change.
func get_current_color() -> Color:
	return _current_color
