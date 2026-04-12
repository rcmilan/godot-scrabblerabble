extends CanvasLayer
class_name ScorePanel

## ScorePanel: Displays round info and cumulative score (Y) vs round target (X).
## Layout: RoundLabel on top, ScoreLabel below.
## Pulses on score update. Rainbow animation when target is beaten.

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
# --- DEAD CODE: particles removed per design ---
# @onready var particles: CPUParticles2D = $VBoxContainer/Particles

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

	# --- DEAD CODE: particles setup removed per design ---
	# _setup_particles()

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
	_play_pulse()

	# Activate rainbow when target is beaten
	if _cumulative > _target and _target > 0 and not _rainbow_active:
		_rainbow_active = true
		print("[ScorePanel] Target beaten! Rainbow animation activated")

	# --- DEAD CODE: particles removed per design ---
	# if _cumulative > _target:
	#     _play_particles()


func _play_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	$VBoxContainer.scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property($VBoxContainer, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_pulse_tween.tween_property($VBoxContainer, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _update_label() -> void:
	score_label.text = "%d / %d" % [_cumulative, _target]


# =============================================================================
# DEAD CODE: Particle celebration removed per design.
# Kept commented for reference.
# =============================================================================

# func _setup_particles() -> void:
#     particles.one_shot = true
#     particles.explosiveness = 0.8
#     particles.lifetime = 0.8
#     particles.scale = Vector2(1.5, 1.5)

# func _play_particles() -> void:
#     if _cumulative <= _target:
#         return
#     var ratio: float = float(_cumulative - _target) / float(_target) if _target > 0 else 0.0
#     var amount: int = 0
#     var velocity: int = 0
#     if ratio < 0.05:
#         return
#     elif ratio < 0.15:
#         amount = 8
#         velocity = 45
#     elif ratio < 0.30:
#         amount = 20
#         velocity = 75
#     else:
#         amount = 40
#         velocity = 110
#     particles.amount = amount
#     particles.initial_velocity_min = velocity
#     particles.initial_velocity_max = velocity
#     particles.show()
#     particles.restart()
