class_name ModifierCollection
extends RefCounted

## Immutable collection of modifiers. All mutations return new instances.

var _modifiers: Dictionary = {}  # ModifierTypes.Type → ModifierInstance

static var _empty: ModifierCollection = null


static func empty() -> ModifierCollection:
	if _empty == null:
		_empty = ModifierCollection.new({})
	return _empty


func _init(modifiers: Dictionary = {}) -> void:
	_modifiers = modifiers.duplicate()


func with_added(modifier: ModifierInstance) -> ModifierCollection:
	var new_mods: Dictionary = _modifiers.duplicate()
	new_mods[modifier.type] = modifier
	return ModifierCollection.new(new_mods)


func without(type: ModifierTypes.Type) -> ModifierCollection:
	if not _modifiers.has(type):
		return self
	var new_mods: Dictionary = _modifiers.duplicate()
	new_mods.erase(type)
	return ModifierCollection.new(new_mods)


func without_lifetime(lifetime: ModifierTypes.Lifetime) -> ModifierCollection:
	var new_mods: Dictionary = {}
	for type in _modifiers:
		var mod: ModifierInstance = _modifiers[type]
		if mod.lifetime != lifetime:
			new_mods[type] = mod
	return ModifierCollection.new(new_mods)


func without_consumables() -> ModifierCollection:
	return without_lifetime(ModifierTypes.Lifetime.CONSUMABLE)


func without_round_modifiers() -> ModifierCollection:
	var new_mods: Dictionary = {}
	for type in _modifiers:
		var mod: ModifierInstance = _modifiers[type]
		if mod.lifetime == ModifierTypes.Lifetime.PERMANENT:
			new_mods[type] = mod
	return ModifierCollection.new(new_mods)


func has(type: ModifierTypes.Type) -> bool:
	return _modifiers.has(type)


func get_modifier(type: ModifierTypes.Type) -> ModifierInstance:
	return _modifiers.get(type)


func get_all() -> Array[ModifierInstance]:
	var result: Array[ModifierInstance] = []
	for mod in _modifiers.values():
		result.append(mod)
	return result


func get_by_lifetime(lifetime: ModifierTypes.Lifetime) -> Array[ModifierInstance]:
	var result: Array[ModifierInstance] = []
	for mod in _modifiers.values():
		if mod.lifetime == lifetime:
			result.append(mod)
	return result


func is_empty() -> bool:
	return _modifiers.is_empty()


func size() -> int:
	return _modifiers.size()


func to_dictionary() -> Dictionary:
	return _modifiers.duplicate()
