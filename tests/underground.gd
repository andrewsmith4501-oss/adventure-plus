extends SceneTree
## Checks saving and loading, and the caves and ores under the wild lands.
## Saves screenshots to user://shots/.
##
##   godot --path . -s res://tests/underground.gd

const SAVE := "user://test_world.save"

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


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ------------------------------------------------ a first session
	await start_game()
	check(not game.loaded_save, "no save at first: a fresh world")
	check(game.hud.play_button.text == "Play", "start button says Play")
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var w = game.world

	# Change the island, open the Hollow's door and build out in the wilds.
	var camp_h: int = w.spots["camp_h"]
	var island_p := Vector3i(w.CAMP_X + 3, camp_h + 1, w.CAMP_Z - 4)
	w.set_block(island_p.x, island_p.y, island_p.z, w.BRICKS)
	var dug := Vector3i(w.CAMP_X - 5, camp_h, w.CAMP_Z + 3)
	var dug_was: int = w.get_b(dug.x, dug.y, dug.z)
	w.set_block(dug.x, dug.y, dug.z, w.AIR)
	var door: Array = w.hollow["door"]
	var a: Vector3i = door[0]
	var b: Vector3i = door[1]
	for y in range(a.y, b.y + 1):
		for z in range(a.z, b.z + 1):
			w.set_block(a.x, y, z, w.AIR)
	game._door_open = true
	var wild_p := Vector3i(-700, 0, 900)
	wild_p.y = int(w.surface_y(wild_p.x, wild_p.z))
	w.set_block(wild_p.x, wild_p.y, wild_p.z, w.LANTERN)
	w.set_block(wild_p.x + 1, wild_p.y, wild_p.z, w.VENT)
	check(w.vents.has(Vector3i(wild_p.x + 1, wild_p.y, wild_p.z)), "a vent placed in the wilds blows")

	game.add_item("iron", 5)
	game.add_item("coal", 7)
	game.add_item("ipick", 1)
	game.select_slot(2)
	game.complete("talk")
	game.complete("glider")
	game.complete("vent_recipe")
	game.caches_found = 2
	game.player.max_hp = 12
	game.player.hp = 9
	game.player.max_stamina = 125.0
	game.player.set_wings()
	tp(Vector3(wild_p.x + 0.5, wild_p.y + 1.0, wild_p.z + 3.5), 1.1, -0.3)
	await settle()
	await frames(10)
	var before: Dictionary = game.save_data()
	check(game.save_game(), "the world saves")
	check(FileAccess.file_exists(SAVE), "the save file exists")
	var size := FileAccess.get_file_as_bytes(SAVE).size()
	print("save file: %d bytes, %d changed chunks" % [size, before["edits"].size()])
	check(size > 0 and size < 200000, "the save file is small")
	await stop_game()

	# ------------------------------------------------ loading it again
	await start_game()
	w = game.world
	check(game.loaded_save, "the save loads on start")
	check(game.hud.play_button.text == "Continue", "start button says Continue")
	check(game.hud.new_world_button.visible, "New world button shows")
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(game.player.pos.distance_to(before["player"]["pos"]) < 0.01, "the hero is back where they were")
	check(game.player.max_hp == 12 and game.player.hp == 9, "hearts are kept")
	check(is_equal_approx(game.player.max_stamina, 125.0) and game.player.wings, "stamina vessel and Gale Wings are kept")
	check(game.count("iron") == 5 and game.count("coal") == 7 and game.count("ipick") == 1, "inventory is kept")
	check(game.sel == 2, "selected hotbar slot is kept")
	check(game.done.has("talk") and game.done.has("glider") and game.done.has("vent_recipe"), "quest steps are kept")
	check(game.caches_found == 2, "cache count is kept")
	check(game._door_open and w.get_b(a.x, a.y, a.z) == w.AIR, "the Hollow's door stays open")
	check(w.get_b(island_p.x, island_p.y, island_p.z) == w.BRICKS, "a block built on the island is still there")
	check(w.get_b(dug.x, dug.y, dug.z) == w.AIR and dug_was != w.AIR, "a hole dug on the island is still there")
	await settle()
	check(w.get_b(wild_p.x, wild_p.y, wild_p.z) == w.LANTERN, "a block built in the wilds is still there")
	check(w.vents.has(Vector3i(wild_p.x + 1, wild_p.y, wild_p.z)), "a vent in the wilds still blows after loading")
	var k := Vector2i(wild_p.x >> 4, wild_p.z >> 4)
	check(w._chunks.has(k), "the changed wild chunk is drawn")
	await frames(10)
	shot("u01_loaded_wild_build")

	# Walk away and back: the edit survives the chunk being dropped.
	tp(Vector3(wild_p.x + 2500.0, 40, wild_p.z), 0.0)
	await settle()
	tp(Vector3(wild_p.x + 0.5, wild_p.y + 1.0, wild_p.z + 3.5), 1.1, -0.3)
	await settle()
	check(w.get_b(wild_p.x, wild_p.y, wild_p.z) == w.LANTERN, "the wild build survives leaving and coming back")

	# ------------------------------------------------ caves and ores
	var tg := Time.get_ticks_usec()
	for i in 12:
		w._gen_chunk(Vector2i(300 + i, -200), true)
	print("a wild chunk takes %.1f ms to make" % ((Time.get_ticks_usec() - tg) / 12000.0))
	var counts := {w.COAL_ORE: 0, w.IRON_ORE: 0, w.SUNSTONE: 0}
	var cave_air := 0
	var chunks := 0
	var cave_spot = null
	for cz in range(-60, -40, 2):
		for cx in range(100, 140, 2):
			var res: Dictionary = w._gen_chunk(Vector2i(cx, cz), false)
			chunks += 1
			var c: PackedByteArray = res["data"]
			var top: PackedInt32Array = res["top"]
			for ci in 256:
				var t: int = top[ci]
				for y in range(1, t):
					var blk: int = c[y + 64 * ci]
					if counts.has(blk):
						counts[blk] += 1
					elif blk == w.AIR and y >= 9 and t - y > 6:
						cave_air += 1
						# A cave floor with headroom, well under the ground.
						if cave_spot == null and c[y - 1 + 64 * ci] != w.AIR and y + 2 < 64 and c[y + 1 + 64 * ci] == w.AIR and c[y + 2 + 64 * ci] == w.AIR and t - y > 10:
							cave_spot = Vector3(cx * 16 + (ci & 15) + 0.5, y, cz * 16 + (ci >> 4) + 0.5)
	print("in %d chunks: coal %d, iron %d, sunstone %d, cave air %d" % [chunks, counts[w.COAL_ORE], counts[w.IRON_ORE], counts[w.SUNSTONE], cave_air])
	check(counts[w.COAL_ORE] > 0, "coal ore appears")
	check(counts[w.IRON_ORE] > 0, "iron ore appears")
	check(counts[w.SUNSTONE] > 0, "sunstone appears")
	check(counts[w.COAL_ORE] > counts[w.IRON_ORE] and counts[w.IRON_ORE] > counts[w.SUNSTONE], "coal is commonest and Sunstone rarest")
	check(cave_air > 500, "caves run under the ground")
	check(w._carved(5000, 3, 5000, 40) == false and w._carved(5000, 8, 5000, 40) == false, "caves never dip to the sea level")
	var island_ore := 0
	for z in range(0, w.D, 2):
		for x in range(0, w.W, 2):
			for y in range(1, 30):
				if w.get_b(x, y, z) in [w.COAL_ORE, w.IRON_ORE]:
					island_ore += 1
	print("ore on the island (every other column): %d" % island_ore)
	check(island_ore > 20, "there is ore to dig on the island too")

	check(cave_spot != null, "found a cave to stand in")
	if cave_spot != null:
		game.done.erase("cave")
		tp(cave_spot, 0.4, -0.15)
		game.player.first_person = true
		await settle()
		await frames(20)
		check(game.underground(), "the hero knows they are underground")
		game._region_t = 0.0
		game._update_region(0.01)
		check(game.done.has("cave"), "finding a cave counts as a goal")
		shot("u02_cave")
		for i in 4:
			game.player.cam_yaw += PI / 2.0
			await frames(6)
			shot("u03_cave_%d" % i)
		game.player.first_person = false

	# A wall of each ore, out in the open, to see how they look.
	var show := Vector3i(-700, 0, 920)
	show.y = int(w.surface_y(show.x, show.z)) + 1
	var row := [w.STONE, w.COAL_ORE, w.IRON_ORE, w.SUNSTONE, w.FURNACE]
	for i in row.size():
		for y in 2:
			w.set_block(show.x + i * 2, show.y + y, show.z, row[i])
	tp(Vector3(show.x + 4.5, show.y, show.z + 5.5), 0.0, -0.1)
	await settle()
	await frames(10)
	shot("u04_ores")

	# ------------------------------------------------ mining and smelting
	var pl = game.player
	var at := Vector3i(floori(pl.pos.x), floori(pl.pos.y), floori(pl.pos.z))
	w.set_block(at.x + 2, at.y, at.z, w.WORKBENCH)
	w.set_block(at.x - 2, at.y, at.z, w.FURNACE)
	game.add_item("iron_ore", 2)
	game.add_item("stick", 6)
	game.add_item("sunstone", 2)
	var rows: Array = game._recipe_rows()
	var known: Array = game._known_recipes()
	var iron_i := -1
	var sword_i := -1
	for i in known.size():
		if known[i]["out"] == "iron":
			iron_i = i
		elif known[i]["out"] == "sunsword":
			sword_i = i
	check(iron_i >= 0 and rows[iron_i]["ok"], "iron can be smelted next to a furnace")
	var iron_before: int = game.count("iron")
	game._craft(iron_i)
	check(game.count("iron") == iron_before + 1 and game.count("iron_ore") == 1, "smelting turns ore and coal into an ingot")
	check(game.done.has("iron"), "smelting counts as a goal")
	game._craft(sword_i)
	check(game.count("sunsword") == 1, "a Sunstone Sword can be forged")
	w.set_block(at.x - 2, at.y, at.z, w.AIR)
	rows = game._recipe_rows()
	check(not rows[iron_i]["ok"] and str(rows[iron_i]["need"]).contains("furnace"), "smelting needs a furnace nearby")
	check(int(game.pick_needed[w.SUNSTONE]) == 2 and int(game.items["spick"]["pick"]) == 1, "Sunstone needs an Iron Pick")

	# ------------------------------------------------ new world
	game._pause()
	await frames(3)
	shot("u05_paused")
	game._new_world()
	check(game.hud.new_world_button.text == "Erase my world?", "New world asks first")
	check(FileAccess.file_exists(SAVE), "asking does not erase anything")
	game._new_world()
	await frames(5)
	check(not FileAccess.file_exists(SAVE), "the second click erases the save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("done, %d failures" % fails)
	quit(1 if fails > 0 else 0)
