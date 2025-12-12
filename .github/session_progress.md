Session progress snapshot
========================
```markdown
Session progress snapshot
========================

Date: 2025-12-12 (Latest Session)

Work completed in this session (major architecture improvements):

**1. Board Architecture Refactoring**
- Centralized BoardModel management inside `scenes/board/board.gd`
- board.gd now owns a BoardModel instance and delegates all operations (place_tile, remove_temp_tile, get_temp_positions, etc.)
- Eliminated duplicate BoardModel instantiation in Main and Debug scenes
- Fixed parameter mismatches: `temporary` (not `is_temp`), `turn_id` (not `turn_number`), `remove_temp_tile()` returns void (not bool)
- Added BoardModel as child node so `_ready()` runs and initializes grid

**2. Debug Overlay System**
- Created DebugManager autoload with F12/tilde toggle
- Split old HUD into MainHUD (production) + DebugOverlay (debug tools)
- DebugOverlay (layer 100): Check Word, Remove All, Redraw Hand, Print Rack buttons
- MainHUD (layer 0): Plays, Score, Target, Rack, Hand, Discards counters + Play/Discard buttons
- F12 toggle works in both Main and Debug scenes

**3. Main Scene Full Implementation**
- Ported complete game logic from word_test.gd to main.gd:
  - RoundManager instantiation and initialization
  - Score tracking with EventBus emission
  - Full discard logic (_on_discard_pressed)
  - Full play/evaluate logic (_on_evaluate_pressed)
  - Tile placement and removal with validation
- Fixed validation logic: proper "any valid + all tiles covered" checking (not just "all ranges valid")
- Added word_checker as child so dictionary loads correctly
- Added debug compatibility methods (validate_word, _on_remove_all_pressed, _on_redraw_hand_pressed, _on_print_rack_pressed)

**4. Signal Architecture & EventBus**
- Tiles emit via EventBus.hand_tile_selected (not direct Hand signal)
- Both Main and Debug connect to EventBus for tile selection
- Consistent signal handling across scenes

**5. UI Positioning & Layout**
- Board: 11×11 cells at 48px = 528×528px
- Centered board in Main.tscn with proper absolute positioning
- Hand positioned below board with 10px gap
- Play/Discard buttons positioned relative to Hand (25px offset left/right)
- Created `.github/game-configuration.md` with canonical dimensions

**6. Code Quality**
- Fixed indentation errors in main.gd
- Verified no legacy Godot 3 code (all using Godot 4 syntax)
- Ensured proper parameter naming consistency across delegation methods

What works now (how to reproduce):
1. Open project in Godot 4 and run `scenes/debug/Debug.tscn` OR `scenes/main/Main.tscn`
2. Both scenes fully functional with complete game logic
3. Click tiles in hand to select, click board to place, right-click board to remove
4. Play button enables when valid words formed, disables after playing
5. Press F12 in either scene to toggle debug overlay
6. Debug overlay: Check Word, Remove All, Redraw Hand, Print Rack all working
7. Discard button: select tile in hand, click Discard, tile returns to bag and draws new one
8. Play button: validates words, calculates score, commits tiles, refills hand, updates round manager

Remaining TODO items (from checklist):
1. **Change refill behavior to 3 tiles** - currently refills to max (10 tiles)
2. **Update round manager for 3-play limit** - currently 10 plays per round
3. **Add consecutive wins counter** - track wins across rounds
4. **Implement full reset on win/loss** - clear board, reset hand, reset counters
5. **Update HUD plays display** - adjust for 3-play limit
6. **Test and adjust UI positioning** - final polish after mechanics complete

Architecture notes for next session:
- Main and Debug scenes now share identical game logic
- Both scenes compatible with DebugOverlay (F12 toggle)
- Board operations centralized in board.gd (single source of truth)
- Components communicate via EventBus signals (scene-agnostic)
- All game logic entities (WordChecker, Scoring, RoundManager) must be added as children so `_ready()` runs

Notes about saving context between sessions:
- This repository is the single-source of truth for resuming work: commit the changes (or create a branch) before switching machines or sharing with the team.
- The chat history is ephemeral; storing the progress inside this file and the repo (commits/branches) is the robust way to preserve session context.

If you want me to apply any of the recommended next steps now (add editable inputs, repo-wide `.empty()` -> `.is_empty()` replacements, or create a branch with fixes), tell me which one and I'll implement it.

```

---

Scoring with tiles — proposed implementation plan
-----------------------------------------------
Goal: Treat tiles as first-class objects with scoring modifiers and implement a turn-aware scoring flow that mirrors Scrabble rules (cell multipliers consumed when first used, words scored when they include at least one tile placed this turn).

Key decisions
- Tile lifecycle: three states — NOT_PLACED, PLACED (this turn), VALIDATED (scored). Track `placement_turn` and `validated_turn` so tiles can be revalidated later if needed.
- Cell multipliers (letter/word) live in BoardModel cell metadata; they are consumed the first time they are applied (classic Scrabble behavior).
- Scoring evaluates all words that include at least one tile placed this turn. Existing tiles contribute face values but do not re-trigger consumed cell multipliers.

Implementation steps (small, reviewable commits)
1) TileModel: extend `scripts/core/tile_model.gd`
  - Add fields: `letter`, `value`, `letter_multiplier`, `word_multiplier`, `temporary_modifiers`, `state`, `placement_turn`, `validated_turn`.
  - Methods: `mark_placed(turn_id)`, `mark_validated(turn_id)`, `reset_validation()`.

2) BoardModel: add `cell_metadata` and helpers
  - `cell_metadata[y][x]` -> {letter_multiplier:1, word_multiplier:1, consumed: false}
  - Helpers: `get_cell_meta(pos)`, `consume_cell_multiplier(pos)`, and keep existing `place_tile(tile, pos, turn_id)` semantics.

3) Scoring: make evaluate_board turn-aware (`placed_positions`, `turn_id`)
  - Use `WordFinder` to find words, then filter to words including at least one newly-placed tile.
  - For each tile in a word compute: effective_letter = tile.value * tile.letter_multiplier * (cell_meta.letter_multiplier if tile.placement_turn == turn_id and not cell_meta.consumed)
  - Accumulate base_sum, aggregate word multipliers (tile.word_multiplier and cell.word_multiplier when applied), multiply at end.
  - After scoring a word, call `consume_cell_multiplier` on cells that contributed so multipliers are single-use.

4) GameManager integration
  - Track `_tiles_placed_positions` (or tile refs) for the current turn.
  - At turn end, call `Scoring.evaluate_board(board.get_grid_state(), _tiles_placed_positions, current_turn)` and then mark `tile.mark_validated(current_turn)` for placed tiles.

5) Tests & debug harness
  - Add `scripts/debug/score_test.gd` that constructs TileModel instances with canonical Scrabble values, sets cell multipliers, places tiles, calls scoring, and prints expected vs actual.
  - Extend the runtime debug UI or the `Debug.tscn` scene to run simple scoring scenarios interactively.

Edge cases & notes
- Blank/wild tiles (value 0) should be supported.
- Moving tiles before validation should reset `placement_turn` appropriately.
- Multi-word plays: sum scores for all words formed that include at least one new tile.
- Provide a non-destructive re-validation mode if you need to preview scoring without consuming multipliers.

Example (Scrabble-like)
- Word: APPLE with base tile values A=1, P=3, P=3, L=1, E=1
- If a double-letter exists under the first P (making that P = 6) and a double-word exists under A (applies to whole word because A was placed this turn), compute per above.

If you'd like, I can implement steps 1–4 now (TileModel, BoardModel cell metadata, scoring update, and a debug test) as a set of small commits. Confirm and I'll start applying patches.
