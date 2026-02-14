class_name ModifierRegistry
extends RefCounted

## ModifierRegistry: Static factory for creating modifier instances.
## Same pattern as QualityRegistry — auto-initializes on first use.

static var _behaviors: Dictionary = {}
static var _initialized: bool = false


static func get_behavior(type: ModifierTypes.Type) -> ModifierBehavior:
	_ensure_initialized()
	return _behaviors.get(type, null)


static func create_modifier(
	type: ModifierTypes.Type,
	tier: ModifierTypes.Tier = ModifierTypes.Tier.BRONZE,
	lifetime: ModifierTypes.Lifetime = ModifierTypes.Lifetime.CONSUMABLE
) -> ModifierInstance:
	_ensure_initialized()
	var behavior: ModifierBehavior = _behaviors.get(type, null)
	return ModifierInstance.new(type, tier, lifetime, behavior)


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	_behaviors[ModifierTypes.Type.EXTRA] = ExtraBehavior.new()
	_behaviors[ModifierTypes.Type.MULTI] = MultiBehavior.new()
	_behaviors[ModifierTypes.Type.RESET] = ResetBehavior.new()
