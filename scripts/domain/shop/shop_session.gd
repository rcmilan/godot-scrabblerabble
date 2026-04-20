class_name ShopSession

var round_number: int
var is_boss_round: bool
var available_modifiers: Array[ModifierTypes.Type]
var available_tiles: Array[TileState]
var pending_assignments: Dictionary = {}

func _init(round: int, is_boss: bool, tiles: Array[TileState], mods: Array[ModifierTypes.Type]) -> void:
	round_number = round
	is_boss_round = is_boss
	available_tiles = tiles
	available_modifiers = mods
	pending_assignments = {}

	# Validate invariants (Principle VI: non-representable invalid states)
	assert(available_tiles.size() == 10, "ShopSession must have exactly 10 tiles")
	assert(available_modifiers.size() in [2, 3], "ShopSession must have 2 or 3 modifiers")


func apply_modifier(tile: TileState, modifier: ModifierInstance) -> ShopSession:
	# Apply modifier to tile; validate max 1 per tile
	if not tile.can_accept_modifier():
		push_error("Cannot apply—tile already has modifier")
		return self

	var new_session = ShopSession.new(round_number, is_boss_round, available_tiles, available_modifiers)
	new_session.pending_assignments = pending_assignments.duplicate()
	new_session.pending_assignments[tile] = modifier
	return new_session


func revert_all() -> ShopSession:
	# Clear all session-applied modifiers; restore pre-loaded state
	return ShopSession.new(round_number, is_boss_round, available_tiles, available_modifiers)


func get_final_tiles() -> Array[TileState]:
	# Return tiles with all applied modifiers (for commit)
	var result: Array[TileState] = []
	for tile in available_tiles:
		if pending_assignments.has(tile):
			result.append(tile.with_session_modifier(pending_assignments[tile]))
		else:
			result.append(tile)
	return result


func get_unused_modifiers() -> Array[ModifierTypes.Type]:
	# Return modifiers not applied to any tile
	var used: Array[ModifierTypes.Type] = []
	for modifier_instance in pending_assignments.values():
		if modifier_instance is ModifierInstance:
			used.append(modifier_instance.type)

	var unused: Array[ModifierTypes.Type] = []
	for mod_type in available_modifiers:
		if mod_type not in used:
			unused.append(mod_type)
	return unused


func can_apply_modifier(tile: TileState) -> bool:
	# Check if tile can accept modifier
	return tile.can_accept_modifier()


func get_tile_modifier(tile: TileState) -> ModifierInstance:
	# Return active modifier on tile (from pending assignments)
	if pending_assignments.has(tile):
		return pending_assignments[tile]
	return null
