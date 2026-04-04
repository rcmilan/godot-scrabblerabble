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

	# Get board reference from parent (Main scene)
	var parent = get_parent()
	if parent and parent.has_node("Board"):
		_board = parent.get_node("Board")

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
## Board slides left off-screen while pause menu slides in from right simultaneously.
func show_pause_menu_animated() -> void:
	if _animating:
		return

	_animating = true
	visible = true

	# Start animations in parallel
	var slide_left_tween: Tween = null
	var slide_in_tween: Tween = null

	if _board:
		slide_left_tween = TileAnimator.animate_slide_left(_board)

	slide_in_tween = TileAnimator.animate_slide_in_from_right(self, func() -> void:
		_animating = false
		_resume_button.grab_focus()
	)


## Closes pause menu with animated scene-swap (reverses the entry animation).
## Pause menu slides left off-screen while board slides in from right simultaneously.
func close_pause_menu_animated() -> void:
	if _animating:
		return

	_animating = true

	# Start animations in parallel (reverse of entry)
	var slide_left_tween: Tween = TileAnimator.animate_slide_left(self)
	var slide_in_tween: Tween = null

	if _board:
		slide_in_tween = TileAnimator.animate_slide_in_from_right(_board, func() -> void:
			_animating = false
			visible = false
			resume_requested.emit()
		)
	else:
		# If no board reference, just complete animation without it
		await slide_left_tween.finished
		_animating = false
		visible = false
		resume_requested.emit()


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
