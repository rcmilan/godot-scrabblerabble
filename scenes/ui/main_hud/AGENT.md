# MainHUD

## Overview
Game state display overlay showing score, plays, round info, deck/hand/discard counts, and action buttons.

## Files
- `MainHUD.tscn` - HUD scene (CanvasLayer, layer 0)
- `main_hud.gd` - HUD controller script

## Class: `MainHUD extends CanvasLayer`

## Node Structure
```
MainHUD (CanvasLayer, layer=0)
├── RoundLabel       # "Round: 1"
├── PlaysLabel       # "Plays: 2"
├── ScoreLabel       # "Score: 0"
├── TargetLabel      # "Target: 100"
├── DeckLabel        # "Deck: 50"
├── HandLabel        # "Hand: 10"
├── DiscardLabel     # "Discard: 0"
├── DrawButton       # Draw tiles from bag
└── PlayButton       # Commit play / End round
```

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `play_requested` | none | Play button pressed |
| `draw_requested` | none | Draw button pressed |

## EventBus Connections
- `score_updated` - Updates score display
- `hand_count_changed` - Updates hand count + draw button state
- `bag_count_changed` - Updates deck count + draw button state
- `discard_count_changed` - Updates discard count
- `play_completed` - Updates plays remaining
- `round_started` - Resets round display
- `run_round_ready` - Configures display for new round

## Public API
```gdscript
set_play_button_enabled(enabled: bool) -> void
set_play_button_mode(is_end_round: bool) -> void  # Toggles "Play" / "End Round" text
```

## Integration
- Connected to `GameplayController` via signals (`play_requested`, `draw_requested`)
- PlayHandler calls `set_play_button_enabled()` and `set_play_button_mode()` to manage button state
