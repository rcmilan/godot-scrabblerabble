extends RefCounted
class_name Run

## Run: Aggregate value object holding run configuration and qualities.
## Built by RunBuilder, consumed by RunManager.

# =============================================================================
# CONFIGURATION
# =============================================================================

var bag_config: BagDistribution = null
var plays_per_round: int = 2
var progression_config: ProgressionConfig = null
var qualities: Array[RunQuality] = []

# =============================================================================
# QUERIES
# =============================================================================

func has_custom_win_condition() -> bool:
	for quality in qualities:
		if quality.has_custom_win_condition():
			return true
	return false


func get_win_condition_qualities() -> Array[RunQuality]:
	var result: Array[RunQuality] = []
	for quality in qualities:
		if quality.has_custom_win_condition():
			result.append(quality)
	return result

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	var quality_dicts: Array[Dictionary] = []
	for quality in qualities:
		quality_dicts.append(quality.to_dict())

	return {
		"plays_per_round": plays_per_round,
		"qualities": quality_dicts,
	}


static func from_dict(data: Dictionary, bag: BagDistribution, progression: ProgressionConfig) -> Run:
	var run := Run.new()
	run.bag_config = bag
	run.progression_config = progression
	run.plays_per_round = data.get("plays_per_round", 2)

	var quality_dicts: Array = data.get("qualities", [])
	for qd in quality_dicts:
		var quality := QualityRegistry.create_from_dict(qd)
		if quality:
			run.qualities.append(quality)

	return run
