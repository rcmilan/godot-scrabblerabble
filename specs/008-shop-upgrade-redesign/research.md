# Phase 0 Research: Shop Upgrade Redesign

**Date**: 2026-04-19  
**Feature**: 008-shop-upgrade-redesign  
**Purpose**: Resolve technical unknowns and document best practices for implementation

---

## 1. Godot 4 Drag-and-Drop Implementation

### Decision: InputEvent-based drag tracking with custom ghost Control node

**Rationale**:
- Godot 4 doesn't have built-in drag-and-drop; use low-level InputEvent handling
- InputEvent.MOUSE_MOTION for cursor tracking during drag
- Custom Control node (ghost) follows cursor using `get_global_mouse_position()`
- Drop zones validated via `Rect2.has_point()` on tile bounds

**Implementation Pattern**:
```gdscript
# In ShopOverlay controller:
var _dragging_modifier: ModifierType = null
var _ghost_node: Control = null

func _input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        # Start drag on modifier click
        _dragging_modifier = _get_modifier_at_position(event.position)
        _create_ghost(_dragging_modifier)
    elif event is InputEventMouseMotion and _dragging_modifier:
        # Update ghost position
        _ghost_node.global_position = event.position - ghost_offset
        # Check drop zones
        var drop_target = _get_drop_target_at_position(event.position)
        _update_drop_feedback(drop_target)
    elif event is InputEventMouseButton and not event.pressed:
        # Complete drag
        _finish_drag(drop_target)
```

**Alternatives Considered**:
- Area2D overlap detection: Overkill for 10 tiles; input-based simpler
- Godot's drag preview system: No built-in; would need custom implementation anyway
- Full physics simulation: Too heavy; grid + jitter sufficient

---

## 2. Vertical Animation Composition (Shop + Board)

### Decision: Extend TileAnimationStrategy; orchestrate dual animations via Main or TileAnimator

**Rationale**:
- Existing TileAnimationStrategy (GlideTileAnimation, etc.) provides reusable pattern
- Shop slide (up) + board slide (down) are parallel, not sequential
- Both must start and end simultaneously (500ms target)
- Godot Tween system supports parallel tweens naturally

**Implementation Pattern**:
```gdscript
# In animation/shop/shop_slide_animation.gd:
class_name ShopSlideAnimation
extends TileAnimationStrategy

func get_animation(tile: Tile) -> Tween:
    var tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.set_parallel(true)  # Allow parallel animations
    tween.tween_property(tile, "position:y", -screen_height, 0.5)
    return tween

# In Main or TileAnimator, on shop entrance:
var shop_anim = ShopSlideAnimation.new()
var board_anim = shop_anim.get_animation(board)  # Board slides up
var shop_anim_tween = create_tween()
shop_anim_tween.tween_property(shop_overlay, "position:y", 0, 0.5)  # Shop slides in from bottom
await board_anim  # Both complete together
```

**Alternatives Considered**:
- Separate animation system for shop: Inconsistent with game's animation infrastructure
- Sequential animations: Breaks the simultaneous 500ms requirement
- Custom Tween composition: Tween.set_parallel() is the native pattern

---

## 3. RunManager Integration for Shop Tiles & Modifiers

### Decision: Add two new methods to RunManager that delegate to TileBag and modifier registry

**Rationale**:
- RunManager already orchestrates deck/hand flow
- TileBag exists and handles tile drawing; shop reuses it
- Modifier pool likely exists in game config or runstate; shop queries it
- Keeps shop dependencies centralized (one call to RunManager, not multiple singletons)

**Implementation Pattern**:
```gdscript
# In RunManager:
func get_shop_tiles(count: int) -> Array[TileState]:
    # Draw tiles from active deck without affecting main hand
    var tiles: Array[TileState] = []
    for i in range(count):
        var tile = TileBag.draw_tile()
        if tile:
            tiles.append(tile)
    return tiles

func get_shop_modifiers(count: int) -> Array[ModifierType]:
    # Sample from available modifiers (may include duplicates per clarification #3)
    var available = _get_modifier_pool()  # TBD: where modifier pool lives
    var selected: Array[ModifierType] = []
    for i in range(count):
        selected.append(available[randi() % available.size()])
    return selected
```

**Alternatives Considered**:
- Direct TileBag.draw() calls from ShopOverlay: Couples shop to TileBag; violates thin controller principle
- Separate ShopManager autoload: Redundant; RunManager already exists
- Passing tiles as parameters in run_shop_requested signal: Works, but shifts responsibility away from RunManager

---

## 4. Immutable TileState Copies for Shop Session

### Decision: Add create_shop_copy() method to TileState; preserve pre-loaded modifier state

**Rationale**:
- TileState is immutable (per constitution); shop needs independent copies
- Pre-loaded modifier must persist across copies; session modifier starts null
- Revert restores original pre-loaded state, not null
- Copy method centralizes clone logic

**Implementation Pattern**:
```gdscript
# In domain/tile/tile_state.gd:
class_name TileState

var character: String
var pre_loaded_modifier: ModifierInstance = null
var session_modifier: ModifierInstance = null

func create_shop_copy() -> TileState:
    var copy = TileState.new()
    copy.character = self.character
    copy.pre_loaded_modifier = self.pre_loaded_modifier  # Preserve pre-load
    copy.session_modifier = null  # Fresh session
    return copy

func apply_session_modifier(mod: ModifierInstance) -> TileState:
    var copy = create_shop_copy()
    copy.session_modifier = mod
    return copy

func revert_to_pre_load() -> TileState:
    var copy = create_shop_copy()
    copy.session_modifier = null  # Drop session mod, keep pre-load
    return copy
```

**Alternatives Considered**:
- Mutating in-place: Violates immutability principle; breaks undo
- Using references to original tiles: Couples shop to hand; breaks isolation contract
- Shallow vs deep copy: Pre-loaded modifier is immutable, so reference copy sufficient

---

## 5. Scattered Tile Layout Algorithm

### Decision: Grid-with-jitter (2 rows of 5, randomized offsets)

**Rationale**:
- Simple, predictable, no complex physics
- Meets "scattered, naturalistic" visual requirement
- 10 tiles fit naturally in 2 rows of 5
- Jitter (±15-20px random offsets per tile) creates visual variation

**Implementation Pattern**:
```gdscript
func generate_tile_positions(tile_count: int) -> Array[Vector2]:
    var positions: Array[Vector2] = []
    var cols = 5
    var cell_width = 100
    var cell_height = 120
    var base_x = 50
    var base_y = 150
    
    for i in range(tile_count):
        var row = i / cols
        var col = i % cols
        var x = base_x + col * cell_width + randf_range(-15, 15)
        var y = base_y + row * cell_height + randf_range(-15, 15)
        positions.append(Vector2(x, y))
    
    return positions
```

**Alternatives Considered**:
- Pure random placement: Risk overlaps; complex validation
- Physics-based (Godot PhysicsServer2D): Overkill for 10 tiles; adds frame latency
- Hand-crafted positions: No variation between visits; breaks requirement #7

---

## Key Dependencies & Assumptions

1. **TileBag exists and is callable** - Assumption based on existing code
2. **ModifierType enum or registry exists** - Assumption based on existing modifier system
3. **TileState is a class in domain/tile/** - Assumption based on existing code
4. **ShakeTileAnimation exists** - Confirmed in codebase (animation/shake/shake_tile_animation.gd)
5. **RunManager has access to deck config** - Assumption; clarification #1 specifies integration point

---

## Open Questions for Implementation

None remaining. All clarifications from `/speckit.clarify` resolved.
