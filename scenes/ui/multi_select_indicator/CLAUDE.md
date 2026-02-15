# MultiSelectIndicator

## Overview
Visual indicator showing current selection mode (single vs multi-select) and selection count.

## Files
- `MultiSelectIndicator.tscn` - Indicator scene (Control)
- `multi_select_indicator.gd` - Indicator controller script

## Class: `MultiSelectIndicator extends Control`

## Node Structure
```
MultiSelectIndicator (Control)
└── Background (Panel)
    └── ModeLabel  # "[Q] Multi" or "MULTI [N]"
```

## Dependencies
- `SelectionManager` (injected via `set_selection_manager()`)
- Connects to `SelectionManager.mode_changed` and `SelectionManager.selection_changed`

## Visual States
| State | Background Color | Text |
|-------|-----------------|------|
| Single mode | Gray (0.3, 0.3, 0.3, 0.5) | "Multi [Q]" |
| Multi mode (no selection) | Green (0.2, 0.6, 0.3, 0.9) | "MULTI [Q]" |
| Multi mode (with selection) | Green | "MULTI [N]" (N = count) |

## Public API
```gdscript
set_selection_manager(sm: SelectionManager) -> void
```
