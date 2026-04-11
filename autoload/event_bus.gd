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

## Emitted when a boss round begins (carries the active boss reference).
signal boss_activated(boss: Boss)

## Emitted when a play is completed (tiles committed).
signal play_completed(plays_remaining: int)

# =============================================================================
# PLAY EVENTS
# =============================================================================

## Emitted when tiles are locked/played (made permanent).
signal tiles_played(tiles: Array[Tile], words: Array)

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
# MODIFIER EVENTS
# =============================================================================

## Emitted when a modifier is applied to a tile.
signal modifier_applied(tile: Tile, modifier: ModifierInstance)

## Emitted when a consumable modifier is consumed after a play.
signal modifier_consumed(tile: Tile, modifier_type: int)

# =============================================================================
# DRAG EVENTS
# =============================================================================

## Emitted when multi-tile drag starts.
signal multi_drag_started(tiles: Array)

## Emitted when multi-tile drag ends.
signal multi_drag_ended(tiles: Array, success: bool)

# =============================================================================
# RUN EVENTS
# =============================================================================

## Emitted when RunManager has prepared the next round's config.
signal run_round_ready(config: RoundConfig)

## Emitted when a successful round triggers the shop transition.
signal run_shop_requested(round_number: int)

## Emitted when the run ends (win or lose).
signal run_ended(victory: bool, total_score: int)

# =============================================================================
# BOARD EVENTS
# =============================================================================

## Emitted when the board is resized (dimensions or position change).
signal board_resized(board_state: BoardState)
