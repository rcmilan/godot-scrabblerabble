extends Node

## EventBus: Global event bus for decoupled game-wide communication.
## All cross-scene signals are centralized here.
## Systems connect to these signals to react to game events without tight coupling.
##
## Usage:
##   EventBus.tile_placed.connect(_on_tile_placed)
##   EventBus.tile_placed.emit(tile, cell)

# =============================================================================
# TILE LIFECYCLE EVENTS
# =============================================================================

## Emitted when a tile is drawn from the bag into the hand.
signal tile_drawn(tile: Tile)

## Emitted when a tile is placed on a board cell.
signal tile_placed(tile: Tile, cell: BoardCell)

## Emitted when a tile is removed from the board back to hand.
signal tile_removed(tile: Tile, cell: BoardCell)

## Emitted when a tile is sent to the discard pile.
signal tile_discarded(tile: Tile)

# =============================================================================
# HAND EVENTS
# =============================================================================

## Emitted when hand tile count changes.
signal hand_count_changed(count: int)

## Emitted when hand becomes empty.
signal hand_empty()

## Emitted when hand is refilled.
signal hand_refilled(count: int)

# =============================================================================
# BAG/DECK EVENTS
# =============================================================================

## Emitted when bag tile count changes (after draw).
signal bag_count_changed(count: int)

## Emitted when the bag becomes empty.
signal bag_empty()

# =============================================================================
# DISCARD EVENTS
# =============================================================================

## Emitted when discard pile count changes.
signal discard_count_changed(count: int)

## Emitted when discard pile is modified.
signal discard_pile_changed(tiles: Array)

# =============================================================================
# ROUND/TURN EVENTS
# =============================================================================

## Emitted when a new round begins.
signal round_started(round_number: int)

## Emitted when a round ends.
signal round_ended(round_number: int, success: bool)

## Emitted when a player's turn begins (for future multiplayer).
signal turn_started(player_id: int)

## Emitted when a player's turn ends.
signal turn_ended(player_id: int)

## Emitted when a play is completed (tiles committed).
signal play_completed(plays_remaining: int)

# =============================================================================
# WORD EVENTS
# =============================================================================

## Emitted when player submits placed tiles as a word.
signal word_submitted(word: String, tiles: Array)

## Emitted after word validation completes.
signal word_validated(word: String, is_valid: bool)

# =============================================================================
# SCORE EVENTS
# =============================================================================

## Emitted when points are calculated for a word.
signal score_calculated(points: int, breakdown: Dictionary)

## Emitted when total score is updated.
signal score_updated(total_score: int, delta: int)

# =============================================================================
# GAME STATE EVENTS
# =============================================================================

## Emitted when a new game starts.
signal game_started()

## Emitted when the game ends (win or lose).
signal game_ended(victory: bool)

## Emitted when game is won.
signal game_won()

## Emitted when game is lost.
signal game_lost()

## Emitted when game is paused.
signal game_paused()

## Emitted when game is resumed.
signal game_resumed()

# =============================================================================
# UI EVENTS
# =============================================================================

## Emitted to request UI updates.
signal ui_refresh_requested()

## Emitted when a notification should be shown.
signal notification_requested(message: String, type: String)
