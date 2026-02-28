extends Control
class_name Main

## Main scene orchestrator.
## Manages round lifecycle, transitions between gameplay and shop.
## Delegates gameplay interaction to GameplayController.

# =============================================================================
# CONTROLLERS
# =============================================================================

var _gameplay_controller: GameplayController = null

# =============================================================================
# LOCAL MANAGERS
# =============================================================================

var _selection_manager: SelectionManager = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var board: Board = $Board
@onready var hand: Hand = $Hand
@onready var discard_pile: Control = $DiscardPile
@onready var discard_dialog: CanvasLayer = $DiscardConfirmationDialog
@onready var main_hud: CanvasLayer = $MainHUD
@onready var shop_overlay: ShopOverlay = $ShopOverlay
@onready var game_over_popup: GameOverPopup = $GameOverPopup
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var multi_select_indicator: Control = $MultiSelectIndicator


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_selection_manager()
	HandManager.set_references(hand)
	HandManager.tile_ready.connect(register_tile)
	_setup_controllers()
	_connect_run_signals()
	_start_run()


func _setup_selection_manager() -> void:
	_selection_manager = SelectionManager.new()
	_selection_manager.name = "SelectionManager"
	add_child(_selection_manager)

	hand.set_selection_manager(_selection_manager)
	discard_pile.set_selection_manager(_selection_manager)
	multi_select_indicator.set_selection_manager(_selection_manager)


func _setup_controllers() -> void:
	_gameplay_controller = GameplayController.new()
	add_child(_gameplay_controller)
	_gameplay_controller.setup(board, hand, discard_pile, discard_dialog, main_hud, _selection_manager)
	_gameplay_controller.play_completed.connect(_on_play_completed)
	_gameplay_controller.pause_requested.connect(_on_pause_requested)


func _connect_run_signals() -> void:
	EventBus.run_round_ready.connect(_on_round_ready)
	EventBus.run_shop_requested.connect(_on_shop_requested)
	EventBus.run_ended.connect(_on_run_ended)
	shop_overlay.continue_requested.connect(_on_shop_continue)
	game_over_popup.return_to_title_requested.connect(_on_return_to_title)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.return_to_title_requested.connect(_on_return_to_title)


func _start_run() -> void:
	# If RunManager was not initialized (e.g., scene loaded directly for testing),
	# initialize with defaults
	if RunManager.run_state == null:
		RunManager.initialize_run_from_builder(RunBuilder.new().build())

	# Populate tile bag once for the entire run
	TileBag.populate_bag(RunManager.run_state.bag_config)

	# Start the run (triggers first round_ready)
	RunManager.start_run()


# =============================================================================
# ROUND LIFECYCLE
# =============================================================================

func _on_round_ready(config: RoundConfig) -> void:
	# Deactivate controller during setup
	_gameplay_controller.deactivate()

	# Cancel any in-flight animations from the previous round before freeing tiles
	TileAnimator.cancel_all()

	# Configure board size for this round
	board.resize_board(config.board_rows, config.board_columns)
	board.clear_board()

	# Reset per-round tile state for rounds after the first
	if config.round_number > 1:
		hand.clear_hand()
		HandManager.clear_discard_pile()
		TileBag.populate_bag(RunManager.run_state.bag_config)

	# Setup GameManager for this round
	GameManager.setup_round(config)

	# Configure hand size
	HandManager.set_hand_size(config.hand_size)

	# Ensure HandManager is ready, then refill hand
	if not HandManager.is_initialized():
		await HandManager.initialized
	HandManager.refill_hand()

	# Activate gameplay and show UI
	_gameplay_controller.activate()
	_show_gameplay_ui()

	print("[Main] Round %d ready - %dx%d board" % [
		config.round_number, config.board_columns, config.board_rows
	])


# =============================================================================
# PLAY HANDLING
# =============================================================================

## Called when tiles are played (locked on board).
## Always consumes a play. Words may be empty if no valid words were formed.
func _on_play_completed(tiles: Array[Tile], words: Array) -> void:
	var total_score: int = 0
	var word_validator: WordValidator = _gameplay_controller.get_word_validator()

	for word_info in words:
		var score_result: Dictionary = word_validator.calculate_placement_score(
			word_info.tiles, word_info.cells
		)
		total_score += score_result.total
		EventBus.score_calculated.emit(score_result.total, score_result)

	GameManager.commit_play(total_score)
	print("[Main] Play committed: %d pts from %d words | Score: %d/%d | Plays left: %d" % [
		total_score, words.size(), GameManager.get_current_score(),
		GameManager.get_target_score(), GameManager.get_plays_remaining()
	])


# =============================================================================
# SHOP TRANSITION
# =============================================================================

func _on_shop_requested(round_number: int) -> void:
	_gameplay_controller.deactivate()
	_hide_gameplay_ui()

	# Peek at next round config for display
	var next_config: RoundConfig = RunManager.progression_rules.get_round_config(
		RunManager.run_state
	)
	shop_overlay.show_shop(round_number, GameManager.get_current_score(), next_config)
	print("[Main] Showing shop after round %d" % round_number)


func _on_shop_continue() -> void:
	RunManager.proceed_from_shop()


# =============================================================================
# GAME OVER / RUN END
# =============================================================================

func _on_run_ended(victory: bool, total_score: int) -> void:
	_gameplay_controller.deactivate()
	if victory:
		game_over_popup.show_victory(total_score)
	else:
		game_over_popup.show_game_over(total_score)
	print("[Main] Run ended - Victory: %s | Score: %d" % [victory, total_score])


func _on_return_to_title() -> void:
	RunManager.reset()
	get_tree().change_scene_to_file("res://scenes/title_screen/title_screen.tscn")


# =============================================================================
# PAUSE HANDLING
# =============================================================================

func _on_pause_requested() -> void:
	_pause_game()


func _pause_game() -> void:
	_gameplay_controller.deactivate()
	GameManager.pause_game()
	pause_menu.show_pause_menu()


func _resume_game() -> void:
	GameManager.resume_game()
	_gameplay_controller.activate()


# =============================================================================
# UI HELPERS
# =============================================================================

func _show_gameplay_ui() -> void:
	board.show()
	hand.show()
	main_hud.show()
	shop_overlay.hide()
	game_over_popup.hide()


func _hide_gameplay_ui() -> void:
	board.hide()
	hand.hide()


# =============================================================================
# PUBLIC API
# =============================================================================

## Registers a tile with the gameplay controller.
## Called by HandManager when tiles are created.
func register_tile(tile: Tile) -> void:
	if _gameplay_controller:
		_gameplay_controller.register_tile(tile)


## Pauses gameplay (e.g., for menus or dialogs).
func pause_gameplay() -> void:
	_gameplay_controller.deactivate()


## Resumes gameplay.
func resume_gameplay() -> void:
	_gameplay_controller.activate()
