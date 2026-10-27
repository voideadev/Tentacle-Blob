extends CharacterBody2D

signal defeated

const BulletScript = preload("res://bullet.gd")
const Humanoid = preload("res://humanoid.gd")
const GRAV := 2200.0
const S := 2.2
const NAMES := ["EL CENTINELA", "EL COMANDANTE", "EL INCINERADOR"]

var btype := 0
var hp_mult := 1.0
var dmg_mult := 1.0
var max_hp := 300.0
var hp := 300.0
var xp_value := 15
var is_human := false
var is_boss := true
var dead := false
var active := false
var invuln := false
var hit_cd := 0.0
var flash := 0.0
var player
var hm
var aim := Vector2.RIGHT
var flaming := false
var atk_t := 2.0
var burst := 0
var burst_t := 0.0
var special_t := 5.0
var stomp_t := 0.0
var summon_t := 1.5
var charge_t := 0.0
var minions: Array = []
var crowd

func boss_name() -> String:
	return NAMES[btype]

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	light_mask = 2
	modulate = Color(1.3, 1.3, 1.3)
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 34.0
	cap.height = 200.0
	cs.shape = cap
	cs.position = Vector2(0, -100)
	add_child(cs)
	max_hp = (260.0 + 40.0 * btype) * hp_mult
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	crowd = get_tree().get_first_node_in_group("crowd")
	hm = Humanoid.new()
	hm.setup(S, 3 + btype, global_position)

func center() -> Vector2:
	return global_position + Vector2(0, -105)

func hit(n: float) -> void:
	if hit_cd > 0.0:
		return
	hit_cd = 0.15
	damage(n)

func damage(n: float) -> void:
	if dead:
		return
	flash = 0.12
	if invuln or not active:
		return
	hp -= n
	if hp <= 0.0:
		dead = true
		defeated.emit()
		if is_instance_valid(player):
			player.register_kill(self)
		else:
			queue_free()

func _process(_d: float) -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	hit_cd -= delta
	flash = move_toward(flash, 0.0, delta)
	if dead:
		return
	var pc := Vector2.ZERO
	var dist := INF
	var to := Vector2.ZERO
	if is_instance_valid(player):
		pc = player.global_position
		to = pc - center()
		dist = to.length()
	if not active and dist < 1200.0:
		active = true
	var dir := signf(to.x) if absf(to.x) > 1.0 else 1.0
	var vx := 0.0
	var mode := Humanoid.WALK
	flaming = false
	invuln = false

	if active:
		aim = (pc - hm.shoulder).normalized()
		match btype:
			0:
				mode = Humanoid.AIM
				if dist > 750.0:
					vx = dir * 95.0
				elif dist < 450.0:
					vx = -dir * 75.0
				atk_t -= delta
				var rage := 1.0 - hp / max_hp
				if atk_t <= 0.0 and burst == 0 and stomp_t <= 0.0:
					burst = 5
					atk_t = 2.8 - 1.0 * rage
				if burst > 0:
					burst_t -= delta
					if burst_t <= 0.0:
						_fire(aim.rotated(randf_range(-0.1, 0.1)), 10.0, 800.0)
						burst -= 1
						burst_t = 0.13
				special_t -= delta
				if special_t <= 0.0 and dist < 560.0 and stomp_t <= 0.0:
					stomp_t = 0.9
					special_t = 7.0
				if stomp_t > 0.0:
					stomp_t -= delta
					vx = 0.0
					if stomp_t <= 0.0:
						_stomp()
			1:
				mode = Humanoid.AIM
				minions = minions.filter(func(u) -> bool: return crowd.is_alive_uid(u))
				invuln = minions.size() > 0
				if dist > 850.0:
					vx = dir * 95.0
				elif dist < 520.0:
					vx = -dir * 105.0
				atk_t -= delta
				if atk_t <= 0.0 and dist < 1300.0:
					_fire(aim, 12.0, 740.0)
					atk_t = 1.1
				summon_t -= delta
				if summon_t <= 0.0 and minions.size() < 6:
					_summon(3)
					summon_t = 13.0
			_:
				charge_t -= delta
				special_t -= delta
				if special_t <= 0.0:
					charge_t = 1.2
					special_t = 7.0
				var sp := 200.0 if charge_t <= 0.0 else 480.0
				vx = dir * sp if dist > 170.0 else 0.0
				if dist < 440.0:
					mode = Humanoid.FLAME
					if dist < 380.0:
						flaming = true
						var dpc: Vector2 = pc - hm.muzzle
						if dpc.length() < 440.0 and dpc.normalized().dot(hm.gun_dir) > 0.75:
							player.take_damage(36.0 * dmg_mult * delta, true)

	velocity.y += GRAV * delta
	velocity.x = move_toward(velocity.x, vx, 1500.0 * delta)
	move_and_slide()
	if is_on_wall() and is_on_floor():
		velocity.y = -720.0
	hm.flash = flash
	hm.flaming = flaming
	hm.update(self, velocity, delta, mode, aim, 0.0, is_on_floor())

func _fire(dir_v: Vector2, dmg: float, spd: float) -> void:
	hm.recoil = 1.0
	var b := BulletScript.new()
	b.position = hm.muzzle
	b.vel = dir_v * spd
	b.dmg = dmg * dmg_mult
	b.big = 1.8
	b.target = player
	get_parent().add_child(b)

func _stomp() -> void:
	player.shockwave.emit(global_position, 420.0)
	player.shake = maxf(player.shake, 0.9)
	var pp: Vector2 = player.global_position
	if pp.distance_to(global_position) < 420.0 and pp.y > global_position.y - 330.0:
		player.take_damage(30.0 * dmg_mult)

func _summon(n: int) -> void:
	for i in n:
		var u: int = crowd.spawn_at(1, global_position + Vector2(randf_range(-80.0, 80.0), -20.0))
		if u >= 0:
			minions.append(u)

func _draw() -> void:
	hm.draw(self)
	if invuln:
		var c := Vector2(0, -105)
		draw_circle(c, 140.0, Color(0.4, 0.7, 1.0, 0.12))
		draw_arc(c, 140.0, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, 0.7), 4.0)
	if stomp_t > 0.0:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.2))
		var f := 1.0 - stomp_t / 0.9
		draw_circle(Vector2.ZERO, 420.0 * f, Color(1.0, 0.2, 0.2, 0.25))
		draw_arc(Vector2.ZERO, 420.0, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.8), 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hm.mode == Humanoid.AIM and hm.recoil <= 0.0 and btype == 0:
		pass
