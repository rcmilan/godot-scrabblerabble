extends Control
class_name ShopOverlay

## ShopOverlay: Transitional scene between rounds.
## Shows round summary and "Continue" button.
## Future: Shop items, upgrades, modifiers.

# =============================================================================
# SIGNALS
# =============================================================================

signal continue_requested
signal debug_config_requested

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _overlay: ColorRect = $Overlay
@onready var _round_label: Label = $ContentContainer/RoundLabel
@onready var _score_label: Label = $ContentContainer/ScoreLabel
@onready var _next_board_label: Label = $ContentContainer/NextBoardLabel
@onready var _continue_button: Button = $ContentContainer/ContinueButton
@onready var _debug_config_button: Button = $ContentContainer/DebugConfigButton
@onready var _debug_popup: DebugRoundConfigPopup = $DebugRoundConfigPopup

var _next_config: RoundConfig = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_debug_config_button.pressed.connect(_on_debug_config_pressed)
	_debug_popup.config_applied.connect(_on_debug_config_applied)
	_debug_popup.popup_closed.connect(_on_debug_popup_closed)
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _debug_popup.visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_shop(round_completed: int, round_score: int, next_config: RoundConfig) -> void:
	_next_config = next_config
	_round_label.text = "Round %d Complete!" % round_completed
	_score_label.text = "Score: %d" % round_score
	_update_next_board_label()
	show()
	_continue_button.grab_focus()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_continue_pressed() -> void:
	hide()
	continue_requested.emit()


func _on_debug_config_pressed() -> void:
	if _next_config:
		_debug_popup.show_popup(_next_config.board_rows, _next_config.board_columns)


func _on_debug_config_applied(rows: int, cols: int) -> void:
	_update_next_board_label()


func _on_debug_popup_closed() -> void:
	_continue_button.grab_focus()


func _update_next_board_label() -> void:
	if _next_config:
		_next_board_label.text = "Next: Round %d (%dx%d board, Target: %d)" % [
			_next_config.round_number, _next_config.board_columns,
			_next_config.board_rows, _next_config.target_score
		]
