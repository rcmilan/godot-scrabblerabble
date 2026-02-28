extends Resource

class_name LetterTileData

## Single letter represented by this tile data
@export var letter: String = " "

## Base point value for this letter (Scrabble-style scoring)
@export var base_points: int = 1

## Visual texture displayed on the tile
@export var texture: Texture2D
