extends Node2D
var max_r := 150.0
var t := 0.0

func _ready() -> void:
	z_index = 4

func _process(delta: float) -> void:
	t += delta * 3.0
	if t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, max_r * t, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 1.0 - t), 8.0)
