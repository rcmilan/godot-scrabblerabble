extends RefCounted
class_name QualityRegistry

## QualityRegistry: Static factory registry for RunQuality types.
## Maps quality IDs to factory callables for creation and deserialization.

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


static func create_from_dict(data: Dictionary) -> RunQuality:
	_ensure_initialized()
	var id: StringName = StringName(data.get("quality_id", ""))
	if not _factories.has(id):
		push_warning("[QualityRegistry] Unknown quality ID: %s" % id)
		return null
	var quality: RunQuality = _factories[id].call()
	return quality


static func create_default(id: StringName) -> RunQuality:
	_ensure_initialized()
	if not _factories.has(id):
		push_warning("[QualityRegistry] Unknown quality ID: %s" % id)
		return null
	return _factories[id].call()


static func get_all_quality_ids() -> Array[StringName]:
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

	# Register all built-in qualities
	_factories[&"max_hand_size"] = func() -> RunQuality: return MaxHandSizeQuality.new()
	_factories[&"time_attack"] = func() -> RunQuality: return TimeAttackQuality.new()
	_factories[&"limited_time_with_increment"] = func() -> RunQuality: return LimitedTimeWithIncrementQuality.new()
	_factories[&"max_score_in_n_rounds"] = func() -> RunQuality: return MaxScoreInNRoundsQuality.new()
