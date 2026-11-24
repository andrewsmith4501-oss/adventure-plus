extends Node3D
## The Mender: a third-person hero that walks, sprints, climbs any wall,
## glides from heights and swims. Also owns the orbiting camera.

const World = preload("res://scripts/world.gd")
const EYE := 1.62

var world: World
var game  # game.gd (left untyped to avoid a preload cycle)
var camera: Camera3D

# Physics body (feet position, axis-aligned box).
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var hw := 0.3
var h := 1.8
var grounded := false

# State.
var yaw := PI * 0.75
var hp := 10
var stamina := 100.0
var exhausted := false
var stam_delay := 0.0
var mode := "walk"  # walk, climb, mantle, glide
var wall := Vector3.ZERO
var mantle_t := 0.0
var leap_t := 0.0
var invuln := 0.0
var regen_t := 0.0
var dead := false
var attack_cd := 0.0
var swing_t := 0.0
var in_water := false
var glide_start_y := 0.0
var glide_dist := 0.0

# Camera.
var cam_yaw := PI * 0.75
var cam_pitch := -0.25
var cam_dist := 4.6
var cam_cur := 4.6
var first_person := false

var held: Node3D
var glider: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _walk_phase := 0.0


func _ready() -> void:
	_build_model()


# ---------------------------------------------------------------- model

func _box(size: Vector3, color: Color, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = at
	parent.add_child(mi)
	return mi


func _limb(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	return n


func _build_model() -> void:
	var tunic := Color("2f8f83")
	var skin := Color("e8b48a")
	var hair := Color("5a3a22")
	var leather := Color("6b4a2b")
	_hip_l = _limb(Vector3(-0.12, 0.8, 0))
	_hip_r = _limb(Vector3(0.12, 0.8, 0))
	for hp_node in [_hip_l, _hip_r]:
		_box(Vector3(0.17, 0.72, 0.19), Color("3b4a5c"), Vector3(0, -0.36, 0), hp_node)
		_box(Vector3(0.19, 0.12, 0.26), Color("4a3424"), Vector3(0, -0.74, 0.03), hp_node)
	_box(Vector3(0.46, 0.58, 0.27), tunic, Vector3(0, 1.09, 0), self)
	_box(Vector3(0.48, 0.08, 0.29), leather, Vector3(0, 0.83, 0), self)
	_box(Vector3(0.5, 0.1, 0.31), Color("f2b84b"), Vector3(0, 1.36, 0), self)
	_box(Vector3(0.1, 0.32, 0.04), Color("f2b84b"), Vector3(0.14, 1.2, -0.17), self)
	_box(Vector3(0.34, 0.34, 0.32), skin, Vector3(0, 1.6, 0), self)
	_box(Vector3(0.37, 0.12, 0.35), hair, Vector3(0, 1.79, 0), self)
	_box(Vector3(0.37, 0.22, 0.07), hair, Vector3(0, 1.66, -0.15), self)
	_box(Vector3(0.05, 0.06, 0.02), Color("1d1d1d"), Vector3(-0.08, 1.62, 0.165), self)
	_box(Vector3(0.05, 0.06, 0.02), Color("1d1d1d"), Vector3(0.08, 1.62, 0.165), self)
	_box(Vector3(0.34, 0.4, 0.16), Color("8a6a3e"), Vector3(0, 1.12, -0.21), self)
	_box(Vector3(0.36, 0.08, 0.18), leather, Vector3(0, 1.33, -0.21), self)
	_sh_l = _limb(Vector3(-0.31, 1.34, 0))
	_sh_r = _limb(Vector3(0.31, 1.34, 0))
	for sh in [_sh_l, _sh_r]:
		_box(Vector3(0.13, 0.56, 0.15), tunic, Vector3(0, -0.26, 0), sh)
		_box(Vector3(0.12, 0.12, 0.12), skin, Vector3(0, -0.58, 0), sh)
	held = Node3D.new()
	held.position = Vector3(0, -0.6, 0.05)
	held.rotation.y = PI
	_sh_r.add_child(held)

	glider = Node3D.new()
	glider.position = Vector3(0, 2.55, 0.05)
	glider.visible = false
	add_child(glider)
	_box(Vector3(2.6, 0.04, 1.1), Color("5fbf4f"), Vector3.ZERO, glider)
	_box(Vector3(2.62, 0.05, 0.2), Color("f2b84b"), Vector3.ZERO, glider)
	for sx in [-0.35, 0.35]:
		_box(Vector3(0.02, 0.75, 0.02), Color("4a3424"), Vector3(sx, -0.38, 0), glider)


## Shows the selected item in the hero's right hand.
func set_held(item: Dictionary) -> void:
	for c in held.get_children():
		c.queue_free()
	if item.is_empty():
		return
	var col: Color = item["color"]
	if item.has("block"):
		_box(Vector3(0.15, 0.15, 0.15), col, Vector3.ZERO, held)
	elif item.has("damage") or item.has("pick") or item["name"] == "Stick":
		var tool := Node3D.new()
		tool.rotation.x = -0.5
		held.add_child(tool)
		var handle := _box(Vector3(0.04, 0.04, 0.2), Color("7a5a34"), Vector3(0, 0, 0.05), tool)
		if item.has("damage"):
			_box(Vector3(0.05, 0.02, 0.5), col, Vector3(0, 0, -0.3), tool)
			_box(Vector3(0.16, 0.04, 0.04), col, Vector3(0, 0, -0.05), tool)
		if item.has("pick"):
			_box(Vector3(0.32, 0.05, 0.06), col, Vector3(0, 0, -0.08), tool)
			handle.scale.z = 1.6
	else:
		_box(Vector3(0.14, 0.14, 0.03), col, Vector3.ZERO, held)


# ---------------------------------------------------------------- helpers

func forward_flat() -> Vector3:
	return Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))


func right_flat() -> Vector3:
	return Vector3(cos(cam_yaw), 0, -sin(cam_yaw))


func look_dir() -> Vector3:
	var cp := cos(cam_pitch)
	return Vector3(-sin(cam_yaw) * cp, sin(cam_pitch), -cos(cam_yaw) * cp)


func _yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _turn_toward(target: float, rate: float) -> void:
	var diff := fposmod(target - yaw + PI, TAU) - PI
	yaw += diff * minf(1.0, rate)


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _wall_probe(w: Vector3, y_off: float) -> bool:
	return world.solid_at(Vector3(pos.x + w.x * (hw + 0.25), pos.y + y_off, pos.z + w.z * (hw + 0.25)))


func _snap_wall(f: Vector3) -> Vector3:
	if absf(f.x) > absf(f.z):
		return Vector3(signf(f.x), 0, 0)
	return Vector3(0, 0, signf(f.z))


func use_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	stam_delay = 0.7
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		game.toast("Out of stamina")


func start_glide() -> void:
	if game.count("glider") <= 0:
		game.toast("Craft a Leaf Glider (C) to glide")
		return
	if exhausted:
		return
	mode = "glide"
	glider.visible = true


func stop_glide() -> void:
	if mode == "glide":
		mode = "walk"
		glider.visible = false


# ---------------------------------------------------------------- update

func update(dt: float, jump: bool) -> void:
	var f := forward_flat()
	var r := right_flat()
	var in_f := (1 if _key(KEY_W) else 0) - (1 if _key(KEY_S) else 0)
	var in_r := (1 if _key(KEY_D) else 0) - (1 if _key(KEY_A) else 0)
	var shift := _key(KEY_SHIFT)
	in_water = pos.y + 0.7 < World.WATER_SURF

	if mode == "climb":
		_update_climb(dt, r, in_f, in_r, shift, jump)
	elif mode == "mantle":
		mantle_t -= dt
		vel = Vector3(wall.x * 2.8, 5.5 if mantle_t > 0.18 else 1.5, wall.z * 2.8)
		world.move_entity(self, dt)
		if mantle_t <= 0.0:
			mode = "walk"
	elif mode == "glide":
		_update_glide(dt, f, r, in_f, in_r, shift, jump)
	else:
		_update_walk(dt, f, r, in_f, in_r, shift, jump)

	# Stamina only refills on solid ground or while floating in water.
	if mode == "walk" and (grounded or in_water):
		stam_delay -= dt
		if stam_delay <= 0.0:
			stamina = minf(100.0, stamina + (28.0 if exhausted else 40.0) * dt)
		if exhausted and stamina >= 100.0:
			exhausted = false

	invuln -= dt
	regen_t += dt
	if regen_t > 7.0 and hp < 10:
		hp += 1
		regen_t = 0.0
		game.hud.set_hearts(hp)
	if pos.y < -10.0:
		pos = world.spawn
		vel = Vector3.ZERO

	animate(dt)
	update_camera(-in_r * 0.08 if mode == "glide" else 0.0)


func _update_climb(dt: float, r: Vector3, in_f: int, in_r: int, shift: bool, jump: bool) -> void:
	yaw = _yaw_of(wall)
	var t := Vector3(-wall.z, 0, wall.x)
	if t.dot(r) < 0.0:
		t = -t
	if leap_t > 0.0:
		leap_t -= dt
		vel = Vector3(0, 7, 0)
	else:
		vel = Vector3(t.x * in_r * 2.2 + wall.x * 0.6, in_f * 2.6, t.z * in_r * 2.2 + wall.z * 0.6)
	use_stamina((11.0 if (in_f != 0 or in_r != 0) else 3.5) * dt)
	if jump:
		if stamina >= 12.0:
			use_stamina(18.0)
			leap_t = 0.28
		else:
			mode = "walk"
			vel = Vector3(-wall.x * 2.0, 2.0, -wall.z * 2.0)
			return
	world.move_entity(self, dt)
	var chest := _wall_probe(wall, 1.2)
	var feet := _wall_probe(wall, 0.3)
	if not chest and feet and (in_f > 0 or leap_t > 0.0):
		mode = "mantle"
		mantle_t = 0.42
		leap_t = 0.0
	elif not chest and not feet:
		mode = "walk"
	elif shift or exhausted:
		mode = "walk"
		vel = Vector3(-wall.x * 1.5, 0, -wall.z * 1.5)
	elif grounded and in_f < 0:
		mode = "walk"


func _update_glide(dt: float, f: Vector3, r: Vector3, in_f: int, in_r: int, shift: bool, jump: bool) -> void:
	vel.y += (-2.0 - vel.y) * minf(1.0, 5.0 * dt)
	var target := f * (9.0 + in_f * 2.0) + r * (in_r * 3.0)
	var k := minf(1.0, 2.2 * dt)
	vel.x += (target.x - vel.x) * k
	vel.z += (target.z - vel.z) * k
	use_stamina(7.0 * dt)
	if first_person:
		yaw = cam_yaw
	else:
		_turn_toward(_yaw_of(vel), 6.0 * dt)
	world.move_entity(self, dt)
	glide_dist += Vector2(vel.x, vel.z).length() * dt
	if glide_start_y - pos.y > 12.0 and glide_dist > 20.0:
		game.complete("glide")
	var w := _snap_wall(f)
	if grounded or in_water or jump or shift or exhausted:
		stop_glide()
	elif in_f > 0 and _wall_probe(w, 1.2):
		stop_glide()
		mode = "climb"
		wall = w


func _update_walk(dt: float, f: Vector3, r: Vector3, in_f: int, in_r: int, shift: bool, jump: bool) -> void:
	var sprint := shift and grounded and in_f > 0 and not exhausted
	var speed := (8.2 if sprint else 5.2) * (0.55 if in_water else 1.0)
	if sprint:
		use_stamina(14.0 * dt)
	var wish := f * in_f + r * in_r
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	if first_person:
		yaw = cam_yaw
	elif wish.length_squared() > 0.01:
		_turn_toward(_yaw_of(wish), 12.0 * dt)
	var k := minf(1.0, (14.0 if grounded else (4.0 if in_water else 2.5)) * dt)
	vel.x += (wish.x * speed - vel.x) * k
	vel.z += (wish.z * speed - vel.z) * k
	if in_water:
		vel.y -= 7.0 * dt
		vel.y *= pow(0.15, dt)
		if _key(KEY_SPACE):
			vel.y = minf(vel.y + 20.0 * dt, 3.2)
	else:
		vel.y = maxf(-45.0, vel.y - 26.0 * dt)
		if jump and grounded:
			vel.y = 8.2
		elif jump and not grounded and vel.y < 1.5:
			glide_start_y = pos.y
			glide_dist = 0.0
			start_glide()
	var landed := world.move_entity(self, dt)
	if landed < -16.0 and not in_water:
		game.hurt_player(ceili((-landed - 16.0) / 3.5), null)
		game.toast("Ouch, a hard landing")
	# Walking into a wall two blocks tall starts a climb.
	if wish.length_squared() > 0.01 and not exhausted and not in_water:
		var wd := wish.normalized()
		var w := _snap_wall(wd)
		if _wall_probe(w, 1.2) and _wall_probe(w, 0.4) and wd.dot(w) > 0.6:
			mode = "climb"
			wall = w
			vel = Vector3.ZERO


# ---------------------------------------------------------------- visuals

func animate(dt: float) -> void:
	position = pos
	rotation.y = yaw + PI
	var sp := Vector2(vel.x, vel.z).length()
	var l_l := 0.0
	var l_r := 0.0
	var a_l := 0.0
	var a_r := 0.0
	var a_lz := 0.0
	var a_rz := 0.0
	if mode == "climb" or mode == "mantle":
		_walk_phase += (absf(vel.y) + sp) * dt * 3.0
		var s := sin(_walk_phase)
		a_l = -2.7 + s * 0.45
		a_r = -2.7 - s * 0.45
		l_l = -0.5 - s * 0.4
		l_r = -0.5 + s * 0.4
	elif mode == "glide":
		a_l = -3.0
		a_r = -3.0
		a_lz = -0.25
		a_rz = 0.25
		l_l = 0.35
		l_r = 0.25
	elif in_water:
		_walk_phase += dt * 5.0
		var s := sin(_walk_phase)
		a_l = -1.2 + s * 0.8
		a_r = -1.2 - s * 0.8
		l_l = s * 0.5
		l_r = -s * 0.5
	elif not grounded:
		a_l = -0.4
		a_r = -0.4
		a_lz = -0.6
		a_rz = 0.6
		l_l = -0.5
		l_r = 0.2
	else:
		_walk_phase += sp * dt * 2.2
		var amt := minf(1.0, sp / 5.0) * (1.0 if sp > 7.0 else 0.7)
		var s := sin(_walk_phase)
		l_l = s * amt
		l_r = -s * amt
		a_l = -s * amt * 0.9
		a_r = s * amt * 0.9
	var k := minf(1.0, 16.0 * dt)
	_hip_l.rotation.x += (l_l - _hip_l.rotation.x) * k
	_hip_r.rotation.x += (l_r - _hip_r.rotation.x) * k
	_sh_l.rotation.x += (a_l - _sh_l.rotation.x) * k
	_sh_r.rotation.x += (a_r - _sh_r.rotation.x) * k
	_sh_l.rotation.z += (a_lz - _sh_l.rotation.z) * k
	_sh_r.rotation.z += (a_rz - _sh_r.rotation.z) * k
	var sw := maxf(0.0, swing_t) / 0.3
	if sw > 0.0:
		_sh_r.rotation.x = -1.4 - sin(sw * PI) * 1.3
		_sh_r.rotation.z = 0.0


func update_camera(roll: float) -> void:
	if first_person:
		visible = false
		camera.position = pos + Vector3(0, EYE, 0)
		camera.rotation = Vector3(cam_pitch, cam_yaw, roll)
		return
	var back := -look_dir()
	var target := pos + Vector3(0, 1.6, 0) + right_flat() * 0.55
	if world.solid_at(target):
		target = pos + Vector3(0, 1.6, 0)
	var hit := world.raycast(target, back, cam_dist)
	var want := cam_dist
	if not hit.is_empty():
		var t: float = hit["t"]
		want = maxf(0.35, t - 0.3)
	# Snap in when something blocks the view, ease back out afterwards.
	cam_cur = want if want < cam_cur else cam_cur + (want - cam_cur) * 0.12
	camera.position = target + back * cam_cur
	camera.rotation = Vector3(cam_pitch, cam_yaw, roll)
	visible = cam_cur > 0.9
