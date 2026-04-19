# Quickstart: Shop Upgrade Integration

**Feature**: 008-shop-upgrade-redesign  
**Target**: Integrate shop redesign into existing Wordatro game  
**Time Estimate**: 3-4 implementation sprints (see tasks.md)

---

## Integration Overview

This quickstart shows how the shop redesign connects to existing systems:

1. **RunManager** provides shop tiles/modifiers (new methods)
2. **ShopOverlay** handles UI and input (redesigned, expanded)
3. **ShopSession** (NEW) manages preview state (domain layer)
4. **Main** orchestrates shop entrance/exit (minor changes)
5. **TileAnimator** plays shop animations (reuses existing patterns)

---

## Key Files & Changes

### New Files (Create)

```
scripts/domain/shop/
├── shop_session.gd              # Domain state object
└── shop_modifier_helpers.gd     # Optional: modifier application logic

scripts/controllers/
├── shop_controller.gd           # Input routing, drag-drop handling
└── shop_ui_manager.gd           # Optional: visual state management

scripts/animation/shop/
└── shop_slide_animation.gd      # Vertical slide animations

scenes/shop/
└── [Updated] shop_overlay.gd    # Enhanced with drag-drop
```

### Modified Files

```
scripts/domain/tile/
└── tile_state.gd               # Add: create_shop_copy(), with_session_modifier(), etc.

autoload/
└── run_manager.gd              # Add: get_shop_tiles(), get_shop_modifiers() methods

scenes/
└── main.gd                      # Minimal: add shop animation orchestration
```

### Unchanged

```
autoload/event_bus.gd           # Signals already defined; no changes
scenes/shop/shop_overlay.tscn   # Scene structure fine; logic updated in .gd
```

---

## Integration Steps

### Step 1: Extend TileState (Domain)

**File**: `scripts/domain/tile/tile_state.gd`

Add fields and methods for shop:

```gdscript
# Add to TileState class:
var pre_loaded_modifier: ModifierInstance = null
var session_modifier: ModifierInstance = null

func create_shop_copy() -> TileState:
    var copy = TileState.new()
    copy.character = character
    copy.pre_loaded_modifier = pre_loaded_modifier  # Preserve
    copy.session_modifier = null  # Fresh
    return copy

func with_session_modifier(mod: ModifierInstance) -> TileState:
    var copy = create_shop_copy()
    copy.session_modifier = mod
    return copy

func revert_session_modifier() -> TileState:
    return create_shop_copy()

func get_active_modifier() -> ModifierInstance:
    return pre_loaded_modifier if pre_loaded_modifier else session_modifier

func can_accept_modifier() -> bool:
    return get_active_modifier() == null
```

---

### Step 2: Add ShopSession (Domain)

**File**: `scripts/domain/shop/shop_session.gd` (NEW)

Create immutable state container:

```gdscript
class_name ShopSession

var round_number: int
var is_boss_round: bool
var available_modifiers: Array[ModifierType]
var available_tiles: Array[TileState]
var pending_assignments: Dictionary  # TileState → ModifierInstance

func _init(round: int, is_boss: bool, tiles: Array[TileState], mods: Array[ModifierType]):
    round_number = round
    is_boss_round = is_boss
    available_tiles = tiles
    available_modifiers = mods
    pending_assignments = {}

func apply_modifier(tile: TileState, modifier: ModifierInstance) -> ShopSession:
    if not tile.can_accept_modifier():
        push_error("Cannot apply—tile already has modifier")
        return self
    
    var copy = ShopSession.new(round_number, is_boss_round, available_tiles, available_modifiers)
    copy.pending_assignments = pending_assignments.duplicate()
    copy.pending_assignments[tile] = modifier
    return copy

func revert_all() -> ShopSession:
    # Clear all session mods; return fresh copy
    return ShopSession.new(round_number, is_boss_round, available_tiles, available_modifiers)

func get_final_tiles() -> Array[TileState]:
    # Return tiles with applied modifiers
    var result: Array[TileState] = []
    for tile in available_tiles:
        if pending_assignments.has(tile):
            result.append(tile.with_session_modifier(pending_assignments[tile]))
        else:
            result.append(tile)
    return result
```

---

### Step 3: Extend RunManager (Autoload)

**File**: `autoload/run_manager.gd`

Add shop tile/modifier sourcing:

```gdscript
func get_shop_tiles(count: int) -> Array[TileState]:
    """Draw tiles from the active deck for shop."""
    var tiles: Array[TileState] = []
    for i in range(count):
        var tile = TileBag.draw_tile()
        if tile:
            tiles.append(tile.create_shop_copy())  # Independent copy
    return tiles

func get_shop_modifiers(count: int) -> Array[ModifierType]:
    """Get random modifiers from available pool."""
    var pool = _get_available_modifiers()
    var selected: Array[ModifierType] = []
    for i in range(count):
        selected.append(pool[randi() % pool.size()])
    return selected

func _get_available_modifiers() -> Array[ModifierType]:
    # Return all available modifiers (implementation depends on game design)
    # Example: return [MODIFIER_TYPE.EXPO, MODIFIER_TYPE.MULTI, MODIFIER_TYPE.BONUS]
    pass
```

---

### Step 4: Create ShopController (Input Routing)

**File**: `scripts/controllers/shop_controller.gd` (NEW)

Handle input and drag-drop:

```gdscript
class_name ShopController
extends Node

var shop_overlay: ShopOverlay
var shop_session: ShopSession
var board: Node
var hand: Node

var _dragging_modifier: ModifierType = null
var _ghost_node: Control = null

func _ready():
    # Connect to shop signals
    shop_overlay.modifier_card_pressed.connect(_on_modifier_selected)
    shop_overlay.revert_pressed.connect(_on_revert)
    shop_overlay.commit_pressed.connect(_on_commit)

func _input(event: InputEvent):
    if not shop_overlay.visible:
        return
    
    if event is InputEventMouseButton and event.pressed:
        var tile = _get_tile_at_position(event.position)
        if tile and _dragging_modifier:
            _attempt_drop(tile, event.position)
    
    # ... drag tracking, keyboard input, etc.

func _on_modifier_selected(modifier: ModifierType):
    _dragging_modifier = modifier
    _create_ghost(modifier)

func _on_revert():
    shop_session = shop_session.revert_all()
    shop_overlay.refresh_display(shop_session)

func _on_commit():
    var final_tiles = shop_session.get_final_tiles()
    RunManager.finalize_shop_commit(final_tiles)
    shop_overlay.hide()
```

---

### Step 5: Update ShopOverlay (UI Controller)

**File**: `scenes/shop/shop_overlay.gd` (MODIFY)

Extend with drag-drop and keyboard handling:

```gdscript
extends Control
class_name ShopOverlay

signal continue_requested
signal modifier_card_pressed(modifier: ModifierType)
signal revert_pressed
signal commit_pressed

# ... existing code ...

func _input(event: InputEvent):
    if not visible:
        return
    
    if event.is_action_pressed("ui_accept"):
        # Enter key: activate focused button or continue
        if _commit_button.has_focus():
            _on_commit_pressed()
        elif _revert_button.has_focus():
            _on_revert_pressed()
    
    if event is InputEventMouseButton:
        # Handle modifier card clicks
        for card in _modifier_cards:
            if card.get_rect().has_point(card.get_local_mouse_position()):
                modifier_card_pressed.emit(card.modifier_type)
    
    # ... drag-drop, TAB navigation, etc.

func refresh_display(session: ShopSession):
    """Update UI to reflect ShopSession state."""
    # Redraw tile badges based on session.pending_assignments
    # Redraw modifier availability
    pass

func _on_commit_pressed():
    commit_pressed.emit()
    continue_requested.emit()
    hide()
```

---

### Step 6: Orchestrate Animations (Main)

**File**: `scenes/main.gd` (MODIFY)

Add shop animation coordination:

```gdscript
func _on_shop_requested(round_number: int) -> void:
    # ... existing code ...
    
    # Create shop session
    var tiles = RunManager.get_shop_tiles(10)
    var modifiers = RunManager.get_shop_modifiers(2 if not is_boss else 3)
    var shop_session = ShopSession.new(round_number, is_boss, tiles, modifiers)
    
    # Trigger shop entrance animation
    var shop_anim = ShopSlideAnimation.new()
    var entrance_tween = shop_anim.get_entrance_animation(shop_overlay, board)
    
    shop_overlay.show_shop(round_number, GameManager.get_current_score(), next_config)
    await entrance_tween
    
    # Shop is now interactive

func _on_shop_continue() -> void:
    # Trigger shop exit animation
    var shop_anim = ShopSlideAnimation.new()
    var exit_tween = shop_anim.get_exit_animation(shop_overlay, board)
    await exit_tween
    
    # Proceed to next round
    RunManager.proceed_from_shop()
```

---

## Data Flow: End-to-End

```
Player wins round
    ↓
RunManager.run_shop_requested signal → Main
    ↓
Main calls RunManager.get_shop_tiles(10) and .get_shop_modifiers(2-3)
    ↓
Main creates ShopSession with tiles + modifiers
    ↓
Main triggers entrance animation (shop in, board out)
    ↓
Player interacts:
  - Click modifier → ShopController selects
  - Drag to tile → ShopController applies → ShopSession updated
  - Click Revert → ShopSession.revert_all() → ShopOverlay refreshes
    ↓
Player clicks Commit
    ↓
ShopSession.get_final_tiles() → finalized tiles with mods
    ↓
Main triggers exit animation (shop out, board in)
    ↓
RunManager processes committed tiles → adds to hand
    ↓
Next round begins with upgraded tiles
```

---

## Testing the Integration

### Manual Test Flow (in Godot editor)

1. **Start game** → Title screen → Run setup
2. **Play round 1** → Win (or use debug auto-win)
3. **Shop appears** ✓
   - Verify: 10 tiles scattered, 2 modifiers visible
   - Verify: Entrance animation smooth
4. **Drag modifier to tile** ✓
   - Click modifier card → highlight
   - Drag to tile → ghost follows
   - Release → badge appears on tile
5. **Drag to occupied tile** ✓
   - Attempt drop on occupied → red X, shake, no badge
6. **Revert** ✓
   - Click Revert → all session mods gone, pre-loads stay
7. **Commit** ✓
   - Click Commit → exit animation
   - Next round starts → modified tiles in hand
8. **Check modified tiles in gameplay** ✓
   - Place modified tile on board → modifier effect active

### Edge Cases to Test

- [ ] Drag modifier over non-tile area → cancel drag
- [ ] Apply same modifier twice (if duplicates allowed) → first one applies
- [ ] Click modifier twice → select/deselect toggle
- [ ] TAB through all focusable elements → correct order
- [ ] ESC key closes shop → reverts all, hides
- [ ] Keyboard drag (arrow keys + Enter) → applies modifier
- [ ] Boss round → 3 modifiers instead of 2

---

## Common Issues & Solutions

### Tiles Overlapping

**Issue**: Scattered layout produces overlaps  
**Solution**: Adjust jitter range in scatter algorithm (reduce from ±20px to ±10px, or add post-gen validation)

### Ghost Ghost Lag

**Issue**: Drag preview jerky or delayed  
**Solution**: Ensure ghost updates in `_process()` not `_input()` for frame-accurate cursor tracking

### ModifierInstance Serialization

**Issue**: Modifiers don't persist between rounds  
**Solution**: Don't rely on serialization. Create fresh ModifierInstance per application; store by type only.

### RunManager Method Signature

**Issue**: TileBag.draw_tile() doesn't exist or has different signature  
**Solution**: Check actual TileBag API; adapt get_shop_tiles() wrapper accordingly.

---

## Success Criteria (Manual Verification)

- [ ] Shop appears after round win with entrance animation
- [ ] 10 unique tiles displayed in scattered layout
- [ ] 2-3 modifiers offered (correct count for round type)
- [ ] Drag-drop applies modifiers correctly
- [ ] Invalid drops rejected with visual feedback
- [ ] Revert clears player changes, keeps pre-loads
- [ ] Commit finalizes tiles, adds to hand, proceeds to next round
- [ ] Modified tiles function correctly in next round's gameplay
- [ ] All keyboard shortcuts (TAB, arrow keys, Enter, ESC) work
- [ ] Exit animation smooth and synchronized with board
- [ ] No memory leaks or orphaned nodes on repeat shop visits

---

## Next Steps

1. **Create Phase 2 tasks** via `/speckit.tasks`
2. **Implement files in dependency order**: domain → controller → UI → main integration
3. **Test manually after each file**: Verify Godot editor loads without errors
4. **Manual gameplay testing**: Win rounds → open shop → test full flow
5. **Iterate on animations**: Adjust timings if 500ms entrance/exit doesn't feel right
6. **Document edge cases** found during testing in `CLAUDE.md` or feature branch notes

---

## Reference

- **Spec**: [spec.md](spec.md)
- **Data Model**: [data-model.md](data-model.md)
- **ShopOverlay Contract**: [contracts/shop_overlay_contract.md](contracts/shop_overlay_contract.md)
- **Research**: [research.md](research.md)
- **Implementation Tasks**: tasks.md (created via `/speckit.tasks`)
