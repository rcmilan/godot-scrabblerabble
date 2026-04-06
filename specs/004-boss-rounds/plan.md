# Implementation Plan: Boss Rounds and Round Counter

**Branch**: `004-boss-rounds` | **Date**: 2026-04-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-boss-rounds/spec.md`

## Summary

Introduce a Boss Round concept to Wordatro: every 3rd Round (3, 6, 9, ...) is a Boss Round. Concretely, this means (1) adding `is_boss_round` to the `RoundConfig` domain value object so any game system can query it, (2) driving a background color change in the main scene (white for Normal, light red for Boss) from that domain flag, (3) replacing the `MainHUD` round label with context-aware text ("Round N" vs "Boss Round"), (4) removing the `MultiSelectIndicator` node from the scene tree, and (5) updating the `AutoWinQuality` display text to use canonical terminology. The multi-select *mechanic* (Q key) is preserved; only the visual indicator is removed.

## Technical Context

**Language/Version**: GDScript 4.6 (Godot Engine 4.6)
**Primary Dependencies**: Godot Engine 4.6 — no external packages
**Storage**: N/A (no persistence changes)
**Testing**: Manual in Godot Editor (Constitution §V)
**Target Platform**: Desktop (Windows primary, via Godot export)
**Project Type**: Desktop game (Godot 4.6)
**Performance Goals**: 60 fps; no new compute-heavy logic added
**Constraints**: No Godot engine imports in `/scripts/domain`. No modals/dialogs per Constitution §Architecture.
**Scale/Scope**: Small feature — 6 files modified, 0 new files, 1 new scene node added

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Check | Status |
|-----------|-------|--------|
| I. Domain-Driven Design | `is_boss_round` logic lives in `ProgressionRules` (domain). `_is_boss_round()` is pure GDScript, no engine deps. UI reads from `RoundConfig`, never computes boss rule itself. | PASS |
| II. Decoupled Communication | Background color and HUD label both react to the existing `EventBus.run_round_ready` signal. No new direct coupling introduced. | PASS |
| III. Immutable Domain Objects | `RoundConfig.is_boss_round` is set once at construction in `ProgressionRules.get_round_config()`, not mutated afterward. | PASS |
| IV. Thin Controllers | `main.gd` and `main_hud.gd` read `config.is_boss_round` for visual updates only. No game rule logic in these layers. | PASS |
| V. Manual Testing First | Feature is manually verifiable: play to Round 3 and observe label + background change. | PASS |
| No Modals | N/A — no dialogs added. | PASS |
| EventBus as Hub | `run_round_ready` already carries `RoundConfig`. Adding `is_boss_round` to it satisfies all consumers. No new signal needed. | PASS |

## Project Structure

### Documentation (this feature)

```text
specs/004-boss-rounds/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks - not created here)
```

### Source Code (files modified)

```text
scripts/domain/
├── round_config.gd          # Add is_boss_round: bool field
└── progression_rules.gd     # Add _is_boss_round(), update get_round_config()

scripts/domain/qualities/
└── auto_win_quality.gd      # Update display text (get_quality_name, get_description)

scenes/
├── main.tscn                # Add Background ColorRect, add RoundIndicator Label (top-left),
|                            #   remove MultiSelectIndicator
└── main.gd                  # Update _on_round_ready() for bg color + round label,
                             #   remove multi_select_indicator refs, add round_indicator ref

scenes/ui/main_hud/
├── main_hud.gd              # No changes needed (top-right panel is debug; left untouched)
└── main_hud.tscn            # No changes needed
```

**Structure Decision**: Single-project GDScript codebase. All changes are in-place modifications to existing files. No new source files created. Two new scene nodes added inside `main.tscn`: a `Background` ColorRect and a `RoundIndicator` Label.

**Clarification applied (2026-04-06)**: The canonical round label is a NEW standalone Label at top-left (replacing MULTI [Q]), not the existing top-right RoundLabel in MainHUD. The top-right stats panel is a debug panel scheduled for future removal -- it is not touched by this feature.

## Complexity Tracking

No Constitution violations — no tracking required.

---

## Phase 0: Research

*Resolved via direct code inspection. No unknowns remain.*

See [research.md](research.md).

**Key decisions:**
- `is_boss_round: bool` added to `RoundConfig` (set at construction, immutable after)
- Boss classification: `round_number % 3 == 0` in `ProgressionRules._is_boss_round()`
- `MainHUD` caches `_current_is_boss: bool` from `run_round_ready` to drive label text
- Background `ColorRect` added to `main.tscn` as first child, driven from `main.gd._on_round_ready()`
- `MultiSelectIndicator` node removed from `main.tscn`; mechanic preserved, indicator gone
- `AutoWinQuality` description: capitalize "Plays" and "Rounds" only

## Phase 1: Design

See [data-model.md](data-model.md) and [quickstart.md](quickstart.md).

**Post-design Constitution Check**: All principles re-verified. No violations.

### Implementation Steps (ordered)

1. **`scripts/domain/round_config.gd`**
   - Add `var is_boss_round: bool = false`
   - Add `p_is_boss: bool = false` as last param to `_init()`
   - Assign `is_boss_round = p_is_boss` in body
   - Update `_to_string()` to append `" (Boss)"` when true

2. **`scripts/domain/progression_rules.gd`**
   - Add `func _is_boss_round(round_number: int) -> bool: return round_number % 3 == 0`
   - In `get_round_config()`: compute `var is_boss := _is_boss_round(round_num)`, pass as last arg to `RoundConfig.new()`

3. **`scripts/domain/qualities/auto_win_quality.gd`**
   - `get_description()`: change `"plays"` -> `"Plays"` and `"rounds"` -> `"Rounds"`

4. **`scenes/main.tscn`**
   - Remove `ext_resource` entry for `multi_select_indicator.tscn` (id `"6_multi"`)
   - Remove `[node name="MultiSelectIndicator" ...]` entry
   - Add `[node name="Background" type="ColorRect" parent="."]` as first child of Main, anchors_preset=15, color=white
   - Add `[node name="RoundIndicator" type="Label" parent="."]` at top-left, same position as the removed MULTI indicator (offset 20,20 approx), font_size=11

5. **`scenes/main.gd`**
   - Remove `@onready var multi_select_indicator` line
   - Remove `multi_select_indicator.set_selection_manager(_selection_manager)` call
   - Add `@onready var _background: ColorRect = $Background`
   - Add `@onready var _round_indicator: Label = $RoundIndicator`
   - Add `var _bg_tween: Tween = null` member variable
   - Add private method `_transition_background(target_color: Color) -> void` that kills any active `_bg_tween`, creates a new one, and tweens `_background.color` to `target_color` over 1.0s with `Tween.TRANS_SINE, Tween.EASE_IN_OUT`
   - In `_on_round_ready(config)`:
     - call `_transition_background(Color(1.0, 0.85, 0.85) if config.is_boss_round else Color.WHITE)`
     - set `_round_indicator.text = "Boss Round" if config.is_boss_round else "Round %d" % config.round_number`

6. **`scenes/ui/main_hud/main_hud.gd`** -- **no changes** (top-right panel is debug; left untouched)

**Verification**: Use [quickstart.md](quickstart.md) — play to Round 3 to confirm all visual changes.
