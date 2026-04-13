class_name HypeConfig
extends Resource

## HypeConfig: Centralized tuning resource for the Play hype sequence.
## All animation timings, speeds, and visual parameters are data-driven here.
## Designed for runtime modification via Godot Inspector.

# =============================================================================
# MASTER SPEED CONTROL
# =============================================================================

## Player-facing game speed multiplier. Runtime-settable via options screen.
## Range: 0.5x to 2.0x. All animation phases scale proportionally by this.
@export var master_speed_multiplier: float = 1.0

## Minimum allowed master speed (options screen lower bound).
@export var master_speed_min: float = 0.5

## Maximum allowed master speed (options screen upper bound).
@export var master_speed_max: float = 2.0

# =============================================================================
# TILE-COUNT SPEED SCALING
# =============================================================================

## Coefficient k in tile-count multiplier formula: 1.0 + k * n^exp
## Larger k = more aggressive scaling with tile count.
@export var speed_scale_k: float = 0.04

## Exponent n in tile-count formula (must be > 1 for proper exponential curve).
## Larger exponent = steeper curve (7-tile plays much faster than 1-tile).
@export var speed_scale_n: float = 2.0

## Minimum tile-count multiplier (baseline for 1-tile plays).
@export var tile_count_speed_min: float = 1.0

## Maximum tile-count multiplier (cap to prevent visual overload).
@export var tile_count_speed_max: float = 3.0

# =============================================================================
# ANIMATION DURATION CONSTRAINTS
# =============================================================================

## Minimum animation phase duration (seconds). No phase may fall below this,
## even with high speed multipliers. Ensures animations remain readable.
@export var min_animation_duration: float = 0.08

## Minimum stagger delay between tiles (seconds). Separate from min_animation_duration
## so stagger can approach near-zero at high tile counts (rapid-fire effect).
@export var min_stagger_delay: float = 0.01

## Normalized progress (0-1) at which a tile is considered "done" for score pop.
## For stomp: typically 0.65 = after slam, before recover.
## Used to emit score pop labels before animation fully completes.
@export var animation_completion_threshold: float = 0.65

# =============================================================================
# LIFT PHASE PARAMETERS
# =============================================================================

## Scale applied to tiles during the lift phase.
## Typical: Vector2(1.2, 1.2) for a slight enlargement upward.
@export var lift_scale: Vector2 = Vector2(1.2, 1.2)

## Vertical pixel offset during lift (negative = upward movement).
## Typical: -20.0 pixels up.
@export var lift_offset_y: float = -20.0

## Duration of the lift phase (seconds).
## Typical: 0.12 seconds for a quick anticipation beat.
@export var lift_duration: float = 0.12

# =============================================================================
# ANIMATION TYPE MAPPING
# =============================================================================

## Data-driven mapping from modifier/tile-type keys to animation preset names.
## Keys are tile modifier type strings (e.g., "EXTRA", "MULTI", "EXPO").
## Values are animation names ("stomp", "spin", or other custom types).
## Unmapped tiles fall back to default_animation.
@export var animation_mapping: Dictionary = {
	"EXTRA": "spin",
	"MULTI": "spin",
	"EXPO": "spin"
}

## Fallback animation preset when a tile type is absent from animation_mapping.
## Typical: "stomp".
@export var default_animation: String = "stomp"

# =============================================================================
# SCORE POP PARAMETERS
# =============================================================================

## How long a score pop label takes to travel from tile to HUD (seconds, at 1x speed).
## Scaled by effective multiplier at runtime (faster plays = faster travel).
@export var score_pop_travel_duration: float = 0.4

## Font size of floating score labels.
@export var score_pop_font_size: int = 22

# =============================================================================
# PULSE INTENSITY (Score Panel)
# =============================================================================

## Scale factor applied to score panel pulse at 1.0 intensity.
## Maps existing pulse behavior (1.0 intensity = original pulse scale).
@export var pulse_base_scale: float = 1.15

## Maximum pulse intensity before clamping.
## Prevents visual distortion from extreme score contributions.
## Typical: 3.0 (allows up to 3x base pulse magnitude).
@export var pulse_intensity_max: float = 3.0

## Intensity threshold at or above which secondary visual effect (shake) triggers.
## Typical: 1.5 (activates on moderate-to-high scores).
@export var secondary_effect_threshold: float = 1.5

## Pixel magnitude of the shake effect applied to score panel.
## Typical: 4.0 pixels horizontal displacement.
@export var secondary_effect_magnitude: float = 4.0

# =============================================================================
# DEBUG & LOGGING
# =============================================================================

## Toggles structured debug logs for the hype sequence.
## When true, logs tile count, speed multipliers, and timing info.
## Off by default to keep production logs clean.
@export var debug_logging_enabled: bool = false

# =============================================================================
# STAGGER PARAMETERS
# =============================================================================

## Base stagger delay between tiles in stomp/spin batches (seconds, at 1x speed).
## Scaled by effective multiplier at runtime.
@export var inter_tile_stagger_delay: float = 0.06

# =============================================================================
# COMPUTED METHODS (not stored; derived from above)
# =============================================================================

## Computes the tile-count multiplier for a given tile count.
## Formula: clamp(1.0 + k * n^exp, min, max)
## Produces exponential scaling: 1-tile ≈ 1.0x, 7-tile ≈ 2.5-3.0x
func get_tile_count_multiplier(tile_count: int) -> float:
	var raw_multiplier = 1.0 + speed_scale_k * pow(tile_count, speed_scale_n)
	return clamp(raw_multiplier, tile_count_speed_min, tile_count_speed_max)


## Computes the effective multiplier combining tile-count and master speed.
func get_effective_multiplier(tile_count: int) -> float:
	return get_tile_count_multiplier(tile_count) * master_speed_multiplier


## Scales a base duration by the effective multiplier, with min threshold.
## Returns: max(base / multiplier, min_threshold)
## Ensures no animation falls below readable minimum duration.
func scale_duration(base: float, multiplier: float) -> float:
	return maxf(base / multiplier, min_animation_duration)


## Scales a stagger delay by the effective multiplier, with a much smaller floor.
## Stagger should approach near-zero at high tile counts (rapid-fire effect).
## Uses min_stagger_delay instead of min_animation_duration.
func scale_stagger(base: float, multiplier: float) -> float:
	return maxf(base / multiplier, min_stagger_delay)
