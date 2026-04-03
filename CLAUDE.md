# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Before Writing Code
- Read all relevant files first. Never edit blind.
- Understand the full requirement before writing anything.

## While Writing Code
- Test after writing. Never leave code untested.
- Fix errors before moving on. Never skip failures.
- Prefer editing over rewriting whole files.
- Simplest working solution. No over-engineering.

## Before Declaring Done
- Run the code one final time to confirm it works.
- Never declare done without a passing test.

## Output
- No sycophantic openers or closing fluff.
- No em dashes, smart quotes, or Unicode. ASCII only.
- Be concise. If unsure, say so. Never guess.

## Override Rule
User instructions always override this file.

## Project Overview

**Wordatro** is a Godot 4.6 word tile game (similar to Scrabble). The game uses a **Domain-Driven Design** architecture with strict separation between domain logic (business rules) and controllers (UI interaction).

## Running and Building

### Prerequisites
- Godot 4.6
- No external dependencies beyond the engine

### Running the Game
Open the project in Godot Editor and press **F5** or click Play. The main scene is configured in `project.godot` under `[application] run/main_scene`.

### Running Tests
No automated test framework is currently integrated. Testing is done manually in the editor.

## Architecture Overview

The codebase is organized into distinct layers with clear responsibilities:

### 1. **Autoload Singletons** (`/autoload`)
Global-scope managers that persist throughout the game lifetime:
- **EventBus**: Centralized event system for decoupled communication between systems
- **GameManager**: Game phase state machine and score tracking
- **RunManager**: Multi-round run flow and shop transitions
- **HandManager**: Hand tile lifecycle management
- **TileBag**: Tile draw pool and deck management
- **TileAnimator**: Coordinates all animation execution
- **KeybindingConfig**: Input key remapping

### 2. **Domain Layer** (`/scripts/domain`)
Pure business logic and immutable value objects. No scene nodes or input handling.

**Key Concepts:**
- **BoardState**: Immutable representation of board tile layout
- **TileState**: Immutable tile properties and modifiers
- **Deck System** (`/decks`): Deck definitions (Standard, Equal, Cursed) and registry
- **Modifiers** (`/modifiers`): Tile effect system with behaviors and qualities
- **Services**: Scoring, word validation, and game rule logic

**Design Pattern:**
- Value objects return new instances rather than mutating state (functional style)
- No Godot node dependencies—can be unit tested independently

### 3. **Controllers** (`/scripts/controllers`)
Thin orchestration layer routing input events and managing UI state.

**Key Classes:**
- **GameplayController**: Main input router and interaction orchestrator
- **PlacementExecutor**: Tile placement/removal logic and cell validation
- **DropExecutor**: Drag-and-drop resolution
- **PlayExecutor**: Play submission, scoring, round end automation
- **CellHoverHandler**: Placement preview and validation feedback
- **WordHighlightHandler**: Real-time word scanning and visual feedback
- **DiscardHandler**: Discard pile interactions
- **MenuController**: Title screen and pause menu routing
- **InputRouter**: Keyboard action dispatch

### 4. **Animation System** (`/scripts/animation`)
Modular animation strategies with pluggable executors.

**Architecture:**
- **TileAnimationStrategy**: Base interface for tile animations
- **AnimationExecutor**: Orchestrates single or batched animations
- **Specific Animations**: DrawTileAnimation, GlideTileAnimation, SpinTileAnimation, StompTileAnimation, ShakeTileAnimation, etc.
- **HandFanLayout**: Procedural hand tile positioning

### 5. **Scenes** (`/scenes`)
Godot scene tree UI hierarchy. Scenes instantiate and wire up controllers and domain logic.

**Structure:**
- `main.tscn`: Main game scene (root)
- `board/`: Board cell grid and tile rendering
- `hand/`: Player hand tile display and drag/drop
- `tile/`: Individual tile visual representation
- `ui/`: HUD, pause menu, dialogs, overlays

## Communication Patterns

### EventBus (Decoupled Communication)
Systems communicate through **EventBus** signals rather than direct references:

```gdscript
# Subscribing to events
EventBus.tile_placed.connect(_on_tile_placed)
EventBus.round_started.connect(_on_round_started)

# Emitting events
EventBus.tile_placed.emit(tile, cell)
```

### Direct Dependency Injection
Controllers receive scene node references (Board, Hand, etc.) via setup methods to enable direct collaboration during tight-coupling scenarios (e.g., GameplayController routing input to PlacementExecutor).

## Key Game Flow

1. **Title Screen** → Configure run settings (deck, difficulty, target score)
2. **Round Start** → Draw initial hand (7 tiles)
3. **Gameplay** → Place tiles, form words, submit plays
4. **Scoring** → Calculate points and check round objectives
5. **Round End** → Success → Shop transition; Failure → Game over
6. **Run End** → Victory/Loss screen

## Development Patterns

### Adding a New Domain Rule
1. Implement logic in `/scripts/domain` (no Godot nodes)
2. Emit events via EventBus when rule changes affect UI
3. Controllers listen to events and update visuals

### Adding a New Animation
1. Extend **TileAnimationStrategy** in new file under `/scripts/animation/{category}/`
2. Implement `get_animation()` method
3. Register in **TileAnimator** autoload
4. Call via `TileAnimator.animate(tile, animation_type)`

### Adding UI Interaction
1. Create handler class in `/scripts/controllers/`
2. Inject dependencies (board, hand, etc.) in setup
3. Listen to input signals and EventBus events
4. Emit signals or call domain services to execute actions

### Input Handling
Input mapping is in `project.godot` under `[input]`. Keybindings are customizable at runtime via **KeybindingConfig**. Use `InputRouter` to dispatch keyboard actions to appropriate handlers.

## Important Notes

- **No Godot Scripts in Domain**: The `/scripts/domain` layer contains zero Godot node dependencies, enabling independent testing and logic verification
- **EventBus is Central**: When unsure how systems should communicate, prefer EventBus signals over direct function calls
- **Immutable Domain Objects**: Domain value objects (BoardState, TileState) should never mutate; return new instances instead
- **DDD Terminology**: "Domain" = game rules; "Controllers" = input/UI logic; "Scenes" = visual hierarchy
- **Scene Tree Structure**: Scenes are organized by feature (board, hand, ui) rather than by architectural layer

## Git Workflow

- **Main branch**: `trunk`
- **Active development**: `spec-kit` (current branch)
- **PR naming**: Descriptive titles with issue numbers (e.g., "DDD refactor: domain layer, controllers, cleanup (#42)")
