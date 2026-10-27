extends RefCounted
## Generador v6: el nivel es un GRAFO DE SALAS (cada sala = una pantalla con camara fija, >= tamano de pantalla).
## Las salas se conectan por conductos (vents). Cada sala tiene layout, tema y contenido propios.
## Layouts: open, platforms, pillars, stairs, tunnel, island.
## Temas: plain, lab, storage, server, reactor.
## Especiales: altar, nest, arena, feast, armory.

const T := 48.0
const BASE_W := 1280.0
const BASE_H := 720.0
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]   # E, W, S, N
const OPP := [1, 0, 3, 2]
const LAYOUTS := ["open", "platforms", "pillars", "stairs", "tunnel", "island"]

static func _link(a: Vector2i, b: Vector2i, conns: Dictionary) -> void:
	var di: int = DIRS.find(b - a)
	for c in conns[a]:
		if c["to"] == b:
			return
	conns[a].append({"dir": di, "to": b})
	conns[b].append({"dir": OPP[di], "to": a})

static func _ngon(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(rot + TAU * i / n) * r)
	return pts

static func _free(r: Rect2, keepout: Array) -> bool:
	for k in keepout:
		if (k as Rect2).intersects(r):
			return false
	return true

static func theme_color(name_: String) -> Color:
	match name_:
		"lab", "feast":
			return Color(0.7, 0.85, 1.0)
		"storage":
			return Color(1.0, 0.75, 0.4)
		"server":
			return Color(0.4, 1.0, 0.9)
		"reactor":
			return Color(1.0, 0.45, 0.2)
		"nest":
			return Color(0.4, 1.0, 0.5)
		"altar":
			return Color(1.0, 0.85, 0.3)
		"arena":
			return Color(1.0, 0.3, 0.3)
		"armory":
			return Color(1.0, 0.6, 0.3)
	return Color(0.9, 0.85, 0.75)

static func enemy_kind(rng: RandomNumberGenerator, depth: int) -> int:
	var p_heavy := 0.0 if depth < 4 else minf(0.04 + 0.015 * depth, 0.18)
	var p_flamer := 0.0 if depth < 3 else minf(0.07 + 0.02 * depth, 0.22)
	var p_soldier := minf(0.22 + 0.03 * depth, 0.5)
	var r := rng.randf()
	if r < p_heavy:
		return 3
	if r < p_heavy + p_flamer:
		return 2
	if r < p_heavy + p_flamer + p_soldier:
		return 1
	return 0

# ======================= grafo de salas =======================
static func generate(depth: int, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var cols := clampi(3 + floori(depth / 3.0), 3, 6)
	var rows := clampi(2 + floori(depth / 5.0), 2, 4)
	var conns := {}
	var cells: Array[Vector2i] = []
	for c in cols:
		for r in rows:
			conns[Vector2i(c, r)] = []
			cells.append(Vector2i(c, r))

	var start := Vector2i(0, rng.randi_range(0, rows - 1))
	var visited := {}
	visited[start] = true
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var nb: Array[Vector2i] = []
		for d in DIRS:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < cols and n.y >= 0 and n.y < rows and not visited.has(n):
				nb.append(n)
		if nb.is_empty():
			stack.pop_back()
		else:
			var pick: Vector2i = nb[rng.randi_range(0, nb.size() - 1)]
			_link(cur, pick, conns)
			visited[pick] = true
			stack.append(pick)
	for cell in cells:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n2: Vector2i = cell + d
			if n2.x < cols and n2.y < rows and rng.randf() < 0.22:
				_link(cell, n2, conns)

	var dist := {}
	dist[start] = 0
	var q: Array[Vector2i] = [start]
	var qi := 0
	while qi < q.size():
		var c2: Vector2i = q[qi]
		qi += 1
		for cn in conns[c2]:
			var to: Vector2i = cn["to"]
			if not dist.has(to):
				dist[to] = dist[c2] + 1
				q.append(to)
	var exit_cell := start
	var best := -1
	for k in dist:
		if dist[k] > best:
			best = dist[k]
			exit_cell = k

	var is_boss := depth % 5 == 0
	var cand: Array = cells.filter(func(cc: Vector2i) -> bool: return cc != start and cc != exit_cell)
	for i in range(cand.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cand[i]
		cand[i] = cand[j]
		cand[j] = tmp
	var kinds := ["arena", "nest", "altar", "feast", "armory"]
	for i in range(kinds.size() - 1, 0, -1):
		var j2 := rng.randi_range(0, i)
		var tk = kinds[i]
		kinds[i] = kinds[j2]
		kinds[j2] = tk
	var n_sp := mini(1 + (1 if depth >= 3 else 0) + (1 if depth >= 6 else 0), mini(kinds.size(), cand.size()))
	var sp_of := {}
	for i in n_sp:
		var sc: Vector2i = cand.pop_back()
		sp_of[sc] = kinds[i]

	var rooms := {}
	var total_h := 0
	for cell in cells:
		var theme := "plain"
		if not sp_of.has(cell) and cell != start and cell != exit_cell:
			var w_rea := 1.0 if depth >= 3 else 0.0
			var roll := rng.randf() * (2.0 + 2.0 + 2.0 + 2.0 + w_rea)
			if roll < 2.0:
				theme = "plain"
			elif roll < 4.0:
				theme = "lab"
			elif roll < 6.0:
				theme = "storage"
			elif roll < 8.0:
				theme = "server"
			else:
				theme = "reactor"
		var room := _make_room(depth, seed_val, cell, conns[cell], theme, sp_of.get(cell, ""),
			cell == start, cell == exit_cell, is_boss)
		rooms[cell] = room
		total_h += room["humans"].size()

	return {"cols": cols, "rows": rows, "rooms": rooms, "conns": conns, "start": start, "exit": exit_cell,
		"total_h": total_h, "boss": is_boss, "exit_open": false}

# ======================= una sala =======================
static func _make_room(depth: int, seed_val: int, cell: Vector2i, cn: Array, theme: String, special: String,
		is_start: bool, is_exit: bool, is_boss: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 31 + cell.x * 1009 + cell.y * 9173 + 7
	var fx := 1.0
	var fy := 1.0
	if is_boss and is_exit:
		fx = 1.45
		fy = 1.3
	elif not is_start:
		fx = rng.randf_range(1.0, 1.5)
		fy = rng.randf_range(1.0, 1.35)
	var W := BASE_W * fx
	var H := BASE_H * fy

	var rects: Array[Rect2] = [
		Rect2(-T, -T, W + 2 * T, T), Rect2(-T, H, W + 2 * T, T),
		Rect2(-T, 0, T, H), Rect2(W, 0, T, H)]
	var polys: Array[PackedVector2Array] = []
	var props: Array = []
	var prop_rects: Array[Rect2] = []
	var keepout: Array = []
	var ledges: Array[Rect2] = []
	var hazards: Array = []
	var specials: Array = []
	var extra_h: Array = []
	var extra_t := 0

	# ---- conductos ----
	var vents: Array = []
	for c in cn:
		var dir: int = c["dir"]
		var pos := Vector2.ZERO
		match dir:
			0:
				pos = Vector2(W - 20.0, rng.randf_range(H * 0.3, H * 0.72))
			1:
				pos = Vector2(20.0, rng.randf_range(H * 0.3, H * 0.72))
			2:
				pos = Vector2(rng.randf_range(W * 0.25, W * 0.75), H - 20.0)
			_:
				pos = Vector2(rng.randf_range(W * 0.25, W * 0.75), 20.0)
		vents.append({"pos": pos, "dir": dir, "to": c["to"]})
		keepout.append(Rect2(pos - Vector2(240, 240), Vector2(480, 480)))
	var spawn := Vector2(W * 0.5, H * 0.5)
	keepout.append(Rect2(spawn - Vector2(160, 160), Vector2(320, 320)))
	var exit_pos := Vector2.ZERO
	if is_exit:
		exit_pos = Vector2(W * 0.5 + rng.randf_range(-220.0, 220.0), H - 4.0)
		keepout.append(Rect2(exit_pos - Vector2(200, 320), Vector2(400, 330)))

	# ---- layout ----
	var layout := "open"
	if not is_start and not (is_boss and is_exit) and special == "":
		layout = LAYOUTS[rng.randi_range(0, LAYOUTS.size() - 1)]
	elif special == "arena" or special == "armory":
		layout = ["platforms", "pillars", "open"][rng.randi_range(0, 2)]
	_layout(layout, W, H, rng, keepout, rects, polys, ledges)

	# ---- tema / especial ----
	var key := special if special != "" else theme
	if special == "":
		_theme(theme, W, H, rng, keepout, props, prop_rects, hazards, ledges, extra_h)
	else:
		match special:
			"altar":
				props.append({"t": "altar", "pos": Vector2(W * 0.5, H - 50.0), "used": false})
				specials.append({"kind": "altar", "pos": Vector2(W * 0.5, H - 110.0), "done": false, "prop": props.back()})
			"nest":
				var pool := {"t": "pool", "r": Rect2(W * 0.5 - 330.0, H - 44.0, 660.0, 44.0), "fill": 1.0}
				props.append(pool)
				specials.append({"kind": "nest", "pos": Vector2(W * 0.5, H - 60.0),
					"rect": Rect2(W * 0.5 - 330.0, H - 300.0, 660.0, 300.0), "cap": 150.0, "prop": pool})
			"arena":
				props.append({"t": "arena_mark", "pos": Vector2(W * 0.5, H - 2.0)})
				specials.append({"kind": "arena", "pos": Vector2(W * 0.5, H * 0.5), "state": 0, "wave": 0, "enemies": []})
			"feast":
				_theme("lab", W, H, rng, keepout, props, prop_rects, hazards, ledges, [])
				extra_h.append([0, 18])
				specials.append({"kind": "feast"})
			"armory":
				for i in 3:
					var r := Rect2(W * 0.3 + i * 150.0, H - 110.0, 110.0, 110.0)
					if _free(r, keepout):
						props.append({"t": "crate", "r": r})
						prop_rects.append(r)
						ledges.append(Rect2(r.position, Vector2(r.size.x, 4)))
				extra_h.append([1, 5])
				extra_t = 3
				specials.append({"kind": "armory"})
	if rng.randf() < 0.5:
		props.append({"t": "pipe", "r": Rect2(60.0, 24.0, W - 120.0, 20.0)})

	# ---- enemigos ----
	var humans: Array = []
	if is_start:
		for k in [0, 0, 0, 1]:
			humans.append({"pos": _floor_pos(W, H, rects, prop_rects, ledges, rng), "kind": k, "alive": true})
	elif not (is_boss and is_exit):
		var n_h := mini(8 + depth + rng.randi_range(0, 4), 30)
		for i in n_h:
			humans.append({"pos": _floor_pos(W, H, rects, prop_rects, ledges, rng),
				"kind": enemy_kind(rng, depth), "alive": true})
		for e in extra_h:
			for i in int(e[1]):
				humans.append({"pos": _floor_pos(W, H, rects, prop_rects, ledges, rng), "kind": int(e[0]), "alive": true})
	var turrets: Array = []
	if depth >= 2 and not is_start and not (is_boss and is_exit):
		var n_t := mini(1 + floori(depth / 3.0), 5) + extra_t
		for i in n_t:
			var tx := rng.randf_range(W * 0.12, W * 0.88)
			if _free(Rect2(tx - 40.0, 0.0, 80.0, 80.0), keepout):
				turrets.append({"pos": Vector2(tx, 4.0), "alive": true})

	# ---- luces ----
	var lamps: Array = []
	var lc := theme_color(key)
	var nl := 3 if W < 1500.0 else 4
	for i in nl:
		var col := lc if key != "plain" else (Color(1.0, 0.85, 0.6) if i % 2 == 0 else Color(0.55, 0.72, 1.0))
		lamps.append({"pos": Vector2(W * (i + 0.5) / nl + rng.randf_range(-60.0, 60.0), 90.0), "color": col})

	return {"w": W, "h": H, "rects": rects, "polys": polys, "props": props, "prop_rects": prop_rects,
		"vents": vents, "hazards": hazards, "specials": specials, "humans": humans, "turrets": turrets,
		"lamps": lamps, "theme": theme, "special": special, "layout": layout, "key": key,
		"spawn": spawn, "exit_pos": exit_pos, "cell": cell}

static func _floor_pos(W: float, H: float, rects: Array, prop_rects: Array, ledges: Array, rng: RandomNumberGenerator) -> Vector2:
	if not ledges.is_empty() and rng.randf() < 0.35:
		var l: Rect2 = ledges[rng.randi_range(0, ledges.size() - 1)]
		return Vector2(rng.randf_range(l.position.x + 30.0, maxf(l.position.x + 31.0, l.end.x - 30.0)), l.position.y - 1.0)
	for i in 16:
		var x := rng.randf_range(100.0, W - 100.0)
		var ok := true
		for r in rects:
			var rr: Rect2 = r
			if rr.position.y < H and rr.end.y > H - 4.0 and x > rr.position.x - 50.0 and x < rr.end.x + 50.0:
				ok = false
				break
		if ok:
			for r in prop_rects:
				var rp: Rect2 = r
				if rp.end.y > H - 4.0 and x > rp.position.x - 50.0 and x < rp.end.x + 50.0:
					ok = false
					break
		if ok:
			return Vector2(x, H - 1.0)
	return Vector2(W * 0.5, H - 1.0)

# ======================= layouts =======================
static func _layout(kind: String, W: float, H: float, rng: RandomNumberGenerator, keepout: Array,
		rects: Array, polys: Array, ledges: Array) -> void:
	match kind:
		"open":
			for i in rng.randi_range(2, 4):
				var c := Vector2(rng.randf_range(W * 0.2, W * 0.8), rng.randf_range(H * 0.25, H * 0.62))
				var rad := rng.randf_range(60.0, 110.0)
				var bb := Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
				if _free(bb.grow(40.0), keepout):
					polys.append(_ngon(c, rad, rng.randi_range(5, 8), rng.randf() * TAU))
					keepout.append(bb.grow(50.0))
		"platforms":
			for i in rng.randi_range(3, 5):
				var w := rng.randf_range(260.0, 420.0)
				var slab := Rect2(rng.randf_range(80.0, W - 80.0 - w), rng.randf_range(H * 0.28, H * 0.78), w, 36.0)
				if _free(slab.grow(60.0), keepout):
					rects.append(slab)
					ledges.append(Rect2(slab.position, Vector2(slab.size.x, 4.0)))
					keepout.append(slab.grow(80.0))
		"pillars":
			var n := rng.randi_range(2, 3)
			for i in n:
				var x := W * (i + 1.0) / (n + 1.0) + rng.randf_range(-70.0, 70.0)
				var r: Rect2
				if i % 2 == 0:
					r = Rect2(x, 0.0, 90.0, H * 0.55)
				else:
					r = Rect2(x, H * 0.5, 90.0, H * 0.5)
					ledges.append(Rect2(r.position, Vector2(r.size.x, 4.0)))
				if _free(r.grow(40.0), keepout):
					rects.append(r)
					keepout.append(r.grow(40.0))
		"stairs":
			var left := rng.randf() < 0.5
			var steps: Array[Rect2] = []
			var ok := true
			for k in 5:
				var h := 60.0 * (k + 1)
				var x2 := k * 140.0 if left else W - (k + 1) * 140.0
				var st := Rect2(x2, H - h, 140.0, h)
				if not _free(st, keepout):
					ok = false
				steps.append(st)
			if ok:
				for st in steps:
					rects.append(st)
					ledges.append(Rect2(st.position, Vector2(st.size.x, 4.0)))
					keepout.append(st)
		"tunnel":
			var bar := Rect2(W * 0.22, H * 0.5, W * 0.56, 44.0)
			if _free(bar.grow(60.0), keepout):
				rects.append(bar)
				ledges.append(Rect2(bar.position, Vector2(bar.size.x, 4.0)))
				keepout.append(bar.grow(80.0))
		"island":
			var c2 := Vector2(W * 0.5 + rng.randf_range(-100.0, 100.0), H * 0.5 + rng.randf_range(-40.0, 40.0))
			var rad2 := rng.randf_range(130.0, 170.0)
			var bb2 := Rect2(c2 - Vector2(rad2, rad2), Vector2(rad2, rad2) * 2.0)
			if _free(bb2.grow(40.0), keepout):
				polys.append(_ngon(c2, rad2, 7, rng.randf() * TAU))
				keepout.append(bb2.grow(60.0))
			for sx in [0.18, 0.82]:
				var c3 := Vector2(W * sx, H * rng.randf_range(0.35, 0.6))
				var bb3 := Rect2(c3 - Vector2(60, 60), Vector2(120, 120))
				if _free(bb3.grow(40.0), keepout):
					polys.append(_ngon(c3, 60.0, 6, rng.randf() * TAU))
					keepout.append(bb3.grow(50.0))

# ======================= temas =======================
static func _theme(theme: String, W: float, H: float, rng: RandomNumberGenerator, keepout: Array,
		props: Array, prop_rects: Array, hazards: Array, ledges: Array, extra_h: Array) -> void:
	match theme:
		"lab":
			var dw := rng.randf_range(200.0, 250.0)
			var d1 := Rect2(W * 0.16, H - 58.0, dw, 58.0)
			var d2 := Rect2(W * 0.72, H - 58.0, dw, 58.0)
			var tk := Rect2(W * 0.5 - 40.0 + rng.randf_range(-80.0, 80.0), H - 300.0, 80.0, 300.0)
			for r in [d1, d2]:
				if _free(r, keepout):
					props.append({"t": "desk", "r": r})
			if _free(tk, keepout):
				props.append({"t": "tank", "r": tk})
			extra_h.append([0, 3])
		"storage":
			for i in 3:
				var bx := W * (0.2 + 0.27 * i) + rng.randf_range(-30.0, 30.0)
				var cs := rng.randf_range(100.0, 135.0)
				for k in rng.randi_range(1, 3):
					var r2 := Rect2(bx, H - cs * (k + 1), cs, cs)
					if _free(r2, keepout):
						props.append({"t": "crate", "r": r2})
						prop_rects.append(r2)
						if k == 0:
							pass
						ledges.append(Rect2(r2.position, Vector2(r2.size.x, 4.0)))
		"server":
			for i in 3:
				var rr := Rect2(W * 0.2 + i * 92.0, H - 340.0, 84.0, 340.0)
				if _free(rr, keepout):
					props.append({"t": "rack", "r": rr})
					prop_rects.append(rr)
			for i in 2:
				var rr2 := Rect2(W * 0.68 + i * 92.0, H - 300.0, 84.0, 300.0)
				if _free(rr2, keepout):
					props.append({"t": "rack", "r": rr2})
					prop_rects.append(rr2)
		"reactor":
			var ped := Rect2(W * 0.5 - 85.0, H - 110.0, 170.0, 110.0)
			if _free(ped, keepout):
				props.append({"t": "pedestal", "r": ped})
				prop_rects.append(ped)
				var core_pos := Vector2(W * 0.5, H - 250.0)
				props.append({"t": "core", "pos": core_pos})
				hazards.append({"pos": core_pos, "r": 250.0, "dps": 9.0})
