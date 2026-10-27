extends Node2D
var draw_cb: Callable
var animated := false

func _process(_d: float) -> void:
	if animated:
		queue_redraw()

func _draw() -> void:
	if draw_cb.is_valid():
		draw_cb.call(self)
