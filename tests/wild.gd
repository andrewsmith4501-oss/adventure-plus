extends SceneTree
## Checks the endless wild world: biomes, streaming speed, edits that
## survive walking away, and ruins. Saves screenshots to user://shots/.
##
##   godot --path . -s res://tests/wild.gd

var game
var fails := 0
var shots_dir := "user://shots/"
var frame_ms: Array = []


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
		var t := Time.get_ticks_usec()
		await process_frame
		frame_ms.append((Time.get_ticks_usec() - t) / 1000.0)


## Waits until every chunk in view is drawn. Returns the seconds it took.
func settle(limit := 30.0) -> float:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < limit:
		await frames(5)
		if game.world.stream_stats()["all_loaded"] and game.world.stream_stats()["pending"] == 0:
			break
	return (Time.get_ticks_msec() - t0) / 1000.0


func tp(x: float, z: float, yaw := 0.0, pitch := -0.25) -> void:
	game.player.pos = Vector3(x, game.world.surface_y(x, z), z)
	game.player.vel = Vector3.ZERO
	game.player.mode = "walk"
	game.player.cam_yaw = yaw
	game.player.yaw = yaw
	game.player.cam_pitch = pitch


func _init() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	game = scene
	_run.call_deferred()


func _run() -> void:
	await frames(3)
	game._resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var w = game.world

	# Biome mix over a 6 x 6 km square, and a little map of it.
	var counts := {}
	var img := Image.create(192, 192, false, Image.FORMAT_RGB8)
	var cols := [Color("2f6fb0"), Color("78b84a"), Color("2f7a32"), Color("e2cf8a"), Color("c0703f"), Color("e8eef6"), Color("8a8c94")]
	for iz in 192:
		for ix in 192:
			var x := (ix - 96) * 32
			var z := (iz - 96) * 32
			var c: Vector2i = w._column(x, z)
			var name: String = w.BIOMES[c.y]
			counts[name] = counts.get(name, 0) + 1
			var col: Color = cols[c.y]
			if x >= 0 and z >= 0 and x < w.W and z < w.D:
				col = Color.RED
			img.set_pixel(ix, iz, col.darkened(clampf(0.4 - c.x / 60.0, 0.0, 0.4)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	img.save_png(shots_dir + "w00_biome_map.png")
	print("biomes: ", counts)
	for b in w.BIOMES:
		check(counts.get(b, 0) > 0, "biome %s appears" % b)

	# How far is the nearest dry land in each direction from the island?
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var start := Vector2i(w.W / 2, w.D / 2)
		var edge := 0
		var found := -1
		for i in range(0, 600):
			var p: Vector2i = start + d * i
			var inside: bool = p.x >= 0 and p.y >= 0 and p.x < w.W and p.y < w.D
			if inside:
				edge = i
				continue
			if w._column(p.x, p.y).x > w.WATER:
				found = i - edge
				break
		print("land past the island edge toward ", d, ": ", found, " blocks of sea")
		check(found >= 0 and found < 120, "land within reach toward %s" % str(d))

	# Island first: everything around the camp should settle.
	var t := await settle()
	print("start area settled in %.1fs, stats %s" % [t, w.stream_stats()])
	frame_ms.clear()

	# Travel far away and watch the frame times while chunks stream in.
	var spots := [[2400.0, -1800.0], [-3100.0, 900.0], [600.0, 4200.0], [-1500.0, -2600.0]]
	var i := 0
	for s in spots:
		frame_ms.clear()
		tp(s[0], s[1], 0.6)
		var tt := await settle()
		var worst := 0.0
		var sum := 0.0
		for f in frame_ms:
			worst = maxf(worst, f)
			sum += f
		var reg: String = w.region_at(game.player.pos)
		print("at %s (%s): view filled in %.1fs, frames avg %.1f ms, worst %.1f ms, %s" % [str(s), reg, tt, sum / maxf(1, frame_ms.size()), worst, w.stream_stats()])
		check(tt < 30.0, "view fills at %s" % str(s))
		await frames(20)
		check(game.player.grounded or game.player.in_water, "hero stands on the ground at %s" % str(s))
		shot("w%02d_%s" % [i + 1, reg])
		i += 1
	# Glide across the land at full speed and watch the frame cost.
	frame_ms.clear()
	var sx: float = spots[1][0]
	var sz: float = spots[1][1]
	for f in 600:
		game.player.pos = Vector3(sx + f * 0.25, 52.0, sz + f * 0.1)
		game.player.vel = Vector3.ZERO
		await frames(1)
	frame_ms.sort()
	var p95: float = frame_ms[int(frame_ms.size() * 0.95)]
	var avg := 0.0
	for f in frame_ms:
		avg += f
	avg /= frame_ms.size()
	print("travelling at 15 blocks/s: frames avg %.1f ms, 95%% under %.1f ms, worst %.1f ms, %s" % [avg, p95, frame_ms[-1], w.stream_stats()])
	check(w.stream_stats()["pending"] < 40, "streaming keeps up with a glide")

	# A high view over a mountain range.
	tp(spots[0][0], spots[0][1], 2.2, -0.45)
	game.player.pos.y += 30.0
	game.player.cam_dist = 9.0
	await frames(3)
	shot("w05_from_above")

	# An edit out in the wilds stays after you leave and come back.
	var px := 2400
	var pz := -1800
	var py := int(w.surface_y(px, pz))
	w.set_block(px, py, pz, w.BRICKS)
	tp(px + 2000.0, pz)
	await settle()
	check(not w._cdata.has(Vector2i(floori(px / 16.0), floori(pz / 16.0))) or w._modified.has(Vector2i(floori(px / 16.0), floori(pz / 16.0))), "far chunks are dropped unless changed")
	tp(px + 0.5, pz + 3.5)
	await settle()
	check(w.get_b(px, py, pz) == w.BRICKS, "a block placed in the wilds is still there")
	var unmodified_kept := 0
	for k in w._cdata.keys():
		if not w.is_island_chunk(k) and not w._modified.has(k) and (k - w._center).length() > w.VIEW + 4:
			unmodified_kept += 1
	check(unmodified_kept == 0, "memory stays bounded (stale chunks %d)" % unmodified_kept)

	# Ruins: walk to the nearest one we know of and open its chest.
	var ruin_pos = null
	for gx in range(20, 30):
		for gz in range(-24, -14):
			if w._hash3(gx, 501, gz) < 0.35:
				continue
			var rx: int = gx * 96 + 16 + floori(w._hash3(gx, 502, gz) * 64.0)
			var rz: int = gz * 96 + 16 + floori(w._hash3(gx, 503, gz) * 64.0)
			var col: Vector2i = w._column(rx, rz)
			if col.y == w.B_SEA or col.x <= w.WATER + 1 or col.x > 42:
				continue
			ruin_pos = Vector2i(rx, rz)
			break
		if ruin_pos != null:
			break
	check(ruin_pos != null, "found a ruin")
	if ruin_pos != null:
		tp(ruin_pos.x + 6.5, ruin_pos.y + 6.5, PI * 0.25, -0.35)
		await settle()
		var found := []
		for k in w.chests:
			var key: String = w.chests[k]
			if key in ["ruin", "tower"] and Vector2(k.x - ruin_pos.x, k.z - ruin_pos.y).length() < 4.0:
				found.append(k)
		check(found.size() == 1, "the ruin has a chest")
		await frames(5)
		shot("w06_ruin")
		if found.size() == 1:
			var before: int = game.ruins_found
			game._open_chest(found[0])
			check(game.ruins_found == before + 1 and w.get_b(found[0].x, found[0].y, found[0].z) == w.CHEST_OPEN, "ruin chest opens")

	print("done, %d failures" % fails)
	quit(1 if fails > 0 else 0)
