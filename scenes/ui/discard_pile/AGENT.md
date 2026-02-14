# DiscardPile

## Overview
Visual drop zone for discarding tiles. Shows discard count and provides drag-and-drop target with click-to-discard support.

## Files
- `DiscardPile.tscn` - Discard pile scene (Control)
- `discard_pile.gd` - Discard pile controller script

## Class: `DiscardPile extends Control`

## Node Structure
```
DiscardPile (Control)
├── Background (Panel)
│   ├── TitleLabel    # "DISCARD"
│   ├── CountLabel    # "0"
│   └── HintLabel     # "[Z] or Drop"
└── DropZone (Control)  # Mouse detection area
```

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tiles_dropped` | `tiles: Array` | Tiles dropped on pile via drag |
| `discard_clicked` | none | Pile clicked with tiles selected |
| `peek_requested` | none | Pile clicked with no selection (future) |

## Dependencies
- `SelectionManager` (injected via `set_selection_manager()`)
- `EventBus` signals: `discard_count_changed`, `multi_drag_started`, `multi_drag_ended`

## Visual States
```gdscript
COLOR_NORMAL: Color = Color(0.3, 0.3, 0.35, 0.8)
COLOR_HOVER: Color = Color(0.4, 0.4, 0.5, 0.9)
COLOR_DROP_VALID: Color = Color(0.3, 0.6, 0.4, 0.9)
COLOR_DROP_INVALID: Color = Color(0.6, 0.3, 0.3, 0.9)
```

## Public API
```gdscript
set_selection_manager(sm: SelectionManager) -> void
is_drop_target(global_pos: Vector2) -> bool
handle_drop(tiles: Array) -> void
get_discard_count() -> int
```
