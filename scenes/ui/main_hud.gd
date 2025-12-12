extends CanvasLayer

# MainHUD: Production game UI displaying core game state.
# Scene-agnostic: works in both Debug.tscn and Main.tscn.

signal play_button_state_changed(enabled: bool)

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

func _ready():
	# Connect to autoloads (always present)
	EventBus.connect("score_updated", Callable(self, "_on_score_updated"))
	EventBus.connect("discard_count_changed", Callable(self, "_on_discard_count_changed"))
	EventBus.connect("discard_pile_changed", Callable(self, "_on_discard_pile_changed"))
	
	# Wire button signals
	discard_button.connect("pressed", Callable(self, "_on_discard_button_pressed"))
	play_button.connect("pressed", Callable(self, "_on_play_button_pressed"))
	
	# Connect to TileBag for rack count updates
	if TileBag:
		TileBag.connect("rack_count_changed", Callable(self, "_on_rack_count_changed"))
		# Set initial rack count
		_on_rack_count_changed(TileBag.get_remaining_tile_count())
		# Set initial discard pile count
		_on_discard_pile_changed(TileBag.get_discarded_tile_count())
	
	game_over_label.hide()
	
	# Initialize Play button as disabled (no tiles placed yet)
	play_button.disabled = true
	
	# Connect to round manager (scene-agnostic)
	call_deferred("_connect_round_manager")
	
	# Position buttons relative to Hand (deferred to ensure Hand is ready)
	call_deferred("_position_buttons_relative_to_hand")

func _connect_round_manager():
	var rm = _find_round_manager()
	if rm:
		rm.connect("round_started", Callable(self, "_on_round_started"))
		rm.connect("play_completed", Callable(self, "_on_play_completed"))
		rm.connect("game_won", Callable(self, "_on_game_won"))
		rm.connect("game_lost", Callable(self, "_on_game_lost"))
		print("[main_hud] Connected to RoundManager")
		# Initial display
		_on_round_started(rm.get_current_round())
		_on_play_completed(rm.get_plays_remaining())
		set_target_score(rm.get_target_score())

func _find_round_manager():
	# Try debug scene structure (WordTest owns RoundManager)
	var scene_root = get_tree().get_current_scene()
	if scene_root and scene_root.name == "WordTest":
		var rm = scene_root.get_node_or_null("RoundManager")
		if rm:
			return rm
	
	# Try main scene structure (GameManager owns it)
	if GameManager and GameManager.has_node("RoundManager"):
		return GameManager.get_node("RoundManager")
	
	# Or GameManager might implement round management directly
	if GameManager and GameManager.has_method("get_current_round"):
		return GameManager
	
	print("[main_hud] Warning: No RoundManager found")
	return null

func _on_round_started(round_number: int):
	game_over_label.hide()

func _on_play_completed(plays_remaining: int):
	plays_label.text = "Plays: %d" % plays_remaining

func _on_score_updated(new_score: int):
	score_label.text = "Score: %d" % new_score

func _on_rack_count_changed(count: int):
	rack_label.text = "Rack: %d" % count

func _on_hand_count_changed(current: int, _max_size: int):
	hand_label.text = "Hand: %d" % current

func _on_discard_count_changed(total_discards: int):
	discard_label.text = "Discards: %d" % total_discards

func _on_discard_pile_changed(pile_size: int):
	discard_pile_label.text = "Discard Pile: %d" % pile_size

func _on_game_won():
	game_over_label.show()
	game_over_label.text = "You Win!\nTarget Reached!"

func _on_game_lost():
	game_over_label.show()
	game_over_label.text = "Game Over\nOut of Plays"

func set_target_score(target: int):
	target_label.text = "Target: %d" % target

func set_play_button_enabled(enabled: bool):
	if play_button:
		play_button.disabled = not enabled

func _position_buttons_relative_to_hand():
	# Find Hand node in current scene
	var hand_node = _find_hand_node()
	if not hand_node:
		print("[main_hud] Hand node not found, using default button positions")
		return
	
	# Get Hand's global position and size
	var hand_global_pos = hand_node.global_position
	var hand_size = hand_node.custom_minimum_size if "custom_minimum_size" in hand_node else Vector2(700, 60)
	
	# Position Discard button to the left of Hand, offset by 25px
	var discard_width = 100.0
	var discard_height = 40.0
	discard_button.position = Vector2(
		hand_global_pos.x - discard_width - 25,
		hand_global_pos.y + (hand_size.y - discard_height) / 2
	)
	discard_button.size = Vector2(discard_width, discard_height)
	
	# Position Play button to the right of Hand, offset by 25px
	var play_width = 100.0
	var play_height = 40.0
	play_button.position = Vector2(
		hand_global_pos.x + hand_size.x + 25,
		hand_global_pos.y + (hand_size.y - play_height) / 2
	)
	play_button.size = Vector2(play_width, play_height)
	
	print("[main_hud] Positioned buttons relative to Hand at ", hand_global_pos)

func _find_hand_node():
	# Search current scene for Hand node
	var scene_root = get_tree().get_current_scene()
	if not scene_root:
		return null
	
	# Try direct child
	var hand = scene_root.get_node_or_null("Hand")
	if hand:
		return hand
	
	# Try searching in DebugUI for Debug scene
	var debug_ui = scene_root.get_node_or_null("DebugUI")
	if debug_ui:
		hand = debug_ui.get_node_or_null("Hand")
		if hand:
			return hand
	
	return null

func _on_discard_button_pressed():
	# Emit signal or call game logic for discard
	# For now, try to find current scene and call handler
	var scene = get_tree().get_current_scene()
	if scene and scene.has_method("_on_discard_pressed"):
		scene._on_discard_pressed()
	else:
		print("[main_hud] Discard button pressed - no handler found")

func _on_play_button_pressed():
	# Emit signal or call game logic for play/evaluate
	var scene = get_tree().get_current_scene()
	if scene and scene.has_method("_on_evaluate_pressed"):
		scene._on_evaluate_pressed()
	else:
		print("[main_hud] Play button pressed - no handler found")
