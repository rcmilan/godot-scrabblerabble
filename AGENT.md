# Wordatro - Roguelike Word Game

## Overview
A word game combining Scrabble mechanics with roguelike deck-building elements. Players form words on a grid board using letter tiles, earn scores, and progress through rounds.

## Engine
Godot 4.5.1 (Mobile renderer)

## Project Structure
```
Wordatro/
├── autoload/               # Global singleton managers
│   ├── event_bus.gd        # Signal hub
│   ├── game_manager.gd     # Game state (encapsulated behind getters)
│   ├── hand_manager.gd     # Hand operations
│   ├── tile_bag.gd         # Tile pool (deck)
│   ├── selection_manager.gd # Selection state (local node, created by Main)
│   ├── tile_animator.gd    # Animation coordinator
│   ├── drag_manager.gd     # Multi-tile drag (local node, created by GameplayController)
│   └── run_manager.gd      # Run progression
│
├── scenes/                 # Game scenes
│   ├── title_screen/       # Main menu / title screen
│   ├── Main.tscn           # Gameplay scene
│   ├── main.gd             # Main controller
│   ├── board/              # Grid component
│   ├── hand/               # Hand component
│   ├── tile/               # Tile component
│   ├── ui/                 # UI components
│   └── debug/              # Debug tools (DebugConsole + DebugManager)
│
├── scripts/                # Utility scripts
│   ├── controllers/        # Game controllers (coordinator + handlers)
│   ├── interaction/        # Input interaction helpers
│   ├── animation/          # Animation strategies
│   └── logic/              # Game logic services
│
├── Data/                   # Game data resources
│   ├── BagDistribution/    # Tile distributions
│   └── TileData/           # Letter tile data
│
└── Assets/                 # Visual assets
    └── Tiles/              # Letter textures
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

| Component | Purpose |
|-----------|---------|
| **TitleScreen** | Main menu with navigation (New Game, Options, Exit) |
| **MenuController** | Menu navigation and keyboard/mouse input |
| **Board** | Dynamic grid (default 8x8), cell management |
| **Tile** | Letter tiles with drag-and-drop |
| **Hand** | Player's available tiles (max 10) |
| **SelectionManager** | Single/multi-select state (local node, injected) |
| **DragManager** | Multi-tile drag coordination (local node, injected) |
| **TileAnimator** | Animation coordination |
| **EventBus** | Decoupled signal communication |
| **GameManager** | Game state and phase control (encapsulated) |
| **TileBag** | Tile pool (deck) management |
| **HandManager** | Draw, discard, refill operations |
| **DebugManager** | Debug commands (RefCounted, owned by DebugConsole) |

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
HandManager.hand_size = 10  # Default
HandManager.MAX_HAND_SIZE = 15  # Maximum
```

### Game Defaults
```gdscript
GameManager.DEFAULT_PLAYS_PER_ROUND = 2
GameManager.DEFAULT_TARGET_SCORE = 1000000
```

### Tile Distribution
Edit `Data/BagDistribution/bag_default.tres` to change letter frequencies.

## Features

### Implemented
- [x] Title screen with main menu
- [x] Menu navigation (keyboard: WASD/arrows, mouse: click/hover)
- [x] Options popup with game settings and debug options
- [x] Tile placement on board
- [x] Drag-and-drop tiles
- [x] Single-select mode
- [x] Multi-select mode (Q key)
- [x] Multi-tile placement (sequential)
- [x] Discard system (Z key)
- [x] Visual discard pile drop zone
- [x] Selection scale animation (5% larger)
- [x] HUD with game stats (score, plays, bag count, draw button)
- [x] Tile bag with distributions
- [x] Hand refill after discard
- [x] Tile draw animations (rise from bottom)
- [x] Tile return-to-hand animations (right-click on board tile)
- [x] Tile shake animations (illegal action feedback)
- [x] Tile stomp animations (play confirmation)
- [x] Play button to lock placed tiles
- [x] Word detection on board (find_formed_words)
- [x] Score calculation with placement scoring
- [x] Locked tiles cannot be moved/returned
- [x] Multi-round run with progression (RoundConfig, ProgressionRules)
- [x] Shop phase between rounds
- [x] Auto-end-round when no valid moves remain
- [x] Run state management (RunManager, RunState)
- [x] Game over and victory screens
- [x] Debug console

### Future
- [ ] Game configuration in title screen (board size, hand size, rounds, target score)
- [ ] Actual options implementation (fullscreen, vsync, volume)
- [ ] Cell multipliers (2x letter, 3x word, etc.)
- [ ] Discard pile peek (view discarded tiles)
- [ ] Save/load system
- [ ] Multiple starting decks
- [ ] Special tile types
- [ ] Achievement system

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
