extends Node

##manages hand logic and functionalities

var hand_ui: Control = null
var main_scene: Node = null

func _ready() -> void:
	# Get scene references from tree after game is ready
	await get_tree().process_frame
	main_scene = get_tree().root.get_node("Main")
	hand_ui = main_scene.get_node("Hand")
	print("[HandManager] is ready")
	

##Draw tiles
func draw_tiles(count: int) -> void:
	if hand_ui == null:
		push_error("[HandManger] Hand UI not found")
		return
	
	var drawn = 0
	
	for i in count:
		#draw from bag
		var tile = TileBag.draw_tile()
		if tile == null:
			print("[HandManager] bag is empty")
			break
		
		#add to hand
		hand_ui.add_tile(tile)
		tile.location = Tile.TileLocation.IN_HAND
		
		#call connection function 
		_connect_tile_signals(tile)
		
		drawn += 1
	
	print("[HandManager Drew %d Tile(s). Hand: %d | Bag: %d]" % [drawn, get_hand_size(), TileBag.tiles_remaining()])
	

#connection function
func _connect_tile_signals(tile: Tile) -> void:
	if main_scene == null:
		return
	tile.tile_selected.connect(main_scene._on_tile_selected)
	tile.tile_right_clicked.connect(main_scene._on_tile_right_clicked)
	tile.tile_drag_ended.connect(main_scene._on_tile_drag_ended)
	
#get current hand size for UI info
func get_hand_size() -> int:
	if hand_ui == null:
		return 0
	return hand_ui.get_tile_count()
	
#Fill hand
func refill_hand() -> void:
	var needed = 10 - get_hand_size()
	if needed > 0:
		draw_tiles(needed)
