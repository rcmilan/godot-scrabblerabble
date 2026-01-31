extends CanvasLayer

## MainHUD: Game UI displaying core game state.
## Connects to EventBus for reactive updates.

# === Signals ===
signal discard_requested
signal play_requested

# === Node References ===
@onready var plays_label: Label = $PlaysLabel
@onready var score_label: Label = $ScoreLabel
@onready var target_label: Label = $TargetLabel
@onready var rack_label: Label = $RackLabel
@onready var hand_label: Label = $HandLabel
@onready var discard_label: Label = $DiscardLabel
@onready var discard_pile_label: Label = $DiscardPileLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var discard_button: Button = $DiscardButton
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
	EventBus.game_won.connect(_on_game_won)
	EventBus.game_lost.connect(_on_game_lost)


func _setup_buttons() -> void:
	discard_button.pressed.connect(_on_discard_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.disabled = true


func _initialize_display() -> void:
	game_over_label.hide()

	# Set initial values
	_update_plays(GameManager.plays_remaining)
	_update_score(GameManager.current_score)
	_update_target(GameManager.target_score)
	_update_rack(TileBag.tiles_remaining())
	_update_hand(HandManager.get_hand_size())
	_update_discard(HandManager.get_discard_count())


# === Signal Handlers ===

func _on_score_updated(total: int, _delta: int) -> void:
	_update_score(total)


func _on_hand_count_changed(count: int) -> void:
	_update_hand(count)


func _on_bag_count_changed(count: int) -> void:
	_update_rack(count)


func _on_discard_count_changed(count: int) -> void:
	_update_discard(count)


func _on_play_completed(plays_remaining: int) -> void:
	_update_plays(plays_remaining)


func _on_round_started(_round_number: int) -> void:
	game_over_label.hide()
	_update_plays(GameManager.plays_remaining)
	_update_target(GameManager.target_score)


func _on_game_won() -> void:
	game_over_label.text = "You Win!\nTarget Reached!"
	game_over_label.show()


func _on_game_lost() -> void:
	game_over_label.text = "Game Over\nOut of Plays"
	game_over_label.show()


# === UI Updates ===

func _update_plays(count: int) -> void:
	plays_label.text = "Plays: %d" % count


func _update_score(score: int) -> void:
	score_label.text = "Score: %d" % score


func _update_target(target: int) -> void:
	target_label.text = "Target: %d" % target


func _update_rack(count: int) -> void:
	rack_label.text = "Rack: %d" % count


func _update_hand(count: int) -> void:
	hand_label.text = "Hand: %d" % count


func _update_discard(count: int) -> void:
	discard_label.text = "Discards: %d" % count
	discard_pile_label.text = "Discard Pile: %d" % count


# === Button Handlers ===

func _on_discard_button_pressed() -> void:
	discard_requested.emit()


func _on_play_button_pressed() -> void:
	play_requested.emit()


# === Public API ===

func set_play_button_enabled(enabled: bool) -> void:
	play_button.disabled = not enabled
