# Shop Component

## Overview
The Shop component appears between rounds, displaying round completion information and allowing the player to continue to the next round. This is the transition point for roguelike features like upgrades and shop items (future).

## Purpose
- Display round summary (score, difficulty progression)
- Transition between rounds
- Debug tool: allow changing board configuration per round
- (Future) Shop for upgrades, relics, modifiers

## Files
- `ShopOverlay.tscn` - Shop scene with UI
- `shop_overlay.gd` - Shop controller script
- `DebugRoundConfigPopup.tscn` - Debug configuration dialog
- `debug_round_config_popup.gd` - Debug dialog controller

## Architecture

### ShopOverlay (`shop_overlay.gd`)
**Class**: `ShopOverlay extends CanvasLayer`

**Purpose**: Controller for shop UI. Shows round results and handles continue button.

**Node Structure**:
```
ShopOverlay (CanvasLayer, layer 1)
├── Overlay                         # Darkens background (ColorRect)
├── Panel                           # Shop content panel
│   └── MarginContainer
│       └── VBoxContainer
│           ├── RoundLabel          # "Round X Complete!"
│           ├── ScoreLabel          # "Score: 1500"
│           ├── NextBoardLabel      # "Next: Round 3 (8x8 board, Target: 500)"
│           ├── ContinueButton      # "Continue"
│           └── DebugConfigButton   # (debug only) "Configure Board"
└── DebugRoundConfigPopup           # (debug only) Config dialog
```

**Lifecycle**:
```gdscript
# Show shop after round ends
show_shop(round_completed: int, round_score: int, next_config: RoundConfig) -> void
    ├─ Updates labels with information
    ├─ Shows the overlay
    └─ Focuses continue button

# Player clicks continue
_on_continue_pressed() -> void
    ├─ Hides overlay
    └─ Emits continue_requested signal
```

**Signals**:
| Signal | Parameters | Description |
|--------|------------|-------------|
| `continue_requested` | none | Player clicked continue |
| `debug_config_requested` | none | Debug config was opened |

**Key Properties**:
```gdscript
var _next_config: RoundConfig = null  # Config for next round (debug edit target)
```

**Key Methods**:
```gdscript
# Public API
show_shop(round_completed, round_score, next_config) -> void
    """Display round summary and prepare for next round"""

# Input handling
_input(event: InputEvent) -> void
    """Press ENTER to continue"""

# Debug
_on_debug_config_pressed() -> void
    """Show debug config popup"""

_on_debug_config_applied(rows: int, cols: int) -> void
    """Update next config with debug values"""
```

---

## DebugRoundConfigPopup

### Purpose
Developer tool to test different board sizes during gameplay without restarting. Allows configuring rows/columns for the next round.

**Class**: `DebugRoundConfigPopup extends CanvasLayer`

**Signals**:
| Signal | Parameters | Description |
|--------|------------|-------------|
| `config_applied` | `rows: int, cols: int` | Config confirmed |
| `popup_closed` | none | Popup closed/cancelled |

**Key Methods**:
```gdscript
show_popup(rows: int, cols: int) -> void
    """Show popup with current board dimensions"""

_on_apply_pressed() -> void
    """Apply new dimensions and close"""

_on_cancel_pressed() -> void
    """Close without applying"""
```

---

## Integration with Main

### How Shop Transitions Work

```gdscript
# In Main, when round ends:
1. PlayHandler detects win/lose
2. GameManager.end_game() emitted
3. Main._on_run_ended() called
   ├─ If ROUND_END → request shop
   ├─ If VICTORY → show victory popup
   └─ If GAME_OVER → show game over popup

# Request shop:
EventBus.run_shop_requested.emit()
    ↓
RunManager._on_run_ended() → prepares next config
    ↓
EventBus.run_round_ready.emit()  # Actually means shop is ready
    ↓
Main._on_shop_requested() → shows ShopOverlay

# Shop continue:
ShopOverlay.continue_requested
    ↓
Main._on_shop_continue()
    ├─ Hides shop
    ├─ Calls RunManager._advance_to_next_round()
    └─ Loop continues
```

---

## Debug Features

### Debug Round Configuration
During gameplay, when shop is open:
1. Click "Configure Board" button (debug only)
2. DebugRoundConfigPopup opens
3. Enter new board dimensions (rows, columns)
4. Click "Apply"
5. Next round will use new board size

**Note**: This modifies `_next_config` during gameplay. Useful for testing different difficulty levels without restarting.

---

## Future Shop Features

- **Shop Items**: Purchasable upgrades
- **Relics**: Passive modifiers with special effects
- **Health/Damage**: Resource management system
- **Currency**: Collect points for upgrades
- **Visual Polish**: Animated shop interface, item descriptions
- **Meta-progression**: Stats tracked across runs

---

## Signal Flow Diagram

```
GameManager.end_game(victory: bool)
    │
    ├─ false (GAME_OVER)
    │   └─ EventBus.game_lost
    │       └─ Main._on_run_ended()
    │           └─ GameOverPopup.show_popup()
    │
    └─ true (GAME_WON or ROUND_WON)
        └─ EventBus.game_won
            └─ (If more rounds)
                └─ EventBus.run_shop_requested
                    └─ Main._on_shop_requested()
                        └─ ShopOverlay.show_shop()
                            └─ (Player clicks Continue)
                                └─ ShopOverlay.continue_requested
                                    └─ Main._on_shop_continue()
```

