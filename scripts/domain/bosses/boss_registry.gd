## BossRegistry: Static registry of all available boss definitions.
##
## Single source of truth for what bosses exist in the game.
## Bosses are registered at startup (hardcoded definitions).
##
## No runtime registration/unregistration -- pool of bosses is fixed per game version.
class_name BossRegistry
extends RefCounted


## Static registry of all bosses (initialized lazily)
var _bosses: Array[Boss] = []
var _initialized: bool = false


## Initialize the registry with all boss definitions
func _init() -> void:
	if _initialized:
		print("[BossRegistry] Already initialized, skipping")
		return

	# Register Gravity boss
	var gravity_boss = Boss.new(
		&"gravity",
		"Gravity",
		Color("#330033"),
		GravityBossHooks.new()
	)
	_bosses.append(gravity_boss)
	print("[BossRegistry] Registered boss: %s | Total bosses: %d" % [gravity_boss.display_name, _bosses.size()])

	# Register Hurry boss
	var hurry_boss = Boss.new(
		&"hurry",
		"Hurry",
		Color.SILVER,
		HurryBossHooks.new()
	)
	_bosses.append(hurry_boss)
	print("[BossRegistry] Registered boss: %s | Total bosses: %d" % [hurry_boss.display_name, _bosses.size()])

	# Register Pitfall boss
	var pitfall_boss = Boss.new(
		&"pitfall",
		"Pitfall",
		Color("#8B4513"),
		PitfallBossHooks.new()
	)
	_bosses.append(pitfall_boss)
	print("[BossRegistry] Registered boss: %s | Total bosses: %d" % [pitfall_boss.display_name, _bosses.size()])

	# Register Diagonal boss
	var diagonal_boss = Boss.new(
		&"diagonal",
		"Diagonal",
		Color("#B8860B"),
		DiagonalBossHooks.new()
	)
	_bosses.append(diagonal_boss)
	print("[BossRegistry] Registered boss: %s | Total bosses: %d" % [diagonal_boss.display_name, _bosses.size()])

	_initialized = true


## Returns all registered bosses
func get_all_bosses() -> Array[Boss]:
	if not _initialized:
		_init()
	return _bosses.duplicate()


## Returns a boss by ID, or null if not found
func get_boss_by_id(id: StringName) -> Boss:
	if not _initialized:
		_init()
	for boss in _bosses:
		if boss.id == id:
			return boss
	return null


## Returns the number of registered bosses
func get_boss_count() -> int:
	if not _initialized:
		_init()
	return _bosses.size()
