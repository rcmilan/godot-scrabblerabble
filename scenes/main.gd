extends Control
class_name Main

## Main scene orchestrator.
## Manages round lifecycle, transitions between gameplay and shop.
## Delegates gameplay interaction to GameplayController.

# =============================================================================
# CONTROLLERS
# =============================================================================

var _gameplay_controller: GameplayController = null
var _shop_controller: ShopController = null

# =============================================================================
# LOCAL MANAGERS
# =============================================================================

var _selection_manager: SelectionManager = null
var _focus_cursor: FocusCursor = null

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
@onready var _background: ColorRect = $Background
@onready var _score_panel: CanvasLayer = $ScorePanel

# Animation state
var _bg_tween: Tween = null

# Hurry boss background color transition
var _hurry_timer: BossTimerRelay = null
var _hurry_time_limit: float = 0.0
var _hurry_base_color: Color = Color.SILVER

# Configuration constants
const SHOP_TRANSITION_DELAY: float = 1.0
const FALLBACK_BOSS_COLOR: Color = Color(1.0, 0.85, 0.85, 1.0)
const NORMAL_ROUND_COLOR: Color = Color(0.85, 0.88, 0.92, 1.0)


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	KeybindingConfig.load_and_apply()
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


func _setup_controllers() -> void:
	var cursor_scene := preload("res://scenes/ui/focus_cursor/FocusCursor.tscn")
	_focus_cursor = cursor_scene.instantiate() as FocusCursor
	_focus_cursor.name = "FocusCursor"
	add_child(_focus_cursor)
	var default_orientation := RunOrientationState.horizontal()
	_focus_cursor.setup(board, hand, default_orientation)

	_gameplay_controller = GameplayController.new()
	_gameplay_controller.name = "GameplayController"
	add_child(_gameplay_controller)
	_gameplay_controller.setup(board, hand, discard_pile, discard_dialog, main_hud, _selection_manager, _focus_cursor)
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
	print("[Main] === ROUND %d START | board: %dx%d | target: %d ===" % [
		config.round_number, config.board_columns, config.board_rows, config.target_score
	])
	_deactivate_gameplay()
	TileAnimator.cancel_all()
	_setup_board_for_round(config)
	await _setup_round_state(config)
	_setup_round_background(config)
	_setup_hurry_timer(config)
	if config.boss != null:
		EventBus.boss_activated.emit(config.boss)
	_activate_gameplay()
	_show_gameplay_ui()
	print("[Main] Round %d ready - %dx%d board" % [
		config.round_number, config.board_columns, config.board_rows
	])


# =============================================================================
# ROUND SETUP HELPERS
# =============================================================================

func _deactivate_gameplay() -> void:
	_gameplay_controller.deactivate()
	_focus_cursor.deactivate()


func _activate_gameplay() -> void:
	_gameplay_controller.activate()
	_focus_cursor.activate()


func _setup_board_for_round(config: RoundConfig) -> void:
	# Configure board size for this round
	board.resize_board(config.board_rows, config.board_columns)
	_gameplay_controller.reset_for_board(config.board_rows, config.board_columns)
	board.clear_board()
	# Apply boss cells (must happen after board is created and cleared)
	_apply_boss_cells(config)


func _apply_boss_cells(config: RoundConfig) -> void:
	if config.boss == null:
		return
	var unavailable: Array = config.boss.hooks.get_unavailable_cells(config.board_rows, config.board_columns)
	if not unavailable.is_empty():
		for pos in unavailable:
			var cell: BoardCell = board.get_cell(pos.y, pos.x)
			if cell:
				cell.set_unavailable(true, config.boss.background_color)
		print("[Main] Applied %d unavailable cells for boss '%s'" % [unavailable.size(), config.boss.display_name])
	var highlighted: Array = config.boss.hooks.get_highlighted_cells(config.board_rows, config.board_columns)
	for pos in highlighted:
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell:
			cell.set_boss_tile_multiplier(config.boss.hooks.get_tile_multiplier(pos))
			cell.set_boss_highlight(true)
	if not highlighted.is_empty():
		print("[Main] Applied %d highlighted cells for boss '%s'" % [highlighted.size(), config.boss.display_name])


func _setup_round_state(config: RoundConfig) -> void:
	# Reset per-round tile state for rounds after the first
	if config.round_number > 1:
		hand.clear_hand()
		HandManager.clear_discard_pile()
		TileBag.reshuffle_for_round()
	# Setup GameManager for this round
	var previous_total: int = RunManager.run_state.total_score if RunManager.run_state else 0
	GameManager.setup_round(config, previous_total)
	# Notify ScorePanel with round info and score state
	if _score_panel:
		_score_panel.set_round_info(config)
	# Pass RoundConfig to PlayExecutor for boss effect handling
	_gameplay_controller.set_play_executor_round_config(config)
	# Configure hand size
	HandManager.set_hand_size(config.hand_size)
	# Ensure HandManager is ready, then refill hand
	if not HandManager.is_initialized():
		await HandManager.initialized
	HandManager.refill_hand()


func _setup_round_background(config: RoundConfig) -> void:
	_clear_background_shader()
	var bg_color: Color = _get_round_background_color(config)
	_transition_background(bg_color)
	BackgroundManager.set_color(bg_color)


func _get_round_background_color(config: RoundConfig) -> Color:
	if config.boss != null:
		var gradient: Dictionary = config.boss.hooks.get_background_gradient()
		if not gradient.is_empty():
			_apply_shader_background(gradient)
		return config.boss.background_color
	elif config.is_boss_round:
		return FALLBACK_BOSS_COLOR
	else:
		return NORMAL_ROUND_COLOR


func _setup_hurry_timer(config: RoundConfig) -> void:
	_disconnect_hurry_timer()
	var boss_timer := RunManager.get_boss_timer()
	if boss_timer and config.boss != null:
		var time_config := config.boss.hooks.get_time_attack_config()
		if not time_config.is_empty():
			_hurry_time_limit = time_config.get("time_limit", 90.0)
			_hurry_base_color = config.boss.background_color
			_hurry_timer = boss_timer
			_hurry_timer.time_updated.connect(_on_hurry_timer_updated)


# =============================================================================
# BACKGROUND TRANSITION
# =============================================================================

func _transition_background(target_color: Color) -> void:
	if _bg_tween:
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.set_trans(Tween.TRANS_SINE)
	_bg_tween.set_ease(Tween.EASE_IN_OUT)
	_bg_tween.tween_property(_background, "color", target_color, 1.0)


func _apply_shader_background(gradient_config: Dictionary) -> void:
	var shader: Shader = load("res://scenes/shaders/diagonal_gradient.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if gradient_config.has("primary_color"):
		mat.set_shader_parameter("primary_color", gradient_config["primary_color"])
	if gradient_config.has("secondary_color"):
		mat.set_shader_parameter("secondary_color", gradient_config["secondary_color"])
	_background.material = mat


func _clear_background_shader() -> void:
	_background.material = null


func _on_hurry_timer_updated(time_remaining: float) -> void:
	if _hurry_time_limit <= 0.0:
		return
	if _bg_tween:
		_bg_tween.kill()
		_bg_tween = null
	var ratio: float = 1.0 - (time_remaining / _hurry_time_limit)
	ratio = clampf(ratio, 0.0, 1.0)
	_background.color = _hurry_base_color.lerp(Color.RED, ratio)


func _disconnect_hurry_timer() -> void:
	if _hurry_timer and _hurry_timer.time_updated.is_connected(_on_hurry_timer_updated):
		_hurry_timer.time_updated.disconnect(_on_hurry_timer_updated)
	_hurry_timer = null
	_hurry_time_limit = 0.0


# =============================================================================
# PLAY HANDLING
# =============================================================================

## Called when tiles are played (locked on board).
## Always consumes a play. Words may be empty if no valid words were formed.
func _on_play_completed(tiles: Array[Tile], words: Array) -> void:
	print("[Main] Play completed: %d words formed | Cumulative Score: %d/%d | Plays left: %d" % [
		words.size(), GameManager.get_cumulative_score(),
		GameManager.get_target_score(), GameManager.get_plays_remaining()
	])


# =============================================================================
# SHOP TRANSITION
# =============================================================================

func _on_shop_requested(round_number: int) -> void:
	print("[Main] === ROUND %d END | score: %d ===" % [round_number, GameManager.get_current_score()])

	# Brief pause so the player sees the final score before transitioning
	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout

	_deactivate_gameplay()
	_hide_gameplay_ui()

	# Create shop session with tiles and modifiers
	var tiles = RunManager.get_shop_tiles(10)
	var is_boss = RunManager.current_round_config.is_boss_round
	var modifier_count = 3 if is_boss else 2
	var modifiers = RunManager.get_shop_modifiers(modifier_count)
	var shop_session = ShopSession.new(round_number, is_boss, tiles, modifiers)

	# Set up shop controller for input handling and drag-drop
	if _shop_controller:
		_shop_controller.queue_free()
	_shop_controller = ShopController.new()
	_shop_controller.name = "ShopController"
	add_child(_shop_controller)
	_shop_controller.setup(shop_overlay, shop_session)

	# Trigger entrance animation (shop slides in from bottom, board slides up)
	var entrance_tween = ShopSlideAnimation.get_entrance_animation(shop_overlay, board, self)
	await entrance_tween

	# Peek at next round config for display (without consuming boss pool)
	var next_config: RoundConfig = RunManager.progression_rules.peek_round_config(
		RunManager.run_state
	)
	shop_overlay.show_shop(round_number, GameManager.get_cumulative_score(), next_config)
	print("[Main] === SHOP START | after round %d ===" % round_number)


func _on_shop_continue() -> void:
	print("[Main] === SHOP END | proceeding to next round ===")

	# Commit modifier assignments to the actual tiles before leaving shop
	if _shop_controller and _shop_controller.shop_session:
		var final_tiles = _shop_controller.shop_session.get_final_tiles()
		RunManager.finalize_shop_commit(final_tiles)

	# Trigger exit animation (shop slides out top, board slides back down)
	var exit_tween = ShopSlideAnimation.get_exit_animation(shop_overlay, board, self)
	await exit_tween

	shop_overlay.hide()
	RunManager.proceed_from_shop()


# =============================================================================
# GAME OVER / RUN END
# =============================================================================

func _on_run_ended(victory: bool, total_score: int) -> void:
	_deactivate_gameplay()
	main_hud.hide_hint_bar()
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
	_deactivate_gameplay()
	GameManager.pause_game()
	pause_menu.show_pause_menu_animated()


func _resume_game() -> void:
	GameManager.resume_game()
	_activate_gameplay()


# =============================================================================
# UI HELPERS
# =============================================================================

func _show_gameplay_ui() -> void:
	board.show()
	hand.show()
	main_hud.show()
	main_hud.show_hint_bar()
	shop_overlay.hide()
	game_over_popup.hide()


func _hide_gameplay_ui() -> void:
	board.hide()
	hand.hide()
	main_hud.hide_hint_bar()


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
	_deactivate_gameplay()


## Resumes gameplay.
func resume_gameplay() -> void:
	_activate_gameplay()
