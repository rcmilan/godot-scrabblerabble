# Wordatro - Roguelike Deck Builder Scrabble Game

## Overview
A word game combining Scrabble mechanics with roguelike deck-building elements. Players form words on a grid board using letter tiles, earn scores, and progress through rounds.

## Engine
Godot 4.5.1 (Mobile renderer)

## Project Structure
```
Wordatro/
├── autoload/           # Global singleton managers
│   ├── event_bus.gd    # Signal hub
│   ├── game_manager.gd # Game state
│   ├── hand_manager.gd # Hand operations
│   ├── tile_bag.gd     # Tile pool (deck)
│   └── debug_manager.gd
│
├── scenes/             # Game scenes
│   ├── Main.tscn       # Root scene
│   ├── board/          # Grid component
│   ├── hand/           # Hand component
│   ├── tile/           # Tile component
│   ├── ui/             # UI overlays
│   └── debug/          # Debug tools
│
├── scripts/            # Utility scripts
│   └── logic/          # Game logic services
│
├── Data/               # Game data resources
│   ├── BagDistribution/ # Tile distributions
│   └── TileData/       # Letter tile data
│
└── Assets/             # Visual assets
    └── Tiles/          # Letter textures
```

## Core Systems

### Game Flow
1. Game starts with configured tile distribution
2. Hand is filled from tile bag
3. Player places tiles on board to form words
4. Score is calculated based on letters and multipliers
5. Round ends when target score reached or plays exhausted
6. (Future) Progress to shop/next round

### Key Components

| Component | Purpose |
|-----------|---------|
| **Board** | Dynamic grid (default 15x15), cell management |
| **Tile** | Letter tiles with drag-and-drop |
| **Hand** | Player's available tiles |
| **EventBus** | Decoupled signal communication |
| **GameManager** | Game state and phase control |
| **TileBag** | Tile pool (deck) management |

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

#### TileLocation (Tile)
```
IN_BAG → IN_HAND ⟷ ON_BOARD
              ↓
         IN_DISCARD
```

## Configuration

### Board Size
```gdscript
# In Board.tscn or via code
board.rows = 15
board.columns = 15
```

### Hand Size
```gdscript
HandManager.hand_size = 10
```

### Tile Distribution
Edit `Data/BagDistribution/bag_default.tres` to change letter frequencies.

## Future Features
- [ ] Multi-select tiles
- [ ] Deck builder
- [ ] Word validation dictionary
- [ ] Special tile modifiers
- [ ] Cell multipliers (2x letter, 3x word, etc.)
- [ ] Multiple rounds with shop phase
- [ ] Discard pile mechanics
- [ ] Flexible board (add rows/columns)
- [ ] Save/load system
- [ ] Multiple starting decks

## Development

### Debug Tools
- Press `D` to toggle debug console
- Commands: `spawn A`, `draw 5`, `clear_board`

### Testing
Run the main scene - game auto-starts with default configuration.

## Documentation
Each component has an `AGENT.md` file with detailed documentation:
- [autoload/AGENT.md](autoload/AGENT.md)
- [scenes/AGENT.md](scenes/AGENT.md)
- [scenes/board/AGENT.md](scenes/board/AGENT.md)
- [scenes/tile/AGENT.md](scenes/tile/AGENT.md)
- [scenes/hand/AGENT.md](scenes/hand/AGENT.md)
- [scripts/AGENT.md](scripts/AGENT.md)
