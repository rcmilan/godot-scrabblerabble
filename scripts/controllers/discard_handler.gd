class_name DiscardHandler
extends RefCounted

## Handles discard pile interactions: request, drop, animate, complete.

var _selection: SelectionManager = null
var _drag_mgr: DragManager = null
var discard_pile: Control = null
var hand: Hand = null

## Callback for post-discard state updates (provided by controller).
var _on_discard_complete: Callable


func setup(
	p_selection: SelectionManager,
	p_drag_mgr: DragManager,
	p_discard_pile: Control,
	p_hand: Hand,
	on_discard_complete: Callable
) -> void:
	_selection = p_selection
	_drag_mgr = p_drag_mgr
	discard_pile = p_discard_pile
	hand = p_hand
	_on_discard_complete = on_discard_complete


## Discards selected hand tiles directly.
func request_discard() -> void:
	var selected_tiles: Array[Tile] = _selection.get_selected_tiles()
	print("[Discard] request_discard: %d selected, mode=%s" % [selected_tiles.size(), _selection.get_mode_name() if _selection.has_method("get_mode_name") else "?"])

	var hand_tiles: Array[Tile] = []
	for tile in selected_tiles:
		print("[Discard]   tile '%s' location=%s" % [tile.letter if tile else "?", tile.location if tile else "?"])
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		print("[Discard] No hand tiles selected to discard (selected=%d, hand_filtered=%d)" % [selected_tiles.size(), hand_tiles.size()])
		return

	execute_discard_animated(hand_tiles)


## Handles tiles dropped onto the discard pile during drag.
func handle_drop_on_discard_pile(tiles: Array[Tile]) -> void:
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		_drag_mgr.restore_tiles_to_parents()
		print("[Gameplay] Cannot discard board tiles")
		return

	_drag_mgr.restore_tiles_to_parents()
	execute_discard_animated(hand_tiles)


## Handles discard pile click.
func on_discard_pile_clicked() -> void:
	request_discard()


## Handles tiles_dropped signal from discard pile.
func on_discard_pile_tiles_dropped(tiles: Array) -> void:
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile is Tile and tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		return

	execute_discard_animated(hand_tiles)


## Handles peek request.
func on_discard_pile_peek_requested() -> void:
	var pile: Array[Tile] = HandManager.get_discard_pile()
	print("[Gameplay] Peek requested - Discard pile has %d tiles" % pile.size())


## Animates tiles to discard pile, then discards them.
func execute_discard_animated(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	_selection.deselect_all()

	var target_pos: Vector2 = _get_discard_pile_center()

	TileAnimator.animate_discard_batch(tiles, target_pos, func():
		_complete_discard(tiles)
	)

	print("[Gameplay] Animating %d tiles to discard pile" % tiles.size())


func _complete_discard(tiles: Array[Tile]) -> void:
	for tile in tiles:
		tile.scale = Vector2.ONE
		tile.modulate = Color.WHITE
		HandManager.discard_tile(tile)

	var refilled: int = HandManager.refill_hand()
	print("[Gameplay] Discarded %d tiles, refilled %d" % [tiles.size(), refilled])

	if _on_discard_complete.is_valid():
		_on_discard_complete.call()


func _get_discard_pile_center() -> Vector2:
	if discard_pile:
		return discard_pile.global_position + (discard_pile.size / 2.0)
	return Vector2.ZERO
