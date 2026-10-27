extends Control

var world
var player
var img: Image
var tex: ImageTexture
var explored := PackedByteArray()
var dirty := false
var gw := 0
var gh := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(w, p) -> void:
	world = w
	player = p
	gw = w.gw
	gh = w.gh
	img = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	tex = ImageTexture.create_from_image(img)
	explored.resize(gw * gh)
	explored.fill(0)

func reveal(c: Vector2, radius: int) -> void:
	if img == null:
		return
	var cx := int(c.x / 64.0)
	var cy := int(c.y / 64.0)
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= gw or y >= gh:
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) > radius * radius:
				continue
			var i := y * gw + x
			if explored[i] == 0:
				explored[i] = 1
				img.set_pixel(x, y, Color(0.62, 0.68, 0.88, 1.0) if world.solid[i] == 1 else Color(0.08, 0.09, 0.14, 0.9))
				dirty = true

func _process(_d: float) -> void:
	if dirty:
		tex.update(img)
		dirty = false

func _is_explored(p: Vector2) -> bool:
	var x := int(p.x / 64.0)
	var y := int(p.y / 64.0)
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return false
	return explored[y * gw + x] == 1

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	if img == null:
		return
	var s := minf(size.x / gw, size.y / gh)
	var off := (size - Vector2(gw, gh) * s) / 2.0
	draw_texture_rect(tex, Rect2(off, Vector2(gw, gh) * s), false)
	for f in get_tree().get_nodes_in_group("features"):
		if not is_instance_valid(f) or not _is_explored(f.global_position):
			continue
		var col := Color(0, 0, 0, 0)
		match f.kind:
			"altar":
				col = Color(1.0, 0.85, 0.3)
			"nest":
				col = Color(0.4, 1.0, 0.5)
			"boss":
				col = Color(1.0, 0.25, 0.25)
			"reactor":
				col = Color(1.0, 0.5, 0.2)
		if col.a > 0.0:
			draw_circle(off + f.global_position / 64.0 * s, 3.5, col)
	if is_instance_valid(player):
		draw_circle(off + player.global_position / 64.0 * s, 4.0, Color(1.0, 0.15, 0.2))
