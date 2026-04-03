extends Control
class_name TitleScreen

## Title screen with menu navigation.
## Entry point for the game. Swaps between MenuView and RunSetupView;
## the two views are never visible at the same time, so input never leaks.
## Uses MenuController for input handling following the controller pattern.

# =============================================================================
# CONFIGURATION
# =============================================================================

const GAMEPLAY_SCENE_PATH: String = "res://scenes/main.tscn"

# =============================================================================
# CONTROLLERS
# =============================================================================

var _menu_controller: MenuController = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _menu_view: Control = $MenuView
@onready var _new_game_button: Button = $MenuView/MenuContainer/VBoxContainer/NewGameButton
@onready var _exit_button: Button = $MenuView/MenuContainer/VBoxContainer/ExitButton
@onready var _run_setup_view: RunSetupView = $RunSetupView

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_menu_controller()
	_setup_signals()


func _setup_menu_controller() -> void:
	_menu_controller = MenuController.new()
	add_child(_menu_controller)
	_menu_controller.setup(_new_game_button, _exit_button)
	_menu_controller.new_game_requested.connect(_on_new_game_requested)
	_menu_controller.exit_requested.connect(_on_exit_requested)
	_menu_controller.activate()


func _setup_signals() -> void:
	_run_setup_view.run_confirmed.connect(_on_run_confirmed)
	_run_setup_view.back_requested.connect(_on_run_setup_back)

# =============================================================================
# VIEW SWITCHING
# =============================================================================

func _on_new_game_requested() -> void:
	_menu_controller.deactivate()
	_menu_view.hide()
	_run_setup_view.show_view()


func _on_run_setup_back() -> void:
	_run_setup_view.hide_view()
	_menu_view.show()
	_menu_controller.activate()

# =============================================================================
# GAME START
# =============================================================================

func _on_run_confirmed(run: Run) -> void:
	print("[TitleScreen] Starting run with %d qualities..." % run.qualities.size())
	RunManager.initialize_run_from_builder(run)
	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)

# =============================================================================
# EXIT
# =============================================================================

func _on_exit_requested() -> void:
	print("[TitleScreen] Exiting game...")
	get_tree().quit()
