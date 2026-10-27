extends Node2D

signal killed(kind: int, pos: Vector2)
signal turret_requested(pos: Vector2)

const ViewScript = preload("res://human_view.gd")
const KIND_POWER := [1.0, 2.0, 3.0, 5.0]
const KIND_HP := [1.0, 2.0, 3.0, 6.0]
const GRAV := 2200.0
const CELL := 160.0
const CHUNK := 1024.0
const MM_CAP := 1400

@export var max_agents := 6000
@export var near_views := 28
@export var view_radius := 1100.0
@export var wake_margin := 700.0
@export var enemy_damage_mult := 1.0
@export var start_safe_radius := 1700.0
@export var half_rate_above := 320

var world
var player
var cam: Camera2D
var n := 0
var alive_count := 0
var next_uid := 1
var frame := 0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var aim := PackedVector2Array()
var kind := PackedByteArray()
var state := PackedByteArray()
var alive := PackedByteArray()
var grounded := PackedByteArray()
var flaming := PackedByteArray()
var has_los := PackedByteArray()
var hp := PackedFloat32Array()
var dirv := PackedFloat32Array()
var timer := PackedFloat32Array()
var shoot_cd := PackedFloat32Array()
var los_t := PackedFloat32Array()
var hit_cd := PackedFloat32Array()
var phase := PackedFloat32Array()
var recoil := PackedFloat32Array()
var uid := PackedInt32Array()
var view_of := PackedInt32Array()
var chunk_of := PackedInt32Array()
var uid_idx := {}
var chunks := {}
var active := PackedInt32Array()
var buckets: Array = []
var touched := PackedInt32Array()
var bw := 0
var bh := 0
var views: Array = []
var mms: Array = []
var mm_nodes: Array = []

var bpos := PackedVector2Array()
var bvel := PackedVector2Array()
var bdmg := PackedFloat32Array()
var blife := PackedFloat32Array()

var pp := Vector2.ZERO
var pvel := Vector2.ZERO
var pradius := 20.0

func _ready() -> void:
	add_to_group("crowd")
	z_index = 2
	light_mask = 2

func setup(world_node, player_node, cam_node: Camera2D) -> void:
	world = world_node
	player = player_node
	cam = cam_node
	pos.resize(max_agents)
	vel.resize(max_agents)
	aim.resize(max_agents)
	kind.resize(max_agents)
	state.resize(max_agents)
	alive.resize(max_agents)
	grounded.resize(max_agents)
	flaming.resize(max_agents)
	has_los.resize(max_agents)
	hp.resize(max_agents)
	dirv.resize(max_agents)
	timer.resize(max_agents)
	shoot_cd.resize(max_agents)
	los_t.resize(max_agents)
	hit_cd.resize(max_agents)
	phase.resize(max_agents)
	recoil.resize(max_agents)
	uid.resize(max_agents)
	view_of.resize(max_agents)
	view_of.fill(-1)
	chunk_of.resize(max_agents)
	bw = int(world.gw * 64.0 / CELL) + 2
	bh = int(world.gh * 64.0 / CELL) + 2
	buckets.resize(bw * bh)
	for i in buckets.size():
		buckets[i] = []
	_build_multimeshes()
	for i in near_views:
		var v = ViewScript.new()
		v.crowd = self
		v.vindex = i
		add_child(v)
		views.append(v)
	for z in get_tree().get_nodes_in_group("crowd_zones"):
		_spawn_zone(z)

func _chunk_key(p: Vector2) -> int:
	return int(floorf(p.x / CHUNK)) + int(floorf(p.y / CHUNK)) * 1000

func spawn(k: int, p: Vector2) -> int:
	if n >= max_agents:
		return -1
	var i := n
	n += 1
	pos[i] = p
	vel[i] = Vector2.ZERO
	aim[i] = Vector2.RIGHT
	kind[i] = k
	state[i] = 0
	alive[i] = 1
	grounded[i] = 0
	flaming[i] = 0
	has_los[i] = 0
	hp[i] = KIND_HP[k] * (1.0 + 0.0)
	dirv[i] = 1.0 if randf() > 0.5 else -1.0
	timer[i] = randf_range(1.0, 5.0)
	shoot_cd[i] = randf_range(0.4, 1.6)
	los_t[i] = randf() * 0.25
	hit_cd[i] = 0.0
	phase[i] = randf() * TAU
	recoil[i] = 0.0
	uid[i] = next_uid
	uid_idx[next_uid] = i
	next_uid += 1
	view_of[i] = -1
	var key := _chunk_key(p)
	chunk_of[i] = key
	if not chunks.has(key):
		chunks[key] = []
	chunks[key].append(i)
	alive_count += 1
	return i

func spawn_at(k: int, p: Vector2) -> int:
	var i := spawn(k, p)
	return uid[i] if i >= 0 else -1

func _spawn_zone(z) -> void:
	var area: Vector2 = z.area
	var c: Vector2 = z.global_position
	var counts := [z.scientists, z.soldiers, z.flamers, z.heavies]
	for k in 4:
		for j in int(counts[k]):
			for t in 8:
				var x := c.x + randf_range(-area.x * 0.5, area.x * 0.5)
				var y0 := c.y + randf_range(-area.y * 0.5, area.y * 0.5)
				var fy: float = world.floor_y(x, y0)
				if fy >= 0.0 and fy < c.y + area.y * 0.6 and Vector2(x, fy).distance_to(world.start_pos) > start_safe_radius:
					spawn(k, Vector2(x, fy - 1.0))
					break
	for j in int(z.turrets):
		for t in 8:
			var x2 := c.x + randf_range(-area.x * 0.5, area.x * 0.5)
			var cy: float = world.ceil_y(x2, c.y)
			if cy > 0.0 and Vector2(x2, cy).distance_to(world.start_pos) > start_safe_radius:
				turret_requested.emit(Vector2(x2, cy + 2.0))
				break

func _tri(verts: Array, cols: Array, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	for i in 3:
		cols.append(col)

func _quad(verts: Array, cols: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_tri(verts, cols, a, b, c, col)
	_tri(verts, cols, a, c, d, col)

func _rect(verts: Array, cols: Array, x: float, y: float, w: float, h: float, col: Color) -> void:
	_quad(verts, cols, Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h), col)

func _human_mesh(k: int, stride: int) -> ArrayMesh:
	var top: Color
	var pants: Color
	var skin := Color(0.9, 0.75, 0.6)
	match k:
		0:
			top = Color(0.93, 0.94, 0.97)
			pants = Color(0.25, 0.28, 0.38)
		1:
			top = Color(0.32, 0.43, 0.30)
			pants = Color(0.24, 0.32, 0.22)
		2:
			top = Color(0.82, 0.38, 0.12)
			pants = Color(0.5, 0.22, 0.08)
		_:
			top = Color(0.28, 0.3, 0.34)
			pants = Color(0.2, 0.21, 0.25)
	var verts: Array = []
	var cols: Array = []
	var w := 8.0 if k != 3 else 11.0
	if stride == 0:
		_rect(verts, cols, -7.0, -46.0, 6.0, 46.0, pants)
		_rect(verts, cols, 1.0, -46.0, 6.0, 46.0, pants)
	else:
		_quad(verts, cols, Vector2(-6, -46), Vector2(0, -46), Vector2(-7, 0), Vector2(-14, 0), pants)
		_quad(verts, cols, Vector2(0, -46), Vector2(6, -46), Vector2(15, 0), Vector2(8, 0), pants)
	_rect(verts, cols, -w, -84.0, w * 2.0, 40.0, top)
	_rect(verts, cols, -w - 4.0, -82.0, 4.0, 28.0, top.darkened(0.15))
	_rect(verts, cols, w, -82.0, 4.0, 28.0, top.darkened(0.15))
	if k == 2:
		_rect(verts, cols, -w - 8.0, -80.0, 6.0, 26.0, Color(0.5, 0.52, 0.56))
	if k == 1 or k == 3:
		_rect(verts, cols, w, -66.0, 18.0, 4.0, Color(0.1, 0.1, 0.12))
	var hc := Vector2(0, -93.0)
	for s in 6:
		var a0 := TAU * s / 6.0
		var a1 := TAU * (s + 1) / 6.0
		_tri(verts, cols, hc, hc + Vector2(cos(a0), sin(a0)) * 9.0, hc + Vector2(cos(a1), sin(a1)) * 9.0, skin)
	if k == 1 or k == 3:
		_rect(verts, cols, -10.0, -104.0, 20.0, 7.0, Color(0.2, 0.3, 0.2) if k == 1 else Color(0.18, 0.19, 0.22))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(verts)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(cols)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func _build_multimeshes() -> void:
	for k in 4:
		for s in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			mm.mesh = _human_mesh(k, s)
			mm.instance_count = MM_CAP
			mm.visible_instance_count = 0
			var inst := MultiMeshInstance2D.new()
			inst.multimesh = mm
			inst.z_index = -1
			inst.light_mask = 2
			inst.modulate = Color(1.3, 1.3, 1.3)
			add_child(inst)
			mms.append(mm)
			mm_nodes.append(inst)

func center_of(i: int) -> Vector2:
	return pos[i] + Vector2(0, -50)

func power_of(i: int) -> float:
	return KIND_POWER[kind[i]]

func is_alive_uid(u: int) -> bool:
	return uid_idx.has(u)

func query_radius(c: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := maxi(0, int((c.x - r) / CELL))
	var x1 := mini(bw - 1, int((c.x + r) / CELL))
	var y0 := maxi(0, int((c.y - r - 60.0) / CELL))
	var y1 := mini(bh - 1, int((c.y + r + 60.0) / CELL))
	var r2 := r * r
	for by in range(y0, y1 + 1):
		for bx in range(x0, x1 + 1):
			for j in buckets[by * bw + bx]:
				if alive[j] == 1:
					var d := pos[j] + Vector2(0, -50) - c
					if d.x * d.x + d.y * d.y <= r2:
						out.append(j)
	return out

func grab(i: int) -> void:
	state[i] = 3
	vel[i] = Vector2.ZERO

func ungrab(i: int) -> void:
	if alive[i] == 1 and state[i] == 3:
		state[i] = 0

func drag_to(i: int, c: Vector2) -> void:
	pos[i] = c + Vector2(0, 50)

func damage(i: int, n_: float) -> void:
	if alive[i] == 0:
		return
	hp[i] -= n_
	if hp[i] <= 0.0:
		_kill(i)

func hit(i: int, n_: float) -> void:
	if alive[i] == 0 or hit_cd[i] > 0.0:
		return
	hit_cd[i] = 0.15
	damage(i, n_)

func damage_radius(c: Vector2, r: float, n_: float) -> void:
	for j in query_radius(c, r):
		damage(j, n_)

func hit_radius(c: Vector2, r: float, n_: float) -> void:
	for j in query_radius(c, r):
		hit(j, n_)

func eat(i: int) -> void:
	_kill(i)

func _kill(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	alive_count -= 1
	uid_idx.erase(uid[i])
	if view_of[i] >= 0:
		views[view_of[i]].release()
		view_of[i] = -1
	killed.emit(int(kind[i]), pos[i] + Vector2(0, -50))

func _active_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var half := vp / (2.0 * maxf(cam.zoom.x, 0.05)) + Vector2(wake_margin, wake_margin)
	return Rect2(cam.global_position - half, half * 2.0)

func _los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 28.0) + 1
	for s in range(1, steps):
		var p := a + d * (float(s) / steps)
		if world.is_solid_px(p.x, p.y):
			return false
	return true

func _physics_process(delta: float) -> void:
	if player == null or cam == null:
		return
	frame += 1
	pp = player.global_position
	pvel = player.velocity
	pradius = player.body_radius()
	var rect := _active_rect()

	active.clear()
	var cx0 := int(floorf(rect.position.x / CHUNK))
	var cx1 := int(floorf(rect.end.x / CHUNK))
	var cy0 := int(floorf(rect.position.y / CHUNK))
	var cy1 := int(floorf(rect.end.y / CHUNK))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var key := cx + cy * 1000
			if not chunks.has(key):
				continue
			var arr: Array = chunks[key]
			var j := arr.size() - 1
			while j >= 0:
				var i: int = arr[j]
				if alive[i] == 0:
					arr[j] = arr[arr.size() - 1]
					arr.pop_back()
				elif rect.has_point(pos[i]):
					active.append(i)
				j -= 1

	var half_rate := active.size() > half_rate_above
	for i in active:
		hit_cd[i] = maxf(0.0, hit_cd[i] - delta)
		if half_rate:
			if ((i + frame) & 1) == 0:
				_step(i, delta * 2.0)
		else:
			_step(i, delta)

	for k in touched:
		buckets[k].clear()
	touched.clear()
	for i in active:
		var p := pos[i]
		var bx := clampi(int(p.x / CELL), 0, bw - 1)
		var by := clampi(int(p.y / CELL), 0, bh - 1)
		var key2 := by * bw + bx
		var b: Array = buckets[key2]
		if b.is_empty():
			touched.append(key2)
		b.append(i)

	_update_bullets(delta)

func _step(i: int, dt: float) -> void:
	var st := state[i]
	if st == 3:
		return
	var p := pos[i]
	var v := vel[i]
	var k := kind[i]
	var d := pp - p
	var dist := d.length()
	var want := dirv[i] * 60.0
	var jump_ok := false
	var ns := 0
	flaming[i] = 0
	recoil[i] = maxf(0.0, recoil[i])
	if k == 0:
		if dist < 650.0:
			ns = 1
			if absf(d.x) > 1.0:
				dirv[i] = -signf(d.x)
			want = dirv[i] * 240.0
			jump_ok = true
	else:
		los_t[i] -= dt
		if los_t[i] <= 0.0:
			los_t[i] = 0.25
			has_los[i] = 1 if (dist < 1200.0 and _los(p + Vector2(0, -70), pp)) else 0
		if has_los[i] == 1 and dist < 1200.0:
			ns = 2
			var sgn := signf(d.x) if absf(d.x) > 1.0 else dirv[i]
			dirv[i] = sgn
			var from := p + Vector2(0, -62)
			aim[i] = (pp + pvel * 0.22 - from).normalized()
			if k == 2:
				want = sgn * 165.0 if dist > 170.0 else 0.0
				jump_ok = true
				if dist < 330.0 and aim[i].dot((pp - from).normalized()) > 0.8:
					flaming[i] = 1
					player.take_damage(26.0 * enemy_damage_mult * dt, true)
			else:
				if dist < 340.0:
					want = -sgn * 150.0
				elif dist > 620.0:
					want = sgn * (90.0 if k == 1 else 60.0)
				else:
					want = 0.0
				shoot_cd[i] -= dt
				if shoot_cd[i] <= 0.0:
					if k == 1:
						shoot_cd[i] = randf_range(0.55, 0.95)
						_fire(i, 0.0, 9.0)
					else:
						shoot_cd[i] = randf_range(1.3, 1.9)
						_fire(i, -0.07, 8.0)
						_fire(i, 0.0, 8.0)
						_fire(i, 0.07, 8.0)
	state[i] = ns
	if ns == 0:
		timer[i] -= dt
		if timer[i] <= 0.0:
			timer[i] = randf_range(2.0, 6.0)
			if randf() < 0.5:
				dirv[i] = -dirv[i]

	var vx := move_toward(v.x, want, 1500.0 * dt)
	var x := p.x
	var y := p.y
	var nx := x + vx * dt
	var vy := v.y
	if absf(vx) > 1.0:
		var sg := signf(vx)
		var px := nx + sg * 10.0
		if world.is_solid_px(px, y - 8.0) or world.is_solid_px(px, y - 50.0) or world.is_solid_px(px, y - 88.0):
			if jump_ok and grounded[i] == 1:
				vy = -650.0
			elif ns == 0:
				dirv[i] = -dirv[i]
			vx = 0.0
			nx = x
		elif ns == 0 and grounded[i] == 1 and not world.is_solid_px(nx + sg * 24.0, y + 10.0):
			dirv[i] = -dirv[i]
			vx = 0.0
			nx = x
	vy += GRAV * dt
	var ny := y + vy * dt
	grounded[i] = 0
	if vy >= 0.0:
		if world.is_solid_px(nx, ny):
			ny = floorf(ny / 64.0) * 64.0 - 0.5
			vy = 0.0
			grounded[i] = 1
	elif world.is_solid_px(nx, ny - 92.0):
		vy = 0.0
		ny = y
	pos[i] = Vector2(nx, ny)
	vel[i] = Vector2(vx, vy)
	phase[i] += dt * (3.0 + absf(vx) * 0.04)

	var key := _chunk_key(pos[i])
	if key != chunk_of[i]:
		var old: Array = chunks[chunk_of[i]]
		var f := old.find(i)
		if f >= 0:
			old[f] = old[old.size() - 1]
			old.pop_back()
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(i)
		chunk_of[i] = key

func _fire(i: int, spread: float, dmg: float) -> void:
	var from := pos[i] + Vector2(dirv[i] * 12.0, -62.0)
	bpos.append(from)
	bvel.append(aim[i].rotated(spread + randf_range(-0.05, 0.05)) * 820.0)
	bdmg.append(dmg * enemy_damage_mult)
	blife.append(2.2)
	recoil[i] = 1.0

func _update_bullets(dt: float) -> void:
	var i := bpos.size() - 1
	var shield: bool = player.shield_tentacles
	while i >= 0:
		blife[i] -= dt
		var np := bpos[i] + bvel[i] * dt
		var dead: bool = blife[i] <= 0.0 or world.is_solid_px(np.x, np.y)
		if not dead:
			if shield:
				for tp in player.tent_parts:
					if np.distance_to(Vector2(tp.x, tp.y)) < tp.z + 5.0:
						player.heal(1.5)
						dead = true
						break
			if not dead and np.distance_to(pp) < pradius + 6.0:
				player.take_damage(bdmg[i])
				dead = true
		if dead:
			var last := bpos.size() - 1
			bpos[i] = bpos[last]
			bvel[i] = bvel[last]
			bdmg[i] = bdmg[last]
			blife[i] = blife[last]
			bpos.resize(last)
			bvel.resize(last)
			bdmg.resize(last)
			blife.resize(last)
		else:
			bpos[i] = np
		i -= 1

func _assign_views() -> void:
	if (frame & 3) != 0:
		return
	var cc := cam.global_position
	var lim := view_radius * view_radius
	for v in views:
		if v.idx >= 0:
			var i: int = v.idx
			if alive[i] == 0 or pos[i].distance_squared_to(cc) > lim * 1.6:
				if alive[i] == 1:
					view_of[i] = -1
				v.release()
	var free_views: Array = []
	for v in views:
		if v.idx < 0:
			free_views.append(v)
	if free_views.is_empty():
		return
	var cand: Array = []
	for i in active:
		if view_of[i] < 0 and alive[i] == 1:
			var d2 := pos[i].distance_squared_to(cc)
			if d2 < lim:
				cand.append([d2, i])
	if cand.is_empty():
		return
	cand.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for f in mini(free_views.size(), cand.size()):
		var i2: int = cand[f][1]
		free_views[f].assign(i2)
		view_of[i2] = free_views[f].vindex

func _process(delta: float) -> void:
	if player == null or cam == null:
		return
	_assign_views()
	var vp := get_viewport().get_visible_rect().size
	var half := vp / (2.0 * maxf(cam.zoom.x, 0.05)) + Vector2(240.0, 240.0)
	var rect := Rect2(cam.global_position - half, half * 2.0)
	var counts := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	for i in active:
		if view_of[i] >= 0:
			continue
		var p := pos[i]
		if not rect.has_point(p):
			continue
		var mi := int(kind[i]) * 2 + (1 if (sin(phase[i]) > 0.0 and absf(vel[i].x) > 8.0) else 0)
		var c := counts[mi]
		if c >= MM_CAP:
			continue
		var face := dirv[i] if state[i] != 2 else signf(aim[i].x)
		if face == 0.0:
			face = 1.0
		mms[mi].set_instance_transform_2d(c, Transform2D(0.0, Vector2(face, 1.0), 0.0, p))
		counts[mi] = c + 1
	for m in 8:
		mms[m].visible_instance_count = counts[m]
	queue_redraw()

func _draw() -> void:
	for i in bpos.size():
		draw_line(bpos[i], bpos[i] - bvel[i].normalized() * 24.0, Color(1.0, 0.85, 0.35), 4.0)
		draw_circle(bpos[i], 3.5, Color(1, 1, 0.8))
	for i in active:
		if flaming[i] == 1 and view_of[i] < 0:
			var f := signf(aim[i].x)
			var o := pos[i] + Vector2(f * 18.0, -62.0)
			for s in 7:
				draw_circle(o + aim[i] * (s * 24.0), 6.0 + s * 3.0, Color(1.0, maxf(0.15, 0.62 - s * 0.07), 0.08, maxf(0.15, 0.8 - s * 0.1)))
