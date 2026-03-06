# Auto-Refill Draw Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace manual "Draw Tiles" button with automatic hand refilling after Play and Discard.

**Architecture:** Remove Draw button/signal/keybind, add auto-refill with 0.5s delay in PlayHandler after play animations. `hand_size` is a refill target, not a hard limit.

**Tech Stack:** GDScript, Godot 4.x

---

### Task 1: Remove DrawButton from main_hud.tscn

**Files:**
- Modify: `scenes/ui/main_hud/main_hud.tscn:123-128`

**Step 1: Remove DrawButton node**

Delete lines 123-128 from the .tscn file (the `[node name="DrawButton" ...]` block):

```
[node name="DrawButton" type="Button" parent="."]
offset_left = 865.0
offset_top = 498.0
offset_right = 965.0
offset_bottom = 528.0
text = "Draw Tiles"
```

**Step 2: Commit**

```bash
git add scenes/ui/main_hud/main_hud.tscn
git commit -m "feat: remove DrawButton node from MainHUD scene"
```

---

### Task 2: Remove draw button code from main_hud.gd

**Files:**
- Modify: `scenes/ui/main_hud/main_hud.gd`

**Step 1: Remove draw_requested signal (line 8)**

Delete:
```gdscript
signal draw_requested
```

**Step 2: Remove draw_button @onready reference (line 18)**

Delete:
```gdscript
@onready var draw_button: Button = $DrawButton
```

**Step 3: Remove draw_button connection from _setup_buttons() (line 51)**

Change:
```gdscript
func _setup_buttons() -> void:
	draw_button.pressed.connect(_on_draw_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.disabled = true
```

To:
```gdscript
func _setup_buttons() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.disabled = true
```

**Step 4: Remove _update_draw_button call from _on_hand_count_changed (line 75)**

Change:
```gdscript
func _on_hand_count_changed(count: int) -> void:
	_update_hand(count)
	_update_draw_button(count)
```

To:
```gdscript
func _on_hand_count_changed(count: int) -> void:
	_update_hand(count)
```

**Step 5: Remove _update_draw_button call from _on_bag_count_changed (line 80)**

Change:
```gdscript
func _on_bag_count_changed(count: int) -> void:
	_update_deck(count)
	_update_draw_button(HandManager.get_hand_size())
```

To:
```gdscript
func _on_bag_count_changed(count: int) -> void:
	_update_deck(count)
```

**Step 6: Remove _on_draw_button_pressed handler (lines 212-213)**

Delete:
```gdscript
func _on_draw_button_pressed() -> void:
	draw_requested.emit()
```

**Step 7: Remove entire Draw Button State section (lines 220-239)**

Delete:
```gdscript
# === Draw Button State ===

var _draw_button_blocked: bool = false


func set_draw_button_blocked(blocked: bool) -> void:
	_draw_button_blocked = blocked
	if blocked:
		draw_button.disabled = true
	else:
		_update_draw_button(HandManager.get_hand_size())


func _update_draw_button(hand_count: int) -> void:
	if _draw_button_blocked:
		draw_button.disabled = true
		return
	var hand_full: bool = hand_count >= HandManager.hand_size
	var bag_empty: bool = TileBag.is_empty()
	draw_button.disabled = hand_full or bag_empty
```

**Step 8: Commit**

```bash
git add scenes/ui/main_hud/main_hud.gd
git commit -m "feat: remove draw button code from MainHUD"
```

---

### Task 3: Remove draw handling from gameplay_controller.gd

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Remove DRAW_TILES keyboard shortcut (lines 112-114)**

Delete:
```gdscript
	if event.is_action_pressed(KeyAction.DRAW_TILES):
		_on_draw_requested()
		get_viewport().set_input_as_handled()
```

**Step 2: Remove draw_requested signal connection (line 192)**

Change:
```gdscript
	if main_hud:
		_tracker.track(main_hud.draw_requested, _on_draw_requested)
		_tracker.track(main_hud.play_requested, _on_play_requested)
```

To:
```gdscript
	if main_hud:
		_tracker.track(main_hud.play_requested, _on_play_requested)
```

**Step 3: Remove draw_blocked_changed connection (lines 142-144)**

Delete:
```gdscript
	_play.draw_blocked_changed.connect(
		func(blocked): main_hud.set_draw_button_blocked(blocked)
	)
```

**Step 4: Remove _on_draw_requested method and DRAW HANDLER section (lines 805-815)**

Delete:
```gdscript
# =============================================================================
# DRAW HANDLER
# =============================================================================

func _on_draw_requested() -> void:
	if not _is_active:
		return

	var drawn: int = HandManager.refill_hand()
	print("[Gameplay] Draw requested: refilled %d tiles" % drawn)
```

**Step 5: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: remove draw button handling from GameplayController"
```

---

### Task 4: Remove draw_blocked_changed signal from play_handler.gd and add auto-refill

**Files:**
- Modify: `scripts/controllers/play_handler.gd`

**Step 1: Remove draw_blocked_changed signal declaration (line 13)**

Delete:
```gdscript
signal draw_blocked_changed(blocked: bool)
```

**Step 2: Remove draw blocking emissions and add auto-refill in on_play_requested()**

Change lines 83-98 (from "Block draw button" through "draw_blocked_changed.emit(false)"):
```gdscript
	# Block draw button during play animations
	draw_blocked_changed.emit(true)

	var animation_count: int = 0
	if not stomp_tiles.is_empty():
		TileAnimator.animate_stomp_batch(stomp_tiles)
		animation_count += 1
	if not spin_tiles.is_empty():
		TileAnimator.animate_spin_batch(spin_tiles)
		animation_count += 1

	# Wait for all animations to complete before committing the play
	for i in animation_count:
		await TileAnimator.animation_completed

	draw_blocked_changed.emit(false)
```

To:
```gdscript
	var animation_count: int = 0
	if not stomp_tiles.is_empty():
		TileAnimator.animate_stomp_batch(stomp_tiles)
		animation_count += 1
	if not spin_tiles.is_empty():
		TileAnimator.animate_spin_batch(spin_tiles)
		animation_count += 1

	# Wait for all animations to complete before committing the play
	for i in animation_count:
		await TileAnimator.animation_completed
```

**Step 3: Add auto-refill after play completes**

After `play_completed.emit(unplayed_tiles, words)` (line 105) and before `update_play_button_state()` (line 107), add a 0.5s delay and refill:

Change:
```gdscript
	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

	update_play_button_state()
```

To:
```gdscript
	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

	# Auto-refill hand after a brief delay so player sees the result
	await board.get_tree().create_timer(0.5).timeout
	HandManager.refill_hand()

	update_play_button_state()
```

Note: PlayHandler is RefCounted and cannot call `get_tree()` directly. Use `board.get_tree()` since `board` is an injected Node reference.

**Step 4: Commit**

```bash
git add scripts/controllers/play_handler.gd
git commit -m "feat: replace draw blocking with auto-refill after play"
```

---

### Task 5: Remove Draw hint from keyboard_hint_bar.gd

**Files:**
- Modify: `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd:9-10`

**Step 1: Remove Draw hint entry**

Change:
```gdscript
var HINTS: Array[Dictionary] = [
	{ action = KeyAction.PLAY_HAND,     label = "Play"    },
	{ action = KeyAction.DRAW_TILES,    label = "Draw"    },
	{ action = KeyAction.DISCARD_TILES, label = "Discard" },
	{ action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
	{ action = KeyAction.SWITCH_ZONE,   label = "Zone"    },
	{ action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]
```

To:
```gdscript
var HINTS: Array[Dictionary] = [
	{ action = KeyAction.PLAY_HAND,     label = "Play"    },
	{ action = KeyAction.DISCARD_TILES, label = "Discard" },
	{ action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
	{ action = KeyAction.SWITCH_ZONE,   label = "Zone"    },
	{ action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]
```

**Step 2: Commit**

```bash
git add scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd
git commit -m "feat: remove Draw hint from keyboard hint bar"
```

---

### Task 6: Verify and clean up

**Step 1: Search for any remaining draw_requested or draw_button references**

```bash
grep -rn "draw_requested\|draw_button\|DrawButton\|_on_draw_button\|set_draw_button_blocked\|_update_draw_button\|_draw_button_blocked\|draw_blocked_changed" --include="*.gd" --include="*.tscn"
```

Expected: No matches in code files (only in docs/plans).

**Step 2: Search for DRAW_TILES references that should remain**

```bash
grep -rn "DRAW_TILES" --include="*.gd"
```

Expected: Only in `key_action.gd` (constant definition) and `run_setup_popup.gd` (input guard — unrelated to gameplay). The constant can stay; removing it would be churn.

**Step 3: Run the game and test**

Manual test checklist:
- [ ] No Draw button visible in HUD
- [ ] After playing tiles, 0.5s delay then hand refills automatically
- [ ] After discarding tiles, hand refills immediately
- [ ] If hand has more tiles than `hand_size`, no refill occurs
- [ ] If bag is empty, no error — just draws what it can
- [ ] Keyboard hint bar shows no "Draw" hint

**Step 4: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "feat: complete auto-refill draw system"
```
