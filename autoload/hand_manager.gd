extends Node

## HandManager: Manages the player's hand of tiles.
## Coordinates between TileBag, Hand UI, and Main scene.
## Handles drawing, discarding, and hand state management.

# =============================================================================
# CONFIGURATION
# =============================================================================

const DEFAULT_HAND_SIZE: int = 10
const MAX_HAND_SIZE: int = 15

# =============================================================================
# STATE
# =============================================================================

var hand_size: int = DEFAULT_HAND_SIZE
var discard_pile: Array[Tile] = []

# =============================================================================
# SCENE REFERENCES (resolved at runtime)
# =============================================================================

var _hand_ui: Node = null  # Hand component (typed at runtime)
var _main_scene: Node = null  # Main scene (typed at runtime)
var _is_initialized: bool = false

signal initialized


func _ready() -> void:
	# Wait for scene tree to be ready, then initialize
	get_tree().process_frame.connect(_on_first_frame, CONNECT_ONE_SHOT)


func _on_first_frame() -> void:
	# Try to initialize, retry if Main scene isn't ready yet
	_try_initialize()


# =============================================================================
# PUBLIC API: TILE DRAWING
# =============================================================================

## Draws a specific number of tiles from the bag into the hand.
func draw_tiles(count: int) -> int:
	if not _ensure_initialized():
		return 0

	var drawn: int = 0

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
		_connect_tile_signals(tile)
		drawn += 1

	if drawn > 0:
		EventBus.hand_count_changed.emit(_hand_ui.get_tile_count())
		EventBus.bag_count_changed.emit(TileBag.tiles_remaining())
		print("[HandManager] Drew %d tile(s) | Hand: %d | Bag: %d" % [
			drawn, get_hand_size(), TileBag.tiles_remaining()
		])

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
	tile.location = Tile.TileLocation.IN_DISCARD
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


## Clears the discard pile (for special effects).
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


## Sets the target hand size for refilling.
func set_hand_size(size: int) -> void:
	hand_size = clampi(size, 1, MAX_HAND_SIZE)


# =============================================================================
# PRIVATE: INITIALIZATION
# =============================================================================

func _try_initialize() -> void:
	var root: Node = get_tree().root
	_main_scene = root.get_node_or_null("Main")

	if _main_scene == null:
		# Main scene not ready yet, try again next frame
		get_tree().process_frame.connect(_try_initialize, CONNECT_ONE_SHOT)
		return

	_hand_ui = _main_scene.get_node_or_null("Hand")

	if _hand_ui == null:
		# Hand not ready yet, try again next frame
		get_tree().process_frame.connect(_try_initialize, CONNECT_ONE_SHOT)
		return

	_is_initialized = true
	initialized.emit()
	print("[HandManager] Initialized")


func _ensure_initialized() -> bool:
	if not _is_initialized:
		push_error("[HandManager] Not initialized - call after scene is ready")
		return false
	return true


func _connect_tile_signals(tile: Tile) -> void:
	if _main_scene == null:
		return

	# Connect tile signals to main scene handlers
	if not tile.tile_selected.is_connected(_main_scene._on_tile_selected):
		tile.tile_selected.connect(_main_scene._on_tile_selected)

	if not tile.tile_right_clicked.is_connected(_main_scene._on_tile_right_clicked):
		tile.tile_right_clicked.connect(_main_scene._on_tile_right_clicked)

	if not tile.tile_drag_started.is_connected(_main_scene._on_tile_drag_started):
		tile.tile_drag_started.connect(_main_scene._on_tile_drag_started)

	if not tile.tile_drag_ended.is_connected(_main_scene._on_tile_drag_ended):
		tile.tile_drag_ended.connect(_main_scene._on_tile_drag_ended)
