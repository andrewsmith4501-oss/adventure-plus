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
var max_hp := 10
var stamina := 100.0
var max_stamina := 100.0
## Gale Wings: a faster glider that sinks more slowly and tires you less.
var wings := false
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
## Push from Gale Steppes gusts, set by the game each frame.
var wind := Vector3.ZERO
var _was_in_water := false
var _step_i := 0
var _smooth_warned := false

# Camera.
var cam_yaw := PI * 0.75
var cam_pitch := -0.25
var cam_dist := 4.6
var cam_cur := 4.6
var first_person := false

var held: Node3D
## Shield: worn on the back, raised in front of you while blocking.
var shield: Node3D
var blocking := false
var _shield_mi: MeshInstance3D
var _shield_flash := 0.0
var glider: Node3D
var _wing_mats: Array = []
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
	var tunic_dk := Color("246f66")
	var skin := Color("e8b48a")
	var hair := Color("5a3a22")
	var hair_lt := Color("6e4a2c")
	var leather := Color("6b4a2b")
	var trousers := Color("3b4a5c")
	var gold := Color("f2b84b")
	_hip_l = _limb(Vector3(-0.12, 0.8, 0))
	_hip_r = _limb(Vector3(0.12, 0.8, 0))
	for hp_node in [_hip_l, _hip_r]:
		_box(Vector3(0.17, 0.5, 0.19), trousers, Vector3(0, -0.25, 0), hp_node)
		# Boots with a turned-down cuff and a darker sole.
		_box(Vector3(0.19, 0.24, 0.21), Color("5a3d26"), Vector3(0, -0.6, 0.01), hp_node)
		_box(Vector3(0.21, 0.05, 0.23), Color("7a5634"), Vector3(0, -0.47, 0.01), hp_node)
		_box(Vector3(0.19, 0.12, 0.26), Color("4a3424"), Vector3(0, -0.74, 0.03), hp_node)
		_box(Vector3(0.2, 0.03, 0.27), Color("2c2018"), Vector3(0, -0.795, 0.03), hp_node)
		_box(Vector3(0.12, 0.1, 0.02), Color("4b5d72"), Vector3(0, -0.28, 0.1), hp_node)
	# Tunic with a darker hem, a collar and a belt with a brass buckle.
	_box(Vector3(0.46, 0.58, 0.27), tunic, Vector3(0, 1.09, 0), self)
	_box(Vector3(0.48, 0.1, 0.29), tunic_dk, Vector3(0, 0.78, 0), self)
	_box(Vector3(0.48, 0.08, 0.29), leather, Vector3(0, 0.88, 0), self)
	_box(Vector3(0.1, 0.08, 0.02), gold, Vector3(0, 0.88, 0.15), self)
	_box(Vector3(0.05, 0.04, 0.02), Color("6b4a2b"), Vector3(0, 0.88, 0.162), self)
	_box(Vector3(0.14, 0.16, 0.05), Color("7a5634"), Vector3(-0.16, 0.82, 0.13), self)
	_box(Vector3(0.16, 0.12, 0.02), Color("d8efe9"), Vector3(0, 1.31, 0.14), self)
	_box(Vector3(0.5, 0.1, 0.31), gold, Vector3(0, 1.36, 0), self)
	_box(Vector3(0.1, 0.32, 0.04), gold, Vector3(0.14, 1.2, -0.17), self)
	_box(Vector3(0.12, 0.1, 0.04), gold.darkened(0.15), Vector3(0.14, 1.02, -0.17), self)
	# Head: face, eyes with whites, brows, nose and a mouth.
	_box(Vector3(0.34, 0.34, 0.32), skin, Vector3(0, 1.6, 0), self)
	_box(Vector3(0.08, 0.04, 0.03), skin.darkened(0.12), Vector3(0, 1.57, 0.165), self)
	_box(Vector3(0.1, 0.02, 0.02), Color("b5715a"), Vector3(0, 1.5, 0.165), self)
	for ex in [-0.08, 0.08]:
		_box(Vector3(0.07, 0.06, 0.02), Color("f4f1ea"), Vector3(ex, 1.63, 0.162), self)
		_box(Vector3(0.035, 0.06, 0.02), Color("2a2a3a"), Vector3(ex + (0.015 if ex < 0 else -0.015), 1.63, 0.168), self)
		_box(Vector3(0.08, 0.025, 0.02), hair, Vector3(ex, 1.68, 0.166), self)
		_box(Vector3(0.05, 0.03, 0.01), Color("e89a82"), Vector3(ex * 1.45, 1.55, 0.163), self)
	# Hair: crown, back, side locks and a fringe.
	_box(Vector3(0.37, 0.12, 0.35), hair, Vector3(0, 1.79, 0), self)
	_box(Vector3(0.37, 0.22, 0.07), hair, Vector3(0, 1.66, -0.15), self)
	_box(Vector3(0.05, 0.2, 0.3), hair, Vector3(-0.18, 1.68, -0.01), self)
	_box(Vector3(0.05, 0.2, 0.3), hair, Vector3(0.18, 1.68, -0.01), self)
	_box(Vector3(0.24, 0.06, 0.04), hair_lt, Vector3(-0.04, 1.73, 0.16), self)
	_box(Vector3(0.1, 0.08, 0.1), hair_lt, Vector3(0.08, 1.87, 0.04), self)
	# Backpack with a bedroll and straps.
	_box(Vector3(0.34, 0.4, 0.16), Color("8a6a3e"), Vector3(0, 1.12, -0.21), self)
	_box(Vector3(0.28, 0.14, 0.04), Color("7a5a34"), Vector3(0, 1.02, -0.3), self)
	_box(Vector3(0.36, 0.08, 0.18), leather, Vector3(0, 1.33, -0.21), self)
	_box(Vector3(0.42, 0.12, 0.12), Color("b0453a"), Vector3(0, 1.44, -0.24), self)
	_box(Vector3(0.43, 0.13, 0.03), Color("e6d3a8"), Vector3(0, 1.44, -0.24), self)
	for strap_x in [-0.12, 0.12]:
		_box(Vector3(0.05, 0.4, 0.02), leather, Vector3(strap_x, 1.12, 0.14), self)
	_sh_l = _limb(Vector3(-0.31, 1.34, 0))
	_sh_r = _limb(Vector3(0.31, 1.34, 0))
	for sh in [_sh_l, _sh_r]:
		_box(Vector3(0.13, 0.4, 0.15), tunic, Vector3(0, -0.18, 0), sh)
		_box(Vector3(0.14, 0.06, 0.16), tunic_dk, Vector3(0, -0.36, 0), sh)
		_box(Vector3(0.12, 0.14, 0.14), skin, Vector3(0, -0.45, 0), sh)
		# Leather gloves.
		_box(Vector3(0.13, 0.13, 0.13), Color("7a5634"), Vector3(0, -0.58, 0), sh)
	held = Node3D.new()
	held.position = Vector3(0, -0.6, 0.05)
	held.rotation.y = PI
	_sh_r.add_child(held)

	shield = Node3D.new()
	shield.visible = false
	add_child(shield)

	glider = Node3D.new()
	glider.position = Vector3(0, 2.55, 0.05)
	glider.visible = false
	add_child(glider)
	for part in [[Vector3(2.6, 0.04, 1.1), Color("5fbf4f")], [Vector3(2.62, 0.05, 0.2), Color("f2b84b")]]:
		var mi := _box(part[0], part[1], Vector3.ZERO, glider)
		_wing_mats.append((mi.mesh as BoxMesh).material)
	for sx in [-0.35, 0.35]:
		_box(Vector3(0.02, 0.75, 0.02), Color("4a3424"), Vector3(sx, -0.38, 0), glider)


## Upgrades the glider to Gale Wings (longer, sky-blue wings).
func set_wings() -> void:
	wings = true
	_wing_mats[0].albedo_color = Color("8fd0ff")
	_wing_mats[1].albedo_color = Color("ffffff")
	for c in glider.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh and (c.mesh as BoxMesh).size.x > 2.0:
			c.scale.x = 1.25


## Shows the selected item in the hero's right hand, as its 3D model.
func set_held(item: Dictionary, mesh: Mesh = null) -> void:
	for c in held.get_children():
		c.queue_free()
	if item.is_empty() or mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if item.has("block"):
		if item["block"] == World.LANTERN:
			# Carried by its handle, hanging a little out from the leg.
			mi.scale = Vector3(0.55, 0.55, 0.55)
			mi.position = Vector3(-0.06, -0.17, 0.02)
		else:
			# Blocks sit in the palm.
			mi.scale = Vector3(0.26, 0.26, 0.26)
			mi.position = Vector3(0, -0.04, -0.1)
			mi.rotation = Vector3(0.2, 0.5, 0)
		held.add_child(mi)
		return
	# Pixel-art items: the grip (lower left of the picture) is in the hand,
	# the blade or head points forward and up, flat side out.
	var tool: bool = item.has("damage") or item.has("pick") or item["name"] == "Stick"
	var pivot := Node3D.new()
	held.add_child(pivot)
	var sc := 0.8 if tool else 0.38
	if tool:
		pivot.basis = Basis(Vector3(0, 0.71, -0.71), Vector3(0, 0.71, 0.71), Vector3(1, 0, 0))
		pivot.position = Vector3(0, -0.02, -0.02)
	else:
		pivot.basis = Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
		pivot.position = Vector3(0, -0.12, -0.06)
	pivot.add_child(mi)
	mi.scale = Vector3(sc, sc, sc)
	if tool:
		mi.rotation.z = -PI / 4.0
		var grip := Vector3(-0.37, -0.37, 0)
		mi.position = -(Basis(Vector3(0, 0, 1), -PI / 4.0) * grip) * sc


## Shows a shield on the hero's back (or none, with null).
func set_shield(mesh: Mesh) -> void:
	for c in shield.get_children():
		c.queue_free()
	_shield_mi = null
	shield.visible = mesh != null
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3(0.62, 0.62, 0.62)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.add_child(mi)
	_shield_mi = mi
	_place_shield(1.0)


## A blocked hit makes the shield jolt (more for a perfect block).
func flash_shield(perfect: bool) -> void:
	_shield_flash = 1.0 if perfect else 0.6


func _place_shield(k: float) -> void:
	# On the back over the pack, or held up in front at the left hand.
	var back_pos := Vector3(0.0, 1.12, -0.36)
	var front_pos := Vector3(-0.12, 1.16, 0.46)
	var to_pos := front_pos if blocking else back_pos
	var to_rot := Vector3(0.0, 0.0, 0.0) if blocking else Vector3(0.12, PI, 0.0)
	shield.position = shield.position.lerp(to_pos, k)
	shield.rotation = Vector3(lerp_angle(shield.rotation.x, to_rot.x, k), lerp_angle(shield.rotation.y, to_rot.y, k), lerp_angle(shield.rotation.z, to_rot.z, k))
	if _shield_flash > 0.0:
		shield.position.z -= _shield_flash * 0.08
		shield.rotation.x -= _shield_flash * 0.25


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


## True when the hero is climbing a ladder (no stamina needed).
func on_ladder() -> bool:
	for y_off in [1.2, 0.3]:
		var b := world.block_at(Vector3(pos.x + wall.x * (hw + 0.25), pos.y + y_off, pos.z + wall.z * (hw + 0.25)))
		if b == World.LADDER:
			return true
	return false


## True when the wall in direction w is too smooth to climb (Loomstone).
func _smooth(w: Vector3, y_off: float) -> bool:
	var b := world.block_at(Vector3(pos.x + w.x * (hw + 0.25), pos.y + y_off, pos.z + w.z * (hw + 0.25)))
	return b in World.UNCLIMBABLE


func _smooth_hint() -> void:
	if not _smooth_warned:
		_smooth_warned = true
		game.toast("Loomstone is too smooth to climb")


## The phone's Climb button: grab the wall in front of you, or let go.
func toggle_climb() -> void:
	if mode == "climb" or mode == "mantle":
		mode = "walk"
		vel = Vector3(-wall.x * 1.5, 0, -wall.z * 1.5)
		return
	if mode != "walk" or in_water:
		return
	var fd := Vector3(-sin(yaw), 0, -cos(yaw))
	var w := _snap_wall(fd)
	if not (_wall_probe(w, 1.2) and _wall_probe(w, 0.4)):
		game.toast("Face a wall to climb it")
	elif _smooth(w, 1.2):
		_smooth_hint()
	elif exhausted:
		game.toast("Too tired to climb")
	else:
		mode = "climb"
		wall = w
		vel = Vector3.ZERO


## The phone's Glide button: open the glider in the air, or close it.
func toggle_glide() -> void:
	if mode == "glide":
		stop_glide()
	elif mode == "walk" and not grounded and not in_water:
		glide_start_y = pos.y
		glide_dist = 0.0
		start_glide()
	else:
		game.toast("Jump or step off a ledge first, then open the glider")


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
	game.audio.play("glider_open", -3.0)


func stop_glide() -> void:
	if mode == "glide":
		mode = "walk"
		glider.visible = false
		game.audio.play("glider_close", -6.0)


# ---------------------------------------------------------------- update

func update(dt: float, jump: bool) -> void:
	var f := forward_flat()
	var r := right_flat()
	var in_f := float((1 if _key(KEY_W) else 0) - (1 if _key(KEY_S) else 0))
	var in_r := float((1 if _key(KEY_D) else 0) - (1 if _key(KEY_A) else 0))
	var shift := _key(KEY_SHIFT)
	# The on-screen stick and Sprint button on a phone.
	var touch = game.touch if game != null else null
	if touch != null and touch.enabled:
		in_f = clampf(in_f + touch.move.y, -1.0, 1.0)
		in_r = clampf(in_r + touch.move.x, -1.0, 1.0)
		shift = shift or touch.sprint
	in_water = pos.y + 0.7 < World.WATER_SURF
	if in_water and not _was_in_water and vel.y < -2.0:
		game.audio.play("splash", -4.0)
	_was_in_water = in_water

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
			stamina = minf(max_stamina, stamina + (28.0 if exhausted else 40.0) * dt)
		if exhausted and stamina >= max_stamina:
			exhausted = false

	invuln -= dt
	regen_t += dt
	if regen_t > 7.0 and hp < max_hp:
		hp += 1
		regen_t = 0.0
		game.hud.set_hearts(hp, max_hp)
	if pos.y < -10.0:
		pos = world.spawn
		vel = Vector3.ZERO

	animate(dt)
	update_camera(-in_r * 0.08 if mode == "glide" else 0.0)


func _update_climb(dt: float, r: Vector3, in_f: float, in_r: float, shift: bool, jump: bool) -> void:
	yaw = _yaw_of(wall)
	var t := Vector3(-wall.z, 0, wall.x)
	if t.dot(r) < 0.0:
		t = -t
	var ladder := on_ladder()
	if leap_t > 0.0:
		leap_t -= dt
		vel = Vector3(0, 7, 0)
	else:
		vel = Vector3(t.x * in_r * 2.2 + wall.x * 0.6, in_f * (3.6 if ladder else 2.6), t.z * in_r * 2.2 + wall.z * 0.6)
	if not ladder:
		use_stamina((11.0 if (in_f != 0 or in_r != 0) else 3.5) * dt + wind.length() * 1.6 * dt)
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
	if chest and _smooth(wall, 1.2):
		mode = "walk"
		vel = Vector3(-wall.x * 1.5, 0, -wall.z * 1.5)
		_smooth_hint()
		return
	if not chest and feet and (in_f > 0 or leap_t > 0.0):
		mode = "mantle"
		mantle_t = 0.42
		leap_t = 0.0
	elif not chest and not feet:
		mode = "walk"
	elif shift or (exhausted and not ladder):
		mode = "walk"
		vel = Vector3(-wall.x * 1.5, 0, -wall.z * 1.5)
	elif grounded and in_f < 0:
		mode = "walk"


func _update_glide(dt: float, f: Vector3, r: Vector3, in_f: float, in_r: float, shift: bool, jump: bool) -> void:
	var lift := world.updraft_at(pos)
	if lift > 0.0:
		vel.y += (lift - vel.y) * minf(1.0, 3.0 * dt)
	else:
		vel.y += ((-1.5 if wings else -2.0) - vel.y) * minf(1.0, 5.0 * dt)
	# In an updraft you hang in the air column unless you steer out of it.
	var cruise := (in_f * 5.0) if lift > 0.0 else ((11.5 if wings else 9.0) + in_f * 2.0)
	var target := f * cruise + r * (in_r * 3.0) + wind * 1.4
	var k := minf(1.0, 2.2 * dt)
	vel.x += (target.x - vel.x) * k
	vel.z += (target.z - vel.z) * k
	use_stamina((4.5 if wings else 7.0) * dt)
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
	elif in_f > 0 and _wall_probe(w, 1.2) and not _smooth(w, 1.2):
		stop_glide()
		mode = "climb"
		wall = w


func _update_walk(dt: float, f: Vector3, r: Vector3, in_f: float, in_r: float, shift: bool, jump: bool) -> void:
	var sprint := shift and grounded and in_f > 0 and not exhausted and not blocking
	var speed := (8.2 if sprint else 5.2) * (0.55 if in_water else 1.0) * (0.5 if blocking else 1.0)
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
	var push := wind if grounded and not in_water else wind * 0.5
	vel.x += (wish.x * speed + push.x - vel.x) * k
	vel.z += (wish.z * speed + push.z - vel.z) * k
	if in_water:
		vel.y -= 7.0 * dt
		vel.y *= pow(0.15, dt)
		if _key(KEY_SPACE) or (game.touch != null and game.touch.jump_held):
			vel.y = minf(vel.y + 20.0 * dt, 3.2)
	else:
		vel.y = maxf(-45.0, vel.y - 26.0 * dt)
		if jump and grounded:
			vel.y = 8.2
			game.audio.play("jump", -8.0)
		elif jump and not grounded and vel.y < 1.5:
			glide_start_y = pos.y
			glide_dist = 0.0
			start_glide()
	var landed := world.move_entity(self, dt)
	if grounded and vel.y <= 0.0 and world.block_at(pos + Vector3(0, -0.1, 0)) == World.SPRING:
		vel.y = 18.0
		grounded = false
		glide_start_y = pos.y
		glide_dist = 0.0
		game.on_spring(pos)
		return
	if landed < -7.0 and not in_water:
		game.audio.play("land", -6.0 if landed > -16.0 else 0.0)
	if landed < -16.0 and not in_water:
		game.hurt_player(ceili((-landed - 16.0) / 3.5), null)
		game.toast("Ouch, a hard landing")
	# Walking into a wall two blocks tall starts a climb.
	if wish.length_squared() > 0.01 and not in_water:
		var wd := wish.normalized()
		var w := _snap_wall(wd)
		if exhausted and world.block_at(Vector3(pos.x + w.x * (hw + 0.25), pos.y + 0.4, pos.z + w.z * (hw + 0.25))) != World.LADDER:
			return
		if _wall_probe(w, 1.2) and _wall_probe(w, 0.4) and wd.dot(w) > 0.6 and _smooth(w, 1.2):
			_smooth_hint()
		elif _wall_probe(w, 1.2) and _wall_probe(w, 0.4) and wd.dot(w) > 0.6:
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
		_footstep(-14.0)
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
		if sp > 1.0:
			_footstep(-9.0 if sp > 7.0 else -11.0)
		var amt := minf(1.0, sp / 5.0) * (1.0 if sp > 7.0 else 0.7)
		var s := sin(_walk_phase)
		l_l = s * amt
		l_r = -s * amt
		a_l = -s * amt * 0.9
		a_r = s * amt * 0.9
	if blocking and mode == "walk":
		# Left arm up and forward, holding the shield in front.
		a_l = -1.35
		a_lz = 0.3
	var k := minf(1.0, 16.0 * dt)
	_hip_l.rotation.x += (l_l - _hip_l.rotation.x) * k
	_hip_r.rotation.x += (l_r - _hip_r.rotation.x) * k
	_sh_l.rotation.x += (a_l - _sh_l.rotation.x) * k
	_sh_r.rotation.x += (a_r - _sh_r.rotation.x) * k
	_sh_l.rotation.z += (a_lz - _sh_l.rotation.z) * k
	_sh_r.rotation.z += (a_rz - _sh_r.rotation.z) * k
	if shield.visible:
		_shield_flash = maxf(0.0, _shield_flash - dt * 4.0)
		_place_shield(minf(1.0, 18.0 * dt) if dt > 0.0 else 1.0)
	var sw := maxf(0.0, swing_t) / 0.3
	if sw > 0.0:
		_sh_r.rotation.x = -1.4 - sin(sw * PI) * 1.3
		_sh_r.rotation.z = 0.0


## Plays a footstep each time a foot comes down, matching the ground.
func _footstep(volume_db: float) -> void:
	var i := floori(_walk_phase / PI)
	if i == _step_i:
		return
	_step_i = i
	if dt_paused():
		return
	var b := world.block_at(pos + Vector3(0, -0.2, 0))
	if mode == "climb" or mode == "mantle":
		b = world.block_at(pos + wall * 0.6 + Vector3(0, 1.0, 0))
	var sound := "step_grass"
	if b in [World.STONE, World.BRICKS, World.LOOMSTONE, World.LOOMVEIN, World.SKYGLASS, World.CRYSTAL, World.TABLET, World.VENT, World.PLATE, World.PLATE_ON]:
		sound = "step_stone"
	elif b in [World.PLANKS, World.LOG, World.LADDER, World.WORKBENCH, World.CRATE, World.CHEST, World.CHEST_OPEN]:
		sound = "step_wood"
	game.audio.play(sound, volume_db, 0.12)


func dt_paused() -> bool:
	return game == null or not game.running


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
