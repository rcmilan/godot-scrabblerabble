## HardBossHooks: Implements the Hard boss mechanic.
##
## Doubles the per-round target score requirement.
## Background is metallic gray.
##
## Pure logic -- no Godot node references.
class_name HardBossHooks
extends BossHooks


## Target score is 2x harder.
func get_target_score_multiplier() -> float:
	return 2.0
