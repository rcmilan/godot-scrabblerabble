extends CanvasLayer
class_name ScorePanel

## ScorePanel: Displays cumulative score (Y) and round target (X) in format "Y / X"
## Updates with stagger-matched scoring during play, pulses on each change,
## and plays particles when target is beaten.

@onready var score_label: Label = $HBoxContainer/ScoreLabel
@onready var particles: CPUParticles2D = $HBoxContainer/Particles

var _target: int = 0
var _cumulative: int = 0
var _pulse_tween: Tween = null


func _ready() -> void:
	print("[ScorePanel] Ready")
	# Configure UI at runtime
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color.WHITE)

	# Configure particles
	particles.amount = 40
	particles.lifetime = 0.8
	particles.scale = Vector2(1.5, 1.5)
	particles.emitting = false

	EventBus.run_round_ready.connect(_on_round_ready)
	EventBus.score_updated.connect(_on_score_updated)
	_setup_particles()
	print("[ScorePanel] Connected to EventBus signals")


func _setup_particles() -> void:
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 0.8
	particles.scale = Vector2(1.5, 1.5)

	print("[ScorePanel] Particles configured")


func _on_round_ready(config: RoundConfig) -> void:
	print("[ScorePanel] _on_round_ready called")
	_target = config.target_score
	_cumulative = GameManager.get_cumulative_score()
	score_label.text = "%d / %d" % [_cumulative, _target]
	print("[ScorePanel] Initialized: %d / %d" % [_cumulative, _target])


func _on_score_updated(cumulative: int, delta: int) -> void:
	print("[ScorePanel] _on_score_updated: cumulative=%d, delta=%d, target=%d" % [cumulative, delta, _target])
	_cumulative = cumulative
	score_label.text = "%d / %d" % [_cumulative, _target]

	# Pulse animation
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_BACK)
	_pulse_tween.tween_property($HBoxContainer, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property($HBoxContainer, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Particles if target beaten (re-evaluates every update, so particles fire on each new score past target)
	if _cumulative > _target:
		_play_particles()


func _play_particles() -> void:
	if _cumulative <= _target:
		return

	var ratio: float = float(_cumulative - _target) / float(_target) if _target > 0 else 0.0

	var amount: int = 0
	var velocity: int = 0

	if ratio < 0.05:
		return  # No particles
	elif ratio < 0.15:
		amount = 8
		velocity = 45
	elif ratio < 0.30:
		amount = 20
		velocity = 75
	else:
		amount = 40
		velocity = 110

	particles.amount = amount
	particles.initial_velocity_min = velocity
	particles.initial_velocity_max = velocity
	particles.show()
	particles.restart()

	var tier: int = 0
	if ratio < 0.15:
		tier = 1
	elif ratio < 0.30:
		tier = 2
	else:
		tier = 3
	print("[ScorePanel] Particles triggered | Ratio: %.2f | Tier: %d" % [ratio, tier])
