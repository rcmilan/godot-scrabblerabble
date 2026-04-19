# Quickstart: Tuning the Play Hype Sequence

## Adjusting Game Speed (Player-Facing Setting)

The master game speed multiplier is stored on the `HypeConfig` resource owned by `TileAnimator`:

```gdscript
# Set to half speed (accessibility / slow mode)
TileAnimator.hype_config.master_speed_multiplier = 0.5

# Set to double speed (turbo mode)
TileAnimator.hype_config.master_speed_multiplier = 2.0

# Reset to default
TileAnimator.hype_config.master_speed_multiplier = 1.0
```

Valid range: `0.5` to `2.0` (defined in `master_speed_min` and `master_speed_max`).

When wiring to an options screen slider, clamp the value:
```gdscript
TileAnimator.hype_config.master_speed_multiplier = clamp(
    slider.value,
    TileAnimator.hype_config.master_speed_min,
    TileAnimator.hype_config.master_speed_max
)
```

---

## Adjusting Tile-Count Speed Scaling

The exponential formula is `tileCountMultiplier = clamp(1 + k * tileCount^n, minSpeed, maxSpeed)`.

Edit `HypeConfig` defaults in `scripts/animation/hype/hype_config.tres` (or via the Godot Inspector):

| Parameter | Field | Effect |
|-----------|-------|--------|
| `k = 0.04` | `speed_scale_k` | Raise to make even small plays feel faster |
| `n = 2.0` | `speed_scale_n` | Raise to steepen the curve (7-tile feels more extreme vs 3-tile) |
| `maxSpeed = 3.0` | `tile_count_speed_max` | Cap for large plays |

---

## Adding a New Animation Preset

1. Create a new strategy file: `scripts/animation/{name}/{name}_tile_animation.gd` extending `TileAnimationStrategy`.
2. Register it in `TileAnimator._ensure_{name}_resources()` (lazy-load pattern).
3. Add `animate_{name}_batch(tiles)` to `TileAnimator`.
4. Add the preset name to `HypeConfig.animation_mapping`:
   ```
   # In hype_config.tres (Inspector) or at runtime:
   TileAnimator.hype_config.animation_mapping["MY_MODIFIER"] = "my_animation_name"
   ```
5. In `PlayExecutor._animate_play_from_cats()`, add the new category dispatch alongside stomp/spin.

No code changes to `AnimationCategorizer` or `PlayExecutor` core flow are needed for steps 1-4.

---

## Enabling Debug Logs

```gdscript
TileAnimator.hype_config.debug_logging_enabled = true
```

This outputs structured logs to the console:
```
[Play] tileCount=7 speedMultiplier=1.87
[Tile] type=Standard animation=stomp duration=0.19
[Tile] type=EXTRA animation=spin duration=0.19
[Score] delta=15 progress=0.10 intensity=1.10
```

---

## Tuning the Lift Phase

The lift phase runs before stomp/spin. Configure in `hype_config.tres`:

| Field | Default | Effect |
|-------|---------|--------|
| `lift_scale` | `Vector2(1.2, 1.2)` | How much tiles scale up during anticipation |
| `lift_offset_y` | `-20.0` | Pixels upward during lift (negative = up) |
| `lift_duration` | `0.12` | Duration in seconds (also scaled by effectiveMultiplier) |

---

## Tuning Pulse Intensity

| Field | Default | Effect |
|-------|---------|--------|
| `pulse_base_scale` | `1.15` | Scale at 1.0 intensity (matches original behavior) |
| `pulse_intensity_max` | `3.0` | Cap for extreme combos |
| `secondary_effect_threshold` | `1.5` | Intensity at which shake activates |
| `secondary_effect_magnitude` | `4.0` | Pixels of shake offset |
