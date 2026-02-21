extends Node
class_name KeybindingConfig

## Manages saving and loading InputMap overrides from user://keybindings.cfg.
## Acts as an autoload; call load_and_apply() once on game start.

const SAVE_PATH := "user://keybindings.cfg"

const KEYBINDABLE_ACTIONS: Array[StringName] = [
	&"navigate_left", &"navigate_right", &"navigate_up", &"navigate_down",
	&"confirm_action", &"cancel_action",
	&"play_hand", &"draw_tiles", &"discard_tiles",
	&"pause_game", &"toggle_multi_select",
]

const ACTION_DISPLAY_NAMES: Dictionary = {
	&"navigate_left":       "Navigate Left",
	&"navigate_right":      "Navigate Right",
	&"navigate_up":         "Navigate Up",
	&"navigate_down":       "Navigate Down",
	&"confirm_action":      "Confirm / Place",
	&"cancel_action":       "Cancel / Return",
	&"play_hand":           "Play Hand",
	&"draw_tiles":          "Draw Tiles",
	&"discard_tiles":       "Discard Tiles",
	&"pause_game":          "Pause",
	&"toggle_multi_select": "Multi-Select",
}


## Postcondition: any saved overrides in user://keybindings.cfg applied to InputMap.
func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action: StringName in KEYBINDABLE_ACTIONS:
		if cfg.has_section_key("bindings", action):
			var event: Variant = cfg.get_value("bindings", action)
			if event is InputEvent:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)


## Precondition : action is in KEYBINDABLE_ACTIONS.
## Postcondition: InputMap updated; binding persisted to disk.
func save_binding(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("bindings", action, event)
	cfg.save(SAVE_PATH)


## Postcondition: InputMap restored to project defaults; keybindings.cfg cleared.
func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	var cfg := ConfigFile.new()
	cfg.save(SAVE_PATH)


## Returns a human-readable display name for an action.
func get_display_name(action: StringName) -> String:
	return ACTION_DISPLAY_NAMES.get(action, String(action))


## Returns a short display string for an action's current keyboard binding(s).
func get_event_display_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for ev in events:
		if ev is InputEventKey:
			parts.append(ev.as_text_keycode())
	return "  /  ".join(parts) if parts.size() > 0 else "—"
