# Decks Feature Design

**Date**: 2026-02-21
**Status**: Approved

---

## Overview

Add a first-class `Deck` domain concept to Wordatro. A deck defines the tile pool (letter
distribution) and may bundle a `RunQuality` that modifies tile state each round. Players
select a deck in the Run Setup popup before starting a run.

Three built-in decks ship with this feature:

| Deck | Distribution | Bundled Quality |
|------|-------------|-----------------|
| Standard | `bag_default.tres` — 98 tiles, Scrabble frequencies | none |
| Equal | `bag_equal.tres` — 26 tiles, 1 of each letter | none |
| Cursed | `bag_default.tres` — familiar frequencies | `AllResetQuality` (all tiles carry RESET each round) |

---

## Design Principles

- OOP + DDD: `DeckDefinition` is a domain value object, not a scene node.
- Spec-Driven: every public method carries behavioural contracts as doc comments.
- Cyclomatic complexity ≤ 5; decompose any method that exceeds it.
- High-frequency, low-verbosity patterns: follow `RunQuality` / `QualityRegistry` exactly.

---

## Domain Model (`scripts/domain/decks/`)

### `DeckDefinition extends RefCounted`

Abstract base class. Mirrors `RunQuality` structure.

```gdscript
## Precondition : get_id() returns a non-empty, unique StringName.
## Precondition : create_distribution() returns a valid BagDistribution (is_valid() == true).
## Invariant    : create_bundled_quality() returns null or a valid RunQuality instance.

func get_id() -> StringName
func get_display_name() -> String
func get_description() -> String
func create_distribution() -> BagDistribution
func create_bundled_quality() -> RunQuality   # default: return null
```

### Concrete Decks

**`StandardDeck extends DeckDefinition`**
- `get_id()` → `&"standard"`
- `create_distribution()` → loads `res://Data/BagDistribution/bag_default.tres`
- `create_bundled_quality()` → `null`

**`EqualDeck extends DeckDefinition`**
- `get_id()` → `&"equal"`
- `create_distribution()` → loads `res://Data/BagDistribution/bag_equal.tres`
- `create_bundled_quality()` → `null`

**`CursedDeck extends DeckDefinition`**
- `get_id()` → `&"cursed"`
- `create_distribution()` → loads `res://Data/BagDistribution/bag_default.tres`
- `create_bundled_quality()` → `AllResetQuality.new()`

### `DeckRegistry extends RefCounted`

Static factory. Identical pattern to `QualityRegistry`.

```gdscript
## Precondition : _factories populated with standard, equal, cursed on first access.
## Postcondition: create_default(unknown_id) returns null and logs a warning.
## Invariant    : all registered IDs are unique StringNames.

static func register(id: StringName, factory: Callable) -> void
static func create_default(id: StringName) -> DeckDefinition
static func get_all_deck_ids() -> Array[StringName]
```

---

## New Quality (`scripts/domain/qualities/`)

### `AllResetQuality extends RunQuality`

Applied each round to all tiles currently in the bag.

```gdscript
## get_quality_id() → &"all_reset"
## NOT registered in QualityRegistry (deck-bundled only; hidden from UI quality list).
##
## on_round_started:
##   Precondition : TileBag.available_tiles is populated.
##   Postcondition: every tile in TileBag.available_tiles carries a RESET / PER_ROUND modifier.
##   Invariant    : tile.add_modifier() replaces existing RESET by type — no duplicates.
```

---

## New Data File

**`Data/BagDistribution/bag_equal.tres`**
- Type: `BagDistribution`
- Distribution: all 26 letters (A–Z), count = 1 each (26 tiles total).

---

## RunBuilder Integration (`scripts/domain/run_builder.gd`)

Add `set_deck()` alongside the existing `set_bag()`.

```gdscript
## set_deck(deck):
##   Postcondition: build() sets run.bag_config = deck.create_distribution().
##   Postcondition: if deck.create_bundled_quality() != null, quality is added to run.qualities.
##   Invariant    : deck takes precedence over set_bag() when both are called.
##   Invariant    : bundled quality obeys existing duplicate-guard in add_quality().
##
## set_bag() is kept unchanged for the legacy initialize_run() path.
```

Build priority: `_deck` → `_bag_config` → default `bag_default.tres`.

---

## RunSetupPopup Rework (`scenes/title_screen/run_setup_popup.gd`)

Add a **Deck section** above the existing quality list. No new scene file needed — add
nodes dynamically in `_ready()` the same way quality checkboxes are built today.

### New Layout

```
RunSetupPopup (Panel)
└── VBoxContainer
    ├── [NEW] Deck Section (VBoxContainer)
    │   ├── Label  "Deck"
    │   ├── OptionButton  (one item per DeckRegistry entry)
    │   └── Label  deck description — updates on selection change
    ├── [NEW] HSeparator
    ├── [existing] Label  "Modifiers"
    ├── [existing] ScrollContainer → QualityList
    └── [existing] ButtonContainer  (Start / Back)
```

### Behaviour Specs

```
## Spec: _populate_deck_selector() fills OptionButton from DeckRegistry.get_all_deck_ids().
## Spec: default selected index corresponds to &"standard".
## Spec: on OptionButton.item_selected → description label updates immediately.
## Spec: _build_run() calls builder.set_deck(_get_selected_deck()).
## Spec: Start with Standard → run.bag_config == bag_default.tres distribution.
## Spec: Start with CursedDeck → AllResetQuality present in run.qualities.
```

---

## File Map

### New Files

| Path | Purpose |
|------|---------|
| `scripts/domain/decks/deck_definition.gd` | Abstract base `DeckDefinition` |
| `scripts/domain/decks/standard_deck.gd` | StandardDeck |
| `scripts/domain/decks/equal_deck.gd` | EqualDeck |
| `scripts/domain/decks/cursed_deck.gd` | CursedDeck |
| `scripts/domain/decks/deck_registry.gd` | Static factory registry |
| `scripts/domain/qualities/all_reset_quality.gd` | AllResetQuality |
| `Data/BagDistribution/bag_equal.tres` | Equal distribution (26 × 1) |

### Modified Files

| Path | Change |
|------|--------|
| `scripts/domain/run_builder.gd` | Add `set_deck()`, update `build()` priority |
| `scenes/title_screen/run_setup_popup.gd` | Add deck selector section |

---

## Out of Scope

- Saving/loading selected deck between sessions (future: save system).
- Animated deck preview or card-flip UI (future: UI polish phase).
- Deck unlocking / progression gates (future: meta-progression phase).
