## HurryBossHooks: Implements the Hurry boss time-attack mechanic.
##
## When active, the player must complete the round within a time limit.
## If time runs out before the target score is met, the round is lost
## (unless auto-win mode is enabled).
##
## Pure logic -- no Godot node references. Controllers read the config
## and manage the actual countdown timer.
class_name HurryBossHooks
extends BossHooks


## Returns time attack configuration for a 90-second countdown.
func get_time_attack_config() -> Dictionary:
	return {"time_limit": 90.0}
