extends RefCounted

static func _radial(size: int, c0: Color, c1: Color, c2: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c2)
	g.add_point(0.5, c1)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

static func soft_tex(size: int) -> GradientTexture2D:
	return _radial(size, Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0))

static func light_tex(size: int) -> GradientTexture2D:
	return _radial(size, Color.WHITE, Color(0.3, 0.3, 0.3, 1), Color.BLACK)
