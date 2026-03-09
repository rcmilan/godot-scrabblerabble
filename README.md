# Wordatro

A roguelike word game combining Scrabble word-formation mechanics with deck-building progression. Form words on an 8×8 grid board, manage your hand of letter tiles, discard to refresh, and reach target scores within limited plays to advance through increasingly difficult rounds.

**Engine:** Godot 4.5.1 (Mobile renderer)
**Status:** Phase 16 (Input & Keyboard Polish)

## Quick Start

**Requirements:** Godot 4.5.1 | No external dependencies

**Run:** Open in Godot → `F5` (or run `res://scenes/Main.tscn`)

**Controls:**

| Action | Mouse | Keyboard | Gamepad |
|--------|-------|----------|---------|
| Navigate | Hover | WASD / Arrows | D-Pad |
| Select / Place | Click | Space | A |
| Multi-select toggle | — | Q | RB |
| Discard | — | X | LB |
| Play hand | — | Enter | Y |
| Draw tiles | — | L | X |
| Switch zone | — | Tab | LT/RT |
| Pause | — | ESC | — |
| Debug console | — | D | — |

## Ubiquitous Language

| Term | Meaning |
|------|---------|
| **Bag** | Deck of remaining tiles (shuffled at round start) |
| **Board** | 8×8 grid where you form words (horizontal/vertical lines) |
| **BoardState** | Immutable value object representing the board's tile layout |
| **DropDecision** | Result of a drop resolution: PLACE, SWAP, or REJECT |
| **Hand** | Your 10 available tiles; place on board or discard |
| **InteractionState** | Composite of SelectionState and DragSnapshot |
| **Modifier** | Effect on tile scoring (EXTRA, MULTI, EXPO, RESET, LOCKED) |
| **ModifierCollection** | Immutable collection of modifiers on a tile |
| **Play** | Submitted word using hand tiles (limited per round) |
| **PlayResult** | Immutable result of play validation (valid words, score) |
| **Quality** | Run-wide effect (time limit, hand size bonus, etc.) |
| **Round** | Single challenge with target score and play limit |
| **RoundConfig** | Immutable parameters for a single round |
| **Run** | Multi-round game session with increasing difficulty |
| **RunState** | Mutable aggregate tracking the entire run across rounds |
| **Score** | Points from words; must reach target to win round |
| **SelectionState** | Immutable value object for single/multi-select mode |
| **Tile** | Letter with point value; lives in Bag, Hand, Board, or Discard |
| **TileHighlightState** | Unified cursor hover and selection visual priority |
| **TileState** | Immutable value object representing a tile's domain state |
| **Word** | Contiguous line of tiles (horizontal or vertical) with score |
| **WordResult** | Immutable value object representing a scored word |

## Architecture

**Patterns:** Domain-Driven Design, Composition over inheritance, EventBus for decoupling, InputRouter for keyboard dispatch, Strategy pattern for animations

**Core Loop:**
1. RunManager initializes game with RoundConfig
2. Player places tiles on board (GameplayController routes through handlers)
3. WordValidator validates formed words and calculates scores
4. GameManager tracks score, plays remaining, victory/defeat
5. TileBag and HandManager manage deck/hand refill
6. TileAnimator orchestrates visual feedback (draw, glide, stomp, spin)
7. On round end: Shop phase with difficulty progression

**GameplayController handlers:**
PlacementExecutor, DropExecutor, PlayExecutor, CellHoverHandler, WordHighlightHandler, DiscardHandler, InputRouter

## Project Structure

```
scenes/          Game scenes & UI components
├── main.gd      Root scene orchestrator (lifecycle, controllers)
├── board/       Grid and cell components
├── tile/        Letter tile component
├── hand/        Player tile container
├── ui/          HUD, dialogs, overlays, keyboard hints
├── debug/       Debug console and manager
├── shop/        Shop overlay and round config
└── title_screen/ Title screen and run setup

autoload/        Global singleton managers (6)
├── EventBus     Cross-system signal hub
├── GameManager  Game state & phase machine
├── TileBag      Deck management (create, shuffle, draw)
├── HandManager  Draw, discard, refill operations
├── RunManager   Multi-round progression
└── TileAnimator Animation coordinator (Strategy pattern)

scripts/         Game logic and domain model
├── controllers/ GameplayController, handlers, InputRouter
├── domain/      Immutable value objects (20 domain types)
├── animation/   Animation strategies and executors
├── logic/       WordValidator, scoring, word finding
├── input/       KeyAction constants, CursorState, ModalInputGuard
├── interaction/ Drag state machine utilities
├── managers/    Local managers (SelectionManager, DragManager)
└── util/        Utility helpers (SignalTracker)

Data/            Game resources (tiles, distributions, progression)
Assets/          Visual textures (letter tiles)
```

See each directory's **CLAUDE.md** for detailed documentation.

## Engineering Principles

1. **Godot-First:** Leverage built-in APIs; scripts for logic, not UI config
2. **Domain-Driven:** Model the game domain with immutable value objects first
3. **Atomic Operations:** All critical actions complete fully or fail cleanly
4. **Signal-Based:** Decouple via EventBus; no direct cross-system dependencies
5. **Composition:** Managers own logic, Scenes own presentation, handlers own behavior
6. **Entity Component System:** Modifiers are composable tile components
7. **Input Routing:** InputRouter maps actions to handler callables; keeps input logic declarative

## Development

### Navigate the Codebase
Every directory contains a **CLAUDE.md** file with responsibility, APIs, dependencies, and constraints.

**Key docs:**
- [`autoload/CLAUDE.md`](autoload/CLAUDE.md) — EventBus, managers, signals
- [`scripts/CLAUDE.md`](scripts/CLAUDE.md) — Handlers, controllers, domain model
- [`scenes/CLAUDE.md`](scenes/CLAUDE.md) — Scene components and lifecycle

### Add a Feature
1. **Identify the domain responsibility** (modifier? quality? animation?)
2. **Check Design Constraints:** Cyclomatic complexity ≤ 5; use composition if higher
3. **Follow Entity Component System:** Modifiers are composed components on tiles
4. **Spec-Driven:** Spec first, then implement
5. **Log actions:** New features should emit signals or log key operations

### Debug Features
- **Press D:** Toggle debug console
- **Commands:** `spawn A 3` (add 3 A tiles), `draw` (draw tile), `clear_board` (remove non-locked tiles), `help` (list all)
- **Profiling:** Check EventBus signal flow in Output logger

## Status & Roadmap

**Current:** Phase 16 — Input & Keyboard Polish
**Completed:** Core gameplay, selection, discard, word validation, scoring, animations, modifiers, qualities, title screen, shop, multi-round runs, keyboard navigation, input routing
**Next:** Mobile controls, cell multipliers, save/load, multiple decks

See [`docs/plans/`](docs/plans/) for design documents.
