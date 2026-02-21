# Decks Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `DeckDefinition` domain abstraction so players can choose a tile deck (Standard, Equal, Cursed) before starting a run, with the selection wired through `RunBuilder` and surfaced in the Run Setup popup.

**Architecture:** `DeckDefinition extends RefCounted` is an abstract value object with virtual factory methods; three concrete subclasses cover the built-in decks. `DeckRegistry` follows the exact `QualityRegistry` pattern. `RunBuilder.set_deck()` replaces the hardcoded `set_bag()` call in the popup. The popup gains a dynamic deck-selector section built identically to how quality checkboxes are built today.

**Tech Stack:** GDScript 4, Godot 4.5.1, no external dependencies. Specs are behavioral contracts in doc comments (no test runner). Verify each task by launching the game (`F5`) and checking the expected UI/behaviour.

---

## Reference: Key Existing Files

Before starting, skim these files once so the patterns are fresh:

- `scripts/domain/run_quality.gd` — abstract base pattern to mirror for `DeckDefinition`
- `scripts/domain/qualities/quality_registry.gd` — exact registry pattern to copy
- `scripts/domain/qualities/random_modifiers_quality.gd` — `TileBag.available_tiles` + `ModifierRegistry.create_modifier()` usage
- `scripts/domain/run_builder.gd` — where `set_bag()` lives; `build()` priority logic
- `scenes/title_screen/run_setup_popup.gd` — dynamic UI construction to mirror for deck section
- `Data/BagDistribution/bag_default.tres` — `.tres` format to copy for `bag_equal.tres`

---

## Task 1: Create `bag_equal.tres`

**Files:**
- Create: `Data/BagDistribution/bag_equal.tres`

**Step 1: Write the spec contract (in a comment at the top of the file)**

The `.tres` format is plain text. The spec is: distribution must contain exactly the 26 letters A–Z, each with count 1. `is_valid()` must return `true`.

**Step 2: Create the file**

```
[gd_resource type="Resource" script_class="BagDistribution" load_steps=2 format=3 uid="uid://bag_equal_deck_1"]

[ext_resource type="Script" uid="uid://dmo2awwrmb1jw" path="res://Data/BagDistribution/bag_distribution.gd" id="1_q047y"]

[resource]
script = ExtResource("1_q047y")
distribution = {
"A": 1,
"B": 1,
"C": 1,
"D": 1,
"E": 1,
"F": 1,
"G": 1,
"H": 1,
"I": 1,
"J": 1,
"K": 1,
"L": 1,
"M": 1,
"N": 1,
"O": 1,
"P": 1,
"Q": 1,
"R": 1,
"S": 1,
"T": 1,
"U": 1,
"V": 1,
"W": 1,
"X": 1,
"Y": 1,
"Z": 1
}
metadata/_custom_type_script = "uid://dmo2awwrmb1jw"
```

> **Note:** The `uid` value `uid://bag_equal_deck_1` is a placeholder. Godot will regenerate a proper UID the first time it imports the file. That is expected — do not manually fix it.

**Step 3: Verify**

Launch the game (`F5`). The project must load without errors in the Output panel. No crash on startup = pass.

**Step 4: Commit**

```bash
git add Data/BagDistribution/bag_equal.tres
git commit -m "feat: add equal bag distribution (26 tiles, 1 per letter)"
```

---

## Task 2: Create `DeckDefinition` abstract base

**Files:**
- Create: `scripts/domain/decks/deck_definition.gd`

**Step 1: Write the spec contracts first, then implement**

The contracts go in the doc comment block at the top of the file:

```
## Precondition : get_id() returns a non-empty, unique StringName.
## Precondition : create_distribution() returns a non-null BagDistribution where is_valid() == true.
## Invariant    : create_bundled_quality() returns null or a valid RunQuality instance.
## Invariant    : all methods are pure (no side-effects, no global state).
```

**Step 2: Implement**

```gdscript
extends RefCounted
class_name DeckDefinition

## DeckDefinition: Abstract base for player-selectable tile decks.
## A deck defines the tile pool (via create_distribution()) and may bundle
## a RunQuality that modifies tile state each round (via create_bundled_quality()).
##
## Precondition : get_id() returns a non-empty, unique StringName.
## Precondition : create_distribution() returns a non-null BagDistribution where is_valid() == true.
## Invariant    : create_bundled_quality() returns null or a valid RunQuality instance.
## Invariant    : all methods are pure (no side-effects, no global state).

# =============================================================================
# IDENTITY  (override in subclasses)
# =============================================================================

func get_id() -> StringName:
	return &""


func get_display_name() -> String:
	return ""


func get_description() -> String:
	return ""

# =============================================================================
# FACTORY  (override in subclasses)
# =============================================================================

## Returns the tile distribution for this deck.
## Postcondition: result != null and result.is_valid() == true.
func create_distribution() -> BagDistribution:
	return null


## Returns a RunQuality to auto-bundle with the run, or null if none.
func create_bundled_quality() -> RunQuality:
	return null
```

**Step 3: Verify**

Launch game (`F5`). No errors in Output panel. Pass.

**Step 4: Commit**

```bash
git add scripts/domain/decks/deck_definition.gd
git commit -m "feat: add DeckDefinition abstract base class"
```

---

## Task 3: Create `StandardDeck` and `EqualDeck`

**Files:**
- Create: `scripts/domain/decks/standard_deck.gd`
- Create: `scripts/domain/decks/equal_deck.gd`

**Step 1: Implement `StandardDeck`**

```gdscript
extends DeckDefinition
class_name StandardDeck

## StandardDeck: Scrabble-style distribution (98 tiles, frequency-weighted).
## No bundled quality.
##
## Postcondition: create_distribution() loads bag_default.tres successfully.

func get_id() -> StringName:
	return &"standard"


func get_display_name() -> String:
	return "Standard"


func get_description() -> String:
	return "Classic Scrabble-style distribution. Common letters appear more often."


func create_distribution() -> BagDistribution:
	return load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
```

**Step 2: Implement `EqualDeck`**

```gdscript
extends DeckDefinition
class_name EqualDeck

## EqualDeck: One of each letter (26 tiles total).
## No bundled quality.
##
## Postcondition: create_distribution() loads bag_equal.tres successfully.

func get_id() -> StringName:
	return &"equal"


func get_display_name() -> String:
	return "Equal"


func get_description() -> String:
	return "One of every letter. Each tile is equally likely — plan your words carefully."


func create_distribution() -> BagDistribution:
	return load("res://Data/BagDistribution/bag_equal.tres") as BagDistribution
```

**Step 3: Verify**

Launch game (`F5`). No errors. Pass.

**Step 4: Commit**

```bash
git add scripts/domain/decks/standard_deck.gd scripts/domain/decks/equal_deck.gd
git commit -m "feat: add StandardDeck and EqualDeck concrete decks"
```

---

## Task 4: Create `AllResetQuality`

**Files:**
- Create: `scripts/domain/qualities/all_reset_quality.gd`

**Step 1: Understand the pattern**

`RandomModifiersQuality.on_round_started()` iterates `TileBag.available_tiles` and calls `tile.add_modifier(ModifierRegistry.create_modifier(type, tier, lifetime))`. `AllResetQuality` does the same but deterministically: every tile gets `RESET / BRONZE / PER_ROUND`.

`tile.add_modifier()` replaces existing modifier by type — no duplicates possible (existing invariant).

**Step 2: Implement**

```gdscript
extends RunQuality
class_name AllResetQuality

## AllResetQuality: Applies RESET/PER_ROUND modifier to every bag tile at round start.
## Bundled by CursedDeck; NOT registered in QualityRegistry (not shown in UI quality list).
##
## on_round_started:
##   Precondition : TileBag.available_tiles is populated.
##   Postcondition: every tile in TileBag.available_tiles carries a RESET/PER_ROUND modifier.
##   Invariant    : tile.add_modifier() replaces by type — no duplicates possible.

# =============================================================================
# IDENTITY
# =============================================================================

func get_quality_id() -> StringName:
	return &"all_reset"


func get_quality_name() -> String:
	return "Cursed Tiles"


func get_description() -> String:
	return "All tiles carry the Reset modifier each round."

# =============================================================================
# LIFECYCLE
# =============================================================================

func on_round_started(_round_number: int) -> void:
	_apply_reset_to_all_bag_tiles()


# =============================================================================
# PRIVATE
# =============================================================================

func _apply_reset_to_all_bag_tiles() -> void:
	for tile in TileBag.available_tiles:
		var modifier: ModifierInstance = ModifierRegistry.create_modifier(
			ModifierTypes.Type.RESET,
			ModifierTypes.Tier.BRONZE,
			ModifierTypes.Lifetime.PER_ROUND
		)
		tile.add_modifier(modifier)
	print("[AllResetQuality] Applied RESET to %d bag tiles" % TileBag.available_tiles.size())
```

**Step 3: Verify**

Launch game (`F5`). No errors. Pass.

**Step 4: Commit**

```bash
git add scripts/domain/qualities/all_reset_quality.gd
git commit -m "feat: add AllResetQuality (applies RESET to all bag tiles each round)"
```

---

## Task 5: Create `CursedDeck`

**Files:**
- Create: `scripts/domain/decks/cursed_deck.gd`

**Step 1: Implement**

```gdscript
extends DeckDefinition
class_name CursedDeck

## CursedDeck: Standard distribution with AllResetQuality bundled.
## Every tile drawn will carry the RESET modifier each round.
##
## Postcondition: create_distribution() returns bag_default.tres distribution.
## Postcondition: create_bundled_quality() returns a valid AllResetQuality instance.

func get_id() -> StringName:
	return &"cursed"


func get_display_name() -> String:
	return "Cursed"


func get_description() -> String:
	return "Familiar letters, dark magic. All tiles carry the Reset modifier every round."


func create_distribution() -> BagDistribution:
	return load("res://Data/BagDistribution/bag_default.tres") as BagDistribution


func create_bundled_quality() -> RunQuality:
	return AllResetQuality.new()
```

**Step 2: Verify**

Launch game (`F5`). No errors. Pass.

**Step 3: Commit**

```bash
git add scripts/domain/decks/cursed_deck.gd
git commit -m "feat: add CursedDeck (bundles AllResetQuality)"
```

---

## Task 6: Create `DeckRegistry`

**Files:**
- Create: `scripts/domain/decks/deck_registry.gd`

**Step 1: Understand the pattern**

Copy the structure of `scripts/domain/qualities/quality_registry.gd` exactly:
- `static var _factories: Dictionary`
- `static var _initialized: bool`
- `_ensure_initialized()` registers all built-in decks
- `create_default(id)` / `get_all_deck_ids()` public API

**Step 2: Implement**

```gdscript
extends RefCounted
class_name DeckRegistry

## DeckRegistry: Static factory registry for DeckDefinition types.
## Mirrors QualityRegistry. Maps deck IDs to factory callables.
##
## Precondition : _factories populated with standard, equal, cursed on first access.
## Postcondition: create_default(unknown_id) returns null and logs a warning.
## Invariant    : all registered IDs are unique StringNames.

# =============================================================================
# REGISTRY STATE
# =============================================================================

static var _factories: Dictionary = {}
static var _initialized: bool = false

# =============================================================================
# PUBLIC API
# =============================================================================

static func register(id: StringName, factory: Callable) -> void:
	_ensure_initialized()
	_factories[id] = factory


static func create_default(id: StringName) -> DeckDefinition:
	_ensure_initialized()
	if not _factories.has(id):
		push_warning("[DeckRegistry] Unknown deck ID: %s" % id)
		return null
	return _factories[id].call()


static func get_all_deck_ids() -> Array[StringName]:
	_ensure_initialized()
	var ids: Array[StringName] = []
	for key in _factories.keys():
		ids.append(key)
	return ids

# =============================================================================
# INITIALIZATION
# =============================================================================

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	_factories[&"standard"] = func() -> DeckDefinition: return StandardDeck.new()
	_factories[&"equal"]    = func() -> DeckDefinition: return EqualDeck.new()
	_factories[&"cursed"]   = func() -> DeckDefinition: return CursedDeck.new()
```

**Step 3: Verify**

Launch game (`F5`). No errors. Pass.

**Step 4: Commit**

```bash
git add scripts/domain/decks/deck_registry.gd
git commit -m "feat: add DeckRegistry static factory (standard, equal, cursed)"
```

---

## Task 7: Update `RunBuilder` — add `set_deck()`

**Files:**
- Modify: `scripts/domain/run_builder.gd`

**Step 1: Read the current file first**

Open `scripts/domain/run_builder.gd`. Current state:
- `var _bag_config: BagDistribution = null`
- `func set_bag(bag: BagDistribution) -> RunBuilder`
- `build()` uses `_bag_config` with fallback to `bag_default.tres`

**Step 2: Add `_deck` field and `set_deck()` method**

Add after line `var _bag_config: BagDistribution = null`:

```gdscript
var _deck: DeckDefinition = null
```

Add after the existing `set_bag()` method:

```gdscript
## set_deck: Selects a deck for this run.
## Postcondition: build() uses deck.create_distribution() as bag_config.
## Postcondition: if deck.create_bundled_quality() != null, quality is added to run.qualities.
## Invariant    : deck takes precedence over set_bag() when both are called.
func set_deck(deck: DeckDefinition) -> RunBuilder:
	_deck = deck
	return self
```

**Step 3: Update `build()` — apply deck before bag fallback**

In `build()`, replace the existing bag-config block:

```gdscript
# OLD (lines ~65-72):
if _bag_config:
    run.bag_config = _bag_config
else:
    var default_bag := load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
    if default_bag == null:
        push_error("[RunBuilder] Failed to load default bag distribution")
    run.bag_config = default_bag
```

Replace with:

```gdscript
if _deck:
    run.bag_config = _deck.create_distribution()
    var bundled := _deck.create_bundled_quality()
    if bundled != null:
        add_quality(bundled)
elif _bag_config:
    run.bag_config = _bag_config
else:
    var default_bag := load("res://Data/BagDistribution/bag_default.tres") as BagDistribution
    if default_bag == null:
        push_error("[RunBuilder] Failed to load default bag distribution")
    run.bag_config = default_bag
```

**Step 4: Verify**

Launch game (`F5`) and start a new game using the existing flow (before UI rework). Game must reach gameplay without errors. Pass.

**Step 5: Commit**

```bash
git add scripts/domain/run_builder.gd
git commit -m "feat: add RunBuilder.set_deck() with auto-bundled quality support"
```

---

## Task 8: Rework `RunSetupPopup` — add deck selector

**Files:**
- Modify: `scenes/title_screen/run_setup_popup.gd`

**Step 1: Read the current file first**

Open `scenes/title_screen/run_setup_popup.gd`. Key points:
- `@onready var _quality_list: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/QualityList`
- `_ready()` calls `_populate_quality_list()` which creates checkboxes dynamically
- `_build_run()` hardcodes `builder.set_bag(load("res://Data/BagDistribution/bag_default.tres"))`

**Step 2: Add new fields**

Add after the existing `@onready` declarations:

```gdscript
@onready var _content_vbox: VBoxContainer = $Panel/MarginContainer/VBoxContainer

var _deck_option: OptionButton = null
var _deck_desc_label: Label = null
var _deck_ids: Array[StringName] = []
```

**Step 3: Add `_populate_deck_selector()` private method**

Add this new method (before `_populate_quality_list`):

```gdscript
func _populate_deck_selector() -> void:
	# Deck label
	var deck_label := Label.new()
	deck_label.text = "Deck"
	deck_label.add_theme_font_size_override("font_size", 14)

	# OptionButton
	_deck_option = OptionButton.new()
	_deck_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_ids = DeckRegistry.get_all_deck_ids()
	for id in _deck_ids:
		var deck := DeckRegistry.create_default(id)
		_deck_option.add_item(deck.get_display_name())
	_deck_option.item_selected.connect(_on_deck_selected)

	# Description label
	_deck_desc_label = Label.new()
	_deck_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_desc_label.add_theme_font_size_override("font_size", 12)
	_deck_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Section container
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(deck_label)
	section.add_child(_deck_option)
	section.add_child(_deck_desc_label)

	# Separator below deck section
	var sep := HSeparator.new()

	# Insert at top of content vbox (before ScrollContainer)
	_content_vbox.add_child(section)
	_content_vbox.add_child(sep)
	_content_vbox.move_child(section, 0)
	_content_vbox.move_child(sep, 1)

	# Trigger initial description display
	_on_deck_selected(0)
```

**Step 4: Add `_on_deck_selected()` callback and `_get_selected_deck()` helper**

```gdscript
func _on_deck_selected(index: int) -> void:
	if _deck_desc_label == null or index >= _deck_ids.size():
		return
	var deck := DeckRegistry.create_default(_deck_ids[index])
	if deck:
		_deck_desc_label.text = deck.get_description()


func _get_selected_deck() -> DeckDefinition:
	var index := _deck_option.selected if _deck_option else 0
	if index < 0 or index >= _deck_ids.size():
		return StandardDeck.new()
	return DeckRegistry.create_default(_deck_ids[index])
```

**Step 5: Update `_ready()` — call `_populate_deck_selector()`**

In `_ready()`, add the call right before `_populate_quality_list()`:

```gdscript
func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	set_process_input(true)
	_populate_deck_selector()   # <- add this line
	_populate_quality_list()
```

**Step 6: Update `_build_run()` — replace `set_bag` with `set_deck`**

Find this line in `_build_run()`:

```gdscript
builder.set_bag(load("res://Data/BagDistribution/bag_default.tres"))
```

Replace with:

```gdscript
builder.set_deck(_get_selected_deck())
```

**Step 7: Verify in-game**

1. Launch the game (`F5`).
2. Click **New Game** on the title screen.
3. The Run Setup popup must show a **Deck** dropdown at the top with three options: Standard, Equal, Cursed.
4. Selecting each option must update the description label below the dropdown.
5. Select **Standard** → click **Start** → gameplay loads with the normal tile bag (verify via Debug Console: press `D`, type `draw 10`, hand fills as expected).
6. Select **Equal** → click **Start** → gameplay loads with 26-tile bag (bag runs out faster).
7. Select **Cursed** → click **Start** → gameplay loads; all tiles in hand should show the RESET visual (inverted shader / no badges).

**Step 8: Commit**

```bash
git add scenes/title_screen/run_setup_popup.gd
git commit -m "feat: rework RunSetupPopup to add deck selector (Standard/Equal/Cursed)"
```

---

## Final Verification Checklist

Run through all three decks end-to-end:

- [ ] Standard: familiar tile frequencies, no modifiers unless Random Modifiers quality selected
- [ ] Equal: only 26 tiles total — bag empties quickly, hand draws show `[TileBag] Empty` sooner
- [ ] Cursed: all drawn tiles show inverted shader (RESET visual); playing a tile shows the stomp animation (RESET denies spin); scoring shows base points only

If any step fails, check the Output panel for errors — they will point to the exact line.

---

## Out of Scope (do not implement now)

- Saving selected deck between sessions
- Animated deck preview or card-flip UI
- Deck unlocking / progression gates
