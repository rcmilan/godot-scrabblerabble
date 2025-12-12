extends Node

# DebugManager: Controls toggleable debug overlay for development and testing.
# Press F12 or ` (tilde/grave) to toggle debug overlay in any scene.

signal debug_overlay_toggled(visible: bool)

var _overlay_visible: bool = false
var _debug_overlay_scene = preload("res://scenes/ui/DebugOverlay.tscn")
var _debug_overlay_instance = null

func _ready():
	# Auto-instantiate in debug builds
	if OS.is_debug_build():
		call_deferred("_instantiate_overlay")

func _input(event):
	# Toggle with F12 or tilde/grave key
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 or event.keycode == KEY_QUOTELEFT:
			toggle_overlay()
			get_viewport().set_input_as_handled()

func toggle_overlay():
	if not _debug_overlay_instance:
		_instantiate_overlay()
	
	_overlay_visible = !_overlay_visible
	if _debug_overlay_instance:
		_debug_overlay_instance.visible = _overlay_visible
	emit_signal("debug_overlay_toggled", _overlay_visible)
	print("[DebugManager] Debug overlay: ", "visible" if _overlay_visible else "hidden")

func _instantiate_overlay():
	if _debug_overlay_instance:
		return
	
	_debug_overlay_instance = _debug_overlay_scene.instantiate()
	# Add to root so it persists across scene changes
	get_tree().root.add_child(_debug_overlay_instance)
	_debug_overlay_instance.visible = _overlay_visible
	print("[DebugManager] Debug overlay instantiated")

func is_overlay_visible() -> bool:
	return _overlay_visible
