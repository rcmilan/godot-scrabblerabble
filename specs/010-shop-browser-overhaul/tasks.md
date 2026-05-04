# Tasks: Shop Browser Overhaul

**Input**: Design documents from `/specs/010-shop-browser-overhaul/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Import external assets and verify prerequisites are in place before any scene work begins.

- [x] T001 Copy exe_icon.png, dll_icon.png, bat_icon.png from godot-design-95 (theme/icon/) into scenes/shop/icons/ in this project
- [x] T002 Verify webcore_theme.tres exists in the project and ThemeSetup is listed as an autoload in project.godot; document findings - no code change if already present

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core building blocks that ALL user stories depend on. Must be complete before any story phase begins.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Create scripts/domain/shop/shop_item.gd - pure GDScript class (no Godot node base), define Type enum (EXE=0, DLL=1, BAT=2), readonly fields `type: Type` and `index: int`, static factory `create(type: Type, index: int) -> ShopItem`
- [x] T004 Create scenes/shop/shop_overlay.tscn - replace existing file entirely; build scene tree: ShopOverlay (Control, full-rect anchor, z_index=10) > BrowserWindow (Panel, theme_type_variation="WindowPanel", anchored center, min_size 640x420) > VBoxContainer > [TitleBar Panel (theme "TitleBarActive", min_height 20) containing HBoxContainer > [Title Label (theme "TitleBarLabel", text "shop.com - Internet Explorer", size_flags expand), CloseButton (Button, theme "TitleBarButton", text "X", custom_minimum_size 20x20)]] > [Toolbar Panel (theme "Win95MenuBar", min_height 26) containing HBoxContainer > [RefreshButton (Button, text "Refresh"), UrlBar (LineEdit, text "shop.com", editable false, size_flags expand)]] > [ContentArea Panel, size_flags expand+fill, containing GridContainer (ItemGrid, columns 3, alignment center) containing 9x ShopItemCell (Button, custom_minimum_size 80x80, FOCUS_ALL, each containing TextureRect "Icon" 32x32 + ColorRect "DimOverlay" full-rect semi-transparent + Label "SoonLabel" text "?" centered)]
- [x] T005 Create scenes/shop/shop_overlay.gd - replace existing file entirely; class_name ShopOverlay extends Control; declare signal continue_requested; declare @onready refs for CloseButton, RefreshButton, UrlBar, ItemGrid, and all 9 ShopItemCell nodes; _ready() connects no signals yet (leave for story phases), calls hide()

**Checkpoint**: ShopItem type exists, scene tree is built, script skeleton compiles. Open the scene in Godot editor to confirm no errors before proceeding.

---

## Phase 3: User Story 1 - Open and Navigate the Shop Browser (Priority: P1) MVP

**Goal**: The Win95 browser window appears when the shop phase starts, the URL bar shows "shop.com" read-only, and the player can cycle through all 11 interactive elements using TAB and Shift+TAB.

**Independent Test**: Complete a round in-game. Browser window appears. Press TAB 11 times and confirm focus returns to RefreshButton. Press Shift+TAB and confirm focus goes to CloseButton. Confirm URL bar cannot be typed in.

- [x] T006 [US1] In scenes/shop/shop_overlay.gd _ready(): wire focus chain using focus_next and focus_previous NodePath properties in code - RefreshButton.focus_next points to Cell0, Cell0..Cell7 each point to next cell, Cell8.focus_next points to CloseButton, CloseButton.focus_next wraps back to RefreshButton; mirror all in reverse for focus_previous
- [x] T007 [P] [US1] In scenes/shop/shop_overlay.gd: define ITEM_TYPES constant array [EXE, DLL, EXE, DLL, BAT, EXE, BAT, DLL, BAT] (3 of each) and ICON_MAP dictionary mapping ShopItem.Type to preloaded Texture2D from scenes/shop/icons/; implement show_shop(round_number: int) to iterate cells, assign Icon.texture from ICON_MAP, then call show() and RefreshButton.grab_focus()
- [x] T008 [P] [US1] In scenes/main.gd _on_shop_requested(): remove ShopController instantiation, ShopSlideAnimation entrance, RunManager.get_shop_tiles, RunManager.get_shop_modifiers, and ShopSession.new calls; replace with: brief pause (existing timer), _deactivate_gameplay(), _hide_gameplay_ui(), shop_overlay.show_shop(round_number)

**Checkpoint**: Launch game, complete a round, verify browser window appears. TAB cycles correctly through 11 elements. UrlBar cannot be edited. All cells show icons.

---

## Phase 4: User Story 2 - Close the Shop and Proceed to Next Round (Priority: P2)

**Goal**: Pressing the X button, clicking it with the mouse, or pressing ESC dismisses the shop and starts the next round.

**Independent Test**: Open shop, press ESC - shop closes, next round starts. Open shop again (if possible to replay), press TAB until CloseButton is focused, press ENTER - same result. Click X with mouse - same result.

- [x] T009 [US2] In scenes/shop/shop_overlay.gd: implement _close_shop() - calls hide() then emits continue_requested; in _ready() connect CloseButton.pressed to _close_shop
- [x] T010 [US2] In scenes/shop/shop_overlay.gd: implement _input(event) with visibility guard (return if not visible); check event.is_action_pressed("ui_cancel") -> call _close_shop() and get_viewport().set_input_as_handled()
- [x] T011 [US2] In scenes/main.gd _on_shop_continue(): remove ShopController finalize block and ShopSlideAnimation exit call; simplify to: shop_overlay.hide(), RunManager.proceed_from_shop()

**Checkpoint**: ESC closes shop and next round loads. Keyboard ENTER on CloseButton does the same. Mouse click on X does the same. No crash. No leftover _shop_controller variable errors (remove the field declaration if present).

---

## Phase 5: User Story 3 - Inspect Grid Items (Priority: P3)

**Goal**: Each of the 9 cells is focusable, shows the "coming soon" visual indicator (DimOverlay + SoonLabel visible), and pressing ENTER or clicking a cell produces no crash and no purchase action.

**Independent Test**: Open shop, TAB through each of the 9 cells. Each shows a visible dimmed overlay and "?" label. Press ENTER on each - nothing happens except focus stays on the cell. All 9 cells visible without scrolling.

- [x] T012 [US3] In scenes/shop/shop_overlay.gd _ready(): for each of the 9 ShopItemCell nodes, ensure DimOverlay and SoonLabel are visible (they should be visible by default from scene; confirm in code that no code hides them); connect each cell's pressed signal to a no-op lambda or empty function _on_cell_pressed(index: int) that does nothing
- [x] T013 [P] [US3] In scenes/shop/shop_overlay.gd _ready(): connect RefreshButton.pressed to a no-op function _on_refresh_pressed() that does nothing (placeholder for future reload logic)

**Checkpoint**: All 9 cells focusable. DimOverlay and SoonLabel visible on each. ENTER on any cell = no effect. ENTER on RefreshButton = no effect. No crash in any interaction.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final wiring cleanup, input isolation, and full manual verification pass.

- [x] T014 Verify input isolation in scenes/shop/shop_overlay.gd: confirm the visibility guard (if not visible: return) at the top of _input() prevents ESC from firing when shop is hidden; manually test by pressing ESC during normal gameplay (shop closed) and confirming no side effect occurs
- [x] T015 [P] Remove _shop_controller field declaration and any remaining ShopController/ShopSlideAnimation references from scenes/main.gd; confirm the file compiles without errors in Godot
- [ ] T016 Run full manual verification checklist from plan.md Phase F in Godot editor play mode: complete round, verify browser appears; TAB/Shift+TAB cycle; URL read-only; ENTER on close; mouse click on X; ESC; ENTER on refresh (no crash); ENTER on cell (no crash); all 9 cells + icons visible; no input leaks to gameplay

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately. T001 and T002 can run in parallel.
- **Foundational (Phase 2)**: Depends on Phase 1. T003 can start once T001 done (icon preloads). T004 can start after T002 (theme verified). T005 depends on T004 (needs scene to exist). Within Phase 2: T003 and T004 can run in parallel; T005 waits for T004.
- **User Story 1 (Phase 3)**: Depends on Phase 2 complete. T006 depends on T005. T007 depends on T003 (ShopItem.Type) and T005. T008 is independent (main.gd).
- **User Story 2 (Phase 4)**: Depends on Phase 3 complete (needs show_shop to exist). T009, T010 depend on T005. T011 depends on T008.
- **User Story 3 (Phase 5)**: Depends on Phase 3 complete (needs scene with cells). T012, T013 depend on T005.
- **Polish (Phase 6)**: Depends on all user story phases complete.

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational only. Start here - it's the MVP.
- **US2 (P2)**: Depends on US1 complete (close logic calls show_shop interface).
- **US3 (P3)**: Depends on US1 complete (needs grid cells from scene). Can overlap with US2 since they touch different functions.

### Parallel Opportunities

- T001 and T002 (both Phase 1) - parallel
- T003 and T004 (both Phase 2) - parallel
- T007 and T008 (both Phase 3) - parallel (different files)
- T012 and T013 (both Phase 5) - parallel (same file but different signal connections)
- T015 and T016 do not have ordering dependency on each other if T015 (cleanup) is done before running T016 (verify)

---

## Parallel Example: User Story 1

```
# Can run simultaneously:
Task T007: Implement show_shop() + icon assignment in scenes/shop/shop_overlay.gd
Task T008: Simplify _on_shop_requested() in scenes/main.gd

# Must run after T005 completes:
Task T006: Wire focus chain in scenes/shop/shop_overlay.gd _ready()
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001, T002)
2. Complete Phase 2: Foundational (T003, T004, T005)
3. Complete Phase 3: User Story 1 (T006, T007, T008)
4. **STOP and VALIDATE**: Browser opens, icons display, TAB navigation works, URL read-only
5. Continue to US2 only after US1 is confirmed working

### Incremental Delivery

1. Phase 1 + Phase 2 -> scene compiles, opens in editor
2. Phase 3 (US1) -> browser appears with icons and keyboard navigation (MVP!)
3. Phase 4 (US2) -> close and ESC work, game loop completes
4. Phase 5 (US3) -> coming-soon cells, full interaction coverage
5. Phase 6 -> verified, cleaned up, ready to merge

---

## Notes

- Godot .tscn files are plain text - T004 can be written directly without the editor
- ShopItem (T003) has no Godot base class - it is a pure GDScript RefCounted (or plain class) with no engine dependencies, per constitution Principle I
- The `ui_cancel` action (ESC) is built into Godot's default InputMap - no project.godot changes needed
- After T015 removes ShopController references, confirm no other file in the project imports ShopController before deleting it
- T016 is the acceptance gate - do not declare the feature done until all checklist items pass manually
