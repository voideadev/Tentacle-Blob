extends RefCounted

enum { WALK, AIM, FLAME, PANIC, DANGLE }

var s := 1.0
var style := 0
var face := 1.0
var phase := 0.0
var recoil := 0.0
var flash := 0.0
var tilt := 0.0
var flaming := false
var grounded := true
var mode := 0
var origin := Vector2.ZERO
var hip := Vector2.ZERO
var shoulder := Vector2.ZERO
var head := Vector2.ZERO
var gun_dir := Vector2.RIGHT
var muzzle := Vector2.ZERO
var pal := {}

var l1 := 22.0
var l2 := 22.0
var a1 := 16.0
var a2 := 15.0
var torso := 30.0
var head_r := 8.0

var feet := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var feet_prev := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var feet_from := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var feet_to := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var feet_st := PackedFloat32Array([1.0, 1.0])
var feet_dur := PackedFloat32Array([0.25, 0.25])
var hands := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var hands_prev := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var knees := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var ankles := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var elbows := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var wrists := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

func setup(scale_: float, style_: int, pos: Vector2) -> void:
	s = scale_
	style = style_
	l1 = 22.0 * s
	l2 = 22.0 * s
	a1 = 16.0 * s
	a2 = 15.0 * s
	torso = 30.0 * s
	head_r = 8.0 * s
	origin = pos
	phase = randf() * TAU
	face = 1.0 if randf() > 0.5 else -1.0
	pal = _palette(style)
	feet = PackedVector2Array([pos + Vector2(-4.0 * s, 0), pos + Vector2(4.0 * s, 0)])
	feet_prev = PackedVector2Array([feet[0], feet[1]])
	feet_from = PackedVector2Array([feet[0], feet[1]])
	feet_to = PackedVector2Array([feet[0], feet[1]])
	var sh := pos + Vector2(0, -(l1 + l2) * 0.93 - torso)
	hands = PackedVector2Array([sh, sh])
	hands_prev = PackedVector2Array([sh, sh])
	hip = pos + Vector2(0, -(l1 + l2) * 0.93)
	shoulder = sh
	head = sh + Vector2(0, -head_r * 1.5)
	var kn0 := hip + Vector2(0, l1)
	knees = PackedVector2Array([kn0, kn0])
	ankles = PackedVector2Array([feet[0], feet[1]])
	var el0 := sh + Vector2(0, a1)
	elbows = PackedVector2Array([el0, el0])
	wrists = PackedVector2Array([hands[0], hands[1]])

func _palette(st: int) -> Dictionary:
	var skins := [Color("f0cfa8"), Color("d9a679"), Color("b57c52"), Color("8a5a3b")]
	var skin: Color = skins[randi() % skins.size()]
	match st:
		0:
			return {"skin": skin, "top": Color(0.93, 0.94, 0.97), "top2": Color(0.62, 0.68, 0.8),
				"pants": Color(0.25, 0.28, 0.38), "shoe": Color(0.1, 0.1, 0.12), "hair": Color(0.72, 0.72, 0.76)}
		1:
			return {"skin": skin, "top": Color(0.32, 0.43, 0.3), "top2": Color(0.18, 0.26, 0.18),
				"pants": Color(0.24, 0.32, 0.22), "shoe": Color(0.07, 0.07, 0.07), "hair": Color(0.2, 0.3, 0.2)}
		2:
			return {"skin": skin, "top": Color(0.82, 0.38, 0.12), "top2": Color(0.6, 0.26, 0.08),
				"pants": Color(0.5, 0.22, 0.08), "shoe": Color(0.1, 0.1, 0.1), "hair": Color(0.3, 0.3, 0.33)}
		3:
			return {"skin": Color(0.55, 0.58, 0.66), "top": Color(0.45, 0.48, 0.56), "top2": Color(0.3, 0.32, 0.4),
				"pants": Color(0.32, 0.34, 0.42), "shoe": Color(0.15, 0.15, 0.18), "hair": Color(0.4, 0.42, 0.5)}
		4:
			return {"skin": skin, "top": Color(0.12, 0.12, 0.16), "top2": Color(0.5, 0.08, 0.1),
				"pants": Color(0.1, 0.1, 0.13), "shoe": Color(0.05, 0.05, 0.05), "hair": Color(0.1, 0.1, 0.12)}
		6:
			return {"skin": skin, "top": Color(0.28, 0.3, 0.34), "top2": Color(0.16, 0.17, 0.2),
				"pants": Color(0.2, 0.21, 0.25), "shoe": Color(0.06, 0.06, 0.07), "hair": Color(0.22, 0.23, 0.27)}
		_:
			return {"skin": Color(0.5, 0.15, 0.12), "top": Color(0.62, 0.12, 0.1), "top2": Color(0.4, 0.07, 0.06),
				"pants": Color(0.35, 0.07, 0.06), "shoe": Color(0.1, 0.08, 0.08), "hair": Color(0.3, 0.1, 0.1)}

static func ik(root: Vector2, target: Vector2, len1: float, len2: float, bend: float) -> PackedVector2Array:
	var d := target - root
	var raw := d.length()
	var dir := d / raw if raw > 0.0001 else Vector2.DOWN
	var dist := clampf(raw, absf(len1 - len2) + 0.01, len1 + len2 - 0.01)
	var ca := clampf((len1 * len1 + dist * dist - len2 * len2) / (2.0 * len1 * dist), -1.0, 1.0)
	var a := acos(ca)
	return PackedVector2Array([root + dir.rotated(a * bend) * len1, root + dir * dist])

func _ground(space: PhysicsDirectSpaceState2D, x: float) -> Vector2:
	var L := l1 + l2
	var q := PhysicsRayQueryParameters2D.create(
		Vector2(x, origin.y - L * 0.6), Vector2(x, origin.y + L * 0.7), 1)
	var h := space.intersect_ray(q)
	if h:
		return h.position
	return Vector2(x, origin.y)

func update(o: Node2D, vel: Vector2, delta: float, m: int, aim: Vector2, fear: float, on_floor: bool) -> void:
	origin = o.global_position
	mode = m
	grounded = on_floor
	var L := l1 + l2
	var speed := absf(vel.x)
	phase += delta * (3.0 + speed * 0.02 / maxf(s, 0.5))
	recoil = move_toward(recoil, 0.0, delta * 7.0)
	flash = move_toward(flash, 0.0, delta)
	if (m == AIM or m == FLAME) and absf(aim.x) > 0.05:
		face = signf(aim.x)
	elif m != DANGLE and speed > 12.0:
		face = signf(vel.x)
	var space := o.get_world_2d().direct_space_state

	var bob := 0.0
	if on_floor and speed > 15.0 and m != DANGLE:
		bob = sin(phase * 2.0) * L * 0.03
	if m == DANGLE:
		hip = origin + Vector2(0, -L * 0.45)
	else:
		hip = origin + Vector2(0, -L * 0.93 + bob)

	var lean := clampf(vel.x * 0.0008, -0.25, 0.25)
	match m:
		AIM, FLAME:
			lean = clampf(aim.x, -1.0, 1.0) * 0.10 - face * recoil * 0.12
		PANIC:
			lean = -face * 0.10
		DANGLE:
			lean = tilt
	var td := Vector2(sin(lean), -cos(lean))
	shoulder = hip + td * torso
	head = shoulder + Vector2(sin(lean * 1.4), -cos(lean * 1.4)) * (head_r * 1.5)

	if m == DANGLE:
		_dangle(delta)
	else:
		_walk_legs(vel, delta, space)
		_arms(aim, speed, fear, delta)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var r := ik(hip + Vector2(side * 2.0 * s, 0), feet[i], l1, l2, -face)
		knees[i] = r[0]
		ankles[i] = r[1]
		var ra := ik(shoulder, hands[i], a1, a2, face)
		elbows[i] = ra[0]
		wrists[i] = ra[1]
	if m == AIM:
		muzzle = wrists[1] + gun_dir * 30.0 * s
	elif m == FLAME:
		muzzle = wrists[1] + gun_dir * 34.0 * s

func _walk_legs(vel: Vector2, delta: float, space: PhysicsDirectSpaceState2D) -> void:
	var L := l1 + l2
	var speed := absf(vel.x)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var tx := origin.x + side * L * 0.10 + vel.x * 0.16
		if not grounded:
			var tgt := hip + Vector2(side * 5.0 * s, L * 0.80 + sin(phase * 3.0 + i) * 3.0 * s)
			feet[i] = feet[i].lerp(tgt, 1.0 - exp(-12.0 * delta))
			feet_st[i] = 1.0
			continue
		if feet_st[i] >= 1.0:
			var dx := absf(feet[i].x - tx)
			var thresh := L * (0.22 if speed > 15.0 else 0.35)
			var far: bool = feet[i].distance_to(hip) > L * 1.05
			if (dx > thresh or far) and feet_st[1 - i] >= 0.6:
				feet_from[i] = feet[i]
				feet_to[i] = _ground(space, tx + vel.x * 0.12)
				feet_st[i] = 0.0
				feet_dur[i] = clampf(0.30 - speed * 0.0006, 0.12, 0.32)
		if feet_st[i] < 1.0:
			feet_st[i] = minf(1.0, feet_st[i] + delta / feet_dur[i])
			var st: float = feet_st[i]
			var e := st * st * (3.0 - 2.0 * st)
			feet[i] = feet_from[i].lerp(feet_to[i], e) + Vector2(0, -sin(st * PI) * L * 0.16)
			if st >= 1.0:
				feet[i] = feet_to[i]
		feet_prev[i] = feet[i]

func _arms(aim: Vector2, speed: float, fear: float, delta: float) -> void:
	var A := a1 + a2
	var k := 1.0 - exp(-18.0 * delta)
	if mode == AIM or mode == FLAME:
		gun_dir = aim.normalized() if aim.length() > 0.01 else Vector2(face, 0)
		k = 1.0 - exp(-32.0 * delta)
	for i in 2:
		var tgt: Vector2
		match mode:
			AIM, FLAME:
				if i == 1:
					tgt = shoulder + gun_dir * A * 0.82 - gun_dir * recoil * 6.0 * s
				else:
					tgt = shoulder + gun_dir * A * 0.97 - gun_dir * recoil * 4.0 * s
			PANIC:
				tgt = shoulder + Vector2(((i * 2 - 1) * 0.45 + sin(phase * 3.0 + i) * 0.14) * A, -A * 0.88)
			_:
				var sw := sin(phase + float(i) * PI) * clampf(speed / 200.0, 0.0, 1.0)
				var idle := sin(phase * 0.7 + i) * 0.03
				tgt = shoulder + Vector2((sw * 0.55 + idle) * A, A * 0.86)
		hands[i] = hands[i].lerp(tgt, k)
		hands_prev[i] = hands[i]

func _dangle(delta: float) -> void:
	var damp := pow(0.25, delta)
	var g := Vector2(0, 1800.0 * s) * delta * delta
	var Lr := (l1 + l2) * 0.98
	var Ar := (a1 + a2) * 0.98
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var rf := hip + Vector2(side * 2.0 * s, 0)
		var p: Vector2 = feet[i]
		var np: Vector2 = p + (p - feet_prev[i]) * damp + g \
			+ Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.3)) * 70.0 * s * delta
		var off := np - rf
		if off.length() > Lr:
			np = rf + off.normalized() * Lr
		feet_prev[i] = p
		feet[i] = np
		feet_st[i] = 1.0
		var ph: Vector2 = hands[i]
		var nh: Vector2 = ph + (ph - hands_prev[i]) * damp + g \
			+ Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.3)) * 70.0 * s * delta
		var offh := nh - shoulder
		if offh.length() > Ar:
			nh = shoulder + offh.normalized() * Ar
		hands_prev[i] = ph
		hands[i] = nh

func _t(c: Color) -> Color:
	return c.lerp(Color.WHITE, clampf(flash * 5.0, 0.0, 0.8))

func _cap(c: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := lerpf(PI, TAU, i / 9.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, col)

func draw(c: CanvasItem) -> void:
	var o := origin
	var f := face
	if grounded and mode != DANGLE:
		c.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.22))
		c.draw_circle(Vector2.ZERO, 22.0 * s, Color(0, 0, 0, 0.35))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pants := _t(pal["pants"])
	var shoe := _t(pal["shoe"])
	var top := _t(pal["top"])
	var top2 := _t(pal["top2"])
	var skin := _t(pal["skin"])
	var hair := _t(pal["hair"])

	for i in 2:
		var k := 0.66 if i == 0 else 1.0
		var sd := Color(k, k, k, 1.0)
		var rt := hip + Vector2((-1.0 if i == 0 else 1.0) * 2.0 * s, 0.0) - o
		var kn: Vector2 = knees[i] - o
		var an: Vector2 = ankles[i] - o
		c.draw_line(rt, kn, pants * sd, 10.5 * s, true)
		c.draw_line(kn, an, pants * sd, 8.5 * s, true)
		c.draw_circle(kn, 4.4 * s, pants * sd)
		c.draw_circle(rt, 5.0 * s, pants * sd)
		c.draw_line(an + Vector2(-f * s, 0), an + Vector2(f * 8.0 * s, s), shoe * sd, 5.5 * s, true)

	var d := (shoulder - hip).normalized()
	var perp := Vector2(-d.y, d.x)
	var sh := shoulder - o
	var hp := hip - o
	var w_s := 6.5 * s
	var w_h := 5.0 * s
	var tail := 0.0
	match style:
		0:
			tail = 11.0 * s
			w_h = 6.0 * s
		2, 5, 6:
			w_s = 8.5 * s
			w_h = 7.5 * s
		3:
			w_s = 10.0 * s
			w_h = 7.0 * s
		4:
			tail = 20.0 * s
			w_h = 7.0 * s
	if style == 2 or style == 5 or style == 3:
		var back := hp + d * torso * 0.5 - Vector2(f * 11.0 * s, 0)
		var tank := Color(0.5, 0.52, 0.56) if style != 3 else Color(0.3, 0.32, 0.38)
		c.draw_line(back - d * 14.0 * s, back + d * 14.0 * s, _t(tank), 10.0 * s, true)
		c.draw_circle(back - d * 14.0 * s, 5.0 * s, _t(tank))
		c.draw_circle(back + d * 14.0 * s, 5.0 * s, _t(tank))
	var poly := PackedVector2Array([
		sh - perp * w_s, sh + perp * w_s,
		hp + perp * w_h - d * tail, hp - perp * w_h - d * tail])
	c.draw_colored_polygon(poly, top)
	match style:
		0:
			c.draw_line(sh - perp * 3.0 * s, sh + perp * 3.0 * s, top2, 3.0 * s)
			c.draw_line(sh - d * 3.0 * s, hp - d * tail * 0.8, top2, 1.6 * s)
		1:
			var vest := PackedVector2Array([
				sh - perp * 5.5 * s - d * 2.0 * s, sh + perp * 5.5 * s - d * 2.0 * s,
				hp + perp * 5.0 * s + d * 4.0 * s, hp - perp * 5.0 * s + d * 4.0 * s])
			c.draw_colored_polygon(vest, top2)
			c.draw_line(hp - perp * w_h, hp + perp * w_h, Color(0.05, 0.05, 0.05), 3.0 * s)
		3:
			c.draw_circle(sh - d * 9.0 * s, 3.6 * s, Color(1.0, 0.2, 0.15))
			c.draw_circle(sh + perp * w_s, 6.5 * s, top2)
			c.draw_circle(sh - perp * w_s, 6.5 * s, top2)
		4:
			c.draw_line(sh - d * 2.0 * s, hp - d * tail, top2, 2.4 * s)
		2, 5, 6:
			c.draw_line(hp - perp * w_h, hp + perp * w_h, top2, 3.0 * s)

	var sleeve := top if style == 0 else top2
	for i in 2:
		var k := 0.72 if i == 0 else 1.0
		var sd := Color(k, k, k, 1.0)
		var el: Vector2 = elbows[i] - o
		var wr: Vector2 = wrists[i] - o
		c.draw_line(sh, el, sleeve * sd, 7.2 * s, true)
		c.draw_line(el, wr, sleeve * sd, 6.2 * s, true)
		c.draw_circle(el, 3.4 * s, sleeve * sd)
	if mode == AIM or mode == FLAME:
		var h1: Vector2 = wrists[1] - o
		var gd := gun_dir
		var dark := Color(0.1, 0.1, 0.12)
		if mode == AIM:
			var g0 := h1 - gd * 10.0 * s
			var g1 := h1 + gd * 30.0 * s
			c.draw_line(g0, g1, dark, 5.5 * s, true)
			c.draw_line(g0, g0 - gd * 8.0 * s + Vector2(0, 5.0 * s), dark, 4.5 * s, true)
			c.draw_line(h1 + gd * 5.0 * s, h1 + gd * 5.0 * s + Vector2(0, 9.0 * s), dark, 4.0 * s, true)
			if recoil > 0.6:
				c.draw_circle(g1 + gd * 4.0 * s, 8.0 * s, Color(1.0, 0.85, 0.4, 0.9))
		else:
			var g0 := h1 - gd * 6.0 * s
			var g1 := h1 + gd * 34.0 * s
			c.draw_line(g0, g1, Color(0.25, 0.25, 0.28), 6.5 * s, true)
			c.draw_circle(g1, 4.0 * s, dark)
			var back := hip + d * torso * 0.5 - Vector2(f * 11.0 * s, 0) - o
			c.draw_line(back, h1, Color(0.08, 0.08, 0.08), 2.4 * s, true)
			if flaming:
				var pr := Vector2(-gd.y, gd.x)
				for i in 9:
					var p := g1 + gd * (i * 20.0 * s) + pr * sin(phase * 6.0 + i * 1.7) * 5.0 * s
					var r := (5.0 + i * 2.6) * s * 0.7
					c.draw_circle(p, r, Color(1.0, maxf(0.15, 0.62 - i * 0.05), 0.08, maxf(0.15, 0.8 - i * 0.08)))
	for i in 2:
		c.draw_circle(wrists[i] - o, 3.4 * s, skin if style != 3 else _t(pal["skin"]))

	var hd := head - o
	var hr := head_r
	c.draw_circle(hd, hr, skin)
	match style:
		0:
			_cap(c, hd, hr * 1.04, hair)
			c.draw_circle(hd + Vector2(f * hr * 0.35, -hr * 0.05), hr * 0.38, Color(0.6, 0.8, 1.0, 0.55))
		1:
			_cap(c, hd, hr * 1.18, hair)
			c.draw_line(hd + Vector2(-hr * 1.15, -hr * 0.1), hd + Vector2(hr * 1.15, -hr * 0.1), hair, 2.4 * s)
		2, 5, 6:
			c.draw_circle(hd, hr * 1.1, hair)
			var visor := Color(1.0, 0.7, 0.2) if style == 2 else (Color(1.0, 0.2, 0.15) if style == 6 else Color(1.0, 0.9, 0.2))
			c.draw_circle(hd + Vector2(f * hr * 0.45, -hr * 0.1), hr * 0.5, visor)
		3:
			c.draw_circle(hd, hr * 1.15, hair)
			c.draw_circle(hd + Vector2(f * hr * 0.45, -hr * 0.1), hr * 0.35, Color(1.0, 0.15, 0.1))
		4:
			_cap(c, hd, hr * 1.12, hair)
			c.draw_line(hd + Vector2(-hr * 1.1, -hr * 0.15), hd + Vector2(f * hr * 1.5, -hr * 0.15), hair, 2.6 * s)
	if style == 0 or style == 1 or style == 4:
		c.draw_circle(hd + Vector2(f * hr * 0.45, -hr * 0.08), 1.4 * s, Color(0.05, 0.05, 0.05))
