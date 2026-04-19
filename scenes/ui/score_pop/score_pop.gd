extends Label
class_name ScorePopLabel

## ScorePopLabel: Floating score label that travels from tile to HUD.
## Animates entrance (fade + scale), travels with easing, triggers callback on arrival, self-destructs.

var _tween: Tween = null


func _ready() -> void:
	# Configure visual properties
	add_theme_font_size_override("font_size", TileAnimator.hype_config.score_pop_font_size if TileAnimator.hype_config else 22)
	add_theme_color_override("font_color", Color.YELLOW)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


## Launches the score pop animation.
## start_pos: Starting position (above tile)
## end_pos: Ending position (score panel label)
## delta: Score value to display
## travel_duration: How long the travel takes
## on_arrive_callback: Called when label reaches end_pos
func launch(start_pos: Vector2, end_pos: Vector2, delta: int, travel_duration: float, on_arrive_callback: Callable) -> void:
	global_position = start_pos
	text = "+%d" % delta
	scale = Vector2.ZERO
	modulate.a = 0.0

	if _tween:
		_tween.kill()
	_tween = create_tween()

	# Entrance: fade in + scale up (0.1s)
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Travel to end position (with configurable duration)
	_tween.set_parallel(false)
	_tween.tween_property(self, "global_position", end_pos, travel_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Call callback and self-destruct
	_tween.tween_callback(on_arrive_callback)
	_tween.tween_callback(queue_free)
