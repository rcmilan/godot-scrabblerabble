# scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd
extends HBoxContainer
class_name KeyboardHintBar

## Displays live key-binding hints for in-game actions.
## Updates automatically when bindings change or a joypad is connected.

var HINTS: Array[Dictionary] = [
	{ action = KeyAction.PLAY_HAND,     label = "Play"    },
	{ action = KeyAction.DISCARD_TILES, label = "Discard" },
	{ action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
	{ action = KeyAction.SWITCH_ZONE,   label = "Zone"    },
	{ action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]

var _chips: Dictionary = {}     ## StringName -> HBoxContainer
var _using_joypad: bool = false


func _ready() -> void:
	_build_chips()
	_refresh_all()
	KeybindingConfig.binding_changed.connect(_on_binding_changed)
	Input.joy_connection_changed.connect(func(_id: int, _connected: bool) -> void:
		var joypads := Input.get_connected_joypads().size()
		print("[KeyboardHintBar] Joypad count changed: %d connected" % joypads)
		_refresh_all()
	)
	print("[KeyboardHintBar] Ready — %d chips, joypad: %s" % [HINTS.size(), _using_joypad])


func _build_chips() -> void:
	for i: int in HINTS.size():
		var hint: Dictionary = HINTS[i]
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)

		var badge := Label.new()
		badge.name = "Badge"
		chip.add_child(badge)

		var lbl := Label.new()
		lbl.text = hint.label
		chip.add_child(lbl)

		add_child(chip)
		_chips[hint.action] = chip

		if i < HINTS.size() - 1:
			var sep := Label.new()
			sep.text = "  ·  "
			add_child(sep)


func _refresh_all() -> void:
	_using_joypad = Input.get_connected_joypads().size() > 0
	for hint: Dictionary in HINTS:
		_update_chip(hint.action)


func _update_chip(action: StringName) -> void:
	var chip: HBoxContainer = _chips.get(action)
	if chip == null:
		return
	var badge: Label = chip.get_node("Badge")
	var text := KeybindingConfig.get_event_display_text(action, _using_joypad)
	if text.is_empty():
		# Fallback to keyboard if no joypad binding exists
		text = KeybindingConfig.get_event_display_text(action, false)
	badge.text = "[%s]" % text


func _on_binding_changed(action: StringName) -> void:
	_update_chip(action)
