class_name TileVisualReactor
extends Node

## Reacts to TileStateChanged events and updates visual state.
## Owns: BadgeContainer, TileSparkEffect, locked_border, modifier tint/invert.
## Added as child of Tile. Subscribes to DomainEventBus.

var _tile: Tile = null
var _event_bus: DomainEventBus = null
var _spark_effect: TileSparkEffect = null

const EXPO_SPARK_COLORS: Dictionary = {
	ModifierTypes.Tier.BRONZE: Color(1.0, 0.3, 0.2),
	ModifierTypes.Tier.SILVER: Color(1.0, 0.6, 0.1),
	ModifierTypes.Tier.GOLD: Color(0.3, 0.5, 1.0),
}


func setup(tile: Tile, event_bus: DomainEventBus) -> void:
	_tile = tile
	_event_bus = event_bus
	if _event_bus:
		_event_bus.tile_state_changed.connect(_on_tile_state_changed)


func _on_tile_state_changed(event: TileStateChanged) -> void:
	if event.tile_id != _tile.get_instance_id():
		return
	_react_to_modifier_diff(event.old_state, event.new_state)


func _react_to_modifier_diff(old_state: TileState, new_state: TileState) -> void:
	var old_mods: ModifierCollection = old_state.get_modifiers()
	var new_mods: ModifierCollection = new_state.get_modifiers()

	# Handle EXPO spark effect
	var had_expo: bool = old_mods.has(ModifierTypes.Type.EXPO)
	var has_expo: bool = new_mods.has(ModifierTypes.Type.EXPO)
	if has_expo and not had_expo:
		var expo_mod: ModifierInstance = new_mods.get_modifier(ModifierTypes.Type.EXPO)
		_add_spark_effect(expo_mod.tier)
	elif had_expo and not has_expo:
		_remove_spark_effect()

	# Update locked border
	if _tile.locked_border:
		_tile.locked_border.visible = new_state.is_locked()

	# Update full modifier visual (tint, invert, badges)
	_tile._apply_modifier_visual()


func _add_spark_effect(tier: ModifierTypes.Tier) -> void:
	_remove_spark_effect()
	_spark_effect = TileSparkEffect.new()
	_spark_effect.spark_color = EXPO_SPARK_COLORS.get(tier, Color.RED)
	_tile.add_child(_spark_effect)


func _remove_spark_effect() -> void:
	if _spark_effect and is_instance_valid(_spark_effect):
		_spark_effect.queue_free()
	_spark_effect = null


func _exit_tree() -> void:
	if _event_bus and _event_bus.tile_state_changed.is_connected(_on_tile_state_changed):
		_event_bus.tile_state_changed.disconnect(_on_tile_state_changed)
