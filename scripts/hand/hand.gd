extends HBoxContainer

# Hand: renders the player's current hand of tiles and handles selection.
# Uses HBoxContainer for automatic horizontal layout of Button tiles.

signal hand_count_changed(current, max_size)

const HAND_SIZE: int = 10
var TileScene = preload("res://scenes/tile/Tile.tscn")
var _discard_count: int = 0  # Total discards this session

var _tiles_nodes: Array = [] # nodes (Tile instances)
var _tile_models: Array = [] # TileModel objects backing the hand

func _ready():
	print("[hand] HBoxContainer ready")
	# Connect to EventBus for right-click discard
	if EventBus and EventBus.has_signal("hand_tile_right_clicked"):
		EventBus.connect("hand_tile_right_clicked", Callable(self, "_on_tile_right_clicked"))
	# Request initial hand from TileBag (if available)
	if TileBag:
		draw_new_hand()

func _on_tile_right_clicked(tile_node):
	# Handle right-click on a hand tile to discard it
	print("[hand] Tile right-clicked for discard")
	discard_tiles([tile_node])

func draw_new_hand():
	clear_hand()
	if not TileBag:
		print("[hand] TileBag not available")
		return
	var drawn = TileBag.draw_tiles(HAND_SIZE)
	_tile_models = drawn
	print("[hand] Drawing ", drawn.size(), " tiles")
	for i in range(drawn.size()):
		var m = drawn[i]
		var tnode = TileScene.instantiate()
		if tnode and tnode.has_method("set_tile_data"):
			# connect tile selection
			if not tnode.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
				tnode.connect("tile_selected", Callable(self, "_on_tile_selected"))
			add_child(tnode)
			tnode.set_tile_data(m)  # Call after add_child so _ready runs first
			_tiles_nodes.append(tnode)
			print("[hand] Added tile ", i, " letter: ", m.letter)
	print("[hand] Drew ", _tiles_nodes.size(), " tiles total")
	_update_hand_count_display()

func clear_hand():
	for n in _tiles_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_tiles_nodes.clear()
	_tile_models.clear()
	_update_hand_count_display()

func redraw_hand_returning():
	# Return current tile models to TileBag, then draw a fresh hand
	if TileBag and _tile_models.size() > 0:
		TileBag.return_tiles(_tile_models)
	clear_hand()
	draw_new_hand()

func remove_one_tile_by_node(node) -> bool:
	# remove the specific tile node from the hand
	if node in _tiles_nodes:
		var idx = _tiles_nodes.find(node)
		_tiles_nodes.remove_at(idx)
		if idx >= 0 and idx < _tile_models.size():
			_tile_models.remove_at(idx)
		if is_instance_valid(node):
			node.queue_free()
		_update_hand_count_display()
		return true
	return false

func refill_hand() -> int:
	# Draw tiles from TileBag to fill hand back to HAND_SIZE.
	# Returns the number of tiles drawn.
	var current_size = _tiles_nodes.size()
	if current_size >= HAND_SIZE:
		print("[hand] Hand is already full (", current_size, "/", HAND_SIZE, ")")
		return 0
	
	var needed = HAND_SIZE - current_size
	if not TileBag:
		print("[hand] TileBag not available for refill")
		return 0
	
	var drawn = TileBag.draw_tiles(needed)
	print("[hand] Refilling hand: need ", needed, ", drew ", drawn.size())
	
	for m in drawn:
		var tnode = TileScene.instantiate()
		if tnode and tnode.has_method("set_tile_data"):
			if not tnode.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
				tnode.connect("tile_selected", Callable(self, "_on_tile_selected"))
			add_child(tnode)
			tnode.set_tile_data(m)
			_tiles_nodes.append(tnode)
			_tile_models.append(m)
	
	print("[hand] Refilled ", drawn.size(), " tiles. Hand now: ", _tiles_nodes.size())
	_update_hand_count_display()
	return drawn.size()

func get_current_hand_size() -> int:
	return _tiles_nodes.size()


func discard_tiles(tile_nodes: Array) -> int:
	# Discard multiple tiles and draw replacements.
	# Returns the number of tiles successfully discarded.
	var discarded_count = 0
	var discarded_models = []
	
	for tile_node in tile_nodes:
		if not tile_node or not tile_node in _tiles_nodes:
			continue
		
		var idx = _tiles_nodes.find(tile_node)
		if idx >= 0 and idx < _tile_models.size():
			var tile_model = _tile_models[idx]
			discarded_models.append(tile_model)
			remove_one_tile_by_node(tile_node)
			discarded_count += 1
	
	# Send all discarded tiles to TileBag discard pile
	if discarded_models.size() > 0 and TileBag and TileBag.has_method("discard_tiles"):
		TileBag.discard_tiles(discarded_models)
		print("[hand] Discarded ", discarded_count, " tile(s)")
		
		# Update discard count and emit signals
		_discard_count += discarded_count
		EventBus.emit_signal("discard_count_changed", _discard_count)
		EventBus.emit_signal("discard_pile_changed", TileBag.get_discarded_tile_count())
		print("[hand] Total discards: ", _discard_count)
	
	# Draw replacement tiles
	if discarded_count > 0 and TileBag and TileBag.has_method("draw_tiles"):
		var drawn_tiles = TileBag.draw_tiles(discarded_count)
		for tile_model in drawn_tiles:
			add_single_tile(tile_model)
		print("[hand] Drew ", drawn_tiles.size(), " replacement tile(s)")
	
	return discarded_count

func add_single_tile(tile_model) -> void:
	# Add a single tile to the hand (used for discards and refills)
	var tnode = TileScene.instantiate()
	if tnode and tnode.has_method("set_tile_data"):
		if not tnode.is_connected("tile_selected", Callable(self, "_on_tile_selected")):
			tnode.connect("tile_selected", Callable(self, "_on_tile_selected"))
		add_child(tnode)
		tnode.set_tile_data(tile_model)
		_tiles_nodes.append(tnode)
		_tile_models.append(tile_model)
		_update_hand_count_display()

func _update_hand_count_display():
	var current = _tiles_nodes.size()
	emit_signal("hand_count_changed", current, HAND_SIZE)

func _on_tile_selected(tile_node):
	# Tile already emits to EventBus directly in tile.gd select() method
	# This handler is kept for potential future Hand-specific logic
	pass
