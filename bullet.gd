extends Node2D
var vel := Vector2.ZERO
var target
var dmg := 8.0
var big := 1.0
var life := 2.5

func _ready() -> void:
	z_index = 5
	light_mask = 2

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + vel * delta
	if is_instance_valid(target) and target.get("shield_tentacles") == true:
		for p in target.tent_parts:
			if to.distance_to(Vector2(p.x, p.y)) < p.z + 5.0:
				target.heal(1.5)
				queue_free()
				return
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		if hit.collider == target and target.has_method("take_damage"):
			target.take_damage(dmg)
		queue_free()
		return
	global_position = to
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2.ZERO, -vel.normalized() * 24.0 * big, Color(1.0, 0.85, 0.35), 4.0 * big)
	draw_circle(Vector2.ZERO, 3.5 * big, Color(1, 1, 0.8))
