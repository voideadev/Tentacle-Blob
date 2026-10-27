extends CharacterBody2D
## kind 0 cientifico | 1 soldado | 2 lanzallamas | 3 pesado (rafagas, mucha vida)
## Usa humanoid.gd (IK). Sin luces 2D (rendimiento): light_mask = 2.

const BulletScript = preload("res://bullet.gd")
const Humanoid = preload("res://humanoid.gd")
const GRAV := 2200.0
const S := 1.15

var kind := 0
var hp_mult := 1.0
var dmg_mult := 1.0
var hp := 1.0
var xp_value := 1
var is_human := true
var is_boss := false
var dead := false
var captured := false
var hit_cd := 0.0
var flash := 0.0
var flaming := false
var engaged := false
var player: Node2D
var hm
var dir := 1.0
var time := randf() * 10.0
var fear := 0.0
var shoot_cd := 1.0
var burst := 0
var burst_t := 0.0
var los_t := randf() * 0.2
var los := false
var aim := Vector2.RIGHT

func _ready() -> void:
	add_to_group("humans")
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	light_mask = 2
	modulate = Color(1.3, 1.3, 1.3)
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0 * S
	cap.height = 88.0 * S
	cs.shape = cap
	cs.position = Vector2(0, -44.0 * S)
	add_child(cs)
	match kind:
		0:
			hp = 1.0
			xp_value = 1
		1:
			hp = 2.0 * hp_mult
			xp_value = 2
		2:
			hp = 3.0 * hp_mult
			xp_value = 3
		_:
			hp = 6.0 * hp_mult
			xp_value = 4
	dir = 1.0 if randf() > 0.5 else -1.0
	shoot_cd = randf_range(0.5, 1.6)
	player = get_tree().get_first_node_in_group("player")
	hm = Humanoid.new()
	hm.setup(S, 6 if kind == 3 else kind, global_position)

func center() -> Vector2:
	return global_position + Vector2(0, -50.0 * S)

func hit(n: float) -> void:
	if hit_cd > 0.0:
		return
	hit_cd = 0.15
	damage(n)

func damage(n: float) -> void:
	if dead:
		return
	hp -= n
	flash = 0.15
	if hp <= 0.0:
		dead = true
		if is_instance_valid(player):
			player.register_kill(self)
		else:
			queue_free()

func _process(_d: float) -> void:
	queue_redraw()

func _update_los(delta: float) -> void:
	los_t -= delta
	if los_t > 0.0:
		return
	los_t = 0.15
	if not is_instance_valid(player):
		los = false
		return
	var q := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -80), player.global_position, 1, [get_rid()])
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	los = r.is_empty() or r.collider == player

func _physics_process(delta: float) -> void:
	time += delta
	hit_cd -= delta
	flash = move_toward(flash, 0.0, delta)
	var dist := INF
	var to_p := Vector2.ZERO
	if is_instance_valid(player):
		to_p = player.global_position - global_position
		dist = to_p.length()

	if captured:
		fear = 1.0
		hm.tilt = sin(time * 3.0) * 0.7 + sin(time * 5.3) * 0.4
		hm.flash = flash
		hm.update(self, Vector2.ZERO, delta, Humanoid.DANGLE, Vector2.RIGHT, 1.0, false)
		return

	shoot_cd -= delta
	var vx := dir * 70.0
	flaming = false
	engaged = false
	var mode := Humanoid.WALK
	var chase := false
	if kind != 0:
		_update_los(delta)

	if kind == 0:
		if dist < 700.0:
			fear = move_toward(fear, 1.0, delta * 4.0)
			dir = -signf(to_p.x) if absf(to_p.x) > 1.0 else dir
			vx = dir * 240.0
		else:
			fear = move_toward(fear, 0.0, delta * 1.5)
		if fear > 0.5:
			mode = Humanoid.PANIC
	elif kind == 1 or kind == 3:
		if dist < 1100.0 and los:
			engaged = true
			fear = 0.4
			dir = signf(to_p.x) if absf(to_p.x) > 1.0 else dir
			if dist < 340.0:
				vx = -dir * 150.0
			elif dist > 620.0:
				vx = dir * (90.0 if kind == 1 else 60.0)
			else:
				vx = 0.0
			mode = Humanoid.AIM
		else:
			fear = move_toward(fear, 0.0, delta * 2.0)
	else:
		if dist < 800.0 and los:
			engaged = true
			chase = true
			dir = signf(to_p.x) if absf(to_p.x) > 1.0 else dir
			vx = dir * 165.0 if dist > 170.0 else 0.0
			mode = Humanoid.FLAME
		fear = 0.0

	if engaged and is_instance_valid(player):
		var lead: Vector2 = player.global_position + player.velocity * 0.22
		aim = (lead - hm.shoulder).normalized()

	velocity.y += GRAV * delta
	velocity.x = move_toward(velocity.x, vx, 1200.0 * delta)
	move_and_slide()
	if is_on_wall():
		if (fear > 0.5 or chase) and is_on_floor():
			velocity.y = -640.0
		else:
			dir = -dir

	hm.flash = flash
	hm.update(self, velocity, delta, mode, aim, fear, is_on_floor())

	if engaged and shoot_cd <= 0.0 and burst == 0 and (kind == 1 or kind == 3):
		if kind == 1:
			burst = 1
			shoot_cd = randf_range(0.55, 0.95)
		else:
			burst = 3
			shoot_cd = randf_range(1.3, 1.9)
		burst_t = 0.0
	if burst > 0:
		burst_t -= delta
		if burst_t <= 0.0:
			_fire()
			burst -= 1
			burst_t = 0.11
	if kind == 2 and engaged:
		var dpc: Vector2 = player.global_position - hm.muzzle
		if dpc.length() < 320.0 and dpc.normalized().dot(hm.gun_dir) > 0.8:
			flaming = true
			player.take_damage(26.0 * dmg_mult * delta, true)
	hm.flaming = flaming

func _fire() -> void:
	hm.recoil = 1.0
	var b := BulletScript.new()
	b.position = hm.muzzle
	b.vel = aim.rotated(randf_range(-0.05, 0.05)) * 820.0
	b.dmg = (9.0 if kind == 1 else 8.0) * dmg_mult
	b.big = 1.0 if kind == 1 else 1.4
	b.target = player
	get_parent().add_child(b)

func _draw() -> void:
	hm.draw(self)
	if (kind == 1 or kind == 3) and engaged and shoot_cd < 0.3 and burst == 0:
		var m: Vector2 = hm.muzzle - global_position
		draw_line(m, m + hm.gun_dir * 520.0, Color(1.0, 0.15, 0.15, 0.5), 2.0)
