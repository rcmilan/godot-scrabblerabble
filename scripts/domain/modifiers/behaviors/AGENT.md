# Modifier Behaviors — Agent Guide

## Purpose

This folder contains the **Strategy pattern** implementations for modifier effects. Each behavior defines three things: how it changes a tile's score, how it looks (tint color), and what badge symbol it shows.

## Architecture

```
ModifierBehavior (abstract base)
  |-- ExtraBehavior   (+N additive bonus)
  |-- MultiBehavior   (xN multiplicative bonus)
  |-- ResetBehavior   (score -> 0, invert shader)
  |-- ExpoBehavior    (score^N exponential)
  |-- LockedBehavior  (no-op, visual handled externally)
```

All behaviors are RefCounted. One instance per type is created by `ModifierRegistry` and shared across all tiles.

## Base Class: ModifierBehavior (modifier_behavior.gd)

Three virtual methods to override:

| Method | Default | Purpose |
|--------|---------|---------|
| `compute(base_score, tier) -> int` | returns `base_score` | Score transformation |
| `get_visual(tier) -> Dictionary` | `{tint: WHITE, invert: false}` | Tile coloring |
| `get_badge_symbol() -> String` | `""` (empty) | Badge character on tile |

## Concrete Behaviors

### ExtraBehavior — Additive bonus

- **Scoring**: `base_score + bonus` where bonus = Bronze:2, Silver:5, Gold:10
- **Tint**: Bronze = warm brown `(0.85, 0.72, 0.53)`, Silver = cool gray `(0.75, 0.75, 0.85)`, Gold = gold `(1.0, 0.84, 0.0)`
- **Badge**: `"+"`
- **Animation**: Spin (scale pulse + 360 rotation)

### MultiBehavior — Multiplicative bonus

- **Scoring**: `base_score * multiplier` where multiplier = Bronze:2, Silver:5, Gold:10
- **Tint**: Bronze = light blue `(0.6, 0.8, 1.0)`, Silver = medium blue `(0.5, 0.65, 1.0)`, Gold = deep blue `(0.35, 0.5, 1.0)`
- **Badge**: `"x"`
- **Animation**: Spin

### ExpoBehavior — Exponential bonus

- **Scoring**: `pow(base_score, exponent)` where exponent = Bronze:2, Silver:3, Gold:5
- **Tint**: Bronze = red `(1.0, 0.55, 0.55)`, Silver = orange `(1.0, 0.7, 0.4)`, Gold = purple `(0.6, 0.4, 1.0)`
- **Badge**: `"^"`
- **Animation**: Spin
- **Special**: Tile gets a `TileSparkEffect` (particle sparks) — managed by `Tile._add_spark_effect()`

### ResetBehavior — Score nullifier

- **Scoring**: Always returns `0`, regardless of base_score or tier
- **Tint**: `Color.WHITE` with `invert: true` (applies invert shader to texture)
- **Badge**: `""` (empty — no badge symbol, the invert shader IS the visual)
- **Animation**: Stomp (Reset denies spin animation — always stomps)
- **Visual dominance**: When RESET is present, `ModifierVisualPipeline` returns `invert=true` with NO badges from any modifier, even if EXTRA/MULTI/EXPO are also present

### LockedBehavior — Board lock (no-op behavior)

- **Scoring**: Returns `base_score` unchanged (passthrough)
- **Tint**: `Color.WHITE` (no tint)
- **Badge**: `""` (no badge)
- **Visual**: Not handled here. The black border is managed by `Tile._update_visual()` via `locked_border.visible = is_locked`
- **Not in pipeline**: LOCKED is not in `ModifierPipeline.execution_order`, so it's skipped by both scoring and visual pipelines

## Scoring Pipeline Order

Modifiers execute in `ModifierPipeline.execution_order`: **RESET -> EXTRA -> EXPO -> MULTI**

Example with RESET + EXTRA(Bronze) + MULTI(Bronze) on a 3-point tile:
```
base = 3
RESET:  3 -> 0
EXTRA:  0 -> 0 + 2 = 2
EXPO:   (not present, skip)
MULTI:  2 -> 2 * 2 = 4
```

Example with EXTRA(Silver) + EXPO(Bronze) on a 3-point tile:
```
base = 3
RESET:  (not present, skip)
EXTRA:  3 -> 3 + 5 = 8
EXPO:   8 -> 8^2 = 64
MULTI:  (not present, skip)
Result: 64
```

## Adding a New Behavior

1. Create a new file `your_behavior.gd` in this folder
2. Extend `ModifierBehavior` with `class_name YourBehavior`
3. Override `compute()` for scoring effect (or leave default for no scoring impact)
4. Override `get_visual()` for tint color per tier (return `{tint: Color, invert: bool}`)
5. Override `get_badge_symbol()` for the badge character (or leave empty for no badge)
6. Register in `ModifierRegistry._ensure_initialized()`
7. Add the Type enum to `ModifierTypes.Type`
8. If it affects scoring/visuals: add to `ModifierPipeline.execution_order` in correct position
9. If it needs a play animation: add dispatch logic in `PlayHandler.on_play_requested()` (spin vs stomp)

## Rules for Behavior Implementations

- `compute()` must be a **pure function** — no side effects, no state mutation
- `get_visual()` must return a Dictionary with keys `tint` (Color) and `invert` (bool)
- Tiers scale the effect strength. All tier-dependent values use const Dictionaries for easy tuning
- Behaviors are **shared singletons** — one instance per type across all tiles. Never store per-tile state in a behavior
- The `tier` parameter comes from the `ModifierInstance`, not the behavior itself
