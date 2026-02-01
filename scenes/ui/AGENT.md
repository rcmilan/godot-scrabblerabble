# UI Components

## Overview
User interface components for game state display, player interactions, and visual feedback. All UI elements connect to EventBus for reactive updates.

## Files
- `MainHUD.tscn` / `main_hud.gd` - Game state display and play button
- `DiscardPile.tscn` / `discard_pile.gd` - Visual discard pile drop zone
- `DiscardConfirmationDialog.tscn` / `discard_confirmation_dialog.gd` - Discard confirmation popup
- `MultiSelectIndicator.tscn` / `multi_select_indicator.gd` - Selection mode indicator
- `DebugOverlay.tscn` / `debug_overlay.gd` - Developer tools for testing

---

## MainHUD

### Purpose
Displays core game information: score, target, plays remaining, deck count, hand count, and discard count.

### Class: `MainHUD extends CanvasLayer`

### Node Structure
```
MainHUD (CanvasLayer)
├── PlaysLabel      # "Plays: 10"
├── ScoreLabel      # "Score: 0"
├── TargetLabel     # "Target: 100"
├── DeckLabel       # "Deck: 50"
├── HandLabel       # "Hand: 10"
├── DiscardLabel    # "Discard: 0"
├── GameOverLabel   # Win/lose message (hidden by default)
└── PlayButton      # Commit play button
```

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `play_requested` | none | Play button pressed |

### EventBus Connections
- `score_updated` - Updates score display
- `hand_count_changed` - Updates hand count
- `bag_count_changed` - Updates deck count
- `discard_count_changed` - Updates discard count
- `play_completed` - Updates plays remaining
- `round_started` - Resets display for new round
- `game_won` / `game_lost` - Shows game over message

### Public API
```gdscript
set_play_button_enabled(enabled: bool) -> void
```

---

## DiscardPile

### Purpose
Visual drop zone for discarding tiles. Shows discard count and provides drag-and-drop target.

### Class: `DiscardPile extends Control`

### Node Structure
```
DiscardPile (Control)
├── Background (Panel)
│   ├── TitleLabel    # "DISCARD"
│   ├── CountLabel    # "0"
│   └── HintLabel     # "[Z] or Drop"
└── DropZone (Control)  # Mouse detection area
```

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tiles_dropped` | `tiles: Array` | Tiles dropped on pile |
| `peek_requested` | none | User clicked to peek (future) |

### Visual States
```gdscript
const COLOR_NORMAL: Color = Color(0.3, 0.3, 0.35, 0.8)
const COLOR_HOVER: Color = Color(0.4, 0.4, 0.5, 0.9)
const COLOR_DROP_VALID: Color = Color(0.3, 0.6, 0.4, 0.9)
const COLOR_DROP_INVALID: Color = Color(0.6, 0.3, 0.3, 0.9)
```

### Public API
```gdscript
is_drop_target(global_pos: Vector2) -> bool  # Check if position is over pile
handle_drop(tiles: Array) -> void  # Process dropped tiles
get_discard_count() -> int  # Get current count
```

### EventBus Connections
- `discard_count_changed` - Updates count display
- `multi_drag_started` - Enables drag highlighting
- `multi_drag_ended` - Resets visual state

---

## DiscardConfirmationDialog

### Purpose
Modal confirmation popup shown before discarding selected tiles.

### Class: `DiscardConfirmationDialog extends CanvasLayer`

### Node Structure
```
DiscardConfirmationDialog (CanvasLayer, layer=10)
├── ColorRect         # Semi-transparent background
└── CenterContainer
    └── Panel
        └── VBoxContainer
            ├── MessageLabel    # "Discard N tiles?"
            └── ButtonContainer
                ├── YesButton   # "Yes (Enter)"
                └── NoButton    # "No (Esc)"
```

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `confirmed` | none | User confirmed discard |
| `cancelled` | none | User cancelled discard |

### Keyboard Shortcuts
- **Enter** - Confirm discard
- **Escape** - Cancel discard

### Public API
```gdscript
show_confirmation(tile_count: int) -> void  # Show dialog with count
```

---

## MultiSelectIndicator

### Purpose
Visual indicator showing current selection mode (single vs multi-select).

### Class: `MultiSelectIndicator extends Control`

### Visual States
- **Single mode**: Gray background, text "[Q] Multi"
- **Multi mode (no selection)**: Green background, text "MULTI [Q]"
- **Multi mode (with selection)**: Green background, text "MULTI [N]" where N is count

### Colors
```gdscript
const COLOR_MULTI_ACTIVE: Color = Color(0.2, 0.6, 0.3, 0.9)
const COLOR_SINGLE: Color = Color(0.3, 0.3, 0.3, 0.5)
```

### EventBus Connections
- `selection_mode_changed` - Updates mode display
- `selection_changed` - Updates selection count

---

## DebugOverlay

### Purpose
Provides developer tools for testing game state and mechanics without cluttering the production UI.

### Class: `DebugOverlay extends CanvasLayer`

### Node Structure
```
DebugOverlay (CanvasLayer)
└── DebugPanel (Panel)
    └── VBox (VBoxContainer)
        ├── WordInput (LineEdit)     # Enter word to validate
        ├── CheckButton              # Validate word
        ├── RemoveAllButton          # Clear all board tiles
        ├── RedrawButton             # Redraw hand from bag
        └── PrintRackButton          # Print current hand to console
```

### Available Tools
| Tool | Action | Description |
|------|--------|-------------|
| Word Validator | Enter word, press CheckButton | Validate word against dictionary |
| Remove All | RemoveAllButton | Clear all tiles from board |
| Redraw Hand | RedrawButton | Return hand to bag and redraw |
| Print Rack | PrintRackButton | Log current hand contents |

### Implementation Details
- Uses reflection-style method lookup (`has_method()`, etc.) on main scene
- Button connections wired in `_ready()`
- Calls methods on main scene: `validate_word()`, `_on_remove_all_pressed()`, `_on_redraw_hand_pressed()`, `_on_print_rack_pressed()`

### Future Enhancement
- Keyboard shortcut to toggle overlay visibility

---

## Input Actions

The UI system uses these input actions defined in `project.godot`:

| Action | Key | Purpose |
|--------|-----|---------|
| `toggle_multi_select` | Q | Toggle single/multi-select mode |
| `discard_tiles` | Z | Request discard of selected tiles |

---

## UI Communication Flow

```
User Input
    │
    ├─► Z key ──────────────────► Main._request_discard_confirmation()
    │                                      │
    │                                      ▼
    │                            DiscardConfirmationDialog.show_confirmation()
    │                                      │
    │                     ┌────────────────┼────────────────┐
    │                     ▼                                 ▼
    │               confirmed ──► Main._on_discard_confirmed()
    │                              │
    │                              ▼
    │                     HandManager.discard_tile() (for each)
    │                              │
    │                              ▼
    │                     HandManager.refill_hand()
    │                              │
    │                              ▼
    │                     EventBus signals ──► UI Updates
    │
    └─► Drag to DiscardPile ──► Same flow as above
```

---

## Future UI Components
- Discard pile viewer (peek at discarded tiles)
- Shop interface (between rounds)
- Deck builder UI
- Settings menu
- Tutorial overlays
- Achievement notifications
