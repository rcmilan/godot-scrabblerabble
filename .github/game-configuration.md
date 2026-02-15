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

## Animation System

### Draw Animation
- **Start Position**: 200px below final position
- **Start Scale**: 0.8x (grows to 1.0x)
- **Start Alpha**: 0.0 (fades in to 1.0)
- **Duration**: 0.3s per tile
- **Stagger Delay**: 0.05s between tiles

### Return/Discard Animation (Glide)
- **Type**: Smooth position transitions
- **Duration**: 0.35s
- **Easing**: TRANS_BACK (subtle overshoot/bounce)
- **For Discard**: Tiles shrink and fade as they glide to pile

### Stomp Animation (Play Confirmation)
- **Phases**: Rise (0.15s) → Slam (0.08s) → Recover (0.12s)
- **Rise Scale**: 1.35x
- **Rise Offset**: -15px (upward)
- **Squish Scale**: 1.1x wide × 0.9x tall
- **Particles**: 12 total, 5 directional emitters
- **Particle Speed**: 200px/s
- **Particle Lifetime**: 0.8s
- **Stagger Delay**: 0.06s between tiles

### Spin Animation (Modifier Tiles on Play)
- **Trigger**: Play confirmed on tiles with EXTRA, MULTI, or EXPO modifiers
- **Peak Scale**: 1.25x
- **Spin-Up Duration**: 0.15s (scale + rotation start)
- **Spin-Down Duration**: 0.20s (return to normal)
- **Rotation**: Full 360°
- **Glow Color**: Color(0.7, 0.9, 1.0, 1.0)
- **Stagger Delay**: 0.06s between tiles

### Shake Animation (Locked Tile Feedback)
- **Trigger**: Right-click on locked tile
- **Distance**: 8px in random 2D direction (different each time)
- **Count**: 3 shake cycles
- **Duration**: 0.08s per direction
- **Easing**: EASE_IN_OUT

## Tile Modifiers Configuration

### RandomModifiersQuality
- **Modifier Chance**: 50% per bag tile
- **Type Weights**: EXTRA (45%), MULTI (30%), EXPO (15%), RESET (10%)
- **Tier Weights**: BRONZE (60%), SILVER (30%), GOLD (10%)
- **Lifetime**: PER_ROUND (persists for entire round)

### Modifier Scoring Values
| Type | Bronze | Silver | Gold |
|------|--------|--------|------|
| EXTRA | +2 | +5 | +10 |
| MULTI | x2 | x5 | x10 |
| EXPO | ^2 | ^3 | ^5 |
| RESET | → 0 | → 0 | → 0 |
| LOCKED | No effect | — | — |

### Modifier Visuals
- **EXTRA tints**: Bronze(0.85,0.72,0.53), Silver(0.75,0.75,0.85), Gold(1.0,0.84,0.0)
- **MULTI tints**: Bronze(0.6,0.8,1.0), Silver(0.5,0.65,1.0), Gold(0.35,0.5,1.0)
- **EXPO tints**: Bronze(1.0,0.55,0.55), Silver(1.0,0.7,0.4), Gold(0.6,0.4,1.0)
- **EXPO sparks**: Bronze=red, Silver=orange, Gold=blue (every ~3s)
- **RESET**: Invert shader, no badges
- **LOCKED**: Black 2px border (hidden during play animations)

## Dictionary

- **Dictionary File**: `res://data/english_words.txt`
- **Validation**: O(1) hash lookup via WordValidator
- **Fallback Mode**: Accept any word ≥ 2 letters (if dictionary not loaded)

## Scene Architecture

### Main Components
- **Main Scene**: `res://scenes/Main.tscn` (production gameplay)
- **Board**: 11×11 tile grid with cell management
- **Hand**: Player tile container (HBoxContainer)
- **Tiles**: Draggable letter tiles with selection/drag-drop support

### UI Components
- **MainHUD**: Score, plays, game state display
- **DiscardPile**: Drop zone for discarding tiles
- **DiscardConfirmationDialog**: Modal confirmation popup
- **MultiSelectIndicator**: Selection mode indicator
- **DebugConsole**: Command console interface (D key to toggle)
- **DebugOverlay**: Developer tools overlay

## Debug System

### Debug Console
- **Toggle**: Press **D** key
- **Commands**:
  - `help` - Show available commands
  - `spawn <letter> [count]` - Spawn tiles in hand
  - `draw [count]` - Draw tiles from bag
  - `clear_board` - Remove all tiles from board
  - `close/exit` - Hide console

### Debug Features
- Console command processing via DebugManager
- Word validation testing
- Board state manipulation
- Tile spawning for rapid testing
