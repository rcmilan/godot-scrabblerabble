# Wordatro

A roguelike word game combining Scrabble word-formation mechanics with deck-building progression. Form words on an 8×8 grid board, manage your hand of letter tiles, discard to refresh, and reach target scores within limited plays to advance through increasingly difficult rounds.

**Engine:** Godot 4.5.1 (Mobile renderer)  
**Status:** Phase 15 (UI Polish & Game Feel)

## Play

**Requirements:** Godot 4.5.1 | No external dependencies

**Run:** Open in Godot ? `F5` (or run `res://scenes/Main.tscn`)

**Controls:**
- **Mouse:** Click tiles to select, drag to place, right-click to preview
- **Keyboard:** WASD/Arrows (navigate), Enter (confirm), Q (multi-select toggle), Z (discard), D (debug), ESC (pause)

## Ubiquitous Language

Core game domain concepts:

| Term | Meaning |
|------|---------|
| **Tile** | Letter with point value; lives in Bag, Hand, Board, or Discard |
| **Bag** | Deck of remaining tiles (shuffled at round start) |
| **Hand** | Your 10 available tiles; drag one to board or discard |
| **Board** | 8×8 grid where you form words (horizontal/vertical lines) |
| **Play** | Submitted word using hand tiles (limited to 2 per round) |
| **Word** | Contiguous line of tiles (horizontal or vertical) with score |
| **Score** | Points from words; must reach target to win round |
| **Modifier** | Effect on tile scoring (EXTRA, MULTI, EXPO, RESET, LOCKED) |
| **Quality** | Run-wide effect (time limit, hand size bonus, etc.) |
| **Round** | Single challenge with target score and play limit |
| **Run** | Multi-round game session with increasing difficulty |

## Quick Architecture

**Pattern:** Domain-Driven Design with Composition, EventBus for decoupling, Strategy pattern for animations

**Core Loop:**
1. RunManager initializes game with RoundConfig
2. Player places tiles on board (GameplayController routes through handlers)
3. WordValidator validates formed words and calculates scores
4. GameManager tracks score, plays remaining, victory/defeat
5. TileBag and HandManager manage deck/hand refill
6. TileAnimator orchestrates visual feedback (draw, glide, stomp, spin)
7. On round end: Shop phase with difficulty progression

## Project Structure

```
scenes/          Game scenes & UI components
+-- main.gd      Root scene orchestrator (lifecycle, controllers)
+-- board/       Grid and cell components
+-- tile/        Letter tile component
+-- hand/        Player tile container
+-- ui/          HUD, dialogs, overlays, debug tools

autoload/        Global singleton managers
+-- EventBus     Cross-system signal hub (decoupled communication)
+-- GameManager  Game state & phase machine
+-- TileBag      Deck management (create, shuffle, draw)
+-- HandManager  Draw, discard, refill operations
+-- RunManager   Multi-round progression
+-- TileAnimator Animation coordinator (Strategy pattern)

scripts/
+-- controllers/ GameplayController and handlers (placement, drag, play)
+-- domain/      Game model (Run, RoundConfig, Modifiers, Qualities)
+-- animation/   Animation strategies and executors
+-- logic/       WordValidator, scoring, word finding
+-- input/       Keyboard input constants and cursor positioning
+-- interaction/ Drag state machine utilities
+-- managers/    Local managers (SelectionManager, DragManager)
+-- util/        Utility helpers (SignalTracker)

Data/            Game resources (tiles, distributions, progression)
+-- TileData/    Letter tile definitions
+-- BagDistribution/ Tile pool configurations
+-- Progression/ Difficulty progression configs

Assets/          Visual textures (letter tiles)
```

## Development

### Navigate the Codebase
Every directory contains a **CLAUDE.md** file:
- Directory responsibility and public APIs
- Dependencies and architectural patterns
- Constraints, conventions, and build tasks

**Key docs:**
- [`autoload/CLAUDE.md`](autoload/CLAUDE.md) ? EventBus, managers, signals
- [`scripts/CLAUDE.md`](scripts/CLAUDE.md) ? Handlers, controllers, domain model
- [`scenes/CLAUDE.md`](scenes/CLAUDE.md) ? Scene components and lifecycle

### Add a Feature
1. **Identify the domain responsibility** (modifier? quality? animation?)
2. **Check Design Constraints:** Cyclomatic complexity = 5; use composition if higher
3. **Follow Entity Component System:** Modifiers are composed components on tiles
4. **Spec-Driven:** Spec first, then implement
5. **Log actions:** New features should emit signals or log key operations

### Debug Features
- **Press D:** Toggle debug console
- **Press F1:** Toggle focus cursor/keyboard navigation debug
- **Commands:** `spawn A 3` (add 3 A tiles), `fill` (fill hand), `draw` (draw tile), `help` (list all)
- **Profiling:** Check EventBus signal flow in Output logger

## Directory Reference

| Path | Purpose |
|------|---------|
| `autoload/` | Global managers (EventBus, GameManager, TileBag, RunManager) |
| `scenes/main.gd` | Root scene orchestrator |
| `scenes/board/` | Board grid and cell components |
| `scenes/tile/` | Tile interaction and state |
| `scenes/hand/` | Player hand container |
| `scenes/ui/` | UI overlays (HUD, dialogs, debug) |
| `scripts/controllers/` | GameplayController and handlers |
| `scripts/domain/` | Game model (Run, Qualities, Modifiers) |
| `scripts/animation/` | Animation strategies/executors |
| `scripts/logic/` | WordValidator, scoring |
| `scripts/input/` | Keyboard constants, cursor state |
| `Data/` | Game resources (tiles, distributions) |
| `Assets/` | Textures and visual assets |

See each directory's **CLAUDE.md** for detailed documentation.

## Engineering Principles

1. **Godot-First:** Leverage built-in APIs; scripts for logic, not UI config
2. **Domain-Driven:** Model the game domain first (tiles, words, plays)
3. **Atomic Operations:** All critical actions complete fully or fail cleanly
4. **Signal-Based:** Decouple via EventBus, no direct dependencies
5. **Composition:** Managers own logic; Scenes own presentation
6. **Entity Component System:** Modifiers are composable tile components

## Status & Roadmap

**Current:** Phase 15 - UI Polish & Game Feel
**Completed:** Core gameplay, selection, discard, word validation, scoring, animations, modifiers, qualities, title screen, shop, multi-round runs
**Next:** Mobile controls, cell multipliers, save/load, multiple decks

See [`docs/plans/`](docs/plans/) for design documents.

## Start Playing

1. Run `res://scenes/Main.tscn` in Godot
2. Configure game in RunSetupPopup
3. Place tiles on board to form words
4. Submit plays with "Play" button or Enter key
5. Reach target score to advance rounds
6. Debug: Press D for developer console

**Explore:** Check the debug console for testing commands and game state inspection.
