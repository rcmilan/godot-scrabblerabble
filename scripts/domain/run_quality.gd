extends RefCounted
class_name RunQuality

## RunQuality: Abstract base class for composable run modifiers.
## Subclasses override hooks to modify run/round behavior.
## Follows open-closed principle — new qualities require no existing code changes.

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted by timer qualities to report remaining time.
signal time_updated(time_remaining: float)

## Emitted by timer qualities when time runs out.
signal time_expired()

## Emitted by timer qualities when time is added (e.g. increment on play).
signal time_incremented(amount: float)

# =============================================================================
# IDENTITY (override in subclasses)
# =============================================================================

func get_quality_id() -> StringName:
	return &""


func get_quality_name() -> String:
	return ""


func get_description() -> String:
	return ""

# =============================================================================
# CONFIGURATION HOOKS
# =============================================================================

## Called once when the run is initialized. Modify run-level state here.
func apply_to_run_state(run_state: RunState) -> void:
	pass


## Called before each round starts. Modify round-level config here.
func apply_to_round_config(config: RoundConfig) -> void:
	pass

# =============================================================================
# LIFECYCLE HOOKS (forwarded by RunManager)
# =============================================================================

func on_round_started(round_number: int) -> void:
	pass


func on_play_completed(plays_remaining: int) -> void:
	pass


func on_score_updated(total_score: int, delta: int) -> void:
	pass


func on_round_ended(round_number: int, success: bool) -> void:
	pass


func on_process(delta: float) -> void:
	pass

# =============================================================================
# UI CAPABILITIES
# =============================================================================

## Override to true if this quality uses a countdown timer (emits time_updated).
func has_timer() -> bool:
	return false

# =============================================================================
# CUSTOM WIN CONDITION
# =============================================================================

## Override to true if this quality defines a custom run-end condition.
func has_custom_win_condition() -> bool:
	return false


## Check if the run should end. Return {"should_end": true/false, "victory": bool}.
func check_run_end_condition(run_state: RunState) -> Dictionary:
	return {"should_end": false}

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {"quality_id": get_quality_id()}
