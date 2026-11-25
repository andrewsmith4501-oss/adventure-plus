extends SceneTree
## Checks the map that fills in as you explore and the shield: crafting
## one, raising it, blocking a Thornling from the front (and not from behind),
## perfect blocks, the guard breaking when stamina runs out, the touch Map and
## Block buttons, and both surviving a save and load. Screenshots go to
## user://shots/.
##
##   godot --path . -s res://tests/map_shield.gd

const SAVE := "user://test_map.save"
const World = preload("res://scripts/world.gd")

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
	await RenderingServer.frame_post_draw
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


func key(code: Key, down: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = down
	Input.parse_input_event(k)
	Input.flush_buffered_events()


func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Puts a Thornling right next to the hero, on the given side.
func thornling_at(side: Vector3):
	var e = game.enemies[0]
	for o in game.enemies.slice(1):
		o.alive = false
		o.visible = false
		o.respawn_t = 999.0
	var p = game.player
	e.alive = true
	e.visible = true
	e.pos = p.pos + side * 0.6
	e.vel = Vector3.ZERO
	e.attack_cd = 0.0
	e.hop_t = 5.0
	e.hurt_t = 0.0
	return e


## Takes the test Thornling out of the way so it can't hit again by itself.
func park(e) -> void:
	e.alive = false
	e.visible = false
	e.respawn_t = 999.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in [SAVE, "user://test_map.settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	game = scene
	await frames(3)
	game._resume()
	await settle()
	await frames(10)
	var p = game.player
	var map = game.map

	# ------------------------------------------------------------ the map
	var near: int = map.explored_count()
	check(near > 2000, "the map fills in around the start (%d columns)" % near)
	check(map.explored(p.pos.x, p.pos.z), "where you stand is on the map")
	check(map.explored(p.pos.x + 30, p.pos.z), "30 blocks away is on the map")
	check(not map.explored(p.pos.x + 400, p.pos.z), "far away is still blank")
	check(not map.explored(-300, -300), "the far wild lands are blank")

	# Water is drawn as water and land as land.
	var sea_px := Color(0, 0, 0)
	var land_px := Color(0, 0, 0)
	for k in map.tiles:
		var px: PackedByteArray = map.tiles[k]
		var top: PackedInt32Array = game.world._ctop[k]
		for ci in 256:
			if px[ci * 4 + 3] == 0:
				continue
			var c := Color8(px[ci * 4], px[ci * 4 + 1], px[ci * 4 + 2])
			if top[ci] < 5 and sea_px == Color(0, 0, 0):
				sea_px = c
			elif top[ci] > 10 and land_px == Color(0, 0, 0):
				land_px = c
	check(sea_px.b > sea_px.r + 0.2, "water shows blue on the map")
	check(land_px != Color(0, 0, 0) and land_px.g >= land_px.b, "land shows as land on the map")

	# Walk (teleport) somewhere new: the map fills in there.
	p.pos = Vector3(150.0, game.world.surface_y(150.0, 40.0), 40.0)
	await settle()
	await frames(20)
	check(map.explored(150, 40), "exploring somewhere new adds it to the map")
	check(map.explored_count() > near + 1000, "the map grows as you explore (%d)" % map.explored_count())
	# High up you see further.
	var low: float = game._sight()
	p.pos.y += 30.0
	check(game._sight() > low + 10.0, "you see further from high up (%.0f > %.0f)" % [game._sight(), low])
	p.pos.y -= 30.0

	# Opening and closing the map with M.
	key(KEY_M, true)
	key(KEY_M, false)
	await frames(3)
	check(game.hud.screens["map"].visible and not game.running, "M opens the map and pauses")
	var v = game.hud.map_view
	check(v.size.x > 600 and v.size.y > 300, "the map fills most of the screen (%s)" % str(v.size))
	check(v.center.distance_to(Vector2(p.pos.x, p.pos.z)) < 1.0, "the map opens centred on you")
	var labels := []
	for m in v.markers:
		labels.append(m["label"])
	check(labels.has("Camp") and labels.has("Quest"), "the map marks the camp and the quest (%s)" % str(labels))
	await shot("map_01_open")
	var z0: float = v.zoom
	v.zoom_by(1.5)
	check(v.zoom > z0, "zooming in works")
	v.zoom = 1.2
	v.center = Vector2(80, 56)
	v.queue_redraw()
	await frames(2)
	await shot("map_02_zoomed_out")
	v.recenter()
	check(v.center.distance_to(Vector2(p.pos.x, p.pos.z)) < 1.0, "Find me centres on you again")
	key(KEY_M, true)
	key(KEY_M, false)
	await frames(3)
	check(not game.hud.screens["map"].visible and game.running, "M closes the map")

	# ------------------------------------------------------------ shield
	p.pos = game.world.spawn
	p.vel = Vector3.ZERO
	await settle()
	await frames(10)
	check(game.best_shield().is_empty(), "no shield to start with")
	# Craft one at a workbench.
	game.add_item("planks", 5)
	game.add_item("stick", 1)
	game.add_item("workbench", 1)
	var wb := Vector3i(floori(p.pos.x) + 2, floori(p.pos.y), floori(p.pos.z))
	game.world.set_block(wb.x, wb.y, wb.z, World.WORKBENCH)
	var idx := -1
	var known: Array = game._known_recipes()
	for i in known.size():
		if known[i]["out"] == "wshield":
			idx = i
	check(idx >= 0, "the Wooden Shield is a recipe")
	var rows: Array = game._recipe_rows()
	check(idx >= 0 and rows[idx]["ok"], "you can craft it at a workbench with 5 planks and a stick")
	if idx >= 0:
		game._craft(idx)
	check(game.count("wshield") == 1, "crafted a Wooden Shield")
	check(game.best_shield().get("id", "") == "wshield", "the shield in your pack is used")
	check(p.shield.visible, "the shield shows on your back")
	game.world.set_block(wb.x, wb.y, wb.z, World.AIR)

	# Hold the sword (not a block), then hold right mouse to block.
	game.add_item("wsword", 1)
	for i in game.HOTBAR:
		var s = game.slots[i]
		if s != null and s["id"] == "wsword":
			game.select_slot(i)
	game.block_held = true
	await frames(3)
	check(game.blocking and p.blocking, "holding block raises the shield")
	var fwd := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	check(p.shield.position.z > 0.2, "the shield is held up in front (z %.2f)" % p.shield.position.z)
	# Blocking makes you slower.
	await frames(30)  # past the perfect-block moment
	fwd = Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	p.stamina = p.max_stamina
	var hp0: int = p.hp
	var e = thornling_at(fwd)
	var e_hp: int = e.hp
	game.hurt_player(1, e.pos, e)
	check(p.hp == hp0, "a hit from the front is blocked (hp %d)" % p.hp)
	check(p.stamina < p.max_stamina - 10.0, "blocking costs stamina (%.0f)" % p.stamina)
	check(e.vel.length() > 3.0 and e.hp == e_hp, "the Thornling is knocked back, unhurt")
	check(game.done.has("block"), "blocking finishes the side goal")
	await shot("shield_01_block")

	# From behind, the shield doesn't help.
	p.invuln = 0.0
	fwd = Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	e = thornling_at(-fwd)
	game.hurt_player(1, e.pos, e)
	check(p.hp == hp0 - 1, "a hit from behind gets through")

	# A perfect block: raise it just as the hit lands.
	park(e)
	p.invuln = 0.0
	p.hp = p.max_hp
	game.block_held = false
	await frames(2)
	check(not game.blocking, "letting go lowers the shield")
	game.block_held = true
	await frames(1)
	p.stamina = 50.0
	fwd = Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	e = thornling_at(fwd)
	game.hurt_player(1, e.pos, e)
	check(p.hp == p.max_hp and p.stamina >= 49.0, "a perfect block costs nothing (stamina %.0f)" % p.stamina)
	check(e.hurt_t > 0.8, "a perfect block stuns the Thornling")
	check(game.done.has("parry"), "perfect block side goal")

	# Out of stamina: the guard breaks.
	park(e)
	await frames(25)
	p.invuln = 0.0
	p.stamina = 5.0
	fwd = Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	e = thornling_at(fwd)
	var hp1: int = p.hp
	game.hurt_player(1, e.pos, e)
	check(p.hp == hp1 - 1, "with no stamina left the guard breaks")
	park(e)
	game.block_held = false
	p.exhausted = false
	p.stamina = p.max_stamina
	await frames(3)

	# Holding a block item, right click still places it.
	game.add_item("dirt", 3)
	for i in game.HOTBAR:
		var s = game.slots[i]
		if s != null and s["id"] == "dirt":
			game.select_slot(i)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	mb.pressed = true
	game._unhandled_input(mb)
	check(not game.block_held, "right click with a block in hand places, it doesn't block")
	mb = mb.duplicate()
	mb.pressed = false
	game._unhandled_input(mb)
	# X blocks whatever you hold.
	key(KEY_X, true)
	await frames(2)
	check(game.blocking, "X raises the shield")
	key(KEY_X, false)
	await frames(2)
	check(not game.blocking, "letting go of X lowers it")

	# Iron Shield is better.
	game.add_item("ishield", 1)
	check(game.best_shield().get("id", "") == "ishield", "an Iron Shield replaces the wooden one")
	check(float(game.items["ishield"]["guard"]) < float(game.items["wshield"]["guard"]), "an Iron Shield costs less stamina per block")

	# ------------------------------------------------------------ touch
	var t = game.touch
	t.set_enabled(true)
	await frames(3)
	check(t._buttons.has("map"), "there's a Map button on the phone controls")
	check(t._buttons.has("block"), "there's a Block button once you have a shield")
	touch(3, t._buttons["block"][0], true)
	await frames(3)
	check(game.blocking, "holding Block raises the shield")
	await shot("shield_02_touch")
	touch(3, t._buttons["block"][0], false)
	await frames(3)
	check(not game.blocking, "letting go of Block lowers it")
	# Block must not overlap the other buttons.
	var overlap := false
	var bb: Array = t._buttons["block"]
	for n in t._buttons:
		if n == "block":
			continue
		var o: Array = t._buttons[n]
		if (bb[0] as Vector2).distance_to(o[0]) < bb[1] + o[1]:
			overlap = true
			print("  overlaps " + n)
	check(not overlap, "the Block button doesn't overlap another button")
	touch(4, t._buttons["map"][0], true)
	await frames(2)
	touch(4, t._buttons["map"][0], false)
	await frames(3)
	check(game.hud.screens["map"].visible, "the Map button opens the map")
	await shot("map_03_touch")
	game.toggle_map()
	await frames(2)
	check(game.running, "and the map closes again")
	t.set_enabled(false)

	# ------------------------------------------------------------ saving
	var count_before: int = map.explored_count()
	check(game.save_game(), "saves")
	var scene2 = load("res://main.tscn").instantiate()
	scene2.save_path = SAVE
	game.save_path = ""
	game.queue_free()
	await frames(2)
	root.add_child(scene2)
	game = scene2
	await frames(3)
	check(game.loaded_save, "loads the save")
	check(game.map.explored_count() == count_before, "the explored map comes back (%d of %d)" % [game.map.explored_count(), count_before])
	check(game.map.explored(150, 40), "far places you explored are still on the map")
	check(game.best_shield().get("id", "") == "ishield", "your shield comes back")
	check(game.player.shield.visible, "and shows on your back")

	game.save_path = ""
	DirAccess.remove_absolute(SAVE)
	print("map_shield: %d failed" % fails)
	quit(1 if fails > 0 else 0)
