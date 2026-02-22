extends Node

## Manages saving and loading InputMap overrides from user://keybindings.cfg.
## Acts as an autoload; call load_and_apply() once on game start.

signal binding_changed(action: StringName)

const SAVE_PATH := "user://keybindings.cfg"

const KEYBINDABLE_ACTIONS: Array[StringName] = [
	&"navigate_left", &"navigate_right", &"navigate_up", &"navigate_down",
	&"confirm_action", &"cancel_action", &"switch_zone",
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
	&"switch_zone":         "Switch Zone",
	&"play_hand":           "Play Hand",
	&"draw_tiles":          "Draw Tiles",
	&"discard_tiles":       "Discard Tiles",
	&"pause_game":          "Pause",
	&"toggle_multi_select": "Multi-Select",
}

const CATEGORIES: Array[Dictionary] = [
	{
		"label":   "Navigation",
		"actions": [&"navigate_left", &"navigate_right", &"navigate_up",
		            &"navigate_down", &"switch_zone"],
	},
	{
		"label":   "Tile Actions",
		"actions": [&"confirm_action", &"cancel_action",
		            &"toggle_multi_select", &"discard_tiles"],
	},
	{
		"label":   "Game Actions",
		"actions": [&"play_hand", &"draw_tiles", &"pause_game"],
	},
]


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
	binding_changed.emit(action)


## Postcondition: InputMap restored to project defaults; keybindings.cfg cleared.
func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	var cfg := ConfigFile.new()
	cfg.save(SAVE_PATH)


## Returns a human-readable display name for an action.
func get_display_name(action: StringName) -> String:
	return ACTION_DISPLAY_NAMES.get(action, String(action))


## Returns a formatted string of bound keys for the action.
## joypad_only: when true, returns only joypad bindings (for controller hint bar).
func get_event_display_text(action: StringName, joypad_only: bool = false) -> String:
	var events := InputMap.action_get_events(action)
	var parts: Array[String] = []
	for event: InputEvent in events:
		var is_joypad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if joypad_only and not is_joypad:
			continue
		if not joypad_only and is_joypad:
			continue
		parts.append(event.as_text())
	return " / ".join(parts)
