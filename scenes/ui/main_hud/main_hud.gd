extends CanvasLayer

## MainHUD: Game UI displaying core game state.
## Connects to EventBus for reactive updates.

# === Signals ===
signal play_requested
signal draw_requested

# === Node References ===
@onready var round_label: Label = $RoundLabel
@onready var plays_label: Label = $PlaysLabel
@onready var score_label: Label = $ScoreLabel
@onready var target_label: Label = $TargetLabel
@onready var deck_label: Label = $DeckLabel
@onready var hand_label: Label = $HandLabel
@onready var discard_label: Label = $DiscardLabel
@onready var draw_button: Button = $DrawButton
@onready var play_button: Button = $PlayButton
@onready var timer_label: Label = $TimerLabel
@onready var timer_increment_label: Label = $TimerIncrementLabel

# === Timer State ===
var _timer_connections: Array[Dictionary] = []
var _increment_tween: Tween = null


func _ready() -> void:
	_connect_signals()
	_setup_buttons()
	_initialize_display()


func _connect_signals() -> void:
	# EventBus signals
	EventBus.score_updated.connect(_on_score_updated)
	EventBus.hand_count_changed.connect(_on_hand_count_changed)
	EventBus.bag_count_changed.connect(_on_bag_count_changed)
	EventBus.discard_count_changed.connect(_on_discard_count_changed)
	EventBus.play_completed.connect(_on_play_completed)
	EventBus.round_started.connect(_on_round_started)
	EventBus.run_round_ready.connect(_on_run_round_ready)


func _setup_buttons() -> void:
	draw_button.pressed.connect(_on_draw_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.disabled = true


func _initialize_display() -> void:
	# Set initial values
	_update_round(GameManager.get_current_round())
	_update_plays(GameManager.get_plays_remaining())
	_update_score(GameManager.get_current_score())
	_update_target(GameManager.get_target_score())
	_update_deck(TileBag.tiles_remaining())
	_update_hand(HandManager.get_hand_size())
	_update_discard(HandManager.get_discard_count())


# === Signal Handlers ===

func _on_score_updated(total: int, _delta: int) -> void:
	_update_score(total)


func _on_hand_count_changed(count: int) -> void:
	_update_hand(count)
	_update_draw_button(count)


func _on_bag_count_changed(count: int) -> void:
	_update_deck(count)
	_update_draw_button(HandManager.get_hand_size())


func _on_discard_count_changed(count: int) -> void:
	_update_discard(count)


func _on_play_completed(plays_remaining: int) -> void:
	_update_plays(plays_remaining)


func _on_round_started(round_number: int) -> void:
	_update_round(round_number)
	_update_plays(GameManager.get_plays_remaining())
	_update_target(GameManager.get_target_score())


func _on_run_round_ready(config: RoundConfig) -> void:
	_update_round(config.round_number)
	_update_plays(config.plays_per_round)
	_update_target(config.target_score)
	_connect_timer_qualities()


# === UI Updates ===

func _update_round(round_number: int) -> void:
	round_label.text = "Round: %d" % round_number


func _update_plays(count: int) -> void:
	plays_label.text = "Plays: %d" % count


func _update_score(score: int) -> void:
	score_label.text = "Score: %d" % score


func _update_target(target: int) -> void:
	target_label.text = "Target: %d" % target


func _update_deck(count: int) -> void:
	deck_label.text = "Deck: %d" % count


func _update_hand(count: int) -> void:
	hand_label.text = "Hand: %d" % count


func _update_discard(count: int) -> void:
	discard_label.text = "Discard: %d" % count


# === Timer Display ===

func _connect_timer_qualities() -> void:
	_disconnect_timer_qualities()

	var run := RunManager.get_active_run()
	if run == null:
		timer_label.hide()
		return

	var has_timer := false
	for quality in run.qualities:
		var updated_cb := _on_timer_updated.bind()
		quality.time_updated.connect(updated_cb)
		_timer_connections.append({"signal": quality.time_updated, "callable": updated_cb})

		var incremented_cb := _on_timer_incremented.bind()
		quality.time_incremented.connect(incremented_cb)
		_timer_connections.append({"signal": quality.time_incremented, "callable": incremented_cb})

		# Check if this quality actually emits timer signals by checking for known timer IDs
		var qid := quality.get_quality_id()
		if qid == &"time_attack" or qid == &"limited_time_with_increment":
			has_timer = true

	timer_label.visible = has_timer
	if not has_timer:
		timer_increment_label.hide()


func _disconnect_timer_qualities() -> void:
	for conn in _timer_connections:
		var sig: Signal = conn["signal"]
		var cb: Callable = conn["callable"]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_timer_connections.clear()


func _on_timer_updated(time_remaining: float) -> void:
	timer_label.text = _format_time(time_remaining)
	if time_remaining < 10.0:
		timer_label.add_theme_color_override("font_color", Color.RED)
	else:
		timer_label.remove_theme_color_override("font_color")


func _on_timer_incremented(amount: float) -> void:
	timer_increment_label.text = "+%ds" % int(amount)
	timer_increment_label.modulate = Color(0.3, 1.0, 0.3, 1.0)
	timer_increment_label.show()
	if _increment_tween and _increment_tween.is_valid():
		_increment_tween.kill()
	_increment_tween = create_tween()
	_increment_tween.tween_interval(0.8)
	_increment_tween.tween_property(timer_increment_label, "modulate:a", 0.0, 0.4)
	_increment_tween.tween_callback(timer_increment_label.hide)


func _format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "0:00"
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [mins, secs]


# === Button Handlers ===

func _on_draw_button_pressed() -> void:
	draw_requested.emit()


func _on_play_button_pressed() -> void:
	play_requested.emit()


# === Draw Button State ===

func _update_draw_button(hand_count: int) -> void:
	var hand_full: bool = hand_count >= HandManager.hand_size
	var bag_empty: bool = TileBag.is_empty()
	draw_button.disabled = hand_full or bag_empty


# === Public API ===

func set_play_button_enabled(enabled: bool) -> void:
	play_button.disabled = not enabled


func set_play_button_mode(is_end_round: bool) -> void:
	play_button.text = "End Round" if is_end_round else "Play"
