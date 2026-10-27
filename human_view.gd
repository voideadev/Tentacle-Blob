extends Node2D

const Humanoid = preload("res://humanoid.gd")
var crowd
var idx := -1
var vindex := 0
var hm
var time := randf() * 10.0

func _ready() -> void:
	light_mask = 2
	modulate = Color(1.3, 1.3, 1.3)
	visible = false

func assign(i: int) -> void:
	idx = i
	var k: int = crowd.kind[i]
	hm = Humanoid.new()
	hm.setup(1.15, 6 if k == 3 else k, crowd.pos[i])
	global_position = crowd.pos[i]
	visible = true

func release() -> void:
	idx = -1
	visible = false

func _physics_process(delta: float) -> void:
	if idx < 0:
		return
	if crowd.alive[idx] == 0:
		release()
		return
	time += delta
	var target: Vector2 = crowd.pos[idx]
	global_position = global_position.move_toward(target, maxf(60.0, global_position.distance_to(target) * 0.6))
	var st: int = crowd.state[idx]
	var k: int = crowd.kind[idx]
	var mode := Humanoid.WALK
	var fear := 0.0
	var tilt := 0.0
	match st:
		1:
			mode = Humanoid.PANIC
			fear = 1.0
		2:
			mode = Humanoid.FLAME if k == 2 else Humanoid.AIM
			fear = 0.3
		3:
			mode = Humanoid.DANGLE
			fear = 1.0
			tilt = sin(time * 3.0) * 0.7 + sin(time * 5.3) * 0.4
	if crowd.recoil[idx] > 0.0:
		hm.recoil = 1.0
		crowd.recoil[idx] = 0.0
	hm.tilt = tilt
	hm.flaming = crowd.flaming[idx] == 1
	hm.update(self, crowd.vel[idx], delta, mode, crowd.aim[idx], fear, crowd.grounded[idx] == 1)

func _process(_d: float) -> void:
	if idx >= 0:
		queue_redraw()

func _draw() -> void:
	if idx >= 0 and hm != null:
		hm.draw(self)
