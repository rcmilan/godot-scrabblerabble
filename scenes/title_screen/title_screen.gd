extends Control
class_name TitleScreen

## Title screen with menu navigation.
## Entry point for the game, handles main menu and options.
## Uses MenuController for input handling following the controller pattern.

# =============================================================================
# CONFIGURATION
# =============================================================================

## Path to the gameplay scene (main.tscn)
const GAMEPLAY_SCENE_PATH: String = "res://scenes/main.tscn"

# =============================================================================
# CONTROLLERS
# =============================================================================

var _menu_controller: MenuController = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _new_game_button: Button = $MenuContainer/VBoxContainer/NewGameButton
@onready var _options_button: Button = $MenuContainer/VBoxContainer/OptionsButton
@onready var _exit_button: Button = $MenuContainer/VBoxContainer/ExitButton
@onready var _options_popup: OptionsPopup = $OptionsPopup
@onready var _run_setup_popup: RunSetupPopup = $RunSetupPopup
@onready var _title_label: Label = $TitleLabel

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_menu_controller()
	_setup_ui()


func _setup_menu_controller() -> void:
	## Create and configure the menu controller.
	_menu_controller = MenuController.new()
	add_child(_menu_controller)

	# Inject dependencies
	_menu_controller.setup(_new_game_button, _options_button, _exit_button)

	# Connect signals
	_menu_controller.new_game_requested.connect(_on_new_game_requested)
	_menu_controller.options_requested.connect(_on_options_requested)
	_menu_controller.exit_requested.connect(_on_exit_requested)

	# Activate controller
	_menu_controller.activate()


func _setup_ui() -> void:
	## Configure UI elements.
	_title_label.text = "Scrabblerabble"

	# Connect options popup
	_options_popup.closed.connect(_on_options_closed)

	# Connect run setup popup
	_run_setup_popup.run_confirmed.connect(_on_run_confirmed)
	_run_setup_popup.cancelled.connect(_on_run_setup_cancelled)

# =============================================================================
# MENU ACTIONS
# =============================================================================

func _on_new_game_requested() -> void:
	## Show run setup popup for quality selection.
	_menu_controller.deactivate()
	_run_setup_popup.show_popup()


func _on_options_requested() -> void:
	## Show options popup.
	_menu_controller.deactivate()
	_options_popup.show_popup()


func _on_exit_requested() -> void:
	## Exit the game.
	print("[TitleScreen] Exiting game...")
	get_tree().quit()

# =============================================================================
# RUN SETUP POPUP
# =============================================================================

func _on_run_confirmed(run: Run) -> void:
	## Start a new game with the configured run.
	print("[TitleScreen] Starting run with %d qualities..." % run.qualities.size())

	RunManager.initialize_run_from_builder(run)

	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)


func _on_run_setup_cancelled() -> void:
	## Re-activate menu when run setup is cancelled.
	_menu_controller.activate()

# =============================================================================
# OPTIONS POPUP
# =============================================================================

func _on_options_closed() -> void:
	## Re-activate menu when options popup closes.
	_menu_controller.activate()
