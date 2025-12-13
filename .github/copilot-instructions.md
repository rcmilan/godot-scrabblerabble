The repository is a Godot 4 project implementing a Scrabble-like word game (Wordatro).

Quick context & goals
- Primary runtime: Godot 4 (scripts use Node2D, Sprite2D, @onready). Open the project in the Godot editor and run the main scene `res://scenes/main/Main.tscn` to reproduce behavior.
- Purpose of this file: give AI coding agents the essential, project-specific knowledge to make productive edits quickly.

Core architecture (high level)
- Autoload singletons: `autoload/event_bus.gd`, `autoload/game_manager.gd`, `autoload/tile_bag.gd`, `autoload/debug_manager.gd`. Use `EventBus` signals to decouple subsystems (example signals: `tile_placed`, `turn_started`, `tiles_drawn`, `score_updated`, `hand_tile_selected`).
- Data models live under `scripts/core/`:
  - `tile_model.gd` (class_name TileModel) — tile data object used across UI and logic.
  - `board_model.gd` — 11×11 grid (not 15×15), `place_tile()` and `get_grid_state()` are authoritative board state.
  - `word_checker.gd` — wraps the dictionary loader and exposes `is_valid_word()`. Must be added as child node so `_ready()` loads dictionary.
- Board scene architecture (IMPORTANT):
  - `scenes/board/Board.tscn` + `board.gd` — owns a BoardModel instance and delegates all operations.
  - `board.gd` methods: `place_tile()`, `remove_temp_tile()`, `get_temp_positions()`, `get_combined_grid_view()`, `commit_temp_tiles()`, etc.
  - Both Main.tscn and Debug.tscn use the same Board scene — NO separate BoardModel instantiation.
- Game logic under `scripts/logic/`:
  - `round_manager.gd` — round lifecycle, plays per round, win/loss conditions.
  - `word_finder.gd` — scans grid rows/columns and returns found words with start/end positions.
  - `scoring.gd` — composes scoring via registered FuncRef rules; basic rule sums tile values.

Scene architecture & separation of concerns
- **Main.tscn** (`scenes/main/Main.tscn` + `main.gd`) — production gameplay scene
  - Includes: Board, BoardView, Hand, MainHUD
  - Full game logic: tile placement, validation, scoring, discard, play/evaluate
  - Compatible with DebugOverlay (F12 toggle) via shared method signatures
- **Debug.tscn** (`scenes/debug/Debug.tscn` + `word_test.gd`) — development/testing harness
  - Same components as Main but with additional debug UI elements
  - Used for testing game mechanics without running full game loop
  - Run this scene during development (set as main scene in project.godot)
- **Shared components** (scene-agnostic design):
  - `MainHUD.tscn` — production UI (Plays, Score, Target, Rack, Hand counters, Play/Discard buttons)
  - `DebugOverlay.tscn` — F12-toggleable debug tools (Check Word, Remove All, Redraw Hand, Print Rack)
  - `Hand.tscn` — player's drawn tiles, works in both scenes
  - `Board.tscn` + `BoardView.tscn` — data model + visual grid, shared by both scenes

Debug system architecture
- **DebugManager** autoload (`autoload/debug_manager.gd`):
  - F12 or tilde (~) toggles DebugOverlay visibility
  - Auto-instantiates in debug builds (OS.is_debug_build())
  - Persists across scene changes (added to root)
- **DebugOverlay** (`scenes/ui/DebugOverlay.tscn` + `debug_overlay.gd`):
  - Layer 100 (always on top), visible=false by default
  - Buttons call methods on current scene: `validate_word()`, `_on_remove_all_pressed()`, `_on_redraw_hand_pressed()`, `_on_print_rack_pressed()`
  - Both Main and Debug scenes implement these methods for compatibility
- **MainHUD** (`scenes/ui/MainHUD.tscn` + `main_hud.gd`):
  - Layer 0 (production UI)
  - Scene-agnostic: finds RoundManager via `_find_round_manager()` in WordTest or GameManager
  - Handles Play/Discard buttons, displays game state counters

Key patterns & conventions (concrete examples)
- Signal-first communication: components rarely call each other directly; instead emit/listen via `EventBus`.
  - Example: Tiles emit `EventBus.hand_tile_selected` when clicked, Main/Debug scenes listen and update `selected_hand_tile`
  - Example: `EventBus.score_updated` emitted on play completion, MainHUD listens and updates display
  - Example: `EventBus.discard_count_changed` emitted by Hand, MainHUD updates discard counter
- Entity encapsulation: each component manages its own state and operations
  - Board.gd owns BoardModel and delegates all board operations
  - Hand.gd manages tile collection, discard logic, and refill behavior
  - Tile.gd manages visual state (selected, temp_used) and emits selection signals
- Preload/instance model: many systems use `preload("res://...").new()` and `add_child()` for helper objects.
  - IMPORTANT: Components like WordChecker, Scoring, RoundManager must be added as children so their `_ready()` methods run
  - Example: `word_checker = WordCheckerClass.new(); add_child(word_checker)` ensures dictionary loads
- Data file: dictionary is `res://data/english_words.txt`. `scripts/util/dictionary_loader.gd` loads it into a Dictionary (hash) for O(1) lookups. Keep this path and loader usage when changing validation logic.
- Visual/scene conventions: scene files live under `scenes/` and are instantiated by scripts (e.g., `Tile.tscn` used by `Hand`). When editing UI, prefer modifying the scene resource and keep script API stable (`set_tile_data`, selection signals).

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

Game configuration & constants
- See `.github/game-configuration.md` for canonical values:
  - Board size: 11×11 cells (not 15×15)
  - Cell size: 48px
  - Window size: 1536×864px
  - Hand size: 10 tiles
  - Plays per round: Currently 10 (TODO: change to 3)
  - Refill behavior: Currently refills to max (TODO: change to fixed 3 tiles)

Development workflow
- Main scene for development: `scenes/debug/Debug.tscn` (set in project.godot)
- Production scene: `scenes/main/Main.tscn` (fully functional but not set as main)
- F12 enables debug overlay in both scenes for testing
- No automated tests — run scenes in Godot editor to verify behavior

If this looks correct I will add or merge this file into `.github/copilot-instructions.md`. Ask for clarifications or point me at any extra project docs you want merged.
