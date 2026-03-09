class_name DomainEventBus
extends Node

## Event bus using Godot signals for domain event dispatch.

signal tile_state_changed(event: TileStateChanged)
signal tile_placed(tile_id: int, cell_position: Vector2i)
signal tiles_swapped(tile_a_id: int, tile_b_id: int)


func publish_tile_state_changed(event: TileStateChanged) -> void:
	tile_state_changed.emit(event)


func publish_tile_placed(tile_id: int, cell_position: Vector2i) -> void:
	tile_placed.emit(tile_id, cell_position)


func publish_tiles_swapped(tile_a_id: int, tile_b_id: int) -> void:
	tiles_swapped.emit(tile_a_id, tile_b_id)
