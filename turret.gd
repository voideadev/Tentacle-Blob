extends Node2D

const BulletScript = preload("res://bullet.gd")

var hp_mult := 1.0
var dmg_mult := 1.0
var hp := 4.0
var xp_value := 2
var is_human := false
var is_boss := false
var dead := false
var hit_cd := 0.0
var flash := 0.0
var cd := randf_range(0.6, 1.6)
var aim := Vector2.DOWN
var player: Node2D

func _ready() -> void:
	add_to_group("enemies")
	z_index = 1
	light_mask = 2
	modulate = Color(1.3, 1.3, 1.3)
	hp = 4.0 * hp_mult
	player = get_tree().get_first_node_in_group("player")

func center() -> Vector2:
	return global_position + Vector2(0, 14)

func hit(n: float) -> void:
	if hit_cd > 0.0:
		return
	hit_cd = 0.15
	damage(n)

func damage(n: float) -> void:
	hp -= n
	flash = 0.15
	if hp <= 0.0 and not dead:
		dead = true
		if is_instance_valid(player):
			player.register_kill(self)
		else:
			queue_free()

func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and global_position.distance_squared_to(player.global_position) > 1900.0 * 1900.0:
		return
	hit_cd -= delta
	flash = move_toward(flash, 0.0, delta)
	cd -= delta
	if not is_instance_valid(player):
		return
	var to := player.global_position - center()
	var dist := to.length()
	if dist < 720.0 and dist > 1.0:
		aim = aim.lerp(to.normalized(), 1.0 - exp(-6.0 * delta))
		if aim.length() > 0.01:
			aim = aim.normalized()
		if cd <= 0.0 and _los():
			cd = randf_range(0.75, 1.2)
			var b := BulletScript.new()
			b.position = center() + aim * 22.0
			b.vel = aim * 680.0
			b.dmg = 10.0 * dmg_mult
			b.target = player
			get_parent().add_child(b)
	queue_redraw()

func _los() -> bool:
	var q := PhysicsRayQueryParameters2D.create(center(), player.global_position, 1)
	var hit_r := get_world_2d().direct_space_state.intersect_ray(q)
	return hit_r.is_empty() or hit_r.collider == player

func _draw() -> void:
	var col := Color(0.35, 0.37, 0.45).lerp(Color.WHITE, flash * 4.0)
	draw_rect(Rect2(-18, -2, 36, 10), col)
	draw_circle(Vector2(0, 14), 13.0, col)
	draw_line(Vector2(0, 14), Vector2(0, 14) + aim * 26.0, Color(0.15, 0.15, 0.2), 6.0)
	draw_circle(Vector2(0, 14), 4.0, Color(1.0, 0.2, 0.2))
