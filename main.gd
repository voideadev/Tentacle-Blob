extends Node2D

const Util = preload("res://util.gd")
const TurretScript = preload("res://turret.gd")
const BossScript = preload("res://boss.gd")
const RingFx = preload("res://ring_fx.gd")
const BlobRenderer = preload("res://blob_renderer.gd")
const Mutations = preload("res://mutations.gd")
const Minimap = preload("res://minimap.gd")
const Meta = preload("res://meta.gd")

enum { MENU, PLAY, PICK, OVER }
@export var camera_zoom_mult := 0.62

var state := MENU
var pending_picks := 0
var rerolls := 1
var bosses_killed := 0
var boss
var dmg_vis := 0.0
var last_health := 100.0
var banner_t := 0.0
var cam_pos := Vector2.ZERO
var hud_t := 0.0
var reveal_t := 0.0
var blood_active := 0

var blob_rect: TextureRect
var post_rect: ColorRect
var health_bar: ProgressBar
var xp_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var mut_label: Label
var grab_label: Label
var unlocked := 1
var banner: Label
var minimap
var dash_btn: TouchScreenButton
var dash_label: Label
var jump_btn: TouchScreenButton
var jump_label: Label
var pick_layer: CanvasLayer
var pick_box: HBoxContainer
var reroll_btn: Button
var over_layer: CanvasLayer
var over_label: Label
var menu_layer: CanvasLayer
var menu_info: Label
var menu_grid: GridContainer

@onready var world = $World
@onready var crowd = $Crowd
@onready var actors: Node2D = $Actors
@onready var player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var label: Label = $HUD/ScoreLabel

func _ready() -> void:
	randomize()
	Meta.load_data()
	var cm := CanvasModulate.new()
	cm.color = Color(0.55, 0.55, 0.65)
	add_child(cm)
	var cam: Camera2D = player.get_node("Camera2D")
	_setup_creature_layer(cam)
	_setup_post()
	_setup_hud_extras()
	_setup_overlays()
	player.killed.connect(_on_killed)
	player.blood.connect(_spawn_blood)
	player.shockwave.connect(_spawn_ring)
	player.health_changed.connect(_on_health)
	player.xp_changed.connect(_on_xp)
	player.level_up.connect(_on_level_up)
	player.died.connect(_on_died)
	crowd.killed.connect(player.on_crowd_kill)
	crowd.turret_requested.connect(_spawn_turret)
	crowd.setup(world, player, cam)
	for f in get_tree().get_nodes_in_group("features"):
		f.triggered.connect(_on_feature)
	player.teleport(world.start_pos)
	cam_pos = world.start_pos
	cam.global_position = cam_pos
	minimap.setup(world, player)
	minimap.reveal(world.start_pos, 16)
	_show_menu()

func _show_menu() -> void:
	state = MENU
	get_tree().paused = true
	_refresh_menu()
	menu_layer.visible = true

func _refresh_menu() -> void:
	menu_info.text = "ADN: %d        Mejor biomasa: %d" % [Meta.dna, Meta.best_depth]
	for c in menu_grid.get_children():
		c.queue_free()
	for id in Meta.DATA:
		var m: Dictionary = Meta.DATA[id]
		var lv := Meta.level(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(390, 104)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var price := "MAX" if lv >= int(m["max"]) else "Coste: %d ADN" % Meta.cost(id)
		b.text = "%s  [%d/%d]\n%s\n%s" % [m["name"], lv, m["max"], m["desc"], price]
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = not Meta.can_buy(id)
		b.pressed.connect(_on_buy.bind(id))
		menu_grid.add_child(b)

func _on_buy(id: String) -> void:
	Meta.buy(id)
	_refresh_menu()

func _begin_run() -> void:
	menu_layer.visible = false
	_apply_meta()
	state = PLAY
	get_tree().paused = false
	_show_banner("SALTO (Shift / botón) para lanzarte a otra pared")

func _apply_meta() -> void:
	player.max_health += 10.0 * Meta.level("hp")
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.xp_mult = 1.0 + 0.08 * Meta.level("xp")
	player.armor_mult *= pow(0.95, Meta.level("armor"))
	player.dash_max += Meta.level("dash")
	player.dash_charges = player.dash_max
	player.extra_tentacles += Meta.level("tent")
	for i in Meta.level("mut"):
		var opts := Mutations.roll(player.mut_stacks, 1)
		if opts.size() > 0:
			player.apply_mutation(opts[0])
	if Meta.level("egg") > 0:
		player.apply_mutation("egg")
	rerolls = 1 + Meta.level("reroll")

func _mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m

func _spawn_turret(pos: Vector2) -> void:
	var t := TurretScript.new()
	t.position = pos
	t.hp_mult = 1.0
	t.dmg_mult = 1.0
	actors.add_child(t)

func _on_feature(kind: String, node: Node) -> void:
	match kind:
		"altar":
			pending_picks += 1
			_show_banner("ALTAR: MUTACIÓN GRATIS")
			call_deferred("_try_pick")
		"boss":
			var b = BossScript.new()
			b.btype = node.boss_type
			b.hp_mult = 1.0 + 0.35 * node.boss_type
			b.dmg_mult = 1.0 + 0.2 * node.boss_type
			b.position = node.global_position + Vector2(0, -4)
			actors.add_child(b)
			b.defeated.connect(_on_boss_defeated)
			boss = b
			_show_banner("¡%s!" % b.boss_name())

func _on_boss_defeated() -> void:
	bosses_killed += 1
	_show_banner("¡JEFE DERROTADO!")
	player.heal(player.max_health * 0.5)
	player.biomass += 30.0
	pending_picks += 1
	call_deferred("_try_pick")
	if bosses_killed >= 3:
		call_deferred("_victory")

func _setup_creature_layer(cam: Camera2D) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	blob_rect = TextureRect.new()
	blob_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blob_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blob_rect.stretch_mode = TextureRect.STRETCH_SCALE
	blob_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blob_rect.material = _mat("res://blob.gdshader")
	layer.add_child(blob_rect)
	var sv := SubViewport.new()
	sv.size = Vector2i(get_viewport().get_visible_rect().size * 1.5)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var bgl := CanvasLayer.new()
	bgl.layer = -100
	sv.add_child(bgl)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgl.add_child(black)
	var rend := BlobRenderer.new()
	rend.player = player
	rend.main_cam = cam
	rend.sv = sv
	rend.rect = blob_rect
	sv.add_child(rend)
	blob_rect.texture = sv.get_texture()

func _setup_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.material = _mat("res://vignette.gdshader")
	layer.add_child(post_rect)

func _setup_hud_extras() -> void:
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(24, 64)
	health_bar.size = Vector2(260, 18)
	health_bar.show_percentage = false
	health_bar.modulate = Color(1.0, 0.35, 0.35)
	hud.add_child(health_bar)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(24, 88)
	xp_bar.size = Vector2(260, 10)
	xp_bar.show_percentage = false
	xp_bar.modulate = Color(0.5, 0.9, 1.0)
	hud.add_child(xp_bar)
	mut_label = Label.new()
	grab_label = Label.new()
	grab_label.position = Vector2(24, 104)
	grab_label.size = Vector2(900, 28)
	grab_label.add_theme_font_size_override("font_size", 18)
	grab_label.modulate = Color(1.0, 0.9, 0.5, 0.95)
	hud.add_child(grab_label)
	mut_label.position = Vector2(24, 134)
	mut_label.size = Vector2(420, 120)
	mut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mut_label.add_theme_font_size_override("font_size", 16)
	mut_label.modulate = Color(1, 1, 1, 0.8)
	hud.add_child(mut_label)
	banner = Label.new()
	banner.add_theme_font_size_override("font_size", 44)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(1000, 60)
	banner.modulate.a = 0.0
	hud.add_child(banner)
	boss_label = Label.new()
	boss_label.add_theme_font_size_override("font_size", 22)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.size = Vector2(600, 30)
	boss_label.visible = false
	hud.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.size = Vector2(600, 18)
	boss_bar.show_percentage = false
	boss_bar.modulate = Color(1.0, 0.3, 0.3)
	boss_bar.visible = false
	hud.add_child(boss_bar)
	minimap = Minimap.new()
	minimap.size = Vector2(240, 150)
	hud.add_child(minimap)
	dash_btn = TouchScreenButton.new()
	dash_btn.texture_normal = Util.soft_tex(160)
	var cs := CircleShape2D.new()
	cs.radius = 80.0
	dash_btn.shape = cs
	dash_btn.action = "dash"
	dash_btn.modulate = Color(1.0, 0.3, 0.3, 0.8)
	hud.add_child(dash_btn)
	dash_label = Label.new()
	dash_label.text = "LUNGE"
	dash_label.add_theme_font_size_override("font_size", 22)
	dash_label.size = Vector2(160, 70)
	dash_label.position = Vector2(0, 50)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_btn.add_child(dash_label)
	jump_btn = TouchScreenButton.new()
	jump_btn.texture_normal = Util.soft_tex(140)
	var cs2 := CircleShape2D.new()
	cs2.radius = 70.0
	jump_btn.shape = cs2
	jump_btn.action = "jump"
	jump_btn.modulate = Color(0.4, 0.8, 1.0, 0.8)
	hud.add_child(jump_btn)
	jump_label = Label.new()
	jump_label.text = "SALTO"
	jump_label.add_theme_font_size_override("font_size", 20)
	jump_label.size = Vector2(140, 40)
	jump_label.position = Vector2(0, 50)
	jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jump_btn.add_child(jump_label)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()

func _layout_hud() -> void:
	var s := get_viewport().get_visible_rect().size
	dash_btn.position = Vector2(s.x - 220.0, s.y - 240.0)
	jump_btn.position = Vector2(s.x - 400.0, s.y - 180.0)
	minimap.position = Vector2(s.x - 264.0, 16.0)
	banner.position = Vector2((s.x - 1000.0) / 2.0, 110.0)
	boss_label.position = Vector2((s.x - 600.0) / 2.0, 14.0)
	boss_bar.position = Vector2((s.x - 600.0) / 2.0, 46.0)

func _setup_overlays() -> void:
	pick_layer = CanvasLayer.new()
	pick_layer.layer = 20
	pick_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pick_layer.visible = false
	add_child(pick_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pick_layer.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	var title := Label.new()
	title.text = "MUTACIÓN"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	pick_box = HBoxContainer.new()
	pick_box.add_theme_constant_override("separation", 24)
	vb.add_child(pick_box)
	reroll_btn = Button.new()
	reroll_btn.custom_minimum_size = Vector2(300, 64)
	reroll_btn.add_theme_font_size_override("font_size", 22)
	reroll_btn.pressed.connect(_on_reroll)
	vb.add_child(reroll_btn)

	over_layer = CanvasLayer.new()
	over_layer.layer = 21
	over_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	over_layer.visible = false
	add_child(over_layer)
	var dim2 := ColorRect.new()
	dim2.color = Color(0.2, 0, 0, 0.85)
	dim2.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(dim2)
	var c2 := CenterContainer.new()
	c2.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(c2)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 24)
	c2.add_child(v2)
	over_label = Label.new()
	over_label.add_theme_font_size_override("font_size", 32)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(over_label)
	var again := Button.new()
	again.text = "Tienda y nueva infestación"
	again.custom_minimum_size = Vector2(380, 90)
	again.add_theme_font_size_override("font_size", 26)
	again.pressed.connect(_restart)
	v2.add_child(again)

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 22
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_layer.visible = false
	add_child(menu_layer)
	var dim3 := ColorRect.new()
	dim3.color = Color(0.03, 0.0, 0.05, 0.92)
	dim3.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(dim3)
	var c3 := CenterContainer.new()
	c3.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(c3)
	var v3 := VBoxContainer.new()
	v3.add_theme_constant_override("separation", 12)
	c3.add_child(v3)
	var t3 := Label.new()
	t3.text = "TENTACLE BLOB"
	t3.add_theme_font_size_override("font_size", 48)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t3.modulate = Color(1.0, 0.3, 0.3)
	v3.add_child(t3)
	menu_info = Label.new()
	menu_info.add_theme_font_size_override("font_size", 24)
	menu_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v3.add_child(menu_info)
	menu_grid = GridContainer.new()
	menu_grid.columns = 3
	menu_grid.add_theme_constant_override("h_separation", 12)
	menu_grid.add_theme_constant_override("v_separation", 10)
	v3.add_child(menu_grid)
	var go := Button.new()
	go.text = "COMENZAR INFESTACIÓN"
	go.custom_minimum_size = Vector2(420, 84)
	go.add_theme_font_size_override("font_size", 30)
	go.pressed.connect(_begin_run)
	v3.add_child(go)

func _show_banner(txt: String) -> void:
	banner.text = txt
	banner.modulate.a = 1.0
	banner_t = 3.0

func _update_hud() -> void:
	label.text = "Biomasa %d    Tamaño ×%.2f    Humanos: %d    Jefes %d/3" % [
		int(player.biomass), player.size_scale, crowd.alive_count, bosses_killed]
	var names := ["Científicos", "Soldados", "Lanzallamas", "Pesados"]
	var can: Array[String] = []
	var next_txt := ""
	for k in 4:
		var need: float = crowd.KIND_POWER[k]
		if player.grab_cap >= need:
			can.append(names[k])
		elif next_txt == "":
			next_txt = "   |   Siguiente: %s (tamaño ×%.2f)" % [names[k], (need - player.grab_base) / player.grab_per_size]
	grab_label.text = "Devoras: " + ", ".join(can) + next_txt
	if can.size() > unlocked:
		unlocked = can.size()
		_show_banner("¡YA PUEDES DEVORAR %s!" % names[can.size() - 1].to_upper())
	var parts: Array[String] = []
	for id in player.mut_stacks:
		var nm: String = Mutations.DATA[id]["name"]
		parts.append("%s ×%d" % [nm, player.mut_stacks[id]])
	mut_label.text = "  ·  ".join(parts)

func _on_killed(_is_human: bool) -> void:
	pass

func _on_health(h: float, m: float) -> void:
	health_bar.max_value = m
	health_bar.value = h
	if h < last_health - 0.01:
		dmg_vis = maxf(dmg_vis, 0.6)
	last_health = h

func _on_xp(v: float, need: float) -> void:
	xp_bar.max_value = need
	xp_bar.value = v

func _on_level_up() -> void:
	pending_picks += 1
	if state == PLAY:
		call_deferred("_try_pick")

func _try_pick() -> void:
	if pending_picks <= 0 or state != PLAY:
		return
	state = PICK
	get_tree().paused = true
	_fill_pick()
	pick_layer.visible = true

func _fill_pick() -> void:
	for c in pick_box.get_children():
		c.queue_free()
	var opts := Mutations.roll(player.mut_stacks, 3)
	for id in opts:
		var m: Dictionary = Mutations.DATA[id]
		var cu: int = player.mut_stacks.get(id, 0)
		var b := Button.new()
		b.custom_minimum_size = Vector2(330, 240)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s\n\n%s\n\n(nivel %d/%d)" % [m["name"], m["desc"], cu + 1, m["max"]]
		b.add_theme_font_size_override("font_size", 22)
		if int(m["w"]) <= 4:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		b.pressed.connect(_on_pick.bind(id))
		pick_box.add_child(b)
	reroll_btn.text = "Relanzar opciones (%d)" % rerolls
	reroll_btn.disabled = rerolls <= 0

func _on_reroll() -> void:
	if rerolls <= 0:
		return
	rerolls -= 1
	_fill_pick()

func _on_pick(id: String) -> void:
	player.apply_mutation(id)
	pending_picks -= 1
	pick_layer.visible = false
	state = PLAY
	get_tree().paused = false
	_update_hud()
	if pending_picks > 0:
		call_deferred("_try_pick")

func _end_run(title: String, bonus: int) -> void:
	state = OVER
	var base := int(player.biomass * 0.6) + bosses_killed * 40 + bonus
	var gain := int(base * (1.0 + 0.2 * Meta.level("dna")))
	Meta.dna += gain
	Meta.best_depth = maxi(Meta.best_depth, int(player.biomass))
	Meta.save_data()
	over_label.text = "%s\n\nBiomasa: %d   Tamaño ×%.2f\nHumanos devorados: %d\nJefes: %d/3\n\n+%d ADN  (total %d)" % [
		title, int(player.biomass), player.size_scale, player.eaten, bosses_killed, gain, Meta.dna]
	over_layer.visible = true
	get_tree().paused = true

func _on_died() -> void:
	dmg_vis = 1.5
	_end_run("LA INFESTACIÓN TERMINA", 0)

func _victory() -> void:
	_end_run("¡ERES EL COLOSO! La instalación es tuya.", 200)

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _spawn_ring(pos: Vector2, r: float) -> void:
	var fx := RingFx.new()
	fx.position = pos
	fx.max_r = r
	add_child(fx)

func _spawn_blood(pos: Vector2) -> void:
	if blood_active >= 14:
		return
	blood_active += 1
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 3
	p.light_mask = 2
	p.texture = Util.soft_tex(16)
	p.amount = 24
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 1000)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = Color(0.7, 0.03, 0.07)
	p.emitting = true
	add_child(p)
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		blood_active -= 1
		p.queue_free())

func _process(delta: float) -> void:
	var pp: Vector2 = player.global_position
	var cam: Camera2D = player.get_node("Camera2D")
	cam_pos = cam_pos.lerp(pp, 1.0 - exp(-8.0 * delta))
	cam.global_position = cam_pos
	var tz := clampf(camera_zoom_mult * 1.05 / pow(player.size_scale, 0.55), 0.2, 1.5)
	cam.zoom = cam.zoom.lerp(Vector2(tz, tz), 1.0 - exp(-2.5 * delta))

	dmg_vis = maxf(0.0, dmg_vis - delta * 1.5)
	(post_rect.material as ShaderMaterial).set_shader_parameter("damage", dmg_vis)
	if banner_t > 0.0:
		banner_t -= delta
		banner.modulate.a = clampf(banner_t, 0.0, 1.0)

	hud_t += delta
	if hud_t > 0.2:
		hud_t = 0.0
		_update_hud()
		minimap.queue_redraw()
	reveal_t += delta
	if reveal_t > 0.3:
		reveal_t = 0.0
		minimap.reveal(pp, 13)
	dash_label.text = "LUNGE\n×%d" % player.dash_charges

	if boss != null and is_instance_valid(boss) and not boss.dead:
		boss_bar.visible = boss.active
		boss_label.visible = boss.active
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
		boss_label.text = boss.boss_name() + ("  (ESCUDO)" if boss.invuln else "")
	else:
		boss_bar.visible = false
		boss_label.visible = false
