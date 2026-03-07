# Typing Mode Orientation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement orientation toggle feature allowing players to switch between horizontal and vertical tile placement directions in typing mode with persistent state throughout the run.

**Architecture:** RunOrientationState is an immutable value object representing game orientation. FocusCursor receives orientation via dependency injection, detects TAB key input, and emits orientation_toggled signal. OrientationIconButton is a new UI component (32x32px, top-left) showing current orientation and detecting clicks. GameplayController coordinates state changes by listening to orientation_toggled signals and updating the typing session with new orientation. BoardTypingSession's word-wrap logic handles both horizontal (row wrapping) and vertical (column wrapping) modes.

**Tech Stack:** GDScript 2.0, Godot 4.x, immutable value objects, signal-based architecture, OOP/DDD patterns

---

### Task 1: Create RunOrientationState Domain Model

**Files:**
- Create: `scripts/domain/run_orientation_state.gd`

**Step 1: Write the immutable value object**

Create new file `scripts/domain/run_orientation_state.gd`:

```gdscript
class_name RunOrientationState extends RefCounted

## Immutable value object representing typing mode orientation.
## Horizontal: tiles placed left-to-right, wrap to next row
## Vertical: tiles placed top-to-bottom, wrap to next column

var orientation: Vector2i  # Vector2i(1, 0) = horizontal, Vector2i(0, 1) = vertical


static func horizontal() -> RunOrientationState:
	var state := RunOrientationState.new()
	state.orientation = Vector2i(1, 0)
	return state


static func vertical() -> RunOrientationState:
	var state := RunOrientationState.new()
	state.orientation = Vector2i(0, 1)
	return state


func is_horizontal() -> bool:
	return orientation == Vector2i(1, 0)


func is_vertical() -> bool:
	return orientation == Vector2i(0, 1)


func toggled() -> RunOrientationState:
	if is_horizontal():
		return vertical()
	else:
		return horizontal()


func _to_string() -> String:
	return "RunOrientationState(%s)" % ("horizontal" if is_horizontal() else "vertical")
```

**Step 2: Verify the code compiles**

Run: `cd C:\Users\suporte\Documents\dev && godot --headless --script addons/gut/run.gd 2>&1 | head -20`

Expected: No compilation errors (or GUT startup output, no gdscript errors)

**Step 3: Verify immutability by creating a simple test**

In GDScript interactive test context, verify:
- `RunOrientationState.horizontal().orientation == Vector2i(1, 0)` ✓
- `RunOrientationState.vertical().orientation == Vector2i(0, 1)` ✓
- `RunOrientationState.horizontal().toggled().is_vertical() == true` ✓
- `RunOrientationState.horizontal().toggled() != RunOrientationState.horizontal()` (new instance) ✓

**Step 4: Commit**

```bash
git add scripts/domain/run_orientation_state.gd
git commit -m "feat: add RunOrientationState immutable value object for typing orientation"
```

---

### Task 2: Update FocusCursor to Accept Orientation Dependency

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd:1-100` (setup and fields)

**Step 1: Add orientation-related fields and signal**

In `focus_cursor.gd`, after line 16 (after `signal backspace_pressed`), add:

```gdscript
signal orientation_toggled(new_state: RunOrientationState)
```

After line 40 (after `var _hand: Hand = null`), add:

```gdscript
var _orientation_state: RunOrientationState = null
```

**Step 2: Update setup() method signature**

Replace the current `setup()` method (line 58-60):

```gdscript
func setup(board: Board, hand: Hand, orientation_state: RunOrientationState) -> void:
	_board = board
	_hand = hand
	_orientation_state = orientation_state
```

**Step 3: Add getter for orientation**

After the `setup()` method, add:

```gdscript
func get_orientation() -> Vector2i:
	if _orientation_state == null:
		return Vector2i(1, 0)  # Default to horizontal
	return _orientation_state.orientation
```

**Step 4: Add method to set orientation state**

After `get_orientation()`, add:

```gdscript
func set_orientation_state(new_state: RunOrientationState) -> void:
	if new_state == null or new_state == _orientation_state:
		return
	_orientation_state = new_state
	if _typing_session != null:
		_typing_session = BoardTypingSession.create_with_orientation(_board, _typing_session.cursor_pos, new_state.orientation)
		_update_typing_cursor_visual()
```

**Step 5: Update activate() to validate orientation_state**

In the `activate()` method (line 64-68), add after line 68:

```gdscript
	if _orientation_state == null:
		_orientation_state = RunOrientationState.horizontal()
```

**Step 6: Add TAB key handling to _input()**

In the `_input()` method, add this before the `if event is InputEventKey` block (around line 217):

```gdscript
	# TAB to toggle orientation (board zone only)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_TAB:
			if _state.position.is_board():
				var new_state := _orientation_state.toggled()
				set_orientation_state(new_state)
				orientation_toggled.emit(new_state)
			get_viewport().set_input_as_handled()
			return
```

**Step 7: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "feat: add orientation dependency injection and TAB handling to FocusCursor"
```

---

### Task 3: Update BoardTypingSession to Support Vertical Wrapping

**Files:**
- Modify: `scripts/interaction/board_typing_session.gd:1-105`

**Step 1: Add vertical orientation constant and factory with orientation parameter**

In `board_typing_session.gd`, after line 7 (after `_HORIZONTAL`), add:

```gdscript
const _VERTICAL := Vector2i(0, 1)
```

Update the `create()` static method to become:

```gdscript
static func create(p_board: Board, start_pos: Vector2i) -> BoardTypingSession:
	return create_with_orientation(p_board, start_pos, _HORIZONTAL)


static func create_with_orientation(p_board: Board, start_pos: Vector2i, orientation: Vector2i) -> BoardTypingSession:
	var s := BoardTypingSession.new()
	s.board = p_board
	s.cursor_pos = start_pos
	s.orientation = orientation
	s.history = []
	return s
```

**Step 2: Update _wrap_pos() to handle both orientations**

Replace the `_wrap_pos()` method (lines 86-89) with:

```gdscript
func _wrap_pos(pos: Vector2i) -> Vector2i:
	if orientation == _HORIZONTAL and pos.x >= board.columns:
		return Vector2i(0, pos.y + 1)
	elif orientation == _VERTICAL and pos.y >= board.rows:
		return Vector2i(pos.x + 1, 0)
	return pos
```

**Step 3: Verify orientation field initialization in _clone()**

The `_clone()` method already copies `orientation`, so no changes needed. Verify line 74 is present:

```gdscript
	s.orientation = orientation
```

**Step 4: Test the implementation**

In the scene, when you call:
- `BoardTypingSession.create(board, Vector2i(0, 0))` → orientation defaults to horizontal ✓
- `BoardTypingSession.create_with_orientation(board, Vector2i(0, 0), Vector2i(0, 1))` → orientation is vertical ✓
- In horizontal mode: position wraps columns first, then rows
- In vertical mode: position wraps rows first, then columns

**Step 5: Commit**

```bash
git add scripts/interaction/board_typing_session.gd
git commit -m "feat: add vertical wrapping support to BoardTypingSession"
```

---

### Task 4: Create OrientationIconButton UI Component

**Files:**
- Create: `scenes/board/orientation_icon_button.gd`

**Step 1: Create the script**

Create new file `scenes/board/orientation_icon_button.gd`:

```gdscript
extends TextureButton
class_name OrientationIconButton

## Small UI button (32x32px) in top-left corner of board.
## Shows current orientation (letter_H.png for horizontal, letter_V.png for vertical).
## Emits orientation_toggled when clicked. Listens to orientation_changed to update visuals.

signal orientation_toggled(new_state: RunOrientationState)

@onready var _icon_h: Texture2D = preload("res://Assets/Tiles/letter_H.png")
@onready var _icon_v: Texture2D = preload("res://Assets/Tiles/letter_V.png")

var _orientation_state: RunOrientationState = null


func _ready() -> void:
	pressed.connect(_on_pressed)
	_set_orientation(RunOrientationState.horizontal())


func set_orientation_state(new_state: RunOrientationState) -> void:
	if new_state == null:
		return
	_orientation_state = new_state
	_set_orientation(new_state)


func _set_orientation(state: RunOrientationState) -> void:
	if state.is_horizontal():
		texture_normal = _icon_h
	else:
		texture_normal = _icon_v


func _on_pressed() -> void:
	if _orientation_state == null:
		return
	var new_state := _orientation_state.toggled()
	orientation_toggled.emit(new_state)
```

**Step 2: Verify the script compiles**

Run: `cd C:\Users\suporte\Documents\dev && godot --headless --script addons/gut/run.gd 2>&1 | head -20`

Expected: No compilation errors

**Step 3: Commit**

```bash
git add scenes/board/orientation_icon_button.gd
git commit -m "feat: create OrientationIconButton UI component for orientation toggle"
```

---

### Task 5: Add OrientationIconButton to Board Scene

**Files:**
- Modify: `scenes/board/board.gd` (setup only, scene changes handled separately)

**Step 1: Check current board structure**

Read `scenes/board/Board.tscn` to understand node hierarchy (you may need to edit in editor or through code)

**Step 2: Add orientation button instance and reference**

In `board.gd`, after line 1 (after `extends`), add field:

```gdscript
var _orientation_button: OrientationIconButton = null
```

After `_ready()` method, add:

```gdscript
func setup_orientation_button() -> OrientationIconButton:
	if _orientation_button == null:
		_orientation_button = OrientationIconButton.new()
		add_child(_orientation_button)
		_orientation_button.position = Vector2(0, 0)
		_orientation_button.size = Vector2(32, 32)
	return _orientation_button


func get_orientation_button() -> OrientationIconButton:
	return _orientation_button
```

**Step 3: Commit**

```bash
git add scenes/board/board.gd
git commit -m "feat: add orientation button setup methods to Board"
```

---

### Task 6: Update GameplayController to Coordinate Orientation Changes

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd:1-250` (coordinator section)

**Step 1: Add orientation state field**

After the state fields section (around line 40), add:

```gdscript
var _orientation_state: RunOrientationState = null
```

**Step 2: Initialize orientation in setup()**

In the `setup()` method, after initializing other dependencies, add:

```gdscript
	_orientation_state = RunOrientationState.horizontal()
	_orientation_button = _board.setup_orientation_button()
	if _orientation_button:
		_orientation_button.set_orientation_state(_orientation_state)
		_orientation_button.orientation_toggled.connect(_on_orientation_toggled)
```

**Step 3: Update FocusCursor setup to include orientation**

Find where FocusCursor is setup (likely in setup() or _connect_signals()), and update:

```gdscript
	# OLD:
	# _cursor.setup(_board, _hand)

	# NEW:
	_cursor.setup(_board, _hand, _orientation_state)
	_cursor.orientation_toggled.connect(_on_orientation_toggled)
```

**Step 4: Add orientation toggle handler**

Add this new method in the CURSOR TYPING HANDLERS section:

```gdscript
func _on_orientation_toggled(new_state: RunOrientationState) -> void:
	_orientation_state = new_state

	# Update cursor's orientation reference
	_cursor.set_orientation_state(new_state)

	# Update icon visual
	if _orientation_button:
		_orientation_button.set_orientation_state(new_state)
		# TODO: Trigger stomp animation on button for feedback

	# If currently typing, recreate session with new orientation
	var current_session := _cursor.get_typing_session()
	if current_session != null and not current_session.is_exhausted():
		var new_session := BoardTypingSession.create_with_orientation(
			_board,
			current_session.cursor_pos,
			new_state.orientation
		)
		_cursor.set_typing_session(new_session)
```

**Step 5: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: add orientation coordination to GameplayController"
```

---

### Task 7: Wire OrientationIconButton to AnimationSystem (Optional Polish)

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd` (animation integration)

**Step 1: Add stomp animation on orientation toggle**

Update `_on_orientation_toggled()` to trigger stomp animation:

```gdscript
func _on_orientation_toggled(new_state: RunOrientationState) -> void:
	_orientation_state = new_state

	_cursor.set_orientation_state(new_state)

	if _orientation_button:
		_orientation_button.set_orientation_state(new_state)
		# Play stomp animation on button for feedback
		var button_node = _orientation_button as Node
		if button_node:
			var stomp_strategy = preload("res://scripts/animation/stomp/stomp_tile_animation.tres")
			if stomp_strategy:
				# Create a simple tween for visual feedback
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_BACK)
				tween.set_ease(Tween.EASE_OUT)
				tween.tween_property(_orientation_button, "scale", Vector2(1.2, 1.2), 0.1)
				tween.tween_property(_orientation_button, "scale", Vector2(1.0, 1.0), 0.1)

	var current_session := _cursor.get_typing_session()
	if current_session != null and not current_session.is_exhausted():
		var new_session := BoardTypingSession.create_with_orientation(
			_board,
			current_session.cursor_pos,
			new_state.orientation
		)
		_cursor.set_typing_session(new_session)
```

**Step 2: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: add stomp animation feedback on orientation toggle"
```

---

### Task 8: Manual Integration Testing

**Files:** None (testing only)

**Step 1: Start a run in the game**

Launch the game and start a new run:

```
F5 (or Run scene in Godot)
```

**Step 2: Test horizontal orientation (default)**

- Navigate to the board with arrow keys
- Start typing: letters should place left-to-right
- When reaching right edge, should wrap to next row
- Expected: Cursor advances right, then wraps to column 0 of next row

**Step 3: Test TAB key toggle**

- Press TAB while on board
- Expected: Orientation icon updates (H → V or V → H), stomp animation plays
- Verify orientation_state was updated

**Step 4: Test vertical orientation**

- Now type more letters
- Expected: Letters should place top-to-bottom
- When reaching bottom edge, should wrap to next column
- Expected: Cursor advances down, then wraps to row 0 of next column

**Step 5: Test persistence across zone switches**

- While in vertical mode, press ESC or navigate to hand zone
- Expected: Typing session ends, orientation state persists
- Switch back to board (navigate up)
- Expected: Can resume typing in vertical mode without pressing TAB again

**Step 6: Test icon click**

- Click on orientation icon in top-left
- Expected: Same behavior as TAB (orientation toggles, animation plays)

**Step 7: Verify placed tiles persist**

- Place some tiles in vertical mode
- Toggle to horizontal
- Expected: Placed tiles remain on board, only direction changes

**Step 8: Test edge cases**

- Test 1-column board + vertical mode → should exhaust quickly
- Test 1-row board + horizontal mode → should exhaust quickly

**Step 9: Commit (manual testing complete)**

```bash
git add -A
git commit -m "test: verify typing orientation feature works end-to-end"
```

---

### Task 9: Final Verification and Documentation

**Files:**
- None (documentation already in design doc)

**Step 1: Verify all files compile**

Run: `cd C:\Users\suporte\Documents\dev && godot --headless --script addons/gut/run.gd 2>&1 | grep -i error`

Expected: No GDScript errors

**Step 2: Verify git history**

Run: `git log --oneline -10`

Expected: See all commits:
- "feat: add RunOrientationState immutable value object..."
- "feat: add orientation dependency injection and TAB handling..."
- "feat: add vertical wrapping support..."
- "feat: create OrientationIconButton..."
- "feat: add orientation button setup methods..."
- "feat: add orientation coordination..."
- "feat: add stomp animation feedback..."
- "test: verify typing orientation..."

**Step 3: Verify design compliance**

Checklist:
- ✓ RunOrientationState is immutable (toggled() returns new instance)
- ✓ Orientation persists throughout run (stored in GameplayController)
- ✓ TAB key and click both toggle orientation
- ✓ Word-wrap: horizontal wraps rows, vertical wraps columns
- ✓ Icon positioned 32x32px top-left
- ✓ Stomp animation on toggle
- ✓ Placed tiles persist when orientation changes
- ✓ DDD pattern: Orientation is domain concept (RunOrientationState)
- ✓ OOP: Dependency injection, signal-based
- ✓ Cyclomatic complexity < 5 in all methods

**Step 4: Final commit (if any doc changes needed)**

```bash
git add -A
git commit -m "chore: finalize typing orientation feature implementation"
```

---

## Execution Summary

This plan implements typing mode orientation toggle in 9 bite-sized tasks:

1. **RunOrientationState** - Immutable domain model (5 min)
2. **FocusCursor orientation support** - Dependency injection + TAB handling (8 min)
3. **BoardTypingSession vertical wrapping** - Extend word-wrap logic (5 min)
4. **OrientationIconButton** - New UI component (5 min)
5. **Board integration** - Add button to board (3 min)
6. **GameplayController coordination** - Wire signals and state (8 min)
7. **Animation feedback** - Stomp effect on toggle (3 min)
8. **Manual testing** - Verify all behaviors (10 min)
9. **Final verification** - Check compliance and commits (2 min)

**Total estimated time:** ~45 minutes

Each task is TDD-friendly with clear verification steps. All follow OOP/DDD principles with immutability, low cyclomatic complexity, and low-verbosity patterns.
