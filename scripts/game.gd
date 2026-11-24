extends Node3D
## Adventure Plus prototype: builds the island, the hero, the Thornlings and
## the HUD, and runs items, crafting, goals and block interaction.

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Thornling = preload("res://scripts/thornling.gd")
const Hud = preload("res://scripts/hud.gd")

var items := {
	"dirt": {"name": "Dirt", "color": Color("865e3b"), "block": World.DIRT},
	"stone": {"name": "Stone", "color": Color("868890"), "block": World.STONE},
	"sand": {"name": "Sand", "color": Color("ddcb8f"), "block": World.SAND},
	"log": {"name": "Log", "color": Color("6b4a2b"), "block": World.LOG},
	"leaves": {"name": "Leaves", "color": Color("3e8538"), "block": World.LEAVES},
	"planks": {"name": "Planks", "color": Color("c79e61"), "block": World.PLANKS},
	"stick": {"name": "Stick", "color": Color("a07a48")},
	"wsword": {"name": "Wooden Sword", "color": Color("d6b27a"), "damage": 2},
	"ssword": {"name": "Stone Sword", "color": Color("a9adb6"), "damage": 3},
	"spick": {"name": "Stone Pick", "color": Color("7f848c"), "pick": true},
	"glider": {"name": "Leaf Glider", "color": Color("5fbf4f")},
	"shard": {"name": "Sky Shard", "color": Color("79f0ff")},
}
var drops := {
	World.GRASS: "dirt", World.DIRT: "dirt", World.STONE: "stone", World.SAND: "sand",
	World.LOG: "log", World.LEAVES: "leaves", World.PLANKS: "planks", World.CRYSTAL: "shard",
}
var break_time := {
	World.GRASS: 0.5, World.DIRT: 0.45, World.SAND: 0.4, World.LOG: 0.9,
	World.LEAVES: 0.2, World.PLANKS: 0.7, World.STONE: 2.4, World.CRYSTAL: 1.2,
}
var recipes := [
	{"out": "planks", "n": 4, "need": {"log": 1}},
	{"out": "stick", "n": 4, "need": {"planks": 2}},
	{"out": "wsword", "n": 1, "need": {"planks": 2, "stick": 1}},
	{"out": "spick", "n": 1, "need": {"stone": 3, "stick": 2}},
	{"out": "ssword", "n": 1, "need": {"stone": 2, "stick": 1}},
	{"out": "glider", "n": 1, "need": {"leaves": 8, "stick": 4}, "once": true},
]
var goals := [
	{"id": "log", "text": "Chop a tree for logs"},
	{"id": "sticks", "text": "Craft planks and sticks"},
	{"id": "glider", "text": "Craft a Leaf Glider"},
	{"id": "shard", "text": "Climb the cliff, take the Sky Shard"},
	{"id": "glide", "text": "Glide off the cliff"},
	{"id": "enemy", "text": "Defeat a Thornling"},
]
var done := {}

var world: World
var player: Player
var hud: Hud
var camera: Camera3D
var enemies: Array = []
var slots: Array = []
var sel := 0
var running := false
var started := false
var mouse_down := false
var jump_pressed := false

var _beacon: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _outline: MeshInstance3D
var _crack: MeshInstance3D
var _crack_mat: StandardMaterial3D
var _break_key := Vector3i(-1, -1, -1)
var _break_progress := 0.0
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	_rng.seed = 99
	_setup_environment()

	world = World.new()
	add_child(world)
	world.generate()
	_add_water()

	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 400.0
	add_child(camera)
	camera.current = true

	player = Player.new()
	player.world = world
	player.game = self
	player.camera = camera
	add_child(player)
	player.pos = world.spawn

	hud = Hud.new()
	add_child(hud)
	hud.play_pressed.connect(_resume)
	hud.craft_closed.connect(_resume)
	hud.respawn_pressed.connect(_respawn)
	hud.craft_requested.connect(_craft)

	_make_beacon()
	_make_markers()
	for i in 4:
		var spot := enemy_spot()
		var e := Thornling.new()
		add_child(e)
		e.pos = Vector3(spot.x, 0, spot.y)
		e.place_on_ground(world)
		enemies.append(e)

	slots.resize(9)
	hud.set_hearts(player.hp)
	hud.set_goals(goals, done)
	_render_hotbar()
	player.animate(0.0)
	player.update_camera(0.0)
	hud.show_screen("start")


# ---------------------------------------------------------------- scene setup

func _setup_environment() -> void:
	var sky := Color("9fd4ff")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.88, 0.95)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = sky
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.9
	add_child(sun)


func _flat_mat(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _add_water() -> void:
	var center := Vector3(World.W / 2.0, 0, World.D / 2.0)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	pm.material = _flat_mat(Color("3d8fc9"), 0.72)
	water.mesh = pm
	water.position = center + Vector3(0, World.WATER_SURF, 0)
	add_child(water)

	var floor_mi := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(600, 600)
	fm.material = _flat_mat(Color("bfae7a"))
	floor_mi.mesh = fm
	floor_mi.position = center + Vector3(0, 3.98, 0)
	add_child(floor_mi)


func _make_beacon() -> void:
	_beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.25
	cm.height = 60.0
	cm.cap_top = false
	cm.cap_bottom = false
	_beacon_mat = _flat_mat(Color("8ff4ff"), 0.28)
	cm.material = _beacon_mat
	_beacon.mesh = cm
	_beacon.position = Vector3(World.MESA_X + 0.5, world.mesa_top + 33, World.MESA_Z + 0.5)
	add_child(_beacon)


func _make_markers() -> void:
	# Thin black outline around the targeted block.
	var im := ImmediateMesh.new()
	var a := -0.502
	var b := 0.502
	var corners := [
		Vector3(a, a, a), Vector3(b, a, a), Vector3(b, a, b), Vector3(a, a, b),
		Vector3(a, b, a), Vector3(b, b, a), Vector3(b, b, b), Vector3(a, b, b),
	]
	var edges := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
	im.surface_begin(Mesh.PRIMITIVE_LINES, _flat_mat(Color.BLACK, 0.55))
	for e in edges:
		im.surface_add_vertex(corners[e[0]])
		im.surface_add_vertex(corners[e[1]])
	im.surface_end()
	_outline = MeshInstance3D.new()
	_outline.mesh = im
	_outline.visible = false
	add_child(_outline)

	_crack = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.01, 1.01, 1.01)
	_crack_mat = _flat_mat(Color.BLACK, 0.0)
	bm.material = _crack_mat
	_crack.mesh = bm
	_crack.visible = false
	add_child(_crack)


## A random grassy spot away from the player and the cliff.
func enemy_spot() -> Vector2:
	for i in 200:
		var x := 6.0 + _rng.randf() * (World.W - 12)
		var z := 6.0 + _rng.randf() * (World.D - 12)
		var h := world.heights[floori(x) + floori(z) * World.W]
		if h <= World.WATER + 1 or h > 24:
			continue
		if Vector2(x - player.pos.x, z - player.pos.z).length() < 18.0:
			continue
		if Vector2(x - World.MESA_X, z - World.MESA_Z).length() < 12.0:
			continue
		return Vector2(x, z)
	return Vector2(20, 20)


# ---------------------------------------------------------------- inventory

func count(id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == id:
			total += int(s["n"])
	return total


func add_item(id: String, n := 1) -> bool:
	for s in slots:
		if s != null and s["id"] == id:
			s["n"] = int(s["n"]) + n
			_render_hotbar()
			return true
	for i in slots.size():
		if slots[i] == null:
			slots[i] = {"id": id, "n": n}
			_render_hotbar()
			return true
	toast("Hotbar full")
	return false


func remove_item(id: String, n: int) -> void:
	for i in slots.size():
		if n <= 0:
			break
		var s = slots[i]
		if s == null or s["id"] != id:
			continue
		var take := mini(n, int(s["n"]))
		s["n"] = int(s["n"]) - take
		n -= take
		if int(s["n"]) <= 0:
			slots[i] = null
	_render_hotbar()


func sel_item() -> Dictionary:
	var s = slots[sel]
	if s == null:
		return {}
	return items[s["id"]]


func _render_hotbar() -> void:
	hud.render_hotbar(slots, sel, items)
	player.set_held(sel_item())


func select_slot(i: int) -> void:
	sel = posmod(i, 9)
	_render_hotbar()
	var it := sel_item()
	hud.show_item_name(it["name"] if not it.is_empty() else "")


func _recipe_rows() -> Array:
	var rows := []
	for r in recipes:
		var out: String = r["out"]
		var owned: bool = r.get("once", false) and count(out) > 0
		var ok := not owned
		var parts := PackedStringArray()
		for k in r["need"]:
			var need: int = r["need"][k]
			var have := count(k)
			if have < need:
				ok = false
			var txt := "%d %s (%d)" % [need, items[k]["name"], have]
			parts.append(txt if have >= need else "[color=#e8564a]%s[/color]" % txt)
		var n: int = r["n"]
		rows.append({
			"name": ("%d " % n if n > 1 else "") + str(items[out]["name"]),
			"need": "Already crafted" if owned else " + ".join(parts),
			"ok": ok,
			"color": items[out]["color"],
		})
	return rows


func _craft(i: int) -> void:
	var r: Dictionary = recipes[i]
	var rows := _recipe_rows()
	if not rows[i]["ok"]:
		return
	for k in r["need"]:
		remove_item(k, r["need"][k])
	add_item(r["out"], r["n"])
	if r["out"] == "stick":
		complete("sticks")
	if r["out"] == "glider":
		complete("glider")
		toast("Press Space in mid-air to glide")
	hud.render_recipes(_recipe_rows())


# ---------------------------------------------------------------- goals, health

func complete(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	hud.set_goals(goals, done)
	for g in goals:
		if g["id"] == id:
			toast("Goal done: " + str(g["text"]))
	if done.size() == goals.size():
		toast("All island goals done. Nice work!")


func toast(msg: String) -> void:
	hud.toast(msg)


func hurt_player(amount: int, from) -> void:
	if player.dead or player.invuln > 0.0:
		return
	player.hp -= amount
	player.invuln = 0.7
	player.regen_t = 0.0
	hud.set_hearts(player.hp)
	hud.flash_hurt()
	if from != null:
		var src: Vector3 = from
		var d := player.pos - src
		d.y = 0.0
		d = d.normalized()
		player.vel = Vector3(d.x * 7.0, 5.0, d.z * 7.0)
		if player.mode != "walk":
			player.stop_glide()
			player.mode = "walk"
	if player.hp <= 0:
		player.dead = true
		running = false
		mouse_down = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_screen("dead")


func _respawn() -> void:
	player.dead = false
	player.hp = 10
	player.stamina = 100.0
	player.exhausted = false
	player.stop_glide()
	player.mode = "walk"
	player.pos = world.spawn
	player.vel = Vector3.ZERO
	hud.set_hearts(player.hp)
	_resume()


# ---------------------------------------------------------------- pause / screens

func _resume() -> void:
	hud.show_screen("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	running = true
	started = true


func _pause() -> void:
	running = false
	mouse_down = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_paused_title(started)
	hud.show_screen("start")


func _toggle_craft() -> void:
	if hud.screens["craft"].visible:
		_resume()
	elif running:
		running = false
		mouse_down = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.render_recipes(_recipe_rows())
		hud.show_screen("craft")


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		player.cam_yaw -= mm.relative.x * 0.0024
		var top := 1.5 if player.first_person else 1.1
		player.cam_pitch = clampf(player.cam_pitch - mm.relative.y * 0.0024, -1.45, top)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not running:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_place_block()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(sel - 1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(sel + 1)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		var code := k.physical_keycode
		if code == KEY_C or code == KEY_E:
			_toggle_craft()
		elif code == KEY_ESCAPE:
			if running:
				_pause()
			elif hud.screens["craft"].visible:
				_resume()
		elif not running:
			return
		elif code == KEY_SPACE:
			jump_pressed = true
		elif code == KEY_V:
			player.first_person = not player.first_person
			toast("First person" if player.first_person else "Third person")
		elif code >= KEY_1 and code <= KEY_9:
			select_slot(code - KEY_1)


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_time += delta
	if running and not player.dead:
		player.update(dt, jump_pressed)
		for e in enemies:
			e.update(dt, world, player, self)
		_update_interaction(dt)
	else:
		player.animate(0.0)
		player.update_camera(0.0)
	jump_pressed = false
	world.flush_dirty()

	var st := player.stamina / 100.0
	hud.set_stamina(st, player.exhausted or st < 0.25)
	var state := "On foot"
	match player.mode:
		"climb", "mantle":
			state = "Climbing"
		"glide":
			state = "Gliding"
		_:
			if player.in_water:
				state = "Swimming"
			elif not player.grounded:
				state = "Falling"
	hud.set_state(state)
	_beacon_mat.albedo_color.a = 0.2 + sin(_time * 2.0) * 0.08


# ---------------------------------------------------------------- interaction

func _ray_box(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3) -> float:
	var t0 := 0.0
	var t1 := INF
	for a in 3:
		if absf(d[a]) < 1e-8:
			if o[a] < bmin[a] or o[a] > bmax[a]:
				return -1.0
			continue
		var ta := (bmin[a] - o[a]) / d[a]
		var tb := (bmax[a] - o[a]) / d[a]
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return -1.0
	return t0


## What the crosshair points at: {"enemy": node, "t": dist}, {"block": hit} or {}.
func _current_target() -> Dictionary:
	var o := camera.global_position
	var d := player.look_dir()
	var best = null
	var best_t := INF
	for e in enemies:
		if not e.alive:
			continue
		var epos: Vector3 = e.pos
		var t := _ray_box(o, d, epos - Vector3(0.5, 0, 0.5), epos + Vector3(0.5, 0.9, 0.5))
		if t >= 0.0 and epos.distance_to(player.pos) < 3.4 and t < best_t:
			best = e
			best_t = t
	var reach := 5.5 + (0.0 if player.first_person else player.cam_cur)
	var hit := world.raycast(o, d, reach)
	if not hit.is_empty():
		var bp: Vector3i = hit["pos"]
		var eye := player.pos + Vector3(0, Player.EYE, 0)
		if eye.distance_to(Vector3(bp) + Vector3(0.5, 0.5, 0.5)) > 5.5:
			hit = {}
	if best != null and (hit.is_empty() or best_t < float(hit["t"])):
		return {"enemy": best, "t": best_t}
	if not hit.is_empty():
		return {"block": hit}
	return {}


func _place_block() -> void:
	var it := sel_item()
	if it.is_empty() or not it.has("block"):
		return
	var tg := _current_target()
	if not tg.has("block"):
		return
	var hit: Dictionary = tg["block"]
	var p: Vector3i = hit["pos"] + hit["n"]
	if world.get_b(p.x, p.y, p.z) != World.AIR or p.y >= World.H:
		return
	var bodies: Array = [player]
	for e in enemies:
		if e.alive:
			bodies.append(e)
	for body in bodies:
		var bp: Vector3 = body.pos
		var bhw: float = body.hw
		var bh: float = body.h
		if p.x + 1 > bp.x - bhw and p.x < bp.x + bhw and p.z + 1 > bp.z - bhw and p.z < bp.z + bhw and p.y + 1 > bp.y and p.y < bp.y + bh:
			return
	world.set_block(p.x, p.y, p.z, it["block"])
	remove_item(slots[sel]["id"], 1)
	player.swing_t = 0.2


func _update_interaction(dt: float) -> void:
	var tg := _current_target()
	if tg.has("block"):
		var bp: Vector3i = tg["block"]["pos"]
		_outline.visible = true
		_outline.position = Vector3(bp) + Vector3(0.5, 0.5, 0.5)
	else:
		_outline.visible = false
	player.attack_cd -= dt
	player.swing_t -= dt
	if mouse_down and player.mode == "walk" and not player.first_person:
		player._turn_toward(player.cam_yaw, 20.0 * dt)

	var breaking := false
	if mouse_down and tg.has("enemy"):
		if player.attack_cd <= 0.0:
			var it := sel_item()
			var dmg: int = it.get("damage", 1)
			if tg["enemy"].hit(dmg, player.pos):
				toast("Thornling defeated")
				complete("enemy")
			player.attack_cd = 0.45
			player.swing_t = 0.3
	elif mouse_down and tg.has("block") and player.mode != "climb":
		breaking = true
		var hit: Dictionary = tg["block"]
		var bp: Vector3i = hit["pos"]
		var b: int = hit["b"]
		if bp != _break_key:
			_break_key = bp
			_break_progress = 0.0
		var it := sel_item()
		var has_pick := not it.is_empty() and it.has("pick")
		var time: float = break_time.get(b, 0.6)
		if b == World.STONE and has_pick:
			time = 0.6
		_break_progress += dt / time
		if player.swing_t <= 0.0:
			player.swing_t = 0.3
		if _break_progress >= 1.0:
			world.set_block(bp.x, bp.y, bp.z, World.AIR)
			if drops.has(b):
				add_item(drops[b], 1)
			if b == World.LOG:
				complete("log")
			if b == World.CRYSTAL:
				complete("shard")
				_beacon.visible = false
				toast("You found the Sky Shard!")
			if b == World.STONE and not has_pick and count("spick") == 0:
				toast("Tip: a Stone Pick breaks stone much faster")
			_break_progress = 0.0
			_break_key = Vector3i(-1, -1, -1)
			breaking = false
		_crack.position = Vector3(bp) + Vector3(0.5, 0.5, 0.5)
		_crack_mat.albedo_color.a = _break_progress * 0.55
	if not breaking:
		_break_key = Vector3i(-1, -1, -1)
		_break_progress = 0.0
	_crack.visible = breaking
