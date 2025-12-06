extends HBoxContainer

# Hand: renders the player's current hand of tiles and handles selection.
# Uses HBoxContainer for automatic horizontal layout of Button tiles.

const HAND_SIZE: int = 10
var TileScene = preload("res://scenes/tile/Tile.tscn")

var _tiles_nodes: Array = [] # nodes (Tile instances)
var _tile_models: Array = [] # TileModel objects backing the hand

func _ready():
	print("[hand] HBoxContainer ready")
	# Request initial hand from TileBag (if available)
	if TileBag:
		draw_new_hand()

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

func clear_hand():
	for n in _tiles_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_tiles_nodes.clear()
	_tile_models.clear()

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
		return true
	return false

func _on_tile_selected(tile_node):
	# Tile already emits to EventBus directly in tile.gd select() method
	# This handler is kept for potential future Hand-specific logic
	pass
