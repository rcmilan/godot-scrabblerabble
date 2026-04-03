extends Node
class_name MenuController

## Handles menu navigation and input for title screen.
## Supports keyboard (WASD/arrows) and mouse input.
## Follows the controller pattern used in GameplayController.

# =============================================================================
# SIGNALS
# =============================================================================

signal menu_item_selected(index: int)
signal new_game_requested()
signal exit_requested()

# =============================================================================
# STATE
# =============================================================================

var _is_active: bool = false
var _menu_items: Array[Button] = []
var _current_index: int = 0

# =============================================================================
# DEPENDENCIES (Injected)
# =============================================================================

var _new_game_button: Button
var _exit_button: Button

# =============================================================================
# LIFECYCLE
# =============================================================================

func setup(new_game_btn: Button, exit_btn: Button) -> void:
	"""Inject menu button dependencies."""
	_new_game_button = new_game_btn
	_exit_button = exit_btn

	_menu_items = [new_game_btn, exit_btn]

	# Connect button signals
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)

	# Connect focus signals for mouse hover
	for i in _menu_items.size():
		var button = _menu_items[i]
		button.focus_entered.connect(_on_button_focus_entered.bind(i))
		button.mouse_entered.connect(func(): _focus_item(i))


func activate() -> void:
	"""Enable menu input processing."""
	_is_active = true
	_focus_item(0)  # Focus first item by default


func deactivate() -> void:
	"""Disable menu input processing."""
	_is_active = false

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# W or Up Arrow - Move up
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		_move_selection(-1)
		get_viewport().set_input_as_handled()

	# S or Down Arrow - Move down
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		_move_selection(1)
		get_viewport().set_input_as_handled()

	# A - Jump to first item
	elif event is InputEventKey and event.pressed and event.keycode == KEY_A:
		_focus_item(0)
		get_viewport().set_input_as_handled()

	# D - Jump to last item
	elif event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_focus_item(_menu_items.size() - 1)
		get_viewport().set_input_as_handled()

	# Enter or Space - Activate selected item
	elif event.is_action_pressed("ui_accept"):
		_activate_current_item()
		get_viewport().set_input_as_handled()

# =============================================================================
# NAVIGATION
# =============================================================================

func _move_selection(delta: int) -> void:
	"""Move selection up or down with wrapping."""
	_current_index = (_current_index + delta) % _menu_items.size()
	if _current_index < 0:
		_current_index = _menu_items.size() - 1
	_focus_item(_current_index)


func _focus_item(index: int) -> void:
	"""Focus a specific menu item."""
	if index < 0 or index >= _menu_items.size():
		return

	_current_index = index
	_menu_items[index].grab_focus()
	menu_item_selected.emit(index)


func _activate_current_item() -> void:
	"""Activate the currently focused menu item."""
	if _current_index >= 0 and _current_index < _menu_items.size():
		_menu_items[_current_index].pressed.emit()

# =============================================================================
# BUTTON CALLBACKS
# =============================================================================

func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()


func _on_button_focus_entered(index: int) -> void:
	"""Track which button has focus."""
	_current_index = index
	menu_item_selected.emit(index)
