extends CanvasLayer

## MainHUD: Game UI displaying core game state.
## Connects to EventBus for reactive updates.

# === Signals ===
signal play_requested

# === Node References ===
@onready var round_label: Label = $RoundLabel
@onready var plays_label: Label = $PlaysLabel
@onready var score_label: Label = $ScoreLabel
@onready var target_label: Label = $TargetLabel
@onready var deck_label: Label = $DeckLabel
@onready var hand_label: Label = $HandLabel
@onready var discard_label: Label = $DiscardLabel
@onready var play_button: Button = $PlayButton


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
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.disabled = true


func _initialize_display() -> void:
	# Set initial values
	_update_round(GameManager.current_round)
	_update_plays(GameManager.plays_remaining)
	_update_score(GameManager.current_score)
	_update_target(GameManager.target_score)
	_update_deck(TileBag.tiles_remaining())
	_update_hand(HandManager.get_hand_size())
	_update_discard(HandManager.get_discard_count())


# === Signal Handlers ===

func _on_score_updated(total: int, _delta: int) -> void:
	_update_score(total)


func _on_hand_count_changed(count: int) -> void:
	_update_hand(count)


func _on_bag_count_changed(count: int) -> void:
	_update_deck(count)


func _on_discard_count_changed(count: int) -> void:
	_update_discard(count)


func _on_play_completed(plays_remaining: int) -> void:
	_update_plays(plays_remaining)


func _on_round_started(round_number: int) -> void:
	_update_round(round_number)
	_update_plays(GameManager.plays_remaining)
	_update_target(GameManager.target_score)


func _on_run_round_ready(config: RoundConfig) -> void:
	_update_round(config.round_number)
	_update_plays(config.plays_per_round)
	_update_target(config.target_score)


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


# === Button Handlers ===

func _on_play_button_pressed() -> void:
	play_requested.emit()


# === Public API ===

func set_play_button_enabled(enabled: bool) -> void:
	play_button.disabled = not enabled
