extends CanvasLayer
class_name ScorePanel

## ScorePanel: Displays round info and cumulative score (Y) vs round target (X).
## Layout: RoundLabel on top, ScoreLabel below.
## Pulses on score update. Rainbow animation when target is beaten.

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel

var _target: int = 0
var _cumulative: int = 0
var _pulse_tween: Tween = null
var _rainbow_active: bool = false
var _rainbow_hue: float = 0.0


func _ready() -> void:
	# Configure font sizes
	round_label.add_theme_font_size_override("font_size", 18)
	round_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color.WHITE)

	EventBus.score_updated.connect(_on_score_updated)

	print("[ScorePanel] Ready")


func _process(delta: float) -> void:
	if _rainbow_active:
		_rainbow_hue = fmod(_rainbow_hue + delta * 0.5, 1.0)
		score_label.add_theme_color_override(
			"font_color", Color.from_hsv(_rainbow_hue, 0.8, 1.0)
		)


## Called by Main._on_round_ready to set round info and reset state.
func set_round_info(config: RoundConfig) -> void:
	_target = config.target_score
	_cumulative = GameManager.get_cumulative_score()

	# Set round/boss display
	if config.boss != null:
		round_label.text = config.boss.display_name
	elif config.is_boss_round:
		round_label.text = "Boss Round"
	else:
		round_label.text = "Round %d" % config.round_number

	# Reset rainbow on new round
	_rainbow_active = false
	score_label.add_theme_color_override("font_color", Color.WHITE)
	_rainbow_hue = 0.0

	_update_label()
	print("[ScorePanel] Round ready | %s | %d / %d" % [round_label.text, _cumulative, _target])


func _on_score_updated(cumulative: int, delta: int) -> void:
	_cumulative = cumulative
	_update_label()

	# Compute pulse intensity locally: 1.0 + (delta / target), clamped
	var hype_config: HypeConfig = TileAnimator.hype_config
	var intensity: float = 1.0
	if hype_config:
		intensity = 1.0 if _target <= 0 else clamp(1.0 + delta / float(_target), 1.0, hype_config.pulse_intensity_max)

	_play_pulse(intensity)

	# Trigger secondary effect if intensity is high enough
	if hype_config and intensity >= hype_config.secondary_effect_threshold:
		_play_shake()

	# Debug logging
	if hype_config and hype_config.debug_logging_enabled:
		var progress = float(cumulative) / float(_target) * 100.0 if _target > 0 else 0.0
		print("[ScorePanel] delta=%d cumulative=%d progress=%.2f%% intensity=%.2f" % [
			delta, cumulative, progress, intensity
		])

	# Activate rainbow when target is beaten
	if _cumulative > _target and _target > 0 and not _rainbow_active:
		_rainbow_active = true
		print("[ScorePanel] Target beaten! Rainbow animation activated")


func _play_pulse(intensity: float = 1.0) -> void:
	if _pulse_tween:
		_pulse_tween.kill()

	var hype_config: HypeConfig = TileAnimator.hype_config
	var base_scale: float = hype_config.pulse_base_scale if hype_config else 1.15
	var pulse_scale: float = base_scale * intensity

	$VBoxContainer.scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property($VBoxContainer, "scale", Vector2(pulse_scale, pulse_scale), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_pulse_tween.tween_property($VBoxContainer, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _play_shake() -> void:
	var hype_config: HypeConfig = TileAnimator.hype_config
	if not hype_config:
		return

	var shake_tween: Tween = create_tween()
	var original_x: float = score_label.position.x
	var magnitude: float = hype_config.secondary_effect_magnitude

	shake_tween.tween_property(score_label, "position:x", original_x - magnitude, 0.05)
	shake_tween.tween_property(score_label, "position:x", original_x + magnitude, 0.05)
	shake_tween.tween_property(score_label, "position:x", original_x - magnitude / 2.0, 0.05)
	shake_tween.tween_property(score_label, "position:x", original_x, 0.05)


func _update_label() -> void:
	score_label.text = "%d / %d" % [_cumulative, _target]


## Returns the global position of the score label for score pop label targeting.
func get_score_label_target_position() -> Vector2:
	return score_label.global_position
