# Phase 5 Testing Guide - Per-Tile Score Pop Labels

## What Changed
Replaced concurrent stagger-based scoring (_commit_scores_staggered) with floating score pop labels that:
1. Appear above each tile after animation completes
2. Travel smoothly to the score panel
3. Trigger score increment only when arriving at the HUD

## Test Scenario 1: Basic Score Pop Labels

1. Start a new round with any deck
2. Place 3-5 tiles on the board
3. Press Play
4. Observe:
   - All tiles lift uniformly (lift phase)
   - Tiles animate (stomp/spin based on modifiers)
   - Yellow "+X" labels pop above each tile
   - Labels travel smoothly from tile positions to score panel
   - Score counter updates ONLY as each label arrives (not before)
   - Multiple labels in flight don't merge or interfere

Expected: Score increments should appear staggered as labels arrive, not all at once.

## Test Scenario 2: Speed Scaling + Score Pop Travel

1. Set `TileAnimator.hype_config.master_speed_multiplier = 2.0` (fast)
2. Place 7 tiles on board
3. Press Play
4. Observe: Labels travel faster proportionally to animation speed

Repeat with master_speed_multiplier = 0.5 (slow):
- Labels travel slower
- All animations remain coordinated

## Test Scenario 3: Single Tile Play

1. Place 1 tile on board
2. Press Play
3. Observe: Label appears and travels correctly
4. Speed should be minimum (near 1.0x multiplier)

## Test Scenario 4: Debug Logging

1. In HypeConfig inspector, enable `debug_logging_enabled`
2. Play any word
3. Check console output for:
   - `[Play] tileCount=N speedMultiplier=X.XX`
   - `[Score] delta=N cumulative=N progress=X.XX%` for each label arrival
4. Progress should go from 0% toward target score percentage

## Verification Checklist

- [ ] Score pop labels appear above all tiles after animation
- [ ] Labels entrance animation is smooth (fade + scale)
- [ ] Labels travel to score panel with easing
- [ ] Score increments ONLY when label arrives (not before)
- [ ] Multiple labels in flight move independently
- [ ] Labels respect speed multiplier (faster plays = faster travel)
- [ ] Single tile plays work correctly
- [ ] Debug logging shows correct delta and progress values
- [ ] Auto-end-round with multiple plays shows labels for each play
- [ ] Score panel pulse intensity responds to each label arrival

## Known Behavior

- Labels are parented to MainHUD CanvasLayer, so they render above game UI
- Travel duration is scaled by effective multiplier (like animations)
- If ScorePanel not found in scene, warning printed and score transfer skipped
- Callbacks wait for all labels to complete before exiting _emit_score_pops

## If Issues Occur

Check console for errors like:
- `Warning: ScorePanel not found in scene` - scene hierarchy issue
- Nil reference errors - check ScorePopLabel is properly instantiated
- Score not incrementing - check EventBus.score_updated signal is emitted
