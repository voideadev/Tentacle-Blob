@tool
extends Marker2D

@export var area := Vector2(900, 500):
	set(v):
		area = v
		queue_redraw()
@export var scientists := 40
@export var soldiers := 0
@export var flamers := 0
@export var heavies := 0
@export var turrets := 0
@export var tier := 0

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("crowd_zones")

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-area / 2.0, area), Color(1.0, 0.5, 0.2, 0.9), false, 6.0)
		draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.5, 0.2))
