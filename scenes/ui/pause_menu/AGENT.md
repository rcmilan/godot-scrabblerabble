# PauseMenu

## Overview
Modal pause menu overlay with resume and return-to-title options. Displayed when the player presses ESC during gameplay.

## Files
- `PauseMenu.tscn` - Pause menu scene (CanvasLayer, layer 10)
- `pause_menu.gd` - Pause menu controller script

## Class: `PauseMenu extends CanvasLayer`

## Node Structure
```
PauseMenu (CanvasLayer, layer=10)
├── Overlay (ColorRect, 0,0,0,0.5)
└── Panel (centered)
    └── MarginContainer
        └── VBoxContainer
            ├── TitleLabel          # "Paused"
            ├── HSeparator
            ├── ResumeButton        # "Resume"
            └── ReturnToTitleButton  # "Return to Title"
```

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `resume_requested` | none | Player wants to resume |
| `return_to_title_requested` | none | Player wants to return to title |

## Keyboard Shortcuts
- **ESC** (`pause_game`) - Closes menu (resumes game)
- **Enter** (`ui_accept`) - Activates focused button

## Public API
```gdscript
show_pause_menu() -> void    # Show menu and focus Resume button
close_pause_menu() -> void   # Hide menu and emit resume_requested
```

## Integration
- `GameplayController` emits `pause_requested` on ESC → Main calls `show_pause_menu()`
- Main connects `resume_requested` → `_resume_game()` (activates controller, resumes GameManager)
- Main connects `return_to_title_requested` → `_on_return_to_title()` (resets run, changes scene)
- Uses `_input()` (not `_unhandled_input`) with `if not visible: return` guard

## Signal Flow
```
Pause:  ESC → GameplayController.pause_requested → Main._pause_game()
            → controller.deactivate() + GameManager.pause_game() + show_pause_menu()
Resume: ESC/ResumeButton → close_pause_menu() → resume_requested
            → Main._resume_game() → GameManager.resume_game() + controller.activate()
```
