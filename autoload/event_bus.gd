extends Node

## EventBus for global game events
## Central hub for signals to decouple game components

# Signals for game flow
signal turn_started(turn_num: int)
signal turn_ended(turn_num: int, score_added: int)
signal game_over(won: bool)

# TODO: Add more signals for tile placement, word validation, etc.