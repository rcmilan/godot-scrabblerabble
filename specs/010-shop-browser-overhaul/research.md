# Research: Shop Browser Overhaul

**Branch**: `010-shop-browser-overhaul` | **Phase**: 0

## Decision 1: Browser Scene Integration Strategy

**Decision**: Copy only the required browser assets from `godot-design-95` into the project directly (no git submodule).

**Rationale**: The project already established `godot-design-95` as the design system source (constitution 1.1.0, branch 009-win95-title-screen). The theme resource (`webcore_theme.tres`) and font (`W95FA.otf`) are expected to already be present from prior UI work. Only the browser-specific files need to be brought in: `browser.tscn`, `browser.gd`, and the three icon PNGs (`exe_icon.png`, `dll_icon.png`, `bat_icon.png`) from `theme/icon/`. The BrowserWindow sub-scene will be extracted from `browser.tscn` and adapted for the shop rather than used as-is (the full `browser.tscn` is a demo scene with desktop icons and click-to-open logic we do not need).

**Alternatives considered**:
- Git submodule: Adds complexity to the build without benefit for a single-player local game.
- Reference by path: Not possible across separate repositories without submodule or manual copy.

## Decision 2: TAB / Shift+TAB Focus Cycling in Godot 4

**Decision**: Use Godot 4's built-in Control focus system with explicit `focus_next` / `focus_previous` neighbor paths set on each focusable node.

**Rationale**: Godot 4 automatically handles TAB (forward) and Shift+TAB (reverse) for Controls whose `focus_mode` is set to `FOCUS_ALL`. By wiring `focus_next` and `focus_previous` on each button/cell node, we get exact control over the cycle order (refresh -> cells 1-9 -> close -> wraps). Automatic tree-order discovery works for simple layouts but is fragile when the scene tree order differs from visual order (e.g., close button is in the title bar node, not the content area). Explicit neighbor paths are deterministic and immune to tree restructuring.

**Alternatives considered**:
- Relying on tree order alone: Fragile; title bar and content area are siblings so close button would appear mid-cycle.
- Custom `_gui_input` handler looping through an Array of nodes: More code, no benefit over native system.

## Decision 3: ESC Key Handling

**Decision**: Handle ESC via `_input(event)` in `shop_overlay.gd`, checking for the `ui_cancel` action (Godot's default ESC mapping), then call the same close function as the X button.

**Rationale**: `ui_cancel` is already in the default InputMap and maps to ESC. Handling it in `_input()` with a `visible` guard (same pattern as current `shop_overlay.gd`) ensures ESC only fires when the shop is visible. No new InputMap entries needed.

**Alternatives considered**:
- Connecting to `EventBus` and emitting from a global input handler: Over-engineered for a single-scene shortcut.
- Mapping a custom action: Unnecessary since `ui_cancel` already exists.

## Decision 4: "Coming Soon" Cell Visual State

**Decision**: Keep all 9 grid cells as focusable Buttons (FOCUS_ALL) with a visual "coming soon" indicator - a small `Label` node overlaid on each cell showing "?" or a lock symbol, plus a semi-transparent ColorRect dimming the icon.

**Rationale**: Cells must remain keyboard-focusable (FR-006, FR-014) so `Button.disabled = true` cannot be used - disabled buttons cannot receive focus in Godot. A visual overlay on each cell communicates the placeholder state without removing interactivity. ENTER on a focused cell calls a no-op handler. This pattern is easy to remove when real purchase logic is added.

**Alternatives considered**:
- `Button.disabled = true`: Prevents keyboard focus, violates FR-006.
- No visual indicator: Violates FR-014 ("coming soon visual state").
- Replacing all icons with a single "locked" icon: Loses the .exe/.dll/.bat visual identity needed for future differentiation.

## Decision 5: Removing Old Shop Logic from main.gd

**Decision**: Simplify `_on_shop_requested()` in `main.gd` to only call `shop_overlay.show_shop()` directly (no ShopController, no ShopSlideAnimation, no tile/modifier sampling). Keep `RunManager.get_shop_tiles` and `get_shop_modifiers` in RunManager untouched (they are not harmful to leave, and removing them risks breaking RunManager internals).

**Rationale**: The new shop has no modifier/tile logic. ShopController, ShopSlideAnimation, and the complex ShopSession are specific to the old shop and have no role in the new browser UI. Removing only their call sites in `main.gd` is the minimal safe change - RunManager internals stay intact for future use.

**Alternatives considered**:
- Deleting ShopController/ShopSlideAnimation scripts entirely: Riskier; may be referenced elsewhere (to verify at implementation time).
- Keeping slide animation: Inconsistent with Win95 browser aesthetic; the spec does not request it.

## Decision 6: ShopSession Domain Object Scope

**Decision**: Create a thin `ShopItem` domain value object (type enum + icon key). Do NOT create a `ShopSession` domain object for this iteration - the scene owns the item list directly as a plain Array.

**Rationale**: The current spec has no purchase logic, no state machine, and no cross-system communication about item state. A `ShopSession` domain class at this point would be an empty wrapper. `ShopItem` is worth creating as a typed value to enforce the three valid types (EXE, DLL, BAT) and to provide the extension point for future price/effect attributes (Principle VI: Non-Representable Invalid States). The session wrapper adds overhead with no benefit until purchasing is implemented.

**Alternatives considered**:
- Full ShopSession domain object now: Premature; adds a class with no invariants to protect.
- No domain objects at all: Loses the type-safety on item kind; future attribute additions would require retrofitting.
