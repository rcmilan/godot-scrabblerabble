extends Node

# WordFinder: Scans the board to find all horizontal and vertical words.

func find_words(grid: Array) -> Array:
	var found_words = []
	if grid.is_empty() or grid[0].is_empty():
		return found_words

	var height = grid.size()
	var width = grid[0].size()

	# Scan rows for horizontal words
	for y in range(height):
		var current_word = ""
		var start_pos = Vector2i(-1, y)
		for x in range(width):
			var tile = grid[y][x]
			if tile:
				if current_word.is_empty():
					start_pos.x = x
				current_word += tile.letter
			else:
				if current_word.length() > 1:
					found_words.append({"word": current_word, "start": start_pos, "end": Vector2i(x - 1, y)})
				current_word = ""
		if current_word.length() > 1:
			found_words.append({"word": current_word, "start": start_pos, "end": Vector2i(width - 1, y)})

	# Scan columns for vertical words
	for x in range(width):
		var current_word = ""
		var start_pos = Vector2i(x, -1)
		for y in range(height):
			var tile = grid[y][x]
			if tile:
				if current_word.is_empty():
					start_pos.y = y
				current_word += tile.letter
			else:
				if current_word.length() > 1:
					found_words.append({"word": current_word, "start": start_pos, "end": Vector2i(x, y - 1)})
				current_word = ""
		if current_word.length() > 1:
			found_words.append({"word": current_word, "start": start_pos, "end": Vector2i(x, height - 1)})
			
	return found_words
