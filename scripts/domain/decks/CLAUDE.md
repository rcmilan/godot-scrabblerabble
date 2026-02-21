# Domain/Decks Directory

## Purpose
Contains deck definitions and DeckRegistry. Decks define tile pool distributions and optional bundled RunQuality modifiers. Players select a deck in the Run Setup popup before starting a run.

## Key Files
- `deck_definition.gd` - Abstract base class for deck definitions
- `deck_registry.gd` - Static factory registry for deck instantiation
- `standard_deck.gd` - Standard Scrabble-style distribution (98 tiles, frequency-weighted)
- `equal_deck.gd` - Equal distribution (26 tiles, 1 of each letter)
- `cursed_deck.gd` - Standard distribution with bundled AllResetQuality (all tiles carry RESET)

## Public Interfaces

### DeckRegistry (Static Factory)
```gdscript
class_name DeckRegistry extends RefCounted

static func register(id: StringName, factory: Callable) -> void
static func create_default(id: StringName) -> DeckDefinition
static func get_all_deck_ids() -> Array[StringName]
```

### DeckDefinition (Abstract Base Class)
```gdscript
class_name DeckDefinition extends RefCounted

# Identity
func get_id() -> StringName
func get_display_name() -> String
func get_description() -> String

# Factory methods
func create_distribution() -> BagDistribution
func create_bundled_quality() -> RunQuality  # default: return null
```

**Preconditions**:
- `get_id()` returns a non-empty, unique StringName
- `create_distribution()` returns a non-null BagDistribution where `is_valid() == true`

**Invariants**:
- `create_bundled_quality()` returns `null` or a valid RunQuality instance
- All methods are pure (no side-effects, no global state)

## Dependencies

### Internal
- `Data/BagDistribution/bag_distribution.gd` - BagDistribution resource class
- `Data/BagDistribution/bag_default.tres` - Standard distribution resource
- `Data/BagDistribution/bag_equal.tres` - Equal distribution resource
- `scripts/domain/run_quality.gd` - Abstract quality base class
- `scripts/domain/qualities/all_reset_quality.gd` - RESET modifier quality (Cursed deck)

### External (Godot)
- `RefCounted` - Base class for deck objects
- `StringName` - For deck IDs
- `load()` - Resource loading

## Architecture / Patterns

**Domain-Driven Design**: DeckDefinition is a value object representing a deck configuration, not a scene node.

**Registry Pattern**: Static factory with lazy initialization. Three built-in decks registered in `_ensure_initialized()`.

**Factory Method Pattern**: 
- DeckRegistry creates DeckDefinition instances
- DeckDefinition creates BagDistribution resources
- DeckDefinition creates optional RunQuality instances

**Strategy Pattern**: Deck selection determines tile distribution and bundled quality behavior.

**Composition**: Decks compose:
1. **BagDistribution** (required) - Defines tile pool composition
2. **RunQuality** (optional) - Defines gameplay modifiers

**Built-in Decks**:

| Deck ID | Display Name | Distribution | Bundled Quality | Description |
|---------|-------------|--------------|-----------------|-------------|
| `standard` | Standard | `bag_default.tres` (98 tiles) | None | Classic Scrabble-style frequency-weighted letters |
| `equal` | Equal | `bag_equal.tres` (26 tiles) | None | One of each letter (A-Z) |
| `cursed` | Cursed | `bag_default.tres` (98 tiles) | AllResetQuality | All tiles carry RESET modifier each round |

## Conventions

### Deck ID Naming
- Snake case StringNames: `&"standard"`, `&"equal"`, `&"cursed"`
- IDs must be unique across all decks
- Registry lookup returns `null` and logs warning for unknown IDs

### Distribution Loading
```gdscript
func create_distribution() -> BagDistribution:
    return load("res://Data/BagDistribution/bag_name.tres") as BagDistribution
```

### Bundled Quality Pattern
```gdscript
func create_bundled_quality() -> RunQuality:
    return ConcreteQuality.new()  # or return null for no quality
```

### Registration Pattern
```gdscript
_factories[&"deck_id"] = func() -> DeckDefinition: return ConcreteDeck.new()
```

### Behavioral Contracts
All deck methods carry specification contracts in doc comments:
- **Preconditions**: Requirements before method execution
- **Postconditions**: Guarantees after method execution
- **Invariants**: Properties that always hold

### Cyclomatic Complexity
All methods maintain cyclomatic complexity ≤ 5. Complex logic decomposed into helper methods.

## Build / Test
Test deck selection and behavior:
1. Launch game (`F5`)
2. Open Run Setup popup
3. Select different decks from dropdown
4. Verify description updates correctly
5. Start run and verify:
   - Tile pool matches expected distribution
   - Bundled quality activates (for Cursed deck: all tiles show RESET)
   - Hand refills correctly from deck
6. Complete round and verify tile bag empties as expected

**Verification Points**:
- Standard: Common letters (E, A, T) appear frequently
- Equal: Only 26 tiles total, one of each letter
- Cursed: All drawn tiles display RESET modifier indicator
