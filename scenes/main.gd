extends Control
class_name Main

## Main scene orchestrator.
## Manages high-level game state and delegates gameplay to controllers.
## Future: Will handle transitions between menu, gameplay, settings, etc.

# =============================================================================
# CONTROLLERS
# =============================================================================

var _gameplay_controller: GameplayController = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var board: Board = $Board
@onready var hand: Hand = $Hand
@onready var discard_pile: Control = $DiscardPile
@onready var discard_dialog: CanvasLayer = $DiscardConfirmationDialog
@onready var main_hud: CanvasLayer = $MainHUD


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_controllers()
	_start_game()


func _setup_controllers() -> void:
	# Create and configure gameplay controller
	_gameplay_controller = GameplayController.new()
	add_child(_gameplay_controller)

	# Inject dependencies
	_gameplay_controller.setup(board, hand, discard_pile, discard_dialog, main_hud)

	# Connect controller signals if needed
	_gameplay_controller.play_completed.connect(_on_play_completed)


func _start_game() -> void:
	var default_bag: BagDistribution = load("res://Data/BagDistribution/bag_default.tres")
	GameManager.start_game(default_bag, 0)

	# Activate gameplay controller
	_gameplay_controller.activate()


# =============================================================================
# GAME STATE MANAGEMENT
# =============================================================================

## Called when tiles are played (locked on board).
func _on_play_completed(tiles: Array[Tile], words: Array) -> void:
	# Future: Update score, check win conditions, etc.
	print("[Main] Play completed: %d tiles, %d words" % [tiles.size(), words.size()])


## Pauses gameplay (e.g., for menus or dialogs).
func pause_gameplay() -> void:
	_gameplay_controller.deactivate()


## Resumes gameplay.
func resume_gameplay() -> void:
	_gameplay_controller.activate()


# =============================================================================
# PUBLIC API - For external systems
# =============================================================================

## Registers a tile with the gameplay controller.
## Called by HandManager when tiles are created.
func register_tile(tile: Tile) -> void:
	if _gameplay_controller:
		_gameplay_controller.register_tile(tile)
