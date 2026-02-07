extends Node


##This script handles debugging functions and logic
##The current debug system uses a console 
##Debug functionality is centralized here to avoid making main.gd difficult to maintain and contextually sane

# Referencing game systems
var main_scene: Node = null
var tile_scene: PackedScene = preload("res://scenes/tile/Tile.tscn")

# Console callback
var console_print: Callable

func _ready() -> void:
	#Getting main scene reference
	await get_tree().process_frame
	main_scene = get_tree().root.get_node("Main")
	print("[DebugManager] is Ready")
	
#Parse and execute a console command
func execute_command(command: String) -> void:
	var parts = command.split(" ", false)
	if parts.is_empty():
		return
		
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)
	
	match cmd:
		"help":
			cmd_help()
		"close", "exit":
			cmd_close()
		"spawn":
			cmd_spawn(args)
		"clear_board":
			cmd_clear_board()
		"draw":
			cmd_draw(args)
		_:
			log_output("Unknown command: %s (type 'help' for available commands)" % cmd)


#commands


##help
func cmd_help() -> void:
	log_output("Available commands: ")
	log_output("  help - Shows debug helper menu")
	log_output("  close (or exit) - Hide the console")
	log_output("  spawn <letter> [count] - Spawn tile(s) (e.g., 'spawn A' or 'spawn Q 3')")
	log_output("  draw [count] - Draw tile(s) from bag (e.g., 'draw' or 'draw 5')")
	log_output("  clear_board - Remove all tiles from board")

##close console
func cmd_close() -> void:
	# Access the console through the scene tree
	var console = get_tree().root.get_node("Main/DebugConsole")
	if console:
		console.hide_console()
	else:
		log_output("Error: Console not found")
	
##spawn a tile for a specific letter in the hand
func cmd_spawn(args: Array) -> void:
	if args.is_empty():
		log_output("Please give a letter as argument: spawn <letter> [count]")
		return
	
	var letter = args[0].to_upper()
	var count = int(args[1]) if args.size() > 1 else 1
	
	if letter.length() != 1 or not letter.unicode_at(0) >= 65 or not letter.unicode_at(0) <= 90:
		log_output("Error: Must be a valid letter from the English alphabet")
		return
	
	spawn_tile(letter, count)
	
#board clearer
func cmd_clear_board() -> void:
	if main_scene == null:
		log_output("Error: Main scene not found.")
		return

	var board = main_scene.get_node("Board")
	var tiles_cleared = 0

	var hand = main_scene.get_node("Hand")
	for cell in board.get_all_cells():
		if cell.is_occupied() and cell.tile != null:
			var tile: Tile = cell.tile
			tile.detach_from_cell()
			tile.set_locked(false)
			if tile.get_parent():
				tile.get_parent().remove_child(tile)
			hand.add_tile(tile)
			tile.move_to_hand()
			tiles_cleared += 1

	if tiles_cleared > 0:
		EventBus.hand_count_changed.emit(hand.get_tile_count())
	log_output("Cleared %d tile(s) from board" % tiles_cleared)


#creating tile spawning function
func spawn_tile(letter: String, count: int = 1) -> void:
	if main_scene == null:
		log_output("Error: Main scene not found.")
		return

	var letter_lower = letter.to_lower()
	var data_path = "res://Data/TileData/tiles/tile_%s.tres" % letter_lower
	var tile_data = load(data_path)

	if tile_data == null:
		log_output("Error: Failed to load tile data for letter: %s" % letter)
		return

	var hand = main_scene.get_node("Hand")

	for i in count:
		var new_tile = tile_scene.instantiate()
		new_tile.initialize(tile_data)
		hand.add_tile(new_tile)

		# Register tile with the gameplay controller via Main
		main_scene.register_tile(new_tile)

	log_output("Spawned %d x '%s' tile(s)" % [count, letter])

##debug draw command
func cmd_draw(args: Array) -> void:
	var count = int(args[0]) if args.size() > 0 else 1
	
	if count < 1:
		log_output("Error: Count must be at least 1")
		return
	
	HandManager.draw_tiles(count)
	


#logging to console
func log_output(message: String) -> void:
	print("[Debug] %s" % message)
	if console_print.is_valid():
		console_print.call(message)
