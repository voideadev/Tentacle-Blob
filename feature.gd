@tool
extends Node2D

signal triggered(kind: String, node: Node)

@export_enum("altar", "nest", "reactor", "boss", "armory", "desk", "crates", "rack", "tank", "lamp") var kind := "altar":
	set(v):
		kind = v
		queue_redraw()
@export var boss_type := 0
@export var lamp_color := Color(1.0, 0.85, 0.6)
@export var radius := 170.0
@export var nest_capacity := 180.0
@export var nest_heal_rate := 18.0
@export var reactor_dps := 9.0
@export var reactor_radius := 260.0

const Util = preload("res://util.gd")

var used := false
var cap := 0.0
var tm := randf() * 10.0
var light: PointLight2D
var player

func _ready() -> void:
	z_index = -6
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("features")
	cap = nest_capacity
	player = get_tree().get_first_node_in_group("player")
	var col := Color.WHITE
	var want := true
	match kind:
		"lamp":
			col = lamp_color
		"altar":
			col = Color(1.0, 0.85, 0.3)
		"nest":
			col = Color(0.4, 1.0, 0.5)
		"reactor":
			col = Color(1.0, 0.45, 0.2)
		"boss":
			col = Color(1.0, 0.25, 0.25)
		_:
			want = false
	if want:
		light = PointLight2D.new()
		light.texture = Util.light_tex(256)
		light.texture_scale = 6.0 if kind == "lamp" else 4.5
		light.color = col
		light.energy = 0.8
		light.position = Vector2(0, -60) if kind != "lamp" else Vector2.ZERO
		add_child(light)

func _process(delta: float) -> void:
	tm += delta
	if Engine.is_editor_hint():
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and global_position.distance_squared_to(player.global_position) < 2000.0 * 2000.0:
		queue_redraw()
		if light:
			light.visible = true
			if kind == "lamp":
				light.energy = 0.8 + 0.12 * sin(tm * 3.0) + (0.25 * randf() if sin(tm * 0.7) > 0.97 else 0.0)
	elif light:
		light.visible = false

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var d: float = global_position.distance_to(player.global_position)
	match kind:
		"altar":
			if not used and d < radius:
				used = true
				triggered.emit("altar", self)
		"nest":
			if cap > 0.0 and d < 360.0 and player.health < player.max_health:
				var amt := minf(cap, nest_heal_rate * delta)
				player.heal(amt)
				cap -= amt
		"reactor":
			if d < reactor_radius + 40.0 and global_position.distance_to(player.global_position + Vector2(0, 60)) < reactor_radius:
				player.take_damage(reactor_dps * delta, true)
		"boss":
			if not used and d < 1500.0:
				used = true
				triggered.emit("boss", self)

func _draw() -> void:
	var t := tm
	match kind:
		"desk":
			draw_rect(Rect2(-110, -58, 220, 12), Color(0.55, 0.6, 0.68))
			draw_rect(Rect2(-100, -46, 200, 46), Color(0.3, 0.33, 0.4))
			draw_rect(Rect2(-60, -98, 56, 40), Color(0.08, 0.1, 0.14))
			draw_rect(Rect2(-56, -94, 48, 30), Color(0.3, 0.8 + 0.1 * sin(t * 3.0), 1.0, 0.65))
		"tank":
			draw_rect(Rect2(-40, -300, 80, 300), Color(0.3, 0.8, 0.7, 0.18))
			draw_rect(Rect2(-36, -240, 72, 236), Color(0.2, 0.9, 0.5, 0.35))
			draw_rect(Rect2(-46, -310, 92, 14), Color(0.2, 0.22, 0.28))
			draw_rect(Rect2(-46, -6, 92, 10), Color(0.2, 0.22, 0.28))
			for i in 4:
				draw_circle(Vector2(-24.0 + i * 16.0, -12.0 - fmod(t * 40.0 + i * 57.0, 220.0)), 3.0, Color(0.7, 1.0, 0.8, 0.7))
		"crates":
			for k in 3:
				var r := Rect2(-130 + k * 110, -110, 100, 110)
				draw_rect(r, Color(0.5, 0.38, 0.24))
				draw_rect(r, Color(0.25, 0.18, 0.1), false, 4.0)
				draw_line(r.position, r.end, Color(0.3, 0.22, 0.12), 4.0)
			draw_rect(Rect2(-80, -210, 100, 100), Color(0.46, 0.34, 0.2))
			draw_rect(Rect2(-80, -210, 100, 100), Color(0.25, 0.18, 0.1), false, 4.0)
		"rack":
			for k in 3:
				var r := Rect2(-130 + k * 92, -340, 84, 340)
				draw_rect(r, Color(0.12, 0.13, 0.18))
				draw_rect(r, Color(0.3, 0.32, 0.4), false, 3.0)
				for i in 10:
					for j in 2:
						var on := sin(t * 3.0 + i * 7.0 + j * 3.0 + k) > 0.2
						draw_rect(Rect2(r.position.x + 12.0 + j * 32.0, r.position.y + 16.0 + i * 30.0, 9, 6),
							Color(0.3, 1.0, 0.5) if on else Color(1.0, 0.25, 0.2))
		"altar":
			draw_rect(Rect2(-50, -40, 100, 40), Color(0.3, 0.28, 0.2))
			draw_rect(Rect2(-34, -54, 68, 16), Color(0.4, 0.36, 0.25))
			if used:
				draw_circle(Vector2(0, -84), 18.0, Color(0.25, 0.22, 0.15))
			else:
				var fy := sin(t * 2.0) * 8.0
				draw_circle(Vector2(0, -94 + fy), 46.0, Color(1.0, 0.85, 0.3, 0.18))
				draw_circle(Vector2(0, -94 + fy), 22.0, Color(1.0, 0.9, 0.4, 0.95))
		"nest":
			var f := maxf(0.15, cap / maxf(nest_capacity, 1.0))
			var top := -44.0 * f
			draw_rect(Rect2(-330, top, 660, -top), Color(0.45, 0.05, 0.1, 0.92))
			var pts := PackedVector2Array()
			for i in 25:
				pts.append(Vector2(-330.0 + 660.0 * i / 24.0, top + sin(t * 2.5 + i * 0.7) * 3.0))
			draw_polyline(pts, Color(0.9, 0.25, 0.3, 0.9), 3.0)
			for i in 5:
				draw_circle(Vector2(-270.0 + i * 120.0, top + 10.0 + fmod(t * 14.0 + i * 9.0, 20.0)), 3.0, Color(1.0, 0.5, 0.5, 0.6))
		"reactor":
			draw_rect(Rect2(-85, -110, 170, 110), Color(0.35, 0.37, 0.42))
			draw_rect(Rect2(-85, -110, 170, 10), Color(1.0, 0.5, 0.2, 0.7))
			var c := Vector2(0, -250)
			var pu := 0.5 + 0.5 * sin(t * 3.0)
			draw_circle(c, 120.0, Color(1.0, 0.4, 0.1, 0.10))
			draw_circle(c, 70.0 + 8.0 * pu, Color(1.0, 0.5, 0.15, 0.30))
			draw_circle(c, 40.0, Color(1.0, 0.85, 0.4, 0.95))
			draw_arc(c, reactor_radius, 0.0, TAU, 64, Color(1.0, 0.4, 0.1, 0.12 + 0.08 * pu), 4.0)
		"armory":
			for k in 3:
				draw_rect(Rect2(-170 + k * 120, -110, 110, 110), Color(0.36, 0.4, 0.3))
				draw_rect(Rect2(-170 + k * 120, -110, 110, 110), Color(0.15, 0.18, 0.12), false, 4.0)
		"boss":
			draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.14))
			draw_arc(Vector2.ZERO, 340.0, 0.0, TAU, 56, Color(1.0, 0.25, 0.25, 0.5 + 0.2 * sin(t * 3.0)), 12.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"lamp":
			draw_line(Vector2(0, -60), Vector2(0, 0), Color(0.3, 0.32, 0.38), 4.0)
			draw_circle(Vector2.ZERO, 14.0, Color(lamp_color.r, lamp_color.g, lamp_color.b, 0.95))
			draw_circle(Vector2.ZERO, 34.0, Color(lamp_color.r, lamp_color.g, lamp_color.b, 0.15))
