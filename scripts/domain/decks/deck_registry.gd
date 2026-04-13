extends RefCounted
class_name DeckRegistry

## DeckRegistry: Static factory registry for DeckDefinition types.
## Mirrors QualityRegistry. Maps deck IDs to factory callables.
##
## Precondition : _factories populated with standard, equal, cursed on first access.
## Postcondition: create_default(unknown_id) returns null and logs a warning.
## Invariant    : all registered IDs are unique StringNames.

# =============================================================================
# REGISTRY STATE
# =============================================================================

static var _factories: Dictionary = {}
static var _initialized: bool = false

# =============================================================================
# PUBLIC API
# =============================================================================

static func register(id: StringName, factory: Callable) -> void:
	_ensure_initialized()
	_factories[id] = factory


static func create_default(id: StringName) -> DeckDefinition:
	_ensure_initialized()
	if not _factories.has(id):
		push_warning("[DeckRegistry] Unknown deck ID: %s" % id)
		return null
	return _factories[id].call()


static func get_all_deck_ids() -> Array[StringName]:
	_ensure_initialized()
	var ids: Array[StringName] = []
	for key in _factories.keys():
		ids.append(key)
	return ids

# =============================================================================
# INITIALIZATION
# =============================================================================

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	_factories[&"standard"] = func() -> DeckDefinition: return StandardDeck.new()
	_factories[&"equal"]    = func() -> DeckDefinition: return EqualDeck.new()
	_factories[&"cursed"]   = func() -> DeckDefinition: return CursedDeck.new()
	_factories[&"multi"]    = func() -> DeckDefinition: return MultiDeck.new()
	_factories[&"expo"]     = func() -> DeckDefinition: return ExpoDeck.new()
	_factories[&"extra"]    = func() -> DeckDefinition: return ExtraDeck.new()
	_factories[&"random_modifiers"] = func() -> DeckDefinition: return RandomModifiersDeck.new()
