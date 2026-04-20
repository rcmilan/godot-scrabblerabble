# Phase 1 Design: Data Model

**Feature**: 008-shop-upgrade-redesign  
**Date**: 2026-04-19  
**Purpose**: Define domain entities and relationships for shop upgrade system

---

## Overview

The shop operates on immutable domain objects. Core entities: **ShopSession** (state container), **TileState** (with pre-load + session modifier tracking), **ModifierInstance** (applied effect), and **ShopAnimation** (animation strategy).

All entities follow immutability principle: modifications return new instances, never mutate in place.

---

## Entity: ShopSession

**File**: `scripts/domain/shop/shop_session.gd`  
**Type**: Immutable domain value object  
**Lifecycle**: Created when shop opens; destroyed when shop closes (committed or reverted)

### Fields

| Field | Type | Cardinality | Notes |
|-------|------|-------------|-------|
| `session_id` | int | 1 | Unique ID per shop visit (for logging) |
| `round_number` | int | 1 | Which round this shop is for |
| `is_boss_round` | bool | 1 | Determines modifier count (2 vs 3) |
| `available_modifiers` | Array[ModifierType] | 2-3 | Options offered this shop; may contain duplicates |
| `available_tiles` | Array[TileState] | 10 | Randomly drawn tiles (may have pre-loaded mods) |
| `pending_assignments` | Dict | 0..10 | Maps TileState → ModifierInstance (session-applied mods only) |

### Methods

```gdscript
class_name ShopSession

# Constructor
func _init(round_num: int, is_boss: bool, tiles: Array[TileState], mods: Array[ModifierType]) -> void

# Public API
func apply_modifier(tile: TileState, modifier: ModifierInstance) -> ShopSession:
    # Returns new ShopSession with modifier applied to tile
    # Validates: target tile is unmodified (max 1 per tile)
    # Returns: error if tile already has modifier
    
func swap_modifier(tile: TileState, old_mod: ModifierInstance, new_mod: ModifierInstance) -> ShopSession:
    # Swap existing modifier (pre-load or session) with new one
    # Returns new ShopSession with swap applied

func revert_all() -> ShopSession:
    # Clear all session-applied modifiers; restore pre-loaded mods
    # Returns new ShopSession with pending_assignments empty

func get_final_tiles() -> Array[TileState]:
    # Returns modified tiles (pre-load + session applied)
    # Used on Commit to create hand tiles

func get_unused_modifiers() -> Array[ModifierType]:
    # Returns modifiers not applied to any tile
    # Used for logging or future shop features

# Validation
func can_apply_modifier(tile: TileState) -> bool:
    # True if tile has no modifier (pre-load or session)

func get_tile_modifier(tile: TileState) -> ModifierInstance:
    # Returns active modifier on tile (pre-load preferred, else session)
    # Returns null if no modifier
```

### Invariants

- `available_tiles.size() == 10` (always)
- `available_modifiers.size() in [2, 3]` (2 for normal, 3 for boss)
- `pending_assignments.keys().all(k in available_tiles)` (only valid tiles)
- No tile appears twice in `available_tiles` (unique instances)
- Max 1 modifier per tile (pre-load or session, never both active simultaneously)
- Pre-loaded modifiers never removed (only swapped); session mods cleared by Revert

### Example Usage

```gdscript
# Create session
var session = ShopSession.new(5, false, tiles, modifiers)

# Apply modifier
var mod = ModifierInstance.new(ModifierType.EXPO)
session = session.apply_modifier(tiles[0], mod)

# Revert all
session = session.revert_all()

# Get final tiles for commit
var final = session.get_final_tiles()
```

---

## Entity: TileState

**File**: `scripts/domain/tile/tile_state.gd` (EXISTING - EXTEND)  
**Type**: Immutable value object  
**Scope**: Represents a single tile with character, modifiers, and properties

### New/Modified Fields (for shop)

| Field | Type | Cardinality | Notes |
|-------|------|-------------|-------|
| `pre_loaded_modifier` | ModifierInstance | 0..1 | Modifier on tile from deck (immutable in shop) |
| `session_modifier` | ModifierInstance | 0..1 | Modifier applied by player in this shop (cleared by Revert) |

### New Methods (for shop)

```gdscript
# Create independent copy for shop session
func create_shop_copy() -> TileState:
    # Returns new TileState with pre-load preserved, session null

# Apply session modifier (returns new tile)
func with_session_modifier(mod: ModifierInstance) -> TileState:
    # Returns new TileState with session_modifier set
    
# Revert session modifier (returns new tile)
func revert_session_modifier() -> TileState:
    # Returns new TileState with session_modifier = null (pre-load unchanged)

# Query active modifier
func get_active_modifier() -> ModifierInstance:
    # Returns pre_loaded_modifier if present, else session_modifier, else null
    
# Check if modifiable
func can_accept_modifier() -> bool:
    # Returns true if no active modifier (pre-load or session)
```

### Invariants (shop context)

- If `pre_loaded_modifier != null`, it came from deck and cannot be null'd
- At most one of `pre_loaded_modifier` or `session_modifier` is active at a time
- Swapping requires: old mod (pre-load or session) → new mod

---

## Entity: ModifierInstance

**File**: `scripts/domain/modifiers/modifier_instance.gd` (EXISTING)  
**Type**: Immutable value object  
**Scope**: Represents a single applied modifier effect

### Fields (existing, no changes for shop)

| Field | Type | Cardinality | Notes |
|-------|------|-------------|-------|
| `modifier_type` | ModifierType | 1 | Type of modifier (EXPO, MULTI, BONUS, etc.) |
| `applied_tile` | TileState | 0..1 | Reference to tile it's applied to (optional) |
| `stack_count` | int | 1 | Stacking count (default 1) |

### Expected Methods

```gdscript
# Clone for shop
func clone() -> ModifierInstance:
    # Returns new ModifierInstance with same type/properties

# Query
func get_display_name() -> String:
    # Returns user-friendly name (e.g., "Expo Multiplier")
    
func get_display_icon() -> Texture2D:
    # Returns icon for ghost drag preview
```

### Notes

- Shop treats ModifierInstance as immutable
- No modifications to ModifierInstance during shop session
- Applied modifiers are "confirmed" on Commit, discarded on Revert

---

## Entity: ShopAnimation

**File**: `scripts/animation/shop/shop_slide_animation.gd` (NEW)  
**Type**: Animation strategy  
**Scope**: Defines shop entrance/exit animations

### Fields

| Field | Type | Cardinality | Notes |
|-------|------|-------------|-------|
| `duration_ms` | float | 1 | Animation duration (500ms) |
| `easing` | Tween.EaseType | 1 | EASE_IN_OUT for smooth entrance |
| `transition` | Tween.TransitionType | 1 | TRANS_SINE for natural feel |

### Methods

```gdscript
class_name ShopSlideAnimation
extends TileAnimationStrategy

# Entrance: shop slides in from bottom, board slides up off-screen
func get_entrance_animation(shop: Control, board: Control) -> Tween:
    # Returns tween animating:
    # - shop.position.y: screen_height → 0 (slides up into view)
    # - board.position.y: 0 → -screen_height (slides up off-screen)
    # Duration: 500ms
    # Synchronized: both start and end together

# Exit: shop slides out to top, board slides back in from bottom
func get_exit_animation(shop: Control, board: Control) -> Tween:
    # Returns tween animating:
    # - shop.position.y: 0 → -screen_height (slides up out)
    # - board.position.y: -screen_height → 0 (slides down in)
    # Duration: 500ms
    # Synchronized: both start and end together
    
# Revert animation (optional visual feedback)
func get_revert_feedback() -> Tween:
    # Optional: Flash or pulse to indicate revert action
```

### Integration Pattern

```gdscript
# In Main._on_shop_requested():
var shop_anim = ShopSlideAnimation.new()
var entrance_tween = shop_anim.get_entrance_animation(shop_overlay, board)
await entrance_tween
# Shop is now visible, player can interact
```

---

## Entity Relationships

```
ShopSession
├── available_modifiers: Array[ModifierType]  (enumeration references)
├── available_tiles: Array[TileState]         (independent copies)
│   └── each TileState has:
│       ├── pre_loaded_modifier: ModifierInstance (from deck)
│       └── session_modifier: ModifierInstance (applied by player)
└── pending_assignments: Dict[TileState → ModifierInstance]

ShopAnimation
└── orchestrates animations for:
    ├── shop_overlay: Control
    └── board: Control
```

---

## State Transitions

### Shop Session Lifecycle

```
INIT: ShopSession created with 10 tiles, 2-3 modifiers
  ↓
PREVIEW: Player drags modifiers onto tiles
  ├→ apply_modifier() → new ShopSession
  └→ apply_modifier() → new ShopSession
  ...
  ├→ revert_all() → new ShopSession (back to INIT state)
  └→ COMMIT
  
COMMIT: Player clicks Commit
  ├ get_final_tiles() → tiles with all mods
  ├ RunManager receives tiles
  └ Shop closes (visibility = false)

OR

REVERT: Player clicks Revert
  └ returns to PREVIEW state
```

### Tile Modifier State Machine

```
Per-Tile States:

CLEAN (no modifier)
  ├→ apply_session_modifier(mod) → MODIFIED_SESSION
  └ (if pre-loaded:)
     └→ MODIFIED_PRELOAD

MODIFIED_SESSION (player-applied)
  ├→ apply_session_modifier(new_mod) → MODIFIED_SESSION (swap)
  ├→ revert_session_modifier() → CLEAN or MODIFIED_PRELOAD
  └ (on Commit:) → FINALIZED_SESSION

MODIFIED_PRELOAD (from deck)
  ├→ swap_modifier(new_mod) → MODIFIED_SESSION (swapped)
  ├→ revert_all() → MODIFIED_PRELOAD (unchanged)
  └ (on Commit:) → FINALIZED_PRELOAD
```

---

## Validation Rules

### Apply Modifier

- Precondition: Target tile has no modifier (`can_accept_modifier() == true`)
- Postcondition: pending_assignments[tile] = modifier
- Error: "Cannot apply—tile already has modifier"

### Revert

- Clears all `session_modifier` fields
- Preserves all `pre_loaded_modifier` fields
- Returns available_modifiers to full state

### Commit

- Creates new TileState instances with applied modifiers finalized
- Discards all session copies (shop-local previews)
- Returns tiles to RunManager/hand system

---

## Assumptions

1. ModifierType is an enum with entries like EXPO, MULTI, BONUS
2. ModifierInstance exists in domain and is immutable
3. TileState currently exists; we extend it with new fields
4. All entities are GDScript classes (no external types)
5. Serialization not required (shop session is ephemeral)
