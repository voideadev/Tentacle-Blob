@tool
extends Node2D

const TILE := 64
const ZoneScript = preload("res://crowd_zone.gd")
const FeatureScript = preload("res://feature.gd")

@export var use_random_seed := true
@export var seed_value := 12345
@export var grid_w := 170
@export var grid_h := 100
@export var room_count := 16
@export_range(6, 10) var pipe_width := 6
@export var humans_per_cell := 0.14
@export var pipe_humans := 7
@export_tool_button("Generar mundo (editable)", "Reload") var generate_button = _editor_generate

var terrain: TileMapLayer
var solid := PackedByteArray()
var gw := 0
var gh := 0
var start_pos := Vector2.ZERO
var rooms: Array[Rect2i] = []

func _ready() -> void:
	terrain = get_node_or_null("Terrain")
	if terrain == null:
		return
	_ensure_tileset()
	if Engine.is_editor_hint():
		return
	if terrain.get_used_cells().is_empty():
		generate(randi() if use_random_seed else seed_value)
	else:
		_load_from_tilemap()
	var ps := get_node_or_null("PlayerStart") as Marker2D
	if ps != null:
		start_pos = ps.global_position
	var bg := ColorRect.new()
	bg.size = Vector2(gw * TILE, gh * TILE)
	bg.z_index = -20
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://bg.gdshader")
	bg.material = m
	add_child(bg)

func _editor_generate() -> void:
	terrain = get_node_or_null("Terrain")
	if terrain == null:
		return
	generate(seed_value)

func is_solid_px(x: float, y: float) -> bool:
	var cx := int(floorf(x / TILE))
	var cy := int(floorf(y / TILE))
	if cx < 0 or cy < 0 or cx >= gw or cy >= gh:
		return true
	return solid[cy * gw + cx] == 1

func floor_y(x: float, y: float) -> float:
	var cx := int(floorf(x / TILE))
	var cy := maxi(0, int(floorf(y / TILE)))
	if cx < 0 or cx >= gw or cy >= gh or solid[cy * gw + cx] == 1:
		return -1.0
	while cy < gh:
		if solid[cy * gw + cx] == 1:
			return float(cy * TILE)
		cy += 1
	return -1.0

func ceil_y(x: float, y: float) -> float:
	var cx := int(floorf(x / TILE))
	var cy := int(floorf(y / TILE))
	if cx < 0 or cx >= gw or cy < 0 or cy >= gh or solid[cy * gw + cx] == 1:
		return -1.0
	while cy >= 0:
		if solid[cy * gw + cx] == 1:
			return float((cy + 1) * TILE)
		cy -= 1
	return -1.0

func _ensure_tileset() -> void:
	if terrain.tile_set != null:
		return
	var img := Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE * 2:
			var lx := x % TILE
			var edge := lx < 2 or lx >= TILE - 2 or y < 2 or y >= TILE - 2
			var c: Color
			if x < TILE:
				c = Color(0.55, 0.58, 0.72) if edge else Color(0.40, 0.43, 0.55)
			else:
				c = Color(0.16, 0.17, 0.23) if edge else Color(0.12, 0.13, 0.18)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	ts.add_source(src, 0)
	var td := src.get_tile_data(Vector2i(0, 0), 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-TILE / 2, -TILE / 2), Vector2(TILE / 2, -TILE / 2),
		Vector2(TILE / 2, TILE / 2), Vector2(-TILE / 2, TILE / 2)]))
	terrain.tile_set = ts
	var m := ShaderMaterial.new()
	m.shader = load("res://wall.gdshader")
	terrain.material = m

func _tile_type(x: int, y: int) -> int:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
				continue
			if solid[ny * gw + nx] == 0:
				return 0
	return 1

func _load_from_tilemap() -> void:
	var ur := terrain.get_used_rect()
	gw = maxi(grid_w, ur.end.x + 1)
	gh = maxi(grid_h, ur.end.y + 1)
	solid.resize(gw * gh)
	solid.fill(0)
	for c in terrain.get_used_cells():
		if c.x >= 0 and c.y >= 0 and c.x < gw and c.y < gh:
			solid[c.y * gw + c.x] = 1
	for y in gh:
		for x in gw:
			if solid[y * gw + x] == 1:
				var t := _tile_type(x, y)
				if terrain.get_cell_atlas_coords(Vector2i(x, y)).x != t:
					terrain.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))

func _paint() -> void:
	terrain.clear()
	for y in gh:
		for x in gw:
			if solid[y * gw + x] == 1:
				terrain.set_cell(Vector2i(x, y), 0, Vector2i(_tile_type(x, y), 0))

func _carve_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(y0, 3), mini(y1, gh - 3)):
		for x in range(maxi(x0, 3), mini(x1, gw - 3)):
			solid[y * gw + x] = 0

func _mark(res: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(y0, 0), mini(y1, gh)):
		for x in range(maxi(x0, 0), mini(x1, gw)):
			res[y * gw + x] = 1

func _carve_room(r: Rect2i, shape: int) -> void:
	var cx := r.position.x + r.size.x * 0.5
	var cy := r.position.y + r.size.y * 0.5
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var inside := true
			if shape == 1:
				var dx := (x + 0.5 - cx) / (r.size.x * 0.5)
				var dy := (y + 0.5 - cy) / (r.size.y * 0.5)
				inside = dx * dx + dy * dy <= 1.0
			elif shape == 2:
				inside = not (x > cx + r.size.x * 0.18 and y < cy - r.size.y * 0.12)
			if inside:
				solid[y * gw + x] = 0

func _carve_pipe(a: Vector2i, b: Vector2i, p: int, rng: RandomNumberGenerator, res: PackedByteArray) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	if rng.randf() < 0.5:
		var mx := rng.randi_range(mini(a.x, b.x), maxi(a.x, b.x))
		pts = [a, Vector2i(mx, a.y), Vector2i(mx, b.y), b]
	else:
		var my := rng.randi_range(mini(a.y, b.y), maxi(a.y, b.y))
		pts = [a, Vector2i(a.x, my), Vector2i(b.x, my), b]
	var half := p / 2
	for k in pts.size() - 1:
		var s := pts[k]
		var e := pts[k + 1]
		var x0 := mini(s.x, e.x) - half
		var x1 := maxi(s.x, e.x) + p - half
		var y0 := mini(s.y, e.y) - half
		var y1 := maxi(s.y, e.y) + p - half
		_carve_rect(x0, y0, x1, y1)
		_mark(res, x0 - 4, y0 - 4, x1 + 4, y1 + 4)
	return pts

func _area_free(res: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> bool:
	for y in range(y0, y1):
		for x in range(x0, x1):
			if x < 3 or y < 3 or x >= gw - 3 or y >= gh - 3:
				return false
			if solid[y * gw + x] == 1 or res[y * gw + x] == 1:
				return false
	return true

func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _own(n: Node) -> void:
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root != null:
			n.owner = root

func _add_zone(zones: Node, pos: Vector2, area: Vector2, counts: Array, tier: int, nm: String) -> void:
	var z = Marker2D.new()
	z.set_script(ZoneScript)
	z.name = nm
	z.position = pos
	z.area = area
	z.scientists = counts[0]
	z.soldiers = counts[1]
	z.flamers = counts[2]
	z.heavies = counts[3]
	z.turrets = counts[4]
	z.tier = tier
	zones.add_child(z)
	_own(z)

func _add_feature(feats: Node, kind: String, pos: Vector2, nm: String, extra := {}) -> void:
	var f = Node2D.new()
	f.set_script(FeatureScript)
	f.name = nm
	f.position = pos
	f.kind = kind
	for k in extra:
		f.set(k, extra[k])
	feats.add_child(f)
	_own(f)

func _counts(t: int, total: int, armory: bool) -> Array:
	var armed := clampf(0.06 * (t - 1), 0.0, 0.35)
	if armory:
		armed = 0.6
	var n_armed := int(total * armed)
	var heavies := int(n_armed * 0.1) if t >= 4 else 0
	var flamers := int(n_armed * 0.2) if t >= 3 else 0
	var soldiers := n_armed - heavies - flamers
	soldiers = mini(soldiers, (8 if armory else 4 + t))
	flamers = mini(flamers, 2)
	heavies = mini(heavies, 2 if armory else 1)
	var sci := maxi(0, total - soldiers - flamers - heavies)
	return [sci, soldiers, flamers, heavies]

func generate(seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	gw = grid_w
	gh = grid_h
	solid.resize(gw * gh)
	solid.fill(1)
	var res := PackedByteArray()
	res.resize(gw * gh)
	res.fill(0)

	rooms.clear()
	var tries := 0
	while rooms.size() < room_count and tries < 900:
		tries += 1
		var rw := rng.randi_range(16, 30)
		var rh := rng.randi_range(11, 18)
		var r := Rect2i(rng.randi_range(4, gw - rw - 4), rng.randi_range(4, gh - rh - 4), rw, rh)
		var ok := true
		for o in rooms:
			if (o as Rect2i).grow(6).intersects(r):
				ok = false
				break
		if ok:
			rooms.append(r)
	var n := rooms.size()
	var shapes: Array[int] = []
	for r in rooms:
		var sh := rng.randi_range(0, 2)
		shapes.append(sh)
		_carve_room(r, sh)

	var cent: Array[Vector2i] = []
	for r in rooms:
		cent.append(r.get_center())
	var adj: Array = []
	var pipes: Array = []
	for i in n:
		adj.append([])
	var in_tree := PackedByteArray()
	in_tree.resize(n)
	in_tree[0] = 1
	for step in n - 1:
		var best_d := INF
		var ba := -1
		var bb := -1
		for a in n:
			if in_tree[a] == 1:
				for b in n:
					if in_tree[b] == 0:
						var d := Vector2(cent[a]).distance_to(Vector2(cent[b]))
						if d < best_d:
							best_d = d
							ba = a
							bb = b
		in_tree[bb] = 1
		adj[ba].append(bb)
		adj[bb].append(ba)
		pipes.append([ba, bb, _carve_pipe(cent[ba], cent[bb], [6, 6, 7, 8][rng.randi_range(0, 3)] if pipe_width <= 6 else pipe_width, rng, res)])
	for a in n:
		if rng.randf() < 0.45:
			var best_d2 := INF
			var bj := -1
			for b in n:
				if b != a and not adj[a].has(b):
					var d2 := Vector2(cent[a]).distance_to(Vector2(cent[b]))
					if d2 < best_d2:
						best_d2 = d2
						bj = b
			if bj >= 0:
				adj[a].append(bj)
				adj[bj].append(a)
				pipes.append([a, bj, _carve_pipe(cent[a], cent[bj], pipe_width, rng, res)])

	var start_i := 0
	var best_s := INF
	for i in n:
		var sc := cent[i].x + cent[i].y * 0.3
		if sc < best_s:
			best_s = sc
			start_i = i
	var tier: Array[int] = []
	tier.resize(n)
	tier.fill(-1)
	tier[start_i] = 0
	var q: Array[int] = [start_i]
	var qi := 0
	while qi < q.size():
		var cur := q[qi]
		qi += 1
		for nb in adj[cur]:
			if tier[nb] < 0:
				tier[nb] = tier[cur] + 1
				q.append(nb)

	for i in n:
		var r2 := rooms[i]
		for t in rng.randi_range(1, 4):
			var sw := rng.randi_range(5, 9)
			if r2.size.x - 8 - sw < 1 or r2.size.y - 9 < 1:
				continue
			var sx := rng.randi_range(r2.position.x + 4, r2.end.x - 4 - sw)
			var sy := rng.randi_range(r2.position.y + 4, r2.end.y - 5)
			if _area_free(res, sx - 3, sy - 3, sx + sw + 3, sy + 4):
				for x in range(sx, sx + sw):
					solid[sy * gw + x] = 1
				_mark(res, sx - 3, sy - 3, sx + sw + 3, sy + 4)
		for t in rng.randi_range(0, 3):
			var tx := rng.randi_range(r2.position.x + 3, r2.end.x - 5)
			var ty := rng.randi_range(r2.position.y, r2.end.y - 1)
			var cy := ceil_y(tx * TILE + 32.0, ty * TILE + 32.0)
			if cy > 0.0:
				var top := int(cy / TILE)
				var ln := rng.randi_range(2, 4)
				if _area_free(res, tx - 1, top, tx + 3, top + ln + 1):
					for yy in range(top, top + ln):
						solid[yy * gw + tx] = 1
						solid[yy * gw + tx + 1] = 1
					_mark(res, tx - 2, top, tx + 4, top + ln + 2)

	_paint()

	var zones := get_node_or_null("Zones")
	var feats := get_node_or_null("Features")
	if zones == null:
		zones = Node2D.new()
		zones.name = "Zones"
		add_child(zones)
		_own(zones)
	if feats == null:
		feats = Node2D.new()
		feats.name = "Features"
		add_child(feats)
		_own(feats)
	_clear_children(zones)
	_clear_children(feats)

	var order: Array[int] = []
	for i in n:
		if i != start_i:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return tier[a] > tier[b])
	var boss_rooms: Array[int] = []
	for i in mini(3, order.size()):
		boss_rooms.append(order[i])
	boss_rooms.reverse()
	var rest: Array[int] = []
	for i in order:
		if not boss_rooms.has(i):
			rest.append(i)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var role := {}
	var idx := 0
	for kind in ["nest", "nest", "nest", "altar", "altar", "altar", "reactor", "reactor", "armory", "armory"]:
		if idx < rest.size():
			role[rest[idx]] = kind
			idx += 1

	for i in n:
		var r3 := rooms[i]
		var c_px := Vector2(cent[i]) * TILE + Vector2(TILE, TILE) * 0.5
		var fl := floor_y(c_px.x, c_px.y)
		if fl < 0.0:
			fl = float(r3.end.y * TILE)
		var t := maxi(tier[i], 0)
		var total := int(clampf(r3.size.x * r3.size.y * humans_per_cell, 14.0, 90.0))
		if i == start_i:
			total = 0
		if boss_rooms.has(i):
			total = int(total * 0.3)
		var is_armory: bool = role.get(i, "") == "armory"
		for sidx in 3:
			var frac := (sidx + 0.5) / 3.0 - 0.5
			var sub_center := Vector2(c_px.x + frac * r3.size.x * TILE * 0.8, c_px.y)
			var sub_area := Vector2(r3.size.x * TILE * 0.8 / 3.0 * 1.1, r3.size.y * TILE * 0.7)
			var cnt := _counts(t, int(total / 3.0), is_armory)
			var tur := 0 if (t < 1 or i == start_i or sidx != 1) else mini(t, 4)
			_add_zone(zones, sub_center, sub_area, [cnt[0], cnt[1], cnt[2], cnt[3], tur], t, "Zone_%d_%d" % [i, sidx])

		var lamp_col := Color(1.0, 0.85, 0.6) if i % 2 == 0 else Color(0.6, 0.75, 1.0)
		var cl := ceil_y(c_px.x, c_px.y)
		if cl < 0.0:
			cl = float(r3.position.y * TILE)
		_add_feature(feats, "lamp", Vector2(c_px.x - r3.size.x * 10.0, cl + 60.0), "Lamp_%da" % i, {"lamp_color": lamp_col})
		_add_feature(feats, "lamp", Vector2(c_px.x + r3.size.x * 10.0, cl + 60.0), "Lamp_%db" % i, {"lamp_color": lamp_col})
		for d in rng.randi_range(2, 3):
			var dx := c_px.x + rng.randf_range(-r3.size.x * 0.4, r3.size.x * 0.4) * TILE
			var fy := floor_y(dx, c_px.y)
			if fy > 0.0:
				_add_feature(feats, ["desk", "crates", "rack", "tank"][rng.randi_range(0, 3)], Vector2(dx, fy), "Decor_%d_%d" % [i, d])
		var rk: String = role.get(i, "")
		if rk != "":
			_add_feature(feats, rk, Vector2(c_px.x, fl), "%s_%d" % [rk.capitalize(), i])
		var bi := boss_rooms.find(i)
		if bi >= 0:
			_add_feature(feats, "boss", Vector2(c_px.x + r3.size.x * 8.0, fl), "Boss_%d" % bi, {"boss_type": bi})

	var zc := 0
	for pp in pipes:
		var pa: int = pp[0]
		var pb: int = pp[1]
		var pts: Array = pp[2]
		var tp := maxi(mini(tier[pa], tier[pb]), 0)
		for k in pts.size() - 1:
			var s0 := Vector2(pts[k])
			var s1 := Vector2(pts[k + 1])
			if absf(s0.y - s1.y) > 0.5:
				continue
			var seg_len := s0.distance_to(s1)
			var steps := int(seg_len / 12.0)
			for st in steps:
				var f := (st + 0.5) / maxf(float(steps), 1.0)
				var px := s0.lerp(s1, f) * TILE + Vector2(TILE, TILE) * 0.5
				var cnt2 := _counts(tp, pipe_humans, false)
				_add_zone(zones, px, Vector2(TILE * 10.0, TILE * 5.0), [cnt2[0], cnt2[1], cnt2[2], cnt2[3], 0], tp, "PipeZone_%d" % zc)
				zc += 1

	var ps_node := get_node_or_null("PlayerStart") as Marker2D
	if ps_node == null:
		ps_node = Marker2D.new()
		ps_node.name = "PlayerStart"
		add_child(ps_node)
		_own(ps_node)
	var sc_px := Vector2(cent[start_i]) * TILE + Vector2(TILE, TILE) * 0.5
	var sf := floor_y(sc_px.x, sc_px.y)
	ps_node.position = Vector2(sc_px.x, (sf if sf > 0.0 else sc_px.y) - 100.0)
	start_pos = ps_node.global_position if ps_node.is_inside_tree() else ps_node.position
