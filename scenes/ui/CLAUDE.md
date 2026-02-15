# UI Components

## Overview
User interface components for game state display, player interactions, and visual feedback. Each component has its own subdirectory with an AGENT.md file.

## Structure
```
scenes/ui/
├── main_hud/                      # Game state display and action buttons
│   ├── MainHUD.tscn
│   ├── main_hud.gd
│   └── AGENT.md
├── discard_pile/                   # Visual discard drop zone
│   ├── DiscardPile.tscn
│   ├── discard_pile.gd
│   └── AGENT.md
├── discard_confirmation_dialog/    # Discard confirmation popup
│   ├── DiscardConfirmationDialog.tscn
│   ├── discard_confirmation_dialog.gd
│   └── AGENT.md
├── multi_select_indicator/         # Selection mode indicator
│   ├── MultiSelectIndicator.tscn
│   ├── multi_select_indicator.gd
│   └── AGENT.md
├── game_over_popup/                # Victory/defeat popup
│   ├── GameOverPopup.tscn
│   ├── game_over_popup.gd
│   └── AGENT.md
├── pause_menu/                     # Pause menu overlay
│   ├── PauseMenu.tscn
│   ├── pause_menu.gd
│   └── AGENT.md
└── debug_overlay/                  # Developer debug tools
    ├── DebugOverlay.tscn
    ├── debug_overlay.gd
    └── AGENT.md
```

## Component Summary

| Component | Type | Layer | Purpose |
|-----------|------|-------|---------|
| [MainHUD](main_hud/AGENT.md) | CanvasLayer | 0 | Score, plays, round info, draw/play buttons |
| [DiscardPile](discard_pile/AGENT.md) | Control | - | Drop zone for discarding tiles |
| [DiscardConfirmationDialog](discard_confirmation_dialog/AGENT.md) | CanvasLayer | 10 | Modal discard confirmation |
| [MultiSelectIndicator](multi_select_indicator/AGENT.md) | Control | - | Shows single/multi-select mode |
| [GameOverPopup](game_over_popup/AGENT.md) | CanvasLayer | 10 | Victory/defeat screen |
| [PauseMenu](pause_menu/AGENT.md) | CanvasLayer | 10 | Pause overlay with resume/quit |
| [DebugOverlay](debug_overlay/AGENT.md) | CanvasLayer | 100 | Developer testing tools |

## Modal Overlay Pattern

Modal UI components (GameOverPopup, PauseMenu, DiscardConfirmationDialog) follow a consistent pattern:
- **Root**: CanvasLayer at layer 10 (above gameplay, below debug)
- **Overlay**: ColorRect with semi-transparent black background
- **Content**: Centered Panel with MarginContainer and VBoxContainer
- **Input**: `_input()` with `if not visible: return` guard
- **Keyboard**: ESC to close, Enter to activate focused button
- **Signals**: Action signals (e.g., `resume_requested`, `return_to_title_requested`)
- **Lifecycle**: `hide()` in `_ready()`, shown via public API method

## Input Actions

| Action | Key | Consumer |
|--------|-----|---------|
| `toggle_multi_select` | Q | GameplayController → SelectionManager |
| `discard_tiles` | Z | GameplayController → discard flow |
| `pause_game` | ESC | GameplayController → Main → PauseMenu |
