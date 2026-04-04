extends Control
class_name PauseMenu

## Pause menu with animated scene-swap transitions.
## When paused: board slides left off-screen, pause menu slides in from right.
## When resumed: pause menu slides left off-screen, board slides in from right.

# =============================================================================
# SIGNALS
# =============================================================================

signal resume_requested
signal return_to_title_requested

# =============================================================================
# STATE
# =============================================================================

var _guard: ModalInputGuard
var _animating: bool = false
var _board: Control = null

# UI references and original positions
var _hand: Control = null
var _main_hud: CanvasLayer = null
var _discard_pile: Control = null
var _multi_select_indicator: Control = null
var _keyboard_hint: Control = null

var _hand_original_pos: Vector2 = Vector2.ZERO
var _hud_original_pos: Vector2 = Vector2.ZERO
var _discard_original_pos: Vector2 = Vector2.ZERO
var _multi_select_original_pos: Vector2 = Vector2.ZERO
var _keyboard_hint_original_pos: Vector2 = Vector2.ZERO

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _overlay: ColorRect = $Overlay
@onready var _resume_button: Button = $ContentContainer/ResumeButton
@onready var _return_button: Button = $ContentContainer/ReturnToTitleButton

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_resume_button.pressed.connect(_on_resume_pressed)
	_return_button.pressed.connect(_on_return_pressed)

	# Get all UI references from parent (Main scene)
	var parent = get_parent()
	if parent:
		if parent.has_node("Board"):
			_board = parent.get_node("Board")
		if parent.has_node("Hand"):
			_hand = parent.get_node("Hand")
			_hand_original_pos = _hand.position
		if parent.has_node("MainHUD"):
			_main_hud = parent.get_node("MainHUD")
			# MainHUD is a CanvasLayer, use offset instead of position
			if _main_hud is CanvasLayer:
				_hud_original_pos = _main_hud.offset
			else:
				_hud_original_pos = _main_hud.position
		if parent.has_node("DiscardPile"):
			_discard_pile = parent.get_node("DiscardPile")
			_discard_original_pos = _discard_pile.position
		if parent.has_node("MultiSelectIndicator"):
			_multi_select_indicator = parent.get_node("MultiSelectIndicator")
			_multi_select_original_pos = _multi_select_indicator.position
		# Find keyboard hint bar (usually in MainHUD)
		if _main_hud and _main_hud.has_node("KeyboardHintBar"):
			_keyboard_hint = _main_hud.get_node("KeyboardHintBar")
			_keyboard_hint_original_pos = _keyboard_hint.position

	# Setup ModalInputGuard for Escape key
	_guard = ModalInputGuard.new().setup(self).add_close_action(KeyAction.PAUSE_GAME)
	# Wire Escape key to trigger animated close (not simple hide)
	_guard.close_requested.connect(func() -> void:
		if not _animating:
			close_pause_menu_animated()
	)

	hide()


func _input(event: InputEvent) -> void:
	if _guard.handle(event):
		return

# =============================================================================
# PUBLIC API
# =============================================================================

## Shows pause menu with animated scene-swap.
## All UI elements slide off-screen in different directions, pause menu slides in from right.
func show_pause_menu_animated() -> void:
	if _animating:
		return

	_animating = true
	visible = true

	# Animate all UI elements out in different directions (in parallel)
	if _board:
		TileAnimator.animate_slide_left(_board)
	if _hand:
		TileAnimator.animate_slide_up(_hand)
	if _main_hud:
		TileAnimator.animate_slide_right(_main_hud)
	if _discard_pile:
		TileAnimator.animate_slide_down(_discard_pile)
	if _multi_select_indicator:
		TileAnimator.animate_slide_up(_multi_select_indicator)
	if _keyboard_hint:
		TileAnimator.animate_slide_down(_keyboard_hint)

	# Pause menu slides in from right with completion callback
	TileAnimator.animate_slide_in_from_right(self, func() -> void:
		if is_instance_valid(self):
			_animating = false
			_resume_button.grab_focus()
	)


## Closes pause menu with animated scene-swap (reverses the entry animation).
## All UI elements slide back in from opposite directions, pause menu slides left off-screen.
func close_pause_menu_animated() -> void:
	if _animating:
		return

	_animating = true

	# Animate pause menu out to the left
	TileAnimator.animate_slide_left(self)

	# Animate all UI elements back in from opposite directions (in parallel)
	if _board:
		TileAnimator.animate_slide_in_from_right(_board)
	if _hand:
		TileAnimator.animate_slide_in_from_top(_hand, _hand_original_pos.y)
	if _main_hud:
		TileAnimator.animate_slide_in_from_left(_main_hud, _hud_original_pos.x)
	if _discard_pile:
		TileAnimator.animate_slide_in_from_bottom(_discard_pile, _discard_original_pos.y)
	if _multi_select_indicator:
		TileAnimator.animate_slide_in_from_top(_multi_select_indicator, _multi_select_original_pos.y)
	if _keyboard_hint:
		TileAnimator.animate_slide_in_from_bottom(_keyboard_hint, _keyboard_hint_original_pos.y, func() -> void:
			if is_instance_valid(self):
				_animating = false
				visible = false
				resume_requested.emit()
		)


## Legacy method for compatibility (non-animated).
func close_pause_menu() -> void:
	hide()
	resume_requested.emit()


## Legacy method for compatibility (non-animated).
func show_pause_menu() -> void:
	show()
	_resume_button.grab_focus()

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_resume_pressed() -> void:
	if not _animating:
		close_pause_menu_animated()


func _on_return_pressed() -> void:
	if not _animating:
		hide()
		return_to_title_requested.emit()
