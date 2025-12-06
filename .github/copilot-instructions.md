The repository is a Godot 4 project implementing a Scrabble-like word game (Wordatro).

Quick context & goals
- Primary runtime: Godot 4 (scripts use Node2D, Sprite2D, @onready). Open the project in the Godot editor and run the main scene `res://scenes/main/Main.tscn` to reproduce behavior.
- Purpose of this file: give AI coding agents the essential, project-specific knowledge to make productive edits quickly.

Core architecture (high level)
- Autoload singletons: `autoload/event_bus.gd`, `autoload/game_manager.gd`, `autoload/tile_bag.gd`. Use `EventBus` signals to decouple subsystems (example signals: `tile_placed`, `turn_started`, `tiles_drawn`, `score_updated`).
- Data models live under `scripts/core/`:
  - `tile_model.gd` (class_name TileModel) — tile data object used across UI and logic.
  - `board_model.gd` — 15x15 grid, `place_tile()` and `get_grid_state()` are authoritative board state.
  - `word_checker.gd` — wraps the dictionary loader and exposes `is_valid_word()`.
- Game logic under `scripts/logic/`:
  - `turn_manager.gd` — turn lifecycle and counters.
  - `word_finder.gd` — scans grid rows/columns and returns found words with start/end positions.
  - `scoring.gd` — composes scoring via registered FuncRef rules; basic rule sums tile values.

Key patterns & conventions (concrete examples)
- Signal-first communication: components rarely call each other directly; instead emit/listen via `EventBus`.
  - Example: `GameManager` connects to `EventBus.tile_placed` and updates `BoardModel` and score.
  - Example: `Rack` connects to `TileBag.tiles_drawn` to instantiate tile scenes.
- Preload/instance model: many systems use `preload("res://...").new()` to create helper objects (see `Main.gd` and `scoring.gd`). Preserve this pattern when adding new helper objects.
- Data file: dictionary is `res://data/english_words.txt`. `scripts/util/dictionary_loader.gd` loads it into a Dictionary (hash) for O(1) lookups. Keep this path and loader usage when changing validation logic.
- Visual/scene conventions: scene files live under `scenes/` and are instantiated by scripts (e.g., `Tile.tscn` used by `Rack`). When editing UI, prefer modifying the scene resource and keep script API stable (`set_tile_data`, selection signals).

Important extension points for AI changes
- To add scoring features, register a new rule via `Scoring._register_rule(FuncRef)`; follow `_calculate_basic_word_score` shape.
- To modify word validation, update `scripts/core/word_checker.gd` or change `dictionary_loader.gd` (keep `DICTIONARY_PATH` constant).
- To add tile behaviors or special tiles, extend `TileModel` (it uses `class_name TileModel`) and update `BoardModel.place_tile()` checks.

Developer workflows & debugging tips
- Run and debug in Godot editor (Godot 4). There are no automated tests in the repo — run scenes to reproduce behavior.
- Quick checks when changing logic:
  - Verify EventBus signal names (see `autoload/event_bus.gd`) and update any connect calls.
  - If you change resource paths, use the Godot editor's FileSystem to ensure files are imported correctly.

Files to inspect for context (examples)
- `autoload/event_bus.gd` — central signals.
- `autoload/game_manager.gd`, `scenes/main/Main.tscn` — top-level orchestration.
- `scripts/core/board_model.gd`, `scripts/core/tile_model.gd` — canonical data structures.
- `scripts/logic/scoring.gd`, `scripts/logic/word_finder.gd` — scoring and word discovery patterns.
- `scripts/util/dictionary_loader.gd`, `data/english_words.txt` — dictionary and word validation.

Agent rules & expectations (concise)
- Preserve EventBus names and preloads; changing them requires repo-wide updates.
- Keep changes small and testable: modify one system at a time (e.g., update scoring rules but keep `evaluate_board()` contract the same).
- When adding public functions to core models, maintain backward-compatible signatures (BoardModel methods are used by multiple scripts).

What I couldn't infer (ask the user)
- Which scene is configured as the project root in Godot (I assume `scenes/main/Main.tscn`).
- Any CI or platform-specific run commands (none found in repo). If you have a preferred Godot CLI or CI config, tell me and I'll include it.

If this looks correct I will add or merge this file into `.github/copilot-instructions.md`. Ask for clarifications or point me at any extra project docs you want merged.
