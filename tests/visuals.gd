extends SceneTree
## Checks how things look: item models and icons, lantern light (in caves,
## through saving and loading, and with many lanterns), and the frame time
## of the textured, lit world. Saves screenshots to user://shots/.
##
##   godot --path . -s res://tests/visuals.gd

const SAVE := "user://test_visuals.save"

var game
var fails := 0
var shots_dir := "user://shots/"


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	img.save_png(shots_dir + name + ".png")


func frames(n: int) -> void:
	for i in n:
		await process_frame


func settle(limit := 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < limit:
		await frames(5)
		var st: Dictionary = game.world.stream_stats()
		if st["all_loaded"] and st["pending"] == 0:
			break


func start_game() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	game = scene
	await frames(3)


func stop_game() -> void:
	game.save_path = ""
	game.queue_free()
	await frames(3)


func tp(p: Vector3, yaw: float, pitch := -0.2) -> void:
	game.player.pos = p
	game.player.vel = Vector3.ZERO
	game.player.mode = "walk"
	game.player.cam_yaw = yaw
	game.player.yaw = yaw
	game.player.cam_pitch = pitch


func hold(id: String) -> void:
	var i := -1
	for s in 9:
		if game.slots[s] != null and game.slots[s]["id"] == id:
			i = s
	if i < 0:
		game.slots[8] = {"id": id, "n": 5}
		i = 8
	game.select_slot(i)


## Average brightness of a chunk mesh's vertex colours near a point.
func light_near(p: Vector3, r: float) -> float:
	var w = game.world
	var k := Vector2i(floori(p.x) >> 4, floori(p.z) >> 4)
	var mi: MeshInstance3D = w._chunks.get(k)
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return -1.0
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var sum := 0.0
	var n := 0
	for i in vs.size():
		if vs[i].distance_to(p) < r:
			sum += cs[i].r
			n += 1
	return sum / maxf(n, 1)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await start_game()
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var w = game.world
	var camp_h: int = w.spots["camp_h"]

	# ------------------------------------------------ looks of things
	check(w.art.texture != null and w.art.texture.get_layers() > 50, "block textures are painted (%d)" % w.art.texture.get_layers())
	check(w.light_count() >= 3, "the camp's lanterns are known")
	for id in game.items:
		var m: ArrayMesh = game.item_mesh(id)
		if m == null or m.get_surface_count() == 0:
			check(false, "item %s has a model" % id)
	check(true, "every item has a 3D model")
	await frames(6)
	check(game.icons_baked, "item icons were rendered from the models")
	var hud_icons: int = game.Hud.ItemIcon.baked.size()
	check(hud_icons >= 15, "block items have rendered icons (%d)" % hud_icons)

	# Fill the hotbar and pack with a bit of everything.

	var all: Array = game.items.keys()
	var si := 0
	for id in all:
		if si >= game.slots.size():
			break
		game.slots[si] = {"id": id, "n": 1 + (si * 7) % 30}
		si += 1
	game._render_hotbar()
	hold("lantern")

	# Camp at dusk-ish view, holding a lantern.
	tp(Vector3(w.CAMP_X + 8.5, camp_h + 1.0, w.CAMP_Z - 1.5), 0.9, -0.25)
	await settle()
	await frames(20)
	shot("v01_camp")
	game.player.first_person = false
	game._toggle_inventory()
	await frames(8)
	shot("v02_inventory")
	game._toggle_inventory()
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(3)

	# Held items, close up.
	for id in ["wsword", "spick", "lantern", "planks"]:
		hold(id)
		tp(Vector3(w.CAMP_X + 8.5, camp_h + 1.0, w.CAMP_Z - 1.5), 2.4, -0.15)
		# Seen from the side.
		game.player.yaw = 2.4 + PI * 0.5
		game.player.cam_dist = 2.6
		await frames(8)
		shot("v03_held_" + id)
	game.player.cam_dist = 4.6

	# A broken block drops its item model, which flies to you.
	var bp := Vector3i(w.CAMP_X + 10, camp_h, w.CAMP_Z - 3)
	var before: int = game._drops.size()
	game._spawn_drop("dirt", Vector3(bp) + Vector3(0.5, 0.5, 0.5))
	check(game._drops.size() == before + 1, "a broken block pops out its item")
	await frames(90)
	check(game._drops.size() == before, "the dropped item flies to the hero")

	# ------------------------------------------------ lanterns in a cave
	var cave_spot = null
	for cz in range(-60, -40, 2):
		if cave_spot != null:
			break
		for cx in range(100, 140, 2):
			if cave_spot != null:
				break
			var res: Dictionary = w._gen_chunk(Vector2i(cx, cz), false)
			var c: PackedByteArray = res["data"]
			var top: PackedInt32Array = res["top"]
			for ci in 256:
				var t: int = top[ci]
				for y in range(9, t):
					if c[y + 64 * ci] == w.AIR and c[y - 1 + 64 * ci] != w.AIR and y + 3 < 64 and c[y + 1 + 64 * ci] == w.AIR and c[y + 2 + 64 * ci] == w.AIR and t - y > 12:
						cave_spot = Vector3(cx * 16 + (ci & 15) + 0.5, y, cz * 16 + (ci >> 4) + 0.5)
						break
				if cave_spot != null:
					break
	check(cave_spot != null, "found a cave")
	if cave_spot != null:
		hold("planks")
		tp(cave_spot, 0.4, -0.2)
		await settle()
		await frames(10)
		var lp := Vector3i(floori(cave_spot.x) + 2, floori(cave_spot.y), floori(cave_spot.z))
		var dark := light_near(Vector3(lp) + Vector3(0.5, 0.5, 0.5), 3.0)
		shot("v04_cave_dark")
		# Find a free floor spot next to the hero for the lantern.
		for dx in range(-3, 4):
			var q := Vector3i(lp.x + dx, lp.y, lp.z)
			if w.get_b(q.x, q.y, q.z) == w.AIR and w.get_b(q.x, q.y - 1, q.z) != w.AIR:
				lp = q
				break
		var t0 := Time.get_ticks_usec()
		w.set_block(lp.x, lp.y, lp.z, w.LANTERN)
		w.flush_dirty()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("placing a lantern and redrawing its chunk: %.1f ms" % ms)
		await frames(20)
		var lit := light_near(Vector3(lp) + Vector3(0.5, 0.5, 0.5), 3.0)
		print("cave light near the lantern: before %.3f, after %.3f" % [dark, lit])
		check(lit > dark + 0.05, "a lantern lights up the cave around it")
		check(w.light_level(Vector3(lp) + Vector3(1.5, 0.5, 0.5)) >= 8, "light is strong next to the lantern")
		check(w.light_level(Vector3(lp) + Vector3(0.5, -3.5, 0.5)) == 0 or w.get_b(lp.x, lp.y - 4, lp.z) == w.AIR, "light doesn't shine through solid rock")
		shot("v05_cave_lantern")
		hold("lantern")
		await frames(15)
		shot("v06_cave_hand_lantern")
		hold("planks")

		# Many lanterns: a row through the cave and the frame time.
		var placed := 0
		t0 = Time.get_ticks_usec()
		for i in 40:
			var q := Vector3i(lp.x + (i % 8) * 3 - 9, lp.y, lp.z + (i / 8) * 3 - 6)
			var y := q.y + 4
			while y > q.y - 6 and w.get_b(q.x, y, q.z) != w.AIR:
				y -= 1
			while y > 1 and w.get_b(q.x, y - 1, q.z) == w.AIR:
				y -= 1
			if w.get_b(q.x, y, q.z) == w.AIR and y > 8:
				w.set_block(q.x, y, q.z, w.LANTERN)
				placed += 1
		w.flush_dirty()
		print("placed %d lanterns in %.0f ms" % [placed, (Time.get_ticks_usec() - t0) / 1000.0])
		await settle()
		await frames(10)
		var ft := 0.0
		var n := 0
		var tf := Time.get_ticks_usec()
		for i in 60:
			await process_frame
			n += 1
		ft = (Time.get_ticks_usec() - tf) / 1000.0 / n
		print("frame time with %d lanterns nearby: %.1f ms" % [w.lights_near(game.player.pos, 24).size(), ft])
		shot("v07_cave_many_lanterns")

		# Saving and loading keeps the light.
		var lp_before := lp
		var light_before := light_near(Vector3(lp) + Vector3(0.5, 0.5, 0.5), 3.0)
		check(game.save_game(), "the world saves with lanterns")
		await stop_game()
		await start_game()
		game._resume()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		w = game.world
		await settle()
		await frames(20)
		check(w.get_b(lp_before.x, lp_before.y, lp_before.z) == w.LANTERN, "the lantern is still there after loading")
		var light_after := light_near(Vector3(lp_before) + Vector3(0.5, 0.5, 0.5), 3.0)
		print("light near the lantern: saved %.3f, loaded %.3f" % [light_before, light_after])
		check(absf(light_after - light_before) < 0.02 and light_after > dark + 0.05, "the cave is still lit after loading")
		shot("v08_cave_after_load")

	# ------------------------------------------------ scenery
	var views := [
		[Vector3(40.5, 0, 40.5), 2.3, -0.12, "v10_meadow"],
		[Vector3(100.5, 0, 50.5), 1.2, -0.1, "v11_steppes"],
		[Vector3(30.5, 0, 20.5), 3.6, -0.18, "v12_river"],
		[Vector3(-30.5, 0, 60.5), 1.6, -0.08, "v13_sea"],
	]
	for v in views:
		var p: Vector3 = v[0]
		p.y = w.surface_y(p.x, p.z) + 1.0
		tp(p, v[1], v[2])
		await settle()
		await frames(30)
		shot(v[3])
	# Bryn and a Thornling up close.
	var bryn = game.bryn
	# Stand beside the camera's line so Bryn, a Thornling and the hero
	# (turned to face us) are all in view.
	var look := 1.15
	var fwd := Vector3(-sin(look), 0, -cos(look))
	var side := Vector3(cos(look), 0, -sin(look))
	hold("wsword")
	tp(bryn.pos - fwd * 3.2 + side * 1.3 + Vector3(0, 0.2, 0), look, -0.1)
	game.player.yaw = look + PI
	game.player.cam_dist = 4.2
	var e = game.enemies[0]
	e.pos = bryn.pos - fwd * 0.4 - side * 1.6
	e.pos.y = w.surface_y(e.pos.x, e.pos.z)
	e.face_yaw = look + PI
	e.hop_t = 99.0
	await frames(30)
	game.player.yaw = look + PI
	await frames(2)
	shot("v14_characters")

	# Frame time out in the open, streaming.
	tp(Vector3(-300.5, 40, 300.5), 0.3, -0.15)
	await settle()
	var tf2 := Time.get_ticks_usec()
	for i in 60:
		await process_frame
	print("frame time in the wild lands: %.1f ms" % ((Time.get_ticks_usec() - tf2) / 60000.0))
	var tm := Time.get_ticks_usec()
	for i in 8:
		w._mesh_main(Vector2i(-20 + i, 18))
	print("main-thread chunk mesh: %.1f ms each" % ((Time.get_ticks_usec() - tm) / 8000.0))
	var tg := Time.get_ticks_usec()
	for i in 8:
		w._gen_chunk(Vector2i(400 + i, -300), true)
	print("worker chunk (blocks + mesh): %.1f ms each" % ((Time.get_ticks_usec() - tg) / 8000.0))

	await stop_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("done, %d failures" % fails)
	quit(1 if fails > 0 else 0)
