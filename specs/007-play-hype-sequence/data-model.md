# Data Model: Play Hype Sequence

## HypeConfig (Resource)

**File**: `scripts/animation/hype/hype_config.gd`
**Type**: `Resource` (stored as `scripts/animation/hype/hype_config.tres`)
**Owner**: `TileAnimator` autoload (via `hype_config` property)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `master_speed_multiplier` | `float` | `1.0` | Player-facing game speed (0.5x to 2.0x). Runtime-settable. |
| `master_speed_min` | `float` | `0.5` | Minimum allowed master speed (for options screen bounds). |
| `master_speed_max` | `float` | `2.0` | Maximum allowed master speed (for options screen bounds). |
| `speed_scale_k` | `float` | `0.04` | Coefficient in tile-count formula. |
| `speed_scale_n` | `float` | `2.0` | Exponent in tile-count formula (must be > 1). |
| `tile_count_speed_min` | `float` | `1.0` | Minimum tile-count multiplier (1-tile plays). |
| `tile_count_speed_max` | `float` | `3.0` | Maximum tile-count multiplier (large plays). |
| `min_animation_duration` | `float` | `0.08` | No animation phase may fall below this threshold (seconds). |
| `animation_completion_threshold` | `float` | `0.65` | Normalized progress (0-1) at which a tile is considered "done" for score pop emission. For stomp: after slam, before recover. |
| `lift_scale` | `Vector2` | `Vector2(1.2, 1.2)` | Scale applied during the lift phase. |
| `lift_offset_y` | `float` | `-20.0` | Vertical pixel offset applied during lift (negative = up). |
| `lift_duration` | `float` | `0.12` | Duration of the lift phase (seconds). |
| `animation_mapping` | `Dictionary` | `{"EXTRA": "spin", "MULTI": "spin", "EXPO": "spin"}` | Maps modifier/tile-type key to animation preset name. Keys match tile modifier type strings. |
| `default_animation` | `String` | `"stomp"` | Fallback animation preset when a tile type is absent from `animation_mapping`. |
| `score_pop_travel_duration` | `float` | `0.4` | How long a score pop label takes to travel to HUD at 1x speed. |
| `score_pop_font_size` | `int` | `22` | Font size of floating score labels. |
| `pulse_base_scale` | `float` | `1.15` | The scale factor for a 1.0 intensity pulse (maps to existing behavior). |
| `pulse_intensity_max` | `float` | `3.0` | Maximum pulse intensity before clamping. |
| `secondary_effect_threshold` | `float` | `1.5` | Intensity at or above which secondary visual effect (shake) fires on score panel. |
| `secondary_effect_magnitude` | `float` | `4.0` | Pixel magnitude of the shake effect. |
| `debug_logging_enabled` | `bool` | `false` | Toggles structured debug logs (off by default). |
| `inter_tile_stagger_delay` | `float` | `0.06` | Base stagger delay between tiles (scaled by effective multiplier at runtime). |

**Computed (not stored)**:
- `tile_count_multiplier(n: int) -> float`: `clamp(1.0 + speed_scale_k * pow(n, speed_scale_n), tile_count_speed_min, tile_count_speed_max)`
- `effective_multiplier(tile_count: int) -> float`: `tile_count_multiplier(tile_count) * master_speed_multiplier`

---

## PlayHypeParams (Transient runtime struct, Dictionary)

**Owner**: `PlayExecutor` (stored per-play in `_hype_params`; cleared after play)
**Not persisted.**

| Key | Type | Description |
|-----|------|-------------|
| `tile_count` | `int` | Number of tiles in the play. |
| `effective_multiplier` | `float` | `tileCountMultiplier * masterSpeed` computed at play start. |
| `stomp_slam_time_scaled` | `float` | `(rise_duration + slam_duration) / effective_multiplier` |
| `stomp_stagger_scaled` | `float` | `stagger_delay / effective_multiplier` |
| `spin_up_time_scaled` | `float` | `spin_up_duration / effective_multiplier` |
| `spin_stagger_scaled` | `float` | `stagger_delay / effective_multiplier` |
| `score_travel_duration_scaled` | `float` | `score_pop_travel_duration / effective_multiplier` |
| `target_score` | `int` | Round target score at play start (for pulse intensity calculation). |

---

## ScorePopLabel (Transient UI node)

**Type**: `Label` node created dynamically, added to HUD CanvasLayer
**Lifecycle**: Created on tile score-commit, freed on arrival at score panel.

| Property | Value | Description |
|----------|-------|-------------|
| `text` | `"+N"` | Score contribution formatted as `"+%d" % delta`. |
| `font_size` | `HypeConfig.score_pop_font_size` | From config. |
| `start_position` | `tile.global_position + Vector2(0, -40)` | Above the tile. |
| `end_position` | `ScorePanel.get_score_label_target_position()` | Score panel's label target. |
| `travel_duration` | `HypeConfig.score_pop_travel_duration / effectiveMultiplier` | Scaled travel time. |
| `on_arrival` | `GameManager.add_tile_score(delta)` | Triggers score update on arrival. |

---

## Modified: EventBus Signals

### `score_updated` (modified)

```
signal score_updated(total_score: int, delta: int, pulse_intensity: float)
```

`pulse_intensity` is the computed `clamp(1.0 + delta / float(target_score), 1.0, pulse_intensity_max)`. Added as third parameter; existing subscribers with two-parameter connections remain valid in GDScript (extra args are silently ignored).

---

## Modified: BossTimerRelay

| Addition | Type | Description |
|----------|------|-------------|
| `_paused: bool` | `bool` | Set by `pause()`/`resume()`. Checked in `on_process()`. |
| `pause() -> void` | method | Sets `_paused = true`. No-op if not active. |
| `resume() -> void` | method | Sets `_paused = false`. No-op if not active. |

`on_process()` guard: `if not _is_active or _paused: return`.

---

## New EventBus Signals

| Signal | Parameters | Purpose |
|--------|-----------|---------|
| `play_sequence_started` | none | Emitted by `PlayExecutor` at start of `_execute_play`. Consumed by `RunManager` to pause boss timer. |
| `play_sequence_ended` | none | Emitted by `PlayExecutor` at end of `_execute_play` (after all score transfers). Consumed by `RunManager` to resume boss timer. |

---

## State Transitions: PlaySequence

```
IDLE
  -> SEQUENCE_ACTIVE  (Play pressed, sequence lock set, timer paused)
      -> LIFT_PHASE   (all tiles lift together)
      -> TILE_ANIMATION_PHASE  (stomp/spin per tile category)
      -> SCORE_TRANSFER_PHASE  (score pops fly, score increments on arrival)
      -> FINALIZING   (GameManager.end_play, consume modifiers)
  -> IDLE  (sequence lock cleared, timer resumed, hand refilled)
```
