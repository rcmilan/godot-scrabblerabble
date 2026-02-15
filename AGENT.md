# Wordatro - Roguelike Word Game

## Overview
A word game combining Scrabble mechanics with roguelike deck-building elements. Players form words on a grid board using letter tiles, earn scores, and progress through rounds.

## Engine
Godot 4.5.1 (Mobile renderer)

## Project Structure
```
Wordatro/
├── autoload/               # Global singleton managers (6 active + 2 demoted to local)
│   ├── event_bus.gd        # Signal hub for decoupled communication
│   ├── game_manager.gd     # Game state & phase management (encapsulated)
│   ├── hand_manager.gd     # Hand operations (draw, discard, refill)
│   ├── tile_bag.gd         # Tile pool (deck) management
│   ├── tile_animator.gd    # Tile animation coordinator (Strategy pattern)
│   ├── run_manager.gd      # Run lifecycle & progression orchestrator
│   ├── managers/
│   │   ├── selection_manager.gd   # [LOCAL NODE] Tile selection state (created by Main)
│   │   └── drag_manager.gd        # [LOCAL NODE] Multi-tile drag coordination
│
├── scenes/                 # Game scenes & components
│   ├── Main.tscn           # Main gameplay scene (root)
│   ├── main.gd             # Main scene orchestrator (lifecycle, controllers)
│   ├── title_screen/       # Title screen and main menu
│   ├── board/              # Grid component for word placement
│   ├── hand/               # Player's tile collection UI
│   ├── tile/               # Individual letter tile component
│   ├── shop/               # Between-round shop and configuration
│   ├── ui/                 # UI overlays, HUD, dialogs, modals
│   └── debug/              # Debug console and utilities
│
├── scripts/                # Game logic and utilities
│   ├── controllers/        # Game behavior coordinators
│   │   ├── gameplay_controller.gd     # Tile interaction coordinator
│   │   ├── tile_placement_handler.gd  # Tile placement logic
│   │   ├── drop_handler.gd            # Drag-and-drop validation
│   │   ├── play_handler.gd            # Play submission & scoring
│   │   └── menu_controller.gd         # Menu navigation
│   ├── animation/          # Tile animation system (Strategy pattern)
│   │   ├── base/           # Abstract animation infrastructure
│   │   ├── draw/           # Draw-from-bag animations
│   │   ├── glide/          # Smooth position transitions
│   │   ├── shake/          # Illegal action feedback
│   │   ├── stomp/          # Play confirmation effect
│   │   ├── spin/           # Spin effect (NEW)
│   │   └── hand/           # Hand tile layout & hover effects
│   ├── domain/             # Game domain model (NEW)
│   │   ├── run.gd          # Run data container
│   │   ├── run_builder.gd  # Run construction and quality system
│   │   ├── run_state.gd    # Run gameplay state tracking
│   │   ├── run_quality.gd  # Quality modifier base class
│   │   ├── round_config.gd # Round configuration (board size, score, etc)
│   │   ├── progression_rules.gd # Progression formula & difficulty
│   │   ├── modifiers/      # Modifier system for qualities
│   │   └── qualities/      # Concrete quality implementations
│   ├── interaction/        # Input event helpers
│   │   └── tile_drag_helper.gd  # Drag calculation utilities
│   └── logic/              # Game logic & algorithms
│       └── word_validator.gd    # Word validation and scoring
│
├── Data/                   # Game data resources
│   ├── BagDistribution/    # Tile pool configurations
│   ├── Progression/        # Game progression configurations
│   └── TileData/           # Letter tile definitions
│
└── Assets/                 # Visual assets
    ├── Tiles/              # Letter textures (letter_A.png - letter_Z.png)
    ├── letter.png          # Generic tile background
    └── blank_tile.png      # Blank/wild tile texture
```

## Core Systems

### Game Flow
1. Game starts at title screen with menu options
2. Player selects "New Game" to start gameplay
3. Game initializes with configured tile distribution
4. Hand is filled from tile bag (10 tiles)
5. Player selects tiles (single or multi-select with Q key)
6. Player places tiles on board to form words
7. Player can discard tiles (Z key or drag to pile)
8. Score is calculated based on letters and multipliers
9. Round ends when target score reached or plays exhausted
10. Shop phase between rounds (upgrades/purchases)
11. Progress through rounds until run victory or game over

### Key Components

| Component | Purpose | Type |
|-----------|---------|------|
| **Main** | Orchestrates round lifecycle, handles pause/shop transitions | Scene Script |
| **GameplayController** | Coordinates all tile interaction, routes input to handlers | Local Node |
| **Board** | Dynamic grid (8×8), cell management, hover detection | Scene |
| **Tile** | Letter tiles with click/drag interaction and cell binding | Scene |
| **Hand** | Tile container UI, displays and manages available tiles | Scene |
| **SelectionManager** | Single source of truth for selection state (SINGLE/MULTI mode) | Local Node |
| **DragManager** | Coordinates multi-tile drag operations | Local Node |
| **EventBus** | Global signal hub for decoupled communication | Autoload |
| **GameManager** | Game state, phases, score tracking (encapsulated behind getters) | Autoload |
| **TileBag** | Tile pool (deck) creation, shuffling, drawing | Autoload |
| **HandManager** | Hand operations: draw, discard, refill | Autoload |
| **TileAnimator** | Animation coordination (Strategy pattern) | Autoload |
| **RunManager** | Run lifecycle, progression rules, quality system | Autoload |
| **WordValidator** | Word validation and score calculation | RefCounted Service |
| **TitleScreen** | Main menu with navigation, run setup, options | Scene |
| **ShopOverlay** | Between-round shop with round summary and debug config | Scene |

### State Machines

#### GamePhase (GameManager)
```
SETUP → PLAYING ⟷ PAUSED
           ↓
      ROUND_END → GAME_OVER
           ↓          ↓
        VICTORY    (retry)
```

#### InteractionMode (Main)
```
IDLE ⟷ TILE_SELECTED ⟷ DRAGGING
```

#### SelectionMode (SelectionManager)
```
SINGLE ⟷ MULTI (toggle with Q key)
```

#### TileLocation (Tile)
```
IN_BAG → IN_HAND ⟷ ON_BOARD
              ↓
         IN_DISCARD
```

## Input Actions

| Key | Action | Description |
|-----|--------|-------------|
| Q | `toggle_multi_select` | Toggle single/multi-select mode |
| Z | `discard_tiles` | Discard selected tiles (with confirmation) |
| D | Debug console | Toggle debug console |

## Configuration

### Board Size
```gdscript
board.rows = 8
board.columns = 8
```

### Hand Size
```gdscript
# Single source of truth: ProgressionConfig.default_hand_size
# At runtime: HandManager.set_hand_size(n) syncs to Hand UI
HandManager.hand_size = 10  # Runtime value (set per round from RoundConfig)
```

### Game Defaults
```gdscript
GameManager.DEFAULT_PLAYS_PER_ROUND = 2
GameManager.DEFAULT_TARGET_SCORE = 1000000
```

### Tile Distribution
Edit `Data/BagDistribution/bag_default.tres` to change letter frequencies.

## Features

### Core Gameplay (Implemented)
- [x] Title screen with main menu and keyboard/mouse navigation
- [x] Run setup popup with game configuration
- [x] Tile placement on 8×8 board with drag-and-drop
- [x] Single-select and multi-select modes (Q key toggle)
- [x] Multi-tile sequential placement
- [x] Tile discard system (Z key) with confirmation dialog
- [x] Visual discard pile drop zone
- [x] Hand management (draw, refill, max capacity)
- [x] Selection visual feedback (scale animation)
- [x] Locked tiles via LOCKED modifier (cannot move placed tiles, black border)

### Tile Modifiers System (Implemented)
- [x] Composable modifier system (multiple modifiers per tile)
- [x] Modifier types: EXTRA (+), MULTI (x), EXPO (^), RESET (→0), LOCKED (border)
- [x] Modifier tiers: BRONZE, SILVER, GOLD with scaling effects
- [x] Modifier lifetimes: CONSUMABLE, PER_ROUND, PERMANENT
- [x] Visual pipeline: tier-based tints, badges, invert shader, spark effects
- [x] Modifier-aware play animation dispatch (spin for EXTRA/MULTI/EXPO, stomp for RESET/plain)
- [x] RandomModifiersQuality: 50% chance per bag tile, weighted type/tier selection
- [x] LOCKED modifier integration: `set_locked()` works through modifier system
- [x] All board tiles re-animate on every play

### Animation System (Implemented)
- [x] Draw tile animations (rise + fade-in from bag, preserves modifier tints)
- [x] Glide animations (smooth transitions for placement, return, discard)
- [x] Shake animations (random 2D direction for locked tile feedback)
- [x] Stomp animations (play confirmation with particles for plain/RESET tiles)
- [x] Spin animations (scale pulse + 360° rotation + glow for modifier tiles)
- [x] Hand fan layout and hover effects
- [x] Tween-based animation coordination (TileAnimator)

### Word & Scoring System (Implemented)
- [x] Word detection on board (find_formed_words algorithm)
- [x] Score calculation with letter points
- [x] Cell multipliers infrastructure (2x letter, 3x word types)
- [x] WordValidator service (word validation & scoring)
- [x] Play button to lock placed tiles and submit

### Run & Progression System (Implemented)
- [x] Multi-round runs with progressive difficulty
- [x] RoundConfig system (custom board size, target score per round)
- [x] ProgressionRules (automatic progression scaling)
- [x] Shop phase between rounds with round summary
- [x] Debug round configuration popup (test different board sizes)
- [x] RunManager orchestration of run lifecycle
- [x] RunBuilder with quality modifier system
- [x] RunQuality system for modifiers (time-attack, max-hand-size, etc.)
- [x] ModifierRegistry and ModifierScoring for custom scoring rules
- [x] Game over and victory detection
- [x] Auto-end-round when no valid moves

### UI & Feedback (Implemented)
- [x] MainHUD: Score, plays remaining, round info, draw button
- [x] MultiSelectIndicator: Shows current selection mode
- [x] GameOverPopup: Victory/defeat screen
- [x] PauseMenu: Pause overlay with resume/quit
- [x] DebugOverlay: Developer testing tools
- [x] OptionsPopup: Game settings menu

### Debug & Testing (Implemented)
- [x] Debug console (D key) with commands
- [x] Spawn tiles command: `spawn A 5`
- [x] Fill hand command: `fill`
- [x] Clear board command: `clear_board`
- [x] Game state inspection tools
- [x] Debug auto-win flag for testing

### Future Features
- [ ] Cell multipliers on board (visual + logic)
- [ ] Discard pile peek (view previously discarded tiles)
- [ ] Save/load game state
- [ ] Multiple starting decks/themes
- [ ] Wild card tiles (blank tiles that can be any letter)
- [ ] Additional modifier types and behaviors
- [ ] Achievement/statistics system
- [ ] Sound and music
- [ ] Mobile touch controls refinement
- [ ] Leaderboard system
- [ ] Additional roguelike modifiers and qualities

## Development

### Debug Tools
- Press `D` to toggle debug console
- Commands: `spawn A 3`, `draw 5`, `clear_board`, `help`

### Testing
Run the main scene - game auto-starts with default configuration.

### Adding Features
1. Add signals to EventBus for cross-system communication
2. Implement logic in appropriate manager (autoload)
3. Connect UI components to EventBus signals
4. Update Main.gd for input handling if needed

## Documentation
Each component has an `AGENT.md` file with detailed documentation:

### Autoloads
- [autoload/AGENT.md](autoload/AGENT.md) - Manager singletons

### Scenes
- [scenes/AGENT.md](scenes/AGENT.md) - Scene overview
- [scenes/title_screen/AGENT.md](scenes/title_screen/AGENT.md) - Title screen and menu
- [scenes/board/AGENT.md](scenes/board/AGENT.md) - Board grid
- [scenes/tile/AGENT.md](scenes/tile/AGENT.md) - Letter tiles
- [scenes/hand/AGENT.md](scenes/hand/AGENT.md) - Player hand
- [scenes/ui/AGENT.md](scenes/ui/AGENT.md) - UI components
- [scenes/debug/AGENT.md](scenes/debug/AGENT.md) - Debug tools

### Data
- [Data/AGENT.md](Data/AGENT.md) - Data resources overview
- [Data/TileData/AGENT.md](Data/TileData/AGENT.md) - Letter definitions
- [Data/BagDistribution/AGENT.md](Data/BagDistribution/AGENT.md) - Tile distributions

### Other
- [scripts/AGENT.md](scripts/AGENT.md) - Utility scripts
- [scripts/animation/AGENT.md](scripts/animation/AGENT.md) - Animation system
- [Assets/AGENT.md](Assets/AGENT.md) - Visual assets
