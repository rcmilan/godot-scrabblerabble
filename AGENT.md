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
│   ├── game_manager.gd     # Game state
│   ├── hand_manager.gd     # Hand operations
│   ├── tile_bag.gd         # Tile pool (deck)
│   ├── selection_manager.gd # Selection state
│   ├── tile_animator.gd    # Animation coordinator
│   └── debug_manager.gd    # Debug tools
│
├── scenes/                 # Game scenes
│   ├── Main.tscn           # Root scene
│   ├── main.gd             # Main controller
│   ├── board/              # Grid component
│   ├── hand/               # Hand component
│   ├── tile/               # Tile component
│   ├── ui/                 # UI components
│   └── debug/              # Debug tools
│
├── scripts/                # Utility scripts
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
1. Game starts with configured tile distribution
2. Hand is filled from tile bag (10 tiles)
3. Player selects tiles (single or multi-select with Q key)
4. Player places tiles on board to form words
5. Player can discard tiles (Z key or drag to pile)
6. Score is calculated based on letters and multipliers
7. Round ends when target score reached or plays exhausted
8. (Future) Progress to shop/next round

### Key Components

| Component | Purpose |
|-----------|---------|
| **Board** | Dynamic grid (default 8x8), cell management |
| **Tile** | Letter tiles with drag-and-drop |
| **Hand** | Player's available tiles (max 10) |
| **SelectionManager** | Single/multi-select state |
| **TileAnimator** | Animation coordination |
| **EventBus** | Decoupled signal communication |
| **GameManager** | Game state and phase control |
| **TileBag** | Tile pool (deck) management |
| **HandManager** | Draw, discard, refill operations |

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
GameManager.DEFAULT_PLAYS_PER_ROUND = 10
GameManager.DEFAULT_TARGET_SCORE = 100
```

### Tile Distribution
Edit `Data/BagDistribution/bag_default.tres` to change letter frequencies.

## Features

### Implemented
- [x] Tile placement on board
- [x] Drag-and-drop tiles
- [x] Single-select mode
- [x] Multi-select mode (Q key)
- [x] Multi-tile placement (sequential)
- [x] Discard system (Z key)
- [x] Discard confirmation dialog
- [x] Visual discard pile drop zone
- [x] Selection scale animation (5% larger)
- [x] HUD with game stats
- [x] Tile bag with distributions
- [x] Hand refill after discard
- [x] Tile draw animations (rise from bottom)
- [x] Tile return-to-hand animations (right-click on board tile)
- [x] Tile shake animations (illegal action feedback)
- [x] Tile stomp animations (play confirmation)
- [x] Play button to lock placed tiles
- [x] Word detection on board (find_formed_words)
- [x] Locked tiles cannot be moved/returned
- [x] Debug console

### Future
- [ ] Word validation dictionary
- [ ] Score calculation with multipliers
- [ ] Cell multipliers (2x letter, 3x word, etc.)
- [ ] Multiple rounds with shop phase
- [ ] Discard pile peek (view discarded tiles)
- [ ] Flexible board (add rows/columns)
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
