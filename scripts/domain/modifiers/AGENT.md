# Modifier System — Agent Guide

## Purpose

This folder contains the **composable tile modifier system**. Modifiers alter a tile's scoring, visual appearance, and behavior. A tile can have multiple modifiers simultaneously (one per Type). The system is split into data (types, instances), orchestration (pipeline, registry), and output (scoring, visuals).

## File Map

| File | Role |
|------|------|
| `modifier_types.gd` | Enum definitions: Type, Lifetime, Tier |
| `modifier_instance.gd` | Value object attaching a behavior to a tile |
| `modifier_pipeline.gd` | Single source of truth for execution order |
| `modifier_registry.gd` | Static factory — creates ModifierInstance with correct behavior |
| `modifier_scoring.gd` | Pure scoring pipeline — applies modifiers to a base score |
| `modifier_visual_pipeline.gd` | Pure visual pipeline — computes tint, invert, badges |

## Enums (modifier_types.gd)

```
Type:     NONE | EXTRA | MULTI | RESET | EXPO | LOCKED
Lifetime: CONSUMABLE | PER_ROUND | PERMANENT
Tier:     BRONZE | SILVER | GOLD
```

- **Type**: What the modifier does. One modifier per Type per tile.
- **Lifetime**: When the modifier gets removed. CONSUMABLE = after a play, PER_ROUND = at round end, PERMANENT = never auto-removed.
- **Tier**: Scales the modifier's effect (higher tier = stronger).

## ModifierInstance (modifier_instance.gd)

Immutable value object. Fields: `type`, `tier`, `lifetime`, `behavior` (a ModifierBehavior subclass or null).

Always create via `ModifierRegistry.create_modifier(type, tier, lifetime)` — never construct directly. The registry attaches the correct behavior automatically.

## ModifierPipeline (modifier_pipeline.gd)

`execution_order: Array[int]` defines the order modifiers are applied in **both** scoring and visual badge display:

```
RESET -> EXTRA -> EXPO -> MULTI
```

LOCKED is intentionally absent — it has no scoring or visual pipeline effect (its visual is the black border handled by Tile directly).

This array is the single source of truth. If you add a new modifier type that affects scoring or visuals, add it here in the correct position.

## ModifierRegistry (modifier_registry.gd)

Static factory with lazy initialization. Maps each Type to its ModifierBehavior subclass.

```gdscript
# Creating a modifier:
var mod = ModifierRegistry.create_modifier(
    ModifierTypes.Type.EXTRA,
    ModifierTypes.Tier.SILVER,
    ModifierTypes.Lifetime.PER_ROUND
)

# Getting a behavior directly:
var behavior = ModifierRegistry.get_behavior(ModifierTypes.Type.MULTI)
```

When adding a new modifier type: register its behavior in `_ensure_initialized()`.

## ModifierScoring (modifier_scoring.gd)

Pure static function. Takes a base score and a tile's modifier dictionary, returns `{score: int, modifiers_applied: Array[Dictionary]}`.

Iterates `ModifierPipeline.execution_order`, calling `behavior.compute(score, tier)` on each present modifier. The order matters:
1. RESET sets score to 0
2. EXTRA adds to 0 (so +2/5/10 from zero)
3. EXPO exponentiates
4. MULTI multiplies the result

Modifiers not in `execution_order` (like LOCKED) are skipped entirely.

## ModifierVisualPipeline (modifier_visual_pipeline.gd)

Pure static function. Takes a tile's modifier dictionary, returns `{tint: Color, invert: bool, badges: Array[Dictionary]}`.

Rules:
- **Empty modifiers** -> white tint, no invert, no badges.
- **RESET present** -> white tint, invert=true, NO badges (Reset dominates visually — denies all other visuals).
- **Otherwise** -> first non-white tint in pipeline order wins; badges collected for all modifiers with non-empty symbols.

LOCKED is not in `execution_order`, so it never contributes tint or badges. Its visual (black border) is handled separately by `Tile._update_visual()`.

## How Tile Uses This System

```
Tile.modifiers: Dictionary  # keyed by ModifierTypes.Type -> ModifierInstance

Tile.add_modifier(mod)      # Stores in dict, syncs is_locked if LOCKED, updates visual
Tile.remove_modifier(type)  # Erases from dict, syncs is_locked, updates visual
Tile.consume_modifiers()    # Removes CONSUMABLE modifiers after a play
Tile.clear_round_modifiers() # Removes CONSUMABLE + PER_ROUND at round end
Tile.set_locked(bool)       # Creates/removes LOCKED modifier via registry
```

The tile calls `ModifierVisualPipeline.compute_tile_visual(modifiers)` to determine its appearance, and scoring goes through `ModifierScoring.compute_tile_score(base, modifiers)`.

## Adding a New Modifier Type

1. Add the enum value to `ModifierTypes.Type`
2. Create a behavior class in `behaviors/` extending `ModifierBehavior`
3. Register it in `ModifierRegistry._ensure_initialized()`
4. If it affects scoring or visuals: add it to `ModifierPipeline.execution_order` in the correct position
5. If it needs a special visual (like LOCKED's border): handle it in `Tile._update_visual()`

## Critical Rules

- **Never tween `modulate` in animations.** `modulate` carries the modifier tint. Animations use scale, position, rotation only. Draw animation may tween `modulate:a` (alpha only) to preserve RGB.
- **One modifier per Type per tile.** Adding a modifier of an existing type overwrites it.
- **Pipeline order is the single source of truth** for both scoring computation and badge display order.
- **RESET dominates visuals** — when present, it forces invert=true with no badges, regardless of other modifiers. In scoring, it sets score to 0 first, but subsequent modifiers (EXTRA, EXPO, MULTI) still apply on top of that 0.
- **LOCKED is special** — it's in the registry but NOT in the pipeline. It has no scoring effect, no tint, no badge. Its visual is the black LockedBorder panel.
