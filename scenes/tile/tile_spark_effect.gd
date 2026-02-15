class_name TileSparkEffect
extends Node2D

## TileSparkEffect: Emits one subtle spark every ~3 seconds
## at a random position within the tile.

var spark_color: Color = Color.RED
var interval: float = 3.0
var _timer: float = 0.0


func _ready():
	_timer = randf() * interval  # Random initial offset, avoid sync


func _process(delta):
	_timer += delta
	if _timer >= interval:
		_timer -= interval
		_spawn_spark()


func _spawn_spark():
	var spark := ColorRect.new()
	spark.color = spark_color
	spark.size = Vector2(3, 3)
	spark.position = Vector2(randf_range(8, 56), randf_range(8, 56))
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spark)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "modulate:a", 0.0, 0.6).from(1.0)
	tween.tween_property(spark, "position:y", spark.position.y - 8.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(spark.queue_free)
