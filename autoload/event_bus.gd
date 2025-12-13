extends Node

# EventBus: A central hub for signals to decouple game components.

signal tile_placed(tile_data, grid_position)
signal turn_started(turn_number)
signal turn_ended(turn_number)
signal game_over(final_score)
signal score_updated(new_score)
signal hand_letter_selected(letter)
signal hand_tile_selected(tile_node)
signal hand_tile_right_clicked(tile_node)
signal tiles_committed(tile_count)
signal discard_count_changed(total_discards)
signal discard_pile_changed(pile_size)
