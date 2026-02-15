class_name ModifierPipeline

## ModifierPipeline: Single source of truth for modifier execution order.
## Controls both scoring computation AND badge display order everywhere.

static var execution_order: Array[int] = [
	ModifierTypes.Type.RESET,   # Short-circuits to 0
	ModifierTypes.Type.EXTRA,   # Additive bonus
	ModifierTypes.Type.EXPO,    # Exponential
	ModifierTypes.Type.MULTI,   # Multiplicative
]
