extends Node2D
## Conducto de salida: se abre al alcanzar la cuota de infestacion.
const Util = preload("res://util.gd")
var open := false
var t := 0.0
var light: PointLight2D

func _ready() -> void:
	z_index = -3
	light = PointLight2D.new()
	light.texture = Util.light_tex(256)
	light.texture_scale = 2.5
	light.color = Color(0.3, 1.0, 0.5)
	light.position = Vector2(0, -30)
	add_child(light)

func _process(delta: float) -> void:
	t += delta
	light.energy = (0.9 + 0.4 * sin(t * 4.0)) if open else 0.15
	queue_redraw()

func _draw() -> void:
	var col := Color(0.25, 1.0, 0.5) if open else Color(0.45, 0.45, 0.5)
	draw_rect(Rect2(-60, -10, 120, 14), Color(0.10, 0.10, 0.13))
	for i in 6:
		draw_line(Vector2(-50 + i * 20, -9), Vector2(-50 + i * 20, 2), col, 4.0)
	if open:
		for k in 3:
			var f := fmod(t * 1.2 + k * 0.33, 1.0)
			draw_arc(Vector2(0, -30), 20.0 + f * 50.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.5, 1.0 - f), 3.0)
