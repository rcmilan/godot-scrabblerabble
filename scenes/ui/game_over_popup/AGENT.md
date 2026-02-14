# GameOverPopup

## Overview
Modal popup displayed when the game ends (victory or defeat). Shows final score and a return-to-title button.

## Files
- `GameOverPopup.tscn` - Popup scene (CanvasLayer, layer 10)
- `game_over_popup.gd` - Popup controller script

## Class: `GameOverPopup extends CanvasLayer`

## Node Structure
```
GameOverPopup (CanvasLayer, layer=10)
├── Overlay (ColorRect, 0,0,0,0.7)
└── Panel (centered)
    └── MarginContainer
        └── VBoxContainer
            ├── MessageLabel   # "Game Over" or "Victory!"
            ├── ScoreLabel     # "Final Score: N"
            └── ReturnButton   # "Return to Title"
```

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `return_to_title_requested` | none | Player wants to return to title |

## Keyboard Shortcuts
- **Enter** (`ui_accept`) - Activates return button

## Public API
```gdscript
show_game_over(total_score: int) -> void
show_victory(total_score: int) -> void
```

## Integration
- Main connects `return_to_title_requested` to `_on_return_to_title()`
- Main calls `show_victory()` or `show_game_over()` from `_on_run_ended()`
