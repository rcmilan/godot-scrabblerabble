# Wordatro Game Configuration

Core game parameters and constants used throughout the project.

## Board Configuration

- **Grid Size**: 11×11 cells
- **Cell Size**: 48px
- **Total Board Size**: 528×528px (11 × 48)
- **Board Type**: Scrabble-like word placement grid

## Window/Display Configuration

- **Window Size**: 1536×864px
- **Board Position** (Main.tscn): 
  - X: 504px (centered: (1536 - 528) / 2)
  - Y: 80px (top margin)
- **Hand Position** (Main.tscn):
  - X: 418px (centered: (1536 - 700) / 2)
  - Y: 618px (10px below board: 80 + 528 + 10)
  - Size: 700×60px

## Gameplay Configuration

- **Hand Size**: 10 tiles
- **Initial Rack Size**: 50 tiles
- **Refill Behavior**: Currently refills to max (10 tiles) - TODO: change to fixed 3 tiles
- **Plays Per Round**: Currently 10 - TODO: change to 3
- **Target Score**: 100 points (configurable via RoundManager)

## UI Layout

- **Button Positioning**: 
  - Discard button: 25px left of hand
  - Play button: 25px right of hand
  - Both vertically centered with hand
- **HUD Labels**: Right-aligned at top-right of screen
- **Debug Overlay**: Toggle with F12, layer 100

## Dictionary

- **Dictionary File**: `res://data/english_words.txt`
- **Validation**: O(1) hash lookup via DictionaryLoader

## Scene Architecture

- **Debug Scene**: `res://scenes/debug/Debug.tscn` (development/testing)
- **Main Scene**: `res://scenes/main/Main.tscn` (production gameplay)
- **Shared Components**: MainHUD, Hand, Board, BoardView
- **Main scene** set to Debug in project.godot for development workflow
