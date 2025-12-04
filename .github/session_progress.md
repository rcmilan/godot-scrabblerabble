Session progress snapshot
========================
```markdown
Session progress snapshot
========================

Date: 2025-11-27

Work completed in this session (safe, minimal changes):
- Added a non-destructive debug prototype: `scenes/debug/Debug.tscn` and `scripts/debug/word_test.gd` exposing console helpers `validate_word`, `place_tile_for_test`, and `print_board`.
- Created a small runtime debug UI (CanvasLayer -> Panel -> VBox -> Buttons) so the helpers can be invoked by clicking when the Editor Evaluator is unavailable.
- Fixed several Godot 4 API mismatches that caused runtime/parser errors:
  - Replaced `String.empty()` with `String.is_empty()` in `scripts/debug/word_test.gd`.
  - Replaced `Array.empty()` with `Array.is_empty()` in `autoload/tile_bag.gd`.
  - Updated Control property usage for Godot 4 (`rect_position`/`rect_size` -> `position`/`size`) used in the runtime UI.
- Made small, defensive scoring/FuncRef changes to avoid engine-specific `funcref()` typing issues (see `scripts/logic/scoring.gd`).
- Created/maintained safe backups when the `project.godot` file was edited during import troubleshooting.

What works now (how to reproduce quickly):
1. Open the project in Godot 4 and run `scenes/debug/Debug.tscn`.
2. Use the on-screen debug panel (top-left) to validate words, place a tile at (7,7), and print the board.
3. Debug prints appear in the Output/Debugger console (example: `[word_test] Ready. Dictionary size: 5`).

Remaining warnings & recommended cleanup (options for next session):
1. Repository hygiene (low-risk): replace any remaining `.empty()` usages with `.is_empty()` and normalize `.gd` indentation to 4 spaces; add an `.editorconfig`.
2. Iterative repair (medium effort): address remaining warnings (unused parameters/variables, shadowed names like `owner`, duplicate local names like `TileModel`) — either rename or prefix unused ones with `_`.
3. Make the debug UI persistent in `scenes/debug/Debug.tscn` (so it can be styled and edited in the Editor), or add input fields so you can type arbitrary words/coords from the running UI.
4. (Optional) Create a small branch/PR with all low-risk fixes so they can be reviewed before merging into the main team repo.

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
