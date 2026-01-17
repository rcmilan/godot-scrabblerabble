extends Node

## Global event bus for game-wide communication
## All cross-scene signals are defined here
## Other systems connect to these signals to react to game events

# === Tile Lifecycle Events ===
## Emitted when a tile is drawn from the bag
signal tile_drawn(tile: Tile)

## Emitted when a tile is placed on the board
signal tile_placed(tile: Tile, cell: BoardCell)

## Emitted when a tile is removed from the board
signal tile_removed(tile: Tile, cell: BoardCell)

## Emitted when a tile is discarded (sent to discard pile)
signal tile_discarded(tile: Tile)


# === Turn Events ===
## Emitted when a player's turn begins
signal turn_started(player_id: int)

## Emitted when a player's turn ends
signal turn_ended(player_id: int)


# === Word Events ===
## Emitted when player submits their placed tiles as a word
signal word_submitted(word: String, tiles: Array)

## Emitted after word validation completes
signal word_validated(word: String, is_valid: bool)


# === Score Events ===
## Emitted when points are calculated for a word
signal score_calculated(player_id: int, points: int)


# === Game State Events ===
## Emitted when a new game starts
signal game_started()

## Emitted when the game ends
signal game_ended()
