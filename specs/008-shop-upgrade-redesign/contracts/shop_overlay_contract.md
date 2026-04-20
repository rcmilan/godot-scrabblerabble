# ShopOverlay Interface Contract

**Component**: ShopOverlay (UI Controller)  
**File**: `scenes/shop/shop_overlay.gd`  
**Type**: Godot Control (full-screen)  
**Scope**: Shop UI orchestration and input routing

---

## Public Interface

### Methods

#### `show_shop(round_completed: int, round_score: int, next_config: RoundConfig) → void`

**Purpose**: Display shop screen after round win.

**Parameters**:
- `round_completed`: Int - Round number just completed (for label)
- `round_score`: Int - Score earned in that round (for label)
- `next_config`: RoundConfig - Configuration for next round (board size, target)

**Behavior**:
1. Store next_config for potential debug modifications
2. Populate round and score labels
3. Update "Next Round" preview label (board dimensions, target)
4. Show shop (set visible=true)
5. Grab focus (continue button)
6. Trigger entrance animation (slide in from bottom)

**Signals Emitted**: `run_shop_requested` (handled by caller, not ShopOverlay)

**Error Handling**: None (assume valid parameters)

---

#### `hide() → void`

**Purpose**: Hide shop screen.

**Behavior**:
1. Set visible=false
2. Trigger exit animation (slide out to top)
3. Clear internal state (if needed)

**Signals Emitted**: None (caller handles post-hide logic)

---

### Signals

#### `signal continue_requested`

**Emitted When**: Player clicks Commit button or presses Enter on Commit button.

**Parameters**: None

**Semantics**: Shop is ready to close; caller should finalize tile assignments and proceed to next round.

---

## Input Handling

### Keyboard

| Key | Action |
|-----|--------|
| Enter / Return | Activate focused button (Commit or Revert) |
| Escape | Close shop without commit (revert all, hide) |
| Tab | Cycle focus: modifier cards → tiles → buttons → loop |
| Shift+Tab | Cycle focus backward |
| Arrow Keys | Move focus between tiles (left/right/up/down based on layout) |

### Mouse

| Event | Action |
|-------|--------|
| Click on Modifier Card | Select modifier (visual highlight) |
| Drag Modifier + Mouse Move | Show ghost, track cursor |
| Drag + Release on Tile (valid) | Apply modifier; remove ghost |
| Drag + Release on Tile (occupied) | Play shake animation; reject drop |
| Drag + Release on empty space | Cancel drag; remove ghost |
| Click on Revert Button | Clear all session mods, restore pre-loads |
| Click on Commit Button | Finalize assignments, emit `continue_requested` |

---

## State & Visibility

### Visibility

- **Visible**: After `show_shop()` completes entrance animation
- **Hidden**: After Commit button pressed (exit animation completes) or Escape key pressed

### Internal State (ShopOverlay responsibility)

- Current selected modifier (visual highlight)
- Dragging state (is dragging, which modifier, ghost node position)
- Focus index (for keyboard navigation)

### External State (caller responsibility)

- ShopSession (domain state, held by RunManager or caller)
- Tile/modifier data (passed via show_shop parameters and stored references)
- Committed tile fate (caller processes on `continue_requested`)

---

## Dependencies

### Scene Graph

```
ShopOverlay (Control, full-rect)
├── Background (ColorRect, background color)
├── TitleLabel (Label, "SHOP")
├── UpgradesSection (VBoxContainer)
│   └── ModifierCard (x2-3, custom components)
├── TilesSection (custom layout)
│   └── TileDisplay (x10, scattered positions)
├── ButtonContainer (VBoxContainer)
│   ├── RevertButton
│   └── CommitButton
├── ControlHint (Label, keyboard hint)
└── DebugRoundConfigPopup (existing, unchanged)
```

### Injected Dependencies

- **Main** (caller): Injects board and hand references (future extensions)
- **BackgroundManager** (autoload): For background color syncing
- **RunManager** (autoload): For tile/modifier data access

### Internal Signals

- `modifier_selected`: Emitted when player clicks a modifier card
- `tile_hovered`: Emitted when cursor hovers over a tile during drag
- `drop_attempt`: Emitted when drag is released over a tile

---

## Visual Feedback

### Modifier Cards

- **Normal**: Standard button appearance
- **Selected**: Highlighted border or color change
- **Dragging**: Faded/semi-transparent (ghost appears separately)

### Tiles

- **Normal**: Display tile character with any pre-loaded modifier badge
- **Dragging Over (valid)**: Green highlight or glow
- **Dragging Over (invalid)**: Red X overlay + shake animation
- **Has Session Modifier**: Badge overlay showing applied modifier
- **Has Pre-loaded Modifier**: Smaller badge (visual distinction from session)

### Buttons

- **Revert**: Enabled always; clicking clears all session mods
- **Commit**: Enabled always; clicking finalizes and closes shop

### Ghost (drag preview)

- **Appearance**: Full modifier card (matches source card design)
- **Position**: Follows cursor offset (top-left corner follows mouse)
- **Opacity**: Semi-transparent (0.7-0.8 alpha)
- **Motion**: Smooth 60fps tracking

---

## Animation Contract

### Entrance (show_shop)

- Duration: 500ms
- Shop slides in from bottom (y: screen_height → 0)
- Board slides up off-screen (y: 0 → -screen_height)
- Both animations synchronized, start and end together
- Easing: SINE in-out for natural feel

### Exit (hide on Commit)

- Duration: 500ms
- Shop slides up out of screen (y: 0 → -screen_height)
- Board slides down back into view (y: -screen_height → 0)
- Both animations synchronized
- Easing: SINE in-out

### Invalid Drop Feedback

- Tile shakes: Use existing `ShakeTileAnimation`
- Red X overlay appears on tile momentarily
- Duration: ~200ms

---

## Error Handling

**Not the ShopOverlay's responsibility**:
- Validating tile/modifier data
- Ensuring RunManager provides valid tiles
- Determining what happens to modified tiles on commit

**ShopOverlay Responsibility**:
- Preventing invalid drops (max 1 mod per tile)
- Gracefully handling edge cases (e.g., clicking occupied tile, dragging over self)

---

## Call Sites

**Allowed**: Main.gd only

**Prohibited**:
- ShopOverlay should not directly call RunManager.proceed_from_shop()
- ShopOverlay should not access HandManager or TileBag
- ShopOverlay should not emit game-wide signals (only `continue_requested`)

---

## Testing Checklist

- [ ] show_shop() displays correct round/score/next info
- [ ] Entrance animation (shop up, board down) completes in 500ms
- [ ] Modifier cards selectable via click and TAB
- [ ] Drag modifier to unmodified tile → modifier badge appears
- [ ] Drag modifier to occupied tile → red X + shake, no badge
- [ ] Revert clears all session mods, preserves pre-loads
- [ ] Continue button triggers exit animation
- [ ] Exit animation (shop out, board in) completes in 500ms
- [ ] Keyboard-only flow works (TAB, arrows, Enter)
- [ ] ESC key closes shop without commit
