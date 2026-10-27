extends Node2D

const Util = preload("res://util.gd")

var player
var main_cam: Camera2D
var sv: SubViewport
var rect: TextureRect
var res_scale := 1.5
var tex: Texture2D
var cam: Camera2D

func _ready() -> void:
	process_priority = 100
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	tex = Util.soft_tex(128)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = false
	add_child(cam)
	cam.make_current()

func _process(_delta: float) -> void:
	if player == null or main_cam == null:
		return
	var vr := main_cam.get_viewport().get_visible_rect().size
	var sz := Vector2i((vr * res_scale).round())
	if sv.size != sz:
		sv.size = sz
	cam.zoom = main_cam.zoom * res_scale
	cam.global_position = main_cam.get_screen_center_position()
	var sm := rect.material as ShaderMaterial
	sm.set_shader_parameter("view_size", vr)
	sm.set_shader_parameter("zoom", main_cam.zoom.x)
	sm.set_shader_parameter("cam_pos", cam.global_position)
	sm.set_shader_parameter("origin", player.global_position)
	sm.set_shader_parameter("energy", player.energy)
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	for p in player.body_parts:
		_blob(p, 0.55)
	for p in player.tent_parts:
		_blob(p, 0.75)

func _blob(p: Vector3, a: float) -> void:
	var r := p.z * 2.2
	draw_texture_rect(tex, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, Color(1, 1, 1, a))
