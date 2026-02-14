# DebugOverlay

## Overview
Developer tools overlay for testing game state and mechanics. Provides buttons for word validation, board clearing, hand redrawing, and rack printing.

## Files
- `DebugOverlay.tscn` - Overlay scene (CanvasLayer, layer 100)
- `debug_overlay.gd` - Overlay controller script

## Class: `DebugOverlay extends CanvasLayer`

## Node Structure
```
DebugOverlay (CanvasLayer, layer=100, initially hidden)
└── DebugPanel (Panel)
    └── VBox (VBoxContainer)
        ├── TitleLabel       # "Debug Tools"
        ├── WordLabel        # "Check Word:"
        ├── WordInput        # LineEdit for word input
        ├── CheckButton      # Validate word
        ├── RemoveAllButton  # Clear board
        ├── RedrawButton     # Redraw hand
        └── PrintRackButton  # Print hand to console
```

## Integration
Uses reflection-style method lookup on the current scene:
- `validate_word()`, `_on_remove_all_pressed()`, `_on_redraw_hand_pressed()`, `_on_print_rack_pressed()`

## Note
Not currently referenced in Main.tscn. Standalone debug tool.
