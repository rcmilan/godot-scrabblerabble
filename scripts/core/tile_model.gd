extends Node

# TileModel: Data model for a single tile.
# Stores letter, point value, modifiers and lifecycle state.

class_name TileModel

enum State { NOT_PLACED, PLACED, VALIDATED }

var letter: String = ""
var value: int = 0

# Per-tile modifiers (defaults)
var letter_multiplier: int = 1
var word_multiplier: int = 1
var temporary_modifiers: Dictionary = {}
var placement_multiplier: int = 1 # contributes to final score multiplier (default 1)

# Lifecycle
var state: int = State.NOT_PLACED
var placement_turn: int = -1
var validated_turn: int = -1

func _init(p_letter: String = "", p_value: int = 0):
	letter = p_letter
	value = p_value

func mark_placed(turn_id: int) -> void:
	state = State.PLACED
	placement_turn = turn_id
	validated_turn = -1

func mark_validated(turn_id: int) -> void:
	state = State.VALIDATED
	validated_turn = turn_id

func reset_validation() -> void:
	validated_turn = -1
	if placement_turn == -1:
		state = State.NOT_PLACED

# Helper: effective letter value taking into account letter_multiplier
func effective_letter_value() -> int:
	return value * letter_multiplier

func add_modifier(mod_name: String, data = null) -> void:
	# Example modifier name: "bonus_multiplier_2" -> sets placement_multiplier to 2
	temporary_modifiers[mod_name] = data
	if mod_name.begins_with("bonus_multiplier_"):
		var parts = mod_name.split("_")
		var v = int(parts[2]) if parts.size() > 2 else 1
		placement_multiplier = v

func clear_modifier(mod_name: String) -> void:
	if temporary_modifiers.has(mod_name):
		temporary_modifiers.erase(mod_name)
	# Reset placement multiplier if modifier removed and no other modifier sets it
	# For simplicity, reset to 1 (further logic could recompute from remaining modifiers)
	placement_multiplier = 1

