extends CharacterBody2D

signal killed(is_human: bool)
signal health_changed(value: float, max_value: float)
signal xp_changed(value: float, need: float)
signal level_up
signal blood(pos: Vector2)
signal shockwave(pos: Vector2, radius: float)
signal died

@export_group("Movimiento")
@export var reach := 400.0
@export var free_speed := 210.0
@export var grip_speed := 720.0
@export var accel := 9.0
@export var stick_force := 130.0
@export var anchor_kick := 180.0
@export var launch_speed := 3300.0
@export var grab_speed := 1500.0
@export var eat_speed := 240.0
@export var swallow_time := 0.4
@export_group("Lunge")
@export var dash_speed := 1450.0
@export var dash_time := 0.2
@export var dash_cooldown := 2.2
@export_group("Salto")
@export var leap_speed := 1250.0
@export var leap_cooldown := 0.9
@export var jump_gravity := 1500.0
@export var air_control := 1.0
@export var air_accel := 4.0
@export var elastic_reach := 2.0
@export_group("Crecimiento")
@export var start_size := 0.35
@export var max_size := 4.0
@export var growth_half := 18.0
@export var growth_power := 0.5
@export var growth_smooth := 1.2
@export var base_tentacles := 3
@export var tentacles_per_size := 3.2
@export var max_tentacles := 14
@export_group("Combate")
@export var max_health := 100.0
@export var grab_base := 0.8
@export var grab_per_size := 2.4

const Util = preload("res://util.gd")
const SEGS := 18
const BASE_R := 40.0
const FAN_RAYS := 44
const KB := [1.0, 2.0, 3.0, 5.0]
enum { IDLE, FLYING, HOLD, PREY }

class Tentacle:
	var pts := PackedVector2Array()
	var prev := PackedVector2Array()
	var tip := Vector2.ZERO
	var anchor := Vector2.ZERO
	var state := 0
	var spread := 0.0
	var phase := 0.0
	var recast := 0.0
	var held := 0.0
	var prey: Node2D = null
	var prey_idx := -1
	var swallow := 0.0

var tents: Array[Tentacle] = []
var tentacle_count := 0
var time := 0.0
var eaten := 0
var biomass := 0.0
var heading := Vector2.RIGHT
var input_active := false
var health := 100.0
var size_scale := 0.35
var size_bonus := 0.0
var extra_tentacles := 0
var energy := 0.0
var shake := 0.0
var dash_t := 0.0
var cur_reach := 300.0
var grab_cap := 1.6
var dead := false

var xp := 0.0
var xp_need := 25.0
var mut_level := 0
var mut_stacks := {}

var reach_mult := 1.0
var speed_mult := 1.0
var claw_dmg := 0.4
var xp_mult := 1.0
var acid_dps := 0.0
var regen := 0.0
var armor_mult := 1.0
var dash_max := 1
var dash_cd_mult := 1.0
var shock_radius := 0.0
var vamp := 0.0
var magnet_stacks := 0
var rush_level := 0
var rush_t := 0.0
var sense := false
var shield_tentacles := false
var revives := 0

var dash_charges := 1
var dash_recharge := 0.0
var dash_gap := 0.0
var leap_t := 0.0
var leap_cd := 0.0
var leap_free := 0.0
var reach_boost := 1.0
var airborne := false
var air_t := 0.0
var nogrip_t := 0.0

var body_parts: Array[Vector3] = []
var tent_parts: Array[Vector3] = []
var lump_pos := PackedVector2Array()
var lump_off := PackedVector2Array()
var lump_r := PackedFloat32Array()
var lump_k := PackedFloat32Array()

var cam: Camera2D
var shape: CircleShape2D
var light: PointLight2D
var crowd

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	health = max_health
	size_scale = start_size
	cur_reach = reach * pow(size_scale, 0.6)
	cam = $Camera2D
	cam.top_level = true
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	var cs: CollisionShape2D = $CollisionShape2D
	cs.shape = cs.shape.duplicate()
	shape = cs.shape
	shape.radius = BASE_R * size_scale * 0.95

	light = PointLight2D.new()
	light.texture = Util.light_tex(256)
	light.texture_scale = 4.6
	light.color = Color(1.0, 0.35, 0.35)
	light.energy = 1.1
	add_child(light)

	lump_off.append(Vector2.ZERO)
	lump_r.append(0.85)
	lump_k.append(40.0)
	for i in 8:
		lump_off.append(Vector2.from_angle(TAU * i / 8.0 + 0.3) * 0.55)
		lump_r.append(0.50)
		lump_k.append(randf_range(9.0, 20.0))
	for i in lump_off.size():
		lump_pos.append(global_position)

	_add_tentacles(base_tentacles + int(size_scale * tentacles_per_size))
	health_changed.emit(health, max_health)
	xp_changed.emit(xp, xp_need)

func body_radius() -> float:
	return BASE_R * size_scale * 0.95

func _update_growth(delta: float) -> void:
	var target := minf(start_size * pow(1.0 + biomass / growth_half, growth_power) + size_bonus, max_size)
	size_scale = lerpf(size_scale, target, 1.0 - exp(-growth_smooth * delta))
	shape.radius = body_radius()
	grab_cap = grab_base + size_scale * grab_per_size
	var want := mini(base_tentacles + int(size_scale * tentacles_per_size) + extra_tentacles, max_tentacles)
	if want > tents.size():
		_add_tentacles(want - tents.size())

func _physics_process(delta: float) -> void:
	time += delta
	energy = move_toward(energy, 0.0, delta * 2.0)
	dash_gap -= delta
	rush_t -= delta
	if crowd == null:
		crowd = get_tree().get_first_node_in_group("crowd")
	_update_growth(delta)
	leap_t -= delta
	leap_cd -= delta
	var want_boost := 1.0
	if input_active and nogrip_t > 0.25 and not airborne:
		want_boost = elastic_reach
	reach_boost = lerpf(reach_boost, want_boost, 1.0 - exp(-6.0 * delta))
	cur_reach = reach * reach_mult * pow(size_scale, 0.5) * reach_boost

	if regen > 0.0 and health < max_health and not dead:
		health = minf(max_health, health + regen * delta)
		health_changed.emit(health, max_health)
	if dash_charges < dash_max:
		dash_recharge -= delta
		if dash_recharge <= 0.0:
			dash_charges += 1
			dash_recharge = dash_cooldown * dash_cd_mult

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	input_active = dir != Vector2.ZERO
	if dir != Vector2.ZERO:
		var h := heading.lerp(dir.normalized(), 1.0 - exp(-12.0 * delta))
		heading = h.normalized() if h.length() > 0.01 else dir.normalized()
	if Input.is_action_just_pressed("dash"):
		_dash(dir)
	if Input.is_action_just_pressed("jump"):
		_leap(dir)

	var hits := _cast_fan()
	var nodes_enemies := get_tree().get_nodes_in_group("enemies")
	var crowd_ok: bool = crowd != null and crowd.n > 0
	if crowd_ok:
		_update_prey()
	_update_boss_prey()

	var grip := 0
	var pull_dir := Vector2.ZERO
	var behind_th := maxf(60.0, BASE_R * size_scale * 1.4)
	for t in tents:
		t.recast -= delta
		match t.state:
			IDLE:
				if dir != Vector2.ZERO and t.recast <= 0.0 and not airborne:
					_try_anchor(t, hits)
			FLYING, HOLD:
				var d := t.anchor - global_position
				var behind := heading.dot(d) < -behind_th and dir != Vector2.ZERO
				t.held += delta
				if d.length() > cur_reach * 1.02 or (behind and t.held > 0.12):
					_release(t)
				elif t.state == HOLD:
					grip += 1
					pull_dir += d.normalized()

	if grip == 0 and input_active and not airborne:
		nogrip_t += delta
	else:
		nogrip_t = 0.0

	var tw := pow(size_scale, 0.6)
	if claw_dmg > 0.0:
		for t in tents:
			if t.state == PREY:
				continue
			if crowd_ok:
				crowd.hit_radius(t.tip, 48.0 * tw, claw_dmg)
			for e in nodes_enemies:
				if is_instance_valid(e) and not e.dead and e.center().distance_to(t.tip) < 48.0 * tw + 20.0:
					e.hit(claw_dmg)
	if acid_dps > 0.0:
		var ar := 150.0 * size_scale
		if crowd_ok:
			crowd.damage_radius(global_position, ar, acid_dps * delta)
		for e in nodes_enemies:
			if is_instance_valid(e) and not e.dead and e.center().distance_to(global_position) < ar:
				e.damage(acid_dps * delta)

	var grip_ratio := clampf(float(grip) / (tentacle_count * 0.5), 0.0, 1.0)
	var rush_mul := (1.0 + 0.2 + 0.15 * rush_level) if rush_t > 0.0 else 1.0
	var size_speed := lerpf(0.85, 1.25, clampf((size_scale - 0.35) / 3.0, 0.0, 1.0))
	var spd := lerpf(free_speed, grip_speed, grip_ratio) * speed_mult * rush_mul * size_speed
	var desired := dir * spd
	if grip > 0:
		desired += (pull_dir / grip) * stick_force
	if dash_t > 0.0:
		dash_t -= delta
		_lunge_eat(nodes_enemies, crowd_ok)
		if dash_t <= 0.0 and shock_radius > 0.0:
			_shockwave(shock_radius)
	elif airborne:
		air_t += delta
		velocity.y += jump_gravity * delta
		velocity.x = lerpf(velocity.x, dir.x * spd * air_control, 1.0 - exp(-air_accel * delta))
	else:
		velocity = velocity.lerp(desired, 1.0 - exp(-accel * delta))
	move_and_slide()
	if airborne and ((air_t > 0.15 and get_slide_collision_count() > 0) or air_t > 3.5):
		_land()

	for i in tents.size():
		_update_tentacle(tents[i], i, delta)
	_update_parts(delta)
	_update_camera(delta)

func _dash(dir: Vector2) -> void:
	if dash_charges <= 0 or dash_gap > 0.0 or dead:
		return
	if dash_charges == dash_max:
		dash_recharge = dash_cooldown * dash_cd_mult
	dash_charges -= 1
	dash_gap = 0.25
	var d := dir.normalized() if dir != Vector2.ZERO else heading
	velocity = d * dash_speed
	dash_t = dash_time
	energy = 1.0
	shake = maxf(shake, 0.3)
	for t in tents:
		if t.state != PREY:
			_release(t)

func _leap(dir: Vector2) -> void:
	if leap_cd > 0.0 or dead or airborne:
		return
	var d := dir.normalized() if dir != Vector2.ZERO else heading
	d = (d + Vector2(0.0, -0.35)).normalized()
	var size_speed := lerpf(0.85, 1.25, clampf((size_scale - 0.35) / 3.0, 0.0, 1.0))
	velocity = d * leap_speed * size_speed
	airborne = true
	air_t = 0.0
	leap_cd = leap_cooldown
	energy = maxf(energy, 0.7)
	shake = maxf(shake, 0.12)
	for t in tents:
		if t.state != PREY:
			_release(t)
			t.recast = 0.0

func _land() -> void:
	airborne = false
	velocity *= 0.35
	shake = maxf(shake, 0.15)
	energy = maxf(energy, 0.5)
	for t in tents:
		t.recast = 0.0

func _lunge_eat(nodes_enemies: Array, crowd_ok: bool) -> void:
	var r := BASE_R * size_scale * 2.2
	if crowd_ok:
		crowd.hit_radius(global_position, r, 3.0)
	for e in nodes_enemies:
		if is_instance_valid(e) and not e.dead and e.center().distance_to(global_position) < r + 30.0:
			e.hit(3.0)

func _shockwave(r: float) -> void:
	shockwave.emit(global_position, r)
	shake = maxf(shake, 0.8)
	energy = 1.0
	if crowd != null and crowd.n > 0:
		crowd.damage_radius(global_position, r, 4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.center().distance_to(global_position) < r:
			e.damage(4.0)

func on_crowd_kill(k: int, c: Vector2) -> void:
	blood.emit(c)
	eaten += 1
	biomass += KB[k]
	heal(3.0 + vamp)
	if rush_level > 0:
		rush_t = 3.0
	shake = maxf(shake, 0.18)
	energy = maxf(energy, 0.6)
	killed.emit(true)
	add_xp(KB[k])

func register_kill(e: Node2D) -> void:
	for t in tents:
		if t.prey == e:
			t.prey = null
			if t.state == PREY:
				_release(t)
	var xv: float = float(e.get("xp_value"))
	blood.emit(e.center())
	e.queue_free()
	biomass += xv * 1.5
	heal(4.0 + vamp)
	shake = maxf(shake, 0.6)
	energy = 1.0
	killed.emit(false)
	add_xp(xv)

func add_xp(n_: float) -> void:
	xp += n_ * xp_mult
	while xp >= xp_need:
		xp -= xp_need
		mut_level += 1
		xp_need = 25.0 + 15.0 * mut_level
		level_up.emit()
	xp_changed.emit(xp, xp_need)

func heal(n_: float) -> void:
	health = minf(max_health, health + n_)
	health_changed.emit(health, max_health)

func take_damage(n_: float, dot := false) -> void:
	if dead:
		return
	health -= n_ * armor_mult
	if dot:
		energy = maxf(energy, 0.35)
	else:
		energy = 1.0
		shake = maxf(shake, 0.5)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		if revives > 0:
			revives -= 1
			health = max_health * 0.5
			_shockwave(280.0)
			health_changed.emit(health, max_health)
		else:
			dead = true
			died.emit()

func teleport(pos: Vector2) -> void:
	global_position = pos
	airborne = false
	velocity = Vector2.ZERO
	for t in tents:
		if t.prey_idx >= 0 and crowd != null:
			crowd.ungrab(t.prey_idx)
		t.state = IDLE
		t.prey = null
		t.prey_idx = -1
		t.swallow = 0.0
		t.tip = pos
		for k in t.pts.size():
			t.pts[k] = pos
			t.prev[k] = pos
	for i in lump_pos.size():
		lump_pos[i] = pos
	cam.reset_smoothing()

func _add_tentacles(n_: int) -> void:
	for j in n_:
		if tents.size() >= max_tentacles:
			break
		var t := Tentacle.new()
		t.tip = global_position
		t.phase = randf() * TAU
		t.pts.resize(SEGS + 1)
		t.prev.resize(SEGS + 1)
		for k in SEGS + 1:
			t.pts[k] = global_position
			t.prev[k] = global_position
		t.recast = j * 0.03
		tents.append(t)
	tentacle_count = tents.size()
	for i in tents.size():
		tents[i].spread = remap(float(i), 0.0, maxf(tents.size() - 1.0, 1.0), -1.1, 1.1)

func apply_mutation(id: String) -> void:
	mut_stacks[id] = mut_stacks.get(id, 0) + 1
	var n_: int = mut_stacks[id]
	match id:
		"tentacles":
			extra_tentacles += 2
		"reach":
			reach_mult += 0.20
		"muscle":
			speed_mult += 0.12
			anchor_kick += 25.0
		"claws":
			claw_dmg += 1.0
		"acid":
			acid_dps += 1.5
		"regen":
			regen += 2.0
		"armor":
			armor_mult *= 0.85
		"dash":
			dash_max += 1
			dash_charges += 1
			dash_cd_mult *= 0.8
		"shock":
			shock_radius = 60.0 + 90.0 * n_
		"vamp":
			vamp += 3.0
		"magnet":
			magnet_stacks += 1
			eat_speed *= 1.25
			grab_base += 0.4
		"rush":
			rush_level += 1
		"hyper":
			max_health += 25.0
			health = max_health
			size_bonus += 0.12
			health_changed.emit(health, max_health)
		"sense":
			sense = true
		"shield":
			shield_tentacles = true
		"egg":
			revives += 1

func _cast_fan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var space := get_world_2d().direct_space_state
	var off := time * 0.9
	for i in FAN_RAYS:
		var a := TAU * i / FAN_RAYS + off
		var q := PhysicsRayQueryParameters2D.create(
			global_position, global_position + Vector2.from_angle(a) * cur_reach)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		if h:
			out.append(h)
	return out

func _try_anchor(t: Tentacle, hits: Array[Dictionary]) -> bool:
	var ahead := global_position + heading.rotated(t.spread) * cur_reach * 0.85
	var gap := maxf(30.0, 65.0 * pow(size_scale, 0.6))
	var best := Vector2.ZERO
	var best_d := INF
	for h in hits:
		var p: Vector2 = h.position
		var busy := false
		for o in tents:
			if o != t and (o.state == FLYING or o.state == HOLD) and o.anchor.distance_to(p) < gap:
				busy = true
				break
		if busy:
			continue
		var d := p.distance_to(ahead)
		if d < best_d:
			best_d = d
			best = p
	if best_d < INF:
		t.anchor = best
		t.state = FLYING
		t.held = 0.0
		return true
	return false

func _release(t: Tentacle) -> void:
	t.state = IDLE
	t.recast = randf_range(0.0, 0.06)

func _update_prey() -> void:
	var targeted := {}
	for t in tents:
		if t.state == PREY and t.prey_idx >= 0 and t.prey == null:
			if crowd.alive[t.prey_idx] == 0:
				t.prey_idx = -1
				_release(t)
			else:
				targeted[t.prey_idx] = true
	var busy := 0
	for t in tents:
		if t.state == PREY:
			busy += 1
	var max_prey := maxi(1, int(tentacle_count * 0.4)) + magnet_stacks
	if busy >= max_prey:
		return
	var prey_r := cur_reach * (0.85 + 0.15 * magnet_stacks)
	var ids: PackedInt32Array = crowd.query_radius(global_position, prey_r)
	if ids.is_empty():
		return
	for t in tents:
		if busy >= max_prey:
			break
		if t.state != IDLE or t.recast > 0.0:
			continue
		var best := -1
		var best_d := INF
		for j in ids:
			if crowd.state[j] == 3 or crowd.alive[j] == 0 or targeted.has(j):
				continue
			if crowd.power_of(j) > grab_cap:
				continue
			var d2: float = crowd.center_of(j).distance_squared_to(global_position)
			if d2 < best_d:
				best_d = d2
				best = j
		if best < 0:
			break
		t.prey_idx = best
		t.swallow = 0.0
		t.state = PREY
		targeted[best] = true
		busy += 1

func _update_boss_prey() -> void:
	var bosses := get_tree().get_nodes_in_group("bosses")
	if bosses.is_empty():
		return
	var b = bosses[0]
	if not is_instance_valid(b) or b.dead or b.invuln or not b.active:
		return
	if b.center().distance_to(global_position) > cur_reach * 1.1:
		return
	var holding := 0
	for t in tents:
		if t.prey == b:
			holding += 1
	if holding >= 4 + magnet_stacks:
		return
	for t in tents:
		if t.prey == null and t.state == IDLE:
			t.prey = b
			t.state = PREY
			return

func _update_tentacle(t: Tentacle, i: int, delta: float) -> void:
	var root := global_position
	var R := BASE_R * size_scale
	match t.state:
		PREY:
			if t.prey_idx >= 0:
				var idx := t.prey_idx
				if t.swallow > 0.0:
					t.swallow -= delta
					crowd.drag_to(idx, root)
					t.tip = t.tip.lerp(root, 1.0 - exp(-12.0 * delta))
					if t.swallow <= 0.0:
						t.prey_idx = -1
						_release(t)
						t.recast = 0.5
						crowd.eat(idx)
				else:
					var c: Vector2 = crowd.center_of(idx)
					if root.distance_to(c) > cur_reach * 1.5:
						crowd.ungrab(idx)
						t.prey_idx = -1
						_release(t)
						t.recast = 0.4
					else:
						t.tip = t.tip.move_toward(c, grab_speed * delta)
						if t.tip.distance_to(c) < 34.0 * pow(size_scale, 0.5) + 10.0:
							if crowd.state[idx] != 3:
								crowd.grab(idx)
							var newc := c.move_toward(root, eat_speed * delta)
							crowd.drag_to(idx, newc)
							t.tip = newc
							if newc.distance_to(root) < R + 12.0:
								t.swallow = swallow_time
			elif t.prey != null:
				if not is_instance_valid(t.prey) or t.prey.dead:
					t.prey = null
					_release(t)
				else:
					var goal: Vector2 = t.prey.center()
					t.tip = t.tip.move_toward(goal, launch_speed * delta)
					if t.prey.invuln or root.distance_to(goal) > cur_reach * 1.4:
						t.prey = null
						_release(t)
					elif t.tip.distance_to(goal) < 50.0:
						t.prey.damage((9.0 + claw_dmg * 4.0) * delta)
			else:
				_release(t)
		FLYING, HOLD:
			t.tip = t.tip.move_toward(t.anchor, launch_speed * delta)
			if t.state == FLYING and t.tip.distance_to(t.anchor) < 1.0:
				t.state = HOLD
				velocity += (t.anchor - root).normalized() * anchor_kick
		_:
			var rad := R + 50.0 * pow(size_scale, 0.8) + sin(time * 2.0 + t.phase) * 22.0 * size_scale
			if airborne:
				rad = R * 0.5
			var g := root + Vector2.from_angle(i * TAU / maxf(tentacle_count, 1) + time * 0.9 + t.phase) * rad
			t.tip = t.tip.lerp(g, 1.0 - exp(-(24.0 if airborne else 14.0) * delta))
	_sim_rope(t, root, delta)

func _sim_rope(t: Tentacle, root: Vector2, delta: float) -> void:
	var n_ := t.pts.size()
	var dist := root.distance_to(t.tip)
	var seg_len := maxf(dist * 1.10, 55.0 * pow(size_scale, 0.7)) / float(n_ - 1)
	var side := (t.tip - root).orthogonal().normalized()
	var damp := pow(0.90, delta * 60.0)
	var wig_amp := 12000.0 * pow(size_scale, 0.6)
	for k in range(1, n_ - 1):
		var cur := t.pts[k]
		var vel := (cur - t.prev[k]) * damp
		t.prev[k] = cur
		var f := float(k) / float(n_ - 1)
		var wig := side * sin(time * 7.0 + f * 7.0 + t.phase) * wig_amp * sin(f * PI)
		t.pts[k] = cur + vel + wig * delta * delta
	t.pts[0] = root
	t.pts[n_ - 1] = t.tip
	for it in 8:
		for k in range(n_ - 1):
			var a := t.pts[k]
			var b := t.pts[k + 1]
			var d := b - a
			var l := d.length()
			if l < 0.0001:
				continue
			var corr := d * ((l - seg_len) / l)
			if k == 0:
				t.pts[k + 1] -= corr
			elif k + 1 == n_ - 1:
				t.pts[k] += corr
			else:
				t.pts[k] += corr * 0.5
				t.pts[k + 1] -= corr * 0.5
		t.pts[0] = root
		t.pts[n_ - 1] = t.tip

func _update_parts(delta: float) -> void:
	var R := BASE_R * size_scale
	body_parts.clear()
	tent_parts.clear()
	var sp := clampf(velocity.length() / grip_speed, 0.0, 1.2)
	var vdir := velocity.normalized()
	for i in lump_off.size():
		var off := lump_off[i]
		var tgt := global_position + off * R * (1.0 + 0.08 * sin(time * 3.0 + i * 1.7))
		tgt += vdir * R * 0.5 * sp * off.dot(vdir)
		lump_pos[i] = lump_pos[i].lerp(tgt, 1.0 - exp(-lump_k[i] * delta))
		var rad := lump_r[i] * R * (1.0 + 0.06 * sin(time * 4.0 + i))
		body_parts.append(Vector3(lump_pos[i].x, lump_pos[i].y, rad))
	var tw := pow(size_scale, 0.7)
	for t in tents:
		var n_ := t.pts.size()
		for k in range(n_ - 1):
			for sub in 2:
				var s := sub * 0.5
				var p := t.pts[k].lerp(t.pts[k + 1], s)
				var f := (k + s) / float(n_ - 1)
				tent_parts.append(Vector3(p.x, p.y, lerpf(15.0, 4.2, f) * tw))
		tent_parts.append(Vector3(t.pts[n_ - 1].x, t.pts[n_ - 1].y, 4.6 * tw))
		if t.state == HOLD:
			tent_parts.append(Vector3(t.anchor.x, t.anchor.y, 9.5 * tw))

func _update_camera(delta: float) -> void:
	shake = move_toward(shake, 0.0, delta * 1.8)
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 14.0
	light.texture_scale = 2.0 + 2.6 * pow(size_scale, 0.6)
	light.energy = 1.0 + 0.3 * sin(time * 2.6) + energy * 0.8
	if acid_dps > 0.0:
		light.color = Color(0.9, 0.5, 0.3)
