# Cursor Visual Polish Design

**Date:** 2026-02-21

## Goal

Four targeted improvements to the keyboard/controller cursor system introduced in the previous session:
1. Cursor hover over hand tile → brightness only (no border)
2. Selection border color → bright yellow (replaces green)
3. Keyboard tile placement → glide animation from hand to board cell
4. RunSetupPopup → WASD navigation alongside existing arrow keys

---

## Item 1 — Cursor Hover: Brightness Only

### Current Behavior
`FocusCursor` calls `tile.set_cursor_highlighted(true)` when navigating over a hand tile. In `_update_visual()`, this currently sets `border.visible = is_selected or _is_cursor_highlighted`, showing the green border even while just hovering.

### Desired Behavior
Hovering = brightness effect only (same as mouse hover). Border appears only on actual selection (`is_selected = true`).

### Change
**File:** `scenes/tile/tile.gd`, `_update_visual()`

```gdscript
# Before
border.visible = is_selected or _is_cursor_highlighted

# After
border.visible = is_selected
```

The brightness in `_apply_modifier_visual()` remains driven by `_is_cursor_highlighted` — no other changes needed.

---

## Item 2 — Yellow Selection Border

### Current Behavior
`StyleBoxFlat_vb0gs` in `Tile.tscn` has `border_color = Color(0.113, 0.602, 0.195, 1)` (green).

### Desired Behavior
Bright golden yellow border for both click-selection and cursor confirmation.

### Change
**File:** `scenes/tile/Tile.tscn`, `StyleBoxFlat_vb0gs`

```
border_color = Color(1.0, 0.85, 0.1, 1)
```

No code changes — pure scene data edit.

---

## Item 3 — Keyboard Placement Animation

### Current Behavior
When the cursor confirms a tile from hand to board, `place_tile_on_cell()` is called synchronously — the tile teleports to the cell with no animation. Mouse drag-and-drop has the same instant placement.

### Desired Behavior
Keyboard confirm triggers a glide animation: tile smoothly travels from its hand position to the board cell position, reusing `GlideTileAnimation` (0.35s, TRANS_BACK bounce). Drag placement is unaffected.

### Architecture

Mirrors `ReturnAnimationExecutor.execute_single()` but in the reverse direction (hand → board instead of board → hand):

1. Capture tile's current `global_position` (in hand)
2. Call synchronous `place_tile_on_cell(tile, cell)` — reparents tile to board, sets up binding, attaches to cell
3. `await get_tree().process_frame` — wait for layout
4. Compute local offset = `captured_global_pos - tile.global_position`; shift tile's local `position` by that offset (visually at hand position)
5. Tween `tile.position` to `Vector2.ZERO` (final cell-local position) using `GlideTileAnimation` settings

### Files

| File | Change |
|------|--------|
| `scripts/animation/glide/return_animation_executor.gd` | Add `execute_place_to_board(tile, cell_node, strategy)` |
| `autoload/tile_animator.gd` | Add `animate_place_to_board(tile, cell_node)` |
| `scripts/controllers/tile_placement_handler.gd` | Add `place_tile_animated(tile, cell)` async method |
| `scripts/controllers/gameplay_controller.gd` | Call `place_tile_animated` for keyboard cursor confirms only |

### Signal Flow

```
FocusCursor.cursor_confirmed(HAND, index)
  → GameplayController._on_cursor_confirmed()
      → (if tile in hand and board zone confirmed)
          → _placement.place_tile_animated(tile, cell)   ← async, awaits animation
```

Drag placement continues to use the synchronous `place_tile_on_cell()` path — no change there.

### Key Constraint
Must not tween `modulate` (carries modifier tint). Only tween `position`. This is already satisfied by `GlideTileAnimation.get_end_properties()` which returns `{"scale": Vector2.ONE}` — no modulate.

---

## Item 4 — WASD in RunSetupPopup

### Current Behavior
`RunSetupPopup` uses Godot's built-in focus traversal (responds to `ui_up`/`ui_down`). Arrow keys and D-pad work. WASD does not because W/S are mapped to `navigate_up`/`navigate_down` (game actions), not `ui_up`/`ui_down`.

### Desired Behavior
W/S (and A/D) navigate focus within the popup exactly as arrow keys do.

### Approach
In `run_setup_popup._input()`, intercept `navigate_up/down/left/right` and re-inject as `ui_up/down/left/right` via `Input.parse_input_event()`. No loop risk: W is exclusive to `navigate_up`; the injected `ui_up` only maps to arrow keys / D-pad.

### Change
**File:** `scenes/title_screen/run_setup_popup.gd`, `_input()`

```gdscript
# After the visibility guard and rebind capture, before ui_cancel check:
var nav_map := {
    "navigate_up":    "ui_up",
    "navigate_down":  "ui_down",
    "navigate_left":  "ui_left",
    "navigate_right": "ui_right",
}
for game_action in nav_map:
    if event.is_action_pressed(game_action):
        var fake := InputEventAction.new()
        fake.action = nav_map[game_action]
        fake.pressed = true
        Input.parse_input_event(fake)
        get_viewport().set_input_as_handled()
        return
```

---

## Out of Scope

- Cursor animations on board cells (cursor rect already works via Panel)
- Sound effects for cursor movement or placement
- Animation for returning tile from board to hand via keyboard (already exists via right-click path)
