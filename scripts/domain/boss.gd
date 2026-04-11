## Boss: Immutable value object representing a unique boss entity.
##
## A Boss carries identity (id, display_name), visual properties (background_color),
## and customization hooks for game mechanics. Boss objects are created once and
## never mutated; they are referenced by RoundConfig and selected from BossPool.
##
## No Godot engine dependencies -- can be tested independently.
class_name Boss
extends RefCounted


## Unique identifier for this boss (e.g., &"gravity")
var id: StringName

## Human-readable display name shown in UI and round indicator
var display_name: String

## Background color during this boss's round
var background_color: Color

## Customization hooks for game mechanics (tile rules, post-play effects, etc.)
var hooks: BossHooks


## Constructor: initialize all four fields
func _init(p_id: StringName, p_display_name: String, p_background_color: Color, p_hooks: BossHooks) -> void:
	id = p_id
	display_name = p_display_name
	background_color = p_background_color
	hooks = p_hooks if p_hooks != null else BossHooks.new()


## String representation for debugging
func _to_string() -> String:
	return "Boss(id=%s, name=%s, color=%s)" % [id, display_name, background_color.to_html()]
