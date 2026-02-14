# DiscardConfirmationDialog

## Overview
Modal confirmation popup shown before discarding selected tiles. Displays tile count and Yes/No options with keyboard shortcuts.

## Files
- `DiscardConfirmationDialog.tscn` - Dialog scene (CanvasLayer, layer 10)
- `discard_confirmation_dialog.gd` - Dialog controller script

## Class: `DiscardConfirmationDialog extends CanvasLayer`

## Node Structure
```
DiscardConfirmationDialog (CanvasLayer, layer=10)
├── ColorRect             # Semi-transparent overlay (0,0,0,0.5)
└── CenterContainer
    └── Panel
        └── VBoxContainer
            ├── MessageLabel    # "Discard N tiles?"
            └── ButtonContainer (HBoxContainer)
                ├── YesButton   # "Yes (Enter)"
                └── NoButton    # "No (Esc)"
```

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `confirmed` | none | User confirmed discard |
| `cancelled` | none | User cancelled discard |

## Keyboard Shortcuts
- **Enter** (`ui_accept`) - Confirm discard
- **Escape** (`ui_cancel`) - Cancel discard

## Public API
```gdscript
show_confirmation(tile_count: int) -> void
```

## Note
Currently unused in the discard flow (discard confirmation was removed in favor of direct discard). Kept for potential future use.
