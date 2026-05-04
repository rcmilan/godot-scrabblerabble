# Data Model: Shop Browser Overhaul

**Branch**: `010-shop-browser-overhaul` | **Phase**: 1

## Entities

### ShopItem (Domain Value Object)

Location: `scripts/domain/shop/shop_item.gd`

Represents one slot in the shop grid. Immutable after construction (Principle III).

| Field    | Type           | Description                                      |
|----------|----------------|--------------------------------------------------|
| `type`   | `ShopItem.Type` (enum) | EXE, DLL, or BAT - determines which icon to display |
| `index`  | `int`          | Position in grid (0-8, left-to-right top-to-bottom) |

**Enum: ShopItem.Type**

| Value | Meaning               | Icon file        |
|-------|-----------------------|------------------|
| EXE   | Executable modifier   | exe_icon.png     |
| DLL   | Library modifier      | dll_icon.png     |
| BAT   | Script modifier       | bat_icon.png     |

**Validation rules**:
- `type` must be one of the three enum values. The enum itself enforces this - no runtime check needed (Principle VI).
- `index` must be in range [0, 8]. Enforced by the scene that constructs items.
- No two ShopItems may share the same index within one shop display.

**Future attributes** (not implemented now):
- `resource_cost: int` - price in player currency
- `effect: ModifierDefinition` - what the item does when purchased
- `is_purchased: bool` - consumed state

**State transitions**: None in this iteration. In future: Unpurchased -> Purchased (one-way).

---

## Scene Nodes (not domain, but structural)

### ShopOverlay (Control scene)

Location: `scenes/shop/shop_overlay.tscn`

The Win95 browser window. Shown/hidden as a sibling node in `main.tscn` (view-swapping, constitution compliant).

| Node              | Type         | Role                                              |
|-------------------|--------------|---------------------------------------------------|
| BrowserWindow     | Panel        | Root Win95 window panel (theme: WindowPanel)      |
| TitleBar          | Panel        | Title bar row (theme: TitleBarActive)             |
| Title             | Label        | Window title text                                 |
| CloseButton       | Button       | X button; focused last in TAB cycle               |
| Toolbar           | Panel        | URL bar row (theme: Win95MenuBar)                 |
| UrlBar            | LineEdit     | Read-only, displays "shop.com"                    |
| RefreshButton     | Button       | Focusable; no-op in this iteration                |
| ContentArea       | Panel        | Hosts the item grid                               |
| ItemGrid          | GridContainer| 3 columns, 3 rows; holds 9 ShopItemCell nodes     |
| ShopItemCell[0-8] | Button       | Focusable; shows icon + coming-soon overlay        |

### ShopItemCell (per-cell structure)

Each cell is a Button with two child nodes:

| Node       | Type       | Role                                              |
|------------|------------|---------------------------------------------------|
| Icon       | TextureRect| Displays exe/dll/bat icon (32x32)                 |
| DimOverlay | ColorRect  | Semi-transparent overlay indicating disabled state|
| SoonLabel  | Label      | Small "?" label indicating placeholder state      |

---

## Focus Order (keyboard navigation)

TAB (forward) cycle, wraps at end:

```
RefreshButton -> ShopItemCell[0] -> [1] -> [2] -> [3] -> [4] -> [5] -> [6] -> [7] -> [8] -> CloseButton -> (back to RefreshButton)
```

Shift+TAB (reverse) is the mirror of the above.

Each node's `focus_next` and `focus_previous` properties are set explicitly to enforce this order regardless of scene tree structure.

---

## Signal Contract

The new `ShopOverlay` preserves the existing signal interface so `main.gd` requires minimal changes.

| Signal              | Emitted when                        | Consumed by     |
|---------------------|-------------------------------------|-----------------|
| `continue_requested` | Close button pressed OR ESC pressed | `main.gd` `_on_shop_continue()` |

`main.gd._on_shop_requested()` is simplified to:
1. `_deactivate_gameplay()` + `_hide_gameplay_ui()`
2. `shop_overlay.show_shop(round_number)`
3. (ShopController, ShopSlideAnimation, tile/modifier sampling removed)

`main.gd._on_shop_continue()` is simplified to:
1. `shop_overlay.hide()`
2. `RunManager.proceed_from_shop()`
3. (finalize_shop_commit removed - no modifier assignments)
