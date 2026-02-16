extends Node

## HandManager: Manages the player's hand of tiles.
## Coordinates between TileBag, Hand UI, and Main scene.
## Handles drawing, discarding, and hand state management.

# =============================================================================
# CONFIGURATION
# =============================================================================
# Hand size default comes from ProgressionConfig.default_hand_size.
# At runtime, set via set_hand_size() which syncs to the Hand UI.

# =============================================================================
# SIGNALS
# =============================================================================

signal initialized
signal tile_ready(tile: Tile)

# =============================================================================
# STATE
# =============================================================================

var hand_size: int = 10
var discard_pile: Array[Tile] = []

# =============================================================================
# SCENE REFERENCES (resolved at runtime)
# =============================================================================

var _hand_ui: Node = null  # Hand component (typed at runtime)
var _is_initialized: bool = false


## Returns true if HandManager has valid references to the current scene.
func is_initialized() -> bool:
	if _is_initialized and not is_instance_valid(_hand_ui):
		_is_initialized = false
	return _is_initialized


func _ready() -> void:
	print("[HandManager] Ready")


# =============================================================================
# PUBLIC API: TILE DRAWING
# =============================================================================

## Draws a specific number of tiles from the bag into the hand.
func draw_tiles(count: int) -> int:
	if not _ensure_initialized():
		return 0

	var drawn: int = 0
	var drawn_tiles: Array[Tile] = []

	for i in count:
		if _hand_ui.is_full():
			print("[HandManager] Hand is full")
			break

		var tile: Tile = TileBag.draw_tile()
		if tile == null:
			print("[HandManager] Bag is empty")
			EventBus.bag_empty.emit()
			break

		_hand_ui.add_tile(tile)
		tile_ready.emit(tile)
		drawn_tiles.append(tile)
		drawn += 1

	if drawn > 0:
		EventBus.hand_count_changed.emit(_hand_ui.get_tile_count())
		EventBus.bag_count_changed.emit(TileBag.tiles_remaining())
		print("[HandManager] Drew %d tile(s) | Hand: %d | Bag: %d" % [
			drawn, get_hand_size(), TileBag.tiles_remaining()
		])

		TileAnimator.animate_draw_batch(drawn_tiles)

	return drawn


## Refills hand to the configured hand size.
func refill_hand() -> int:
	if not _ensure_initialized():
		return 0

	var needed: int = hand_size - get_hand_size()
	if needed <= 0:
		return 0

	var drawn: int = draw_tiles(needed)

	if drawn > 0:
		EventBus.hand_refilled.emit(drawn)

	return drawn


# =============================================================================
# PUBLIC API: DISCARD
# =============================================================================

## Discards a tile from hand to the discard pile.
func discard_tile(tile: Tile) -> bool:
	if not _ensure_initialized():
		return false

	if tile.location != Tile.TileLocation.IN_HAND:
		push_warning("[HandManager] Cannot discard tile not in hand")
		return false

	_hand_ui.remove_tile(tile)
	tile.move_to_discard()  # Atomic state update
	discard_pile.append(tile)

	EventBus.tile_discarded.emit(tile)
	EventBus.discard_count_changed.emit(discard_pile.size())
	EventBus.hand_count_changed.emit(_hand_ui.get_tile_count())

	print("[HandManager] Discarded tile: %s | Discard pile: %d" % [tile.letter, discard_pile.size()])
	return true


## Discards all currently selected tiles.
func discard_selected() -> int:
	if not _ensure_initialized():
		return 0

	var selected: Array[Tile] = _hand_ui.get_selected_tiles()
	var discarded: int = 0

	for tile in selected:
		if discard_tile(tile):
			discarded += 1

	return discarded


## Returns the discard pile contents.
func get_discard_pile() -> Array[Tile]:
	return discard_pile.duplicate()


## Gets the discard pile size.
func get_discard_count() -> int:
	return discard_pile.size()


## Clears the discard pile and returns its contents. Called during round reset.
func clear_discard_pile() -> Array[Tile]:
	var tiles: Array[Tile] = discard_pile.duplicate()
	discard_pile.clear()
	EventBus.discard_count_changed.emit(0)
	EventBus.discard_pile_changed.emit([])
	return tiles


# =============================================================================
# PUBLIC API: QUERIES
# =============================================================================

## Returns current hand size.
func get_hand_size() -> int:
	if _hand_ui == null:
		return 0
	return _hand_ui.get_tile_count()


## Returns true if hand is empty.
func is_hand_empty() -> bool:
	return get_hand_size() == 0


## Returns true if hand is at max capacity.
func is_hand_full() -> bool:
	if _hand_ui == null:
		return false
	return _hand_ui.is_full()


## Sets the target hand size for refilling. Syncs to Hand UI.
func set_hand_size(size: int) -> void:
	hand_size = maxi(size, 1)
	if _hand_ui and is_instance_valid(_hand_ui):
		_hand_ui.max_hand_size = hand_size


# =============================================================================
# INITIALIZATION
# =============================================================================

## Sets references from Main scene. Only initialization path.
func set_references(hand_ui: Node) -> void:
	_hand_ui = hand_ui
	_hand_ui.max_hand_size = hand_size
	_is_initialized = true
	initialized.emit()
	print("[HandManager] Initialized via set_references()")


func _ensure_initialized() -> bool:
	if _is_initialized and is_instance_valid(_hand_ui):
		return true
	push_warning("[HandManager] Not initialized - call set_references() first")
	return false
