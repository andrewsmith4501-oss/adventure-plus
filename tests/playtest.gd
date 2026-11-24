extends SceneTree
## Scripted playtest: walks through the quests by teleporting the hero,
## checks each result and saves screenshots to user://shots/.
##
##   godot --path . -s res://tests/playtest.gd
##
## Prints PASS/FAIL lines and exits with code 1 if anything failed.

var game
var frame := 0
var wait := 0
var step := 0
var fails := 0
var shots_dir := "user://shots/"
var steps: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	img.save_png(shots_dir + name + ".png")


func tp(p: Vector3, yaw: float, pitch := -0.2) -> void:
	game.player.pos = p
	game.player.vel = Vector3.ZERO
	game.player.mode = "walk"
	game.player.glider.visible = false
	game.player.cam_yaw = yaw
	game.player.yaw = yaw
	game.player.cam_pitch = pitch
	game.player.cam_cur = game.player.cam_dist


func _init() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	game = scene
	steps = [
		[10, func():
			game._resume()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var b: Vector3 = game.bryn.pos
			tp(game.world.spawn, atan2(-(b.x - game.world.spawn.x), -(b.z - game.world.spawn.z)))],
		[30, func(): shot("01_camp")],
		[2, func():
			tp(game.bryn.pos + Vector3(2.0, 0, 0.3), PI / 2.0)
			],
		[5, func():
			check(game._interaction().get("text", "") == "F  Talk to Bryn", "talk prompt near Bryn: " + str(game._interaction().get("text", "")))
			game._interact()],
		[5, func():
			check(game.talking(), "dialog open")
			shot("02_dialog")
			for i in 4:
				game._advance_dialog()
			check(game.done.has("talk"), "quest step talk")
			check(not game.talking(), "dialog closed")],
		[2, func():
			game.add_item("glider", 1)
			game.complete("glider")
			tp(Vector3(80, 46, 56), PI / 2.0 + 0.0, -0.75)
			game.player.first_person = true],
		[20, func(): shot("03_overview_west")],
		[1, func(): tp(Vector3(80, 46, 56), -PI / 2.0, -0.6)],
		[20, func():
			shot("04_overview_east")
			game.player.first_person = false],
		[1, func():
			var y = game.world.surface_y(108, 60)
			tp(Vector3(108.5, y, 60.5), -PI / 2.0, -0.05)],
		[30, func():
			check(game.region == "steppes", "region steppes: " + game.region)
			check(game.done.has("steppes"), "quest step steppes")
			shot("05_steppes_mesa")],
		[1, func(): tp(Vector3(112.5, game.world.HOLLOW_FY, 59.9), -PI / 2.0, -0.1)],
		[20, func(): shot("06_hollow_entrance")],
		[1, func(): tp(Vector3(122.5, game.world.HOLLOW_FY, 60.0), -PI / 2.0, -0.15)],
		[20, func():
			check(game.region == "hollow", "region hollow: " + game.region)
			check(game.done.has("hollow"), "quest step hollow")
			shot("07_plate_room")
			var plates = game.world.hollow["plates"]
			game.world.set_block(plates[0].x, plates[0].y + 1, plates[0].z, game.world.STONE)
			tp(Vector3(plates[1].x + 0.5, plates[1].y + 1, plates[1].z + 0.5), -PI / 2.0, -0.3)],
		[20, func():
			check(game._plate_state[0] and game._plate_state[1], "both plates pressed " + str(game._plate_state))
			check(game._door_open, "door open")
			check(game.done.has("door"), "quest step door")
			var d = game.world.hollow["door"][0]
			check(game.world.get_b(d.x, d.y, d.z) == 0, "door blocks removed")
			shot("08_door_open")],
		[1, func():
			var v = game.world.hollow["vent"]
			tp(Vector3(v.x + 0.5, v.y + 1.0, v.z + 0.5), -PI / 2.0, 0.6)
			game.player.vel.y = 3.0
			game.player.pos.y += 1.5
			game.player.start_glide()],
		[90, func():
			check(game.player.pos.y > 35.0, "updraft lifted glider to y=%.1f" % game.player.pos.y)
			shot("09_shaft_updraft")],
		[1, func():
			var n = game.world.hollow["node"]
			tp(Vector3(n.x - 0.5, n.y, n.z + 0.5), -PI / 2.0, -0.9)
			game.player.first_person = true],
		[10, func():
			check(game._interaction().get("text", "") == "F  Restore the Thread Node", "node prompt: " + str(game._interaction().get("text", "")))
			shot("10_node")
			game._interact()
			check(game.done.has("node"), "quest step node")],
		[5, func():
			game.player.first_person = false
			var v = game.world.hollow["vent"]
			check(game.world.vent_top(v) > 45.0, "vent column now reaches %.1f" % game.world.vent_top(v))
			tp(Vector3(v.x + 0.5, v.y + 3.0, v.z + 0.5), PI / 2.0, -0.3)
			game.player.start_glide()],
		[150, func():
			check(game.player.pos.y > 42.0, "rode out through the roof to y=%.1f" % game.player.pos.y)
			shot("11_out_of_mesa")],
		[1, func():
			game.player.stop_glide()
			tp(game.bryn.pos + Vector3(2.0, 0, 0.3), PI / 2.0)],
		[5, func():
			game._interact()
			for i in 3:
				game._advance_dialog()
			check(game.done.has("return"), "quest complete")
			check(game.count("vent") == 2, "got 2 vents")
			var names = []
			for r in game._recipe_rows():
				names.append(r["name"])
			check("Updraft Vent" in names, "vent recipe known")],
		[60, func(): shot("12_quest_complete")],
		[1, func():
			var x := 40
			var z := 40
			var y := int(game.world.surface_y(x, z))
			game.world.set_block(x, y, z, game.world.VENT)
			check(game.world.updraft_at(Vector3(x + 0.5, y + 4, z + 0.5)) > 0.0, "placed vent makes an updraft")
			tp(Vector3(x + 4.5, y + 1, z + 0.5), PI / 2.0 + 0.3, -0.1)],
		[20, func(): shot("13_placed_vent")],
		[1, func():
			var y = game.world.surface_y(112, 30)
			tp(Vector3(112.5, y, 30.5), 0.0, -0.1)
			game._gust_next = 0.01],
		[30, func():
			print("gust dbg region=%s sky=%s left=%.2f next=%.2f pos=%s" % [game.region, game.world.open_sky(game.player.pos), game._gust_left, game._gust_next, game.player.pos])
			check(game.player.wind.length() > 0.5, "gust pushes player on the Steppes (%.2f)" % game.player.wind.length())],
		# ---- Wren and the bridge
		[1, func():
			var w: Vector3 = game.wren.pos
			tp(w + Vector3(2.0, 0, 0.5), PI / 2.0, -0.15)
			check(game.world.ford_route().is_empty(), "no dry route across the river at the start")],
		[10, func():
			check(game._interaction().get("text", "") == "F  Talk to Wren", "talk prompt near Wren: " + str(game._interaction().get("text", "")))
			game._interact()
			for i in 4:
				game._advance_dialog()
			check(game.done.has("wren_talk"), "quest step wren_talk")
			check(game.quests[game.tracked]["title"] == "A Bridge for Wren", "tracking the bridge quest")
			game.player.first_person = true
			tp(Vector3(56.5, 15.0, 31.0), PI - 0.15, -0.4)],
		[3, func():
			shot("14_wren_ford")
			game.player.first_person = false
			# Build a plank bridge that ramps evenly from one bank to the other.
			var a: Vector2i = game.world.ford["a"]
			var b: Vector2i = game.world.ford["b"]
			var ya: int = int(game.world.surface_y(a.x, a.y)) - 1
			var yb: int = int(game.world.surface_y(b.x, b.y)) - 1
			for x in range(a.x + 1, b.x):
				var y := maxi(roundi(lerpf(ya, yb, float(x - a.x) / (b.x - a.x))), game.world.WATER)
				for z in [a.y, a.y + 1]:
					game.world.set_block(x, y, z, game.world.PLANKS)
			game.player.pos = Vector3(a.x + 0.5, game.world.surface_y(a.x + 0.5, a.y + 0.5), a.y + 0.5)],
		[60, func():
			check(not game.world.ford_route().is_empty(), "the bridge makes a dry route")
			check(game.done.has("bridge"), "quest step bridge")
			var w: Vector3 = game.wren.pos
			tp(w + Vector3(2.0, 0, 0.5), PI / 2.0, -0.15)],
		[5, func():
			game._interact()
			for i in 3:
				game._advance_dialog()
			check(game.done.has("wren_return"), "bridge quest complete")
			check(game.count("ladder") == 4 and game.count("spring") == 1, "got ladders and a spring pad")
			check(game.wren.walking(), "Wren walks to camp")],
		[150, func():
			game.player.first_person = true
			tp(Vector3(56.5, 14.0, 33.0), PI - 0.1, -0.4)],
		[3, func():
			shot("15_wren_on_bridge")
			game.player.first_person = false],
		[900, func():
			var h: int = game.world.spots["camp_h"]
			var bench := Vector3i(game.world.CAMP_X + 6, h + 1, game.world.CAMP_Z - 3)
			check(game.world.get_b(bench.x, bench.y, bench.z) == game.world.WORKBENCH, "workbench at camp")
			check(game.wren.pos.x < game.world.ford["a"].x - 4, "Wren crossed the river (x=%.1f)" % game.wren.pos.x)
			tp(Vector3(bench.x - 2.5, h + 1, bench.z + 3.5), PI * 0.8, -0.25)
			game.add_item("stick", 3)
			var idx := -1
			var rows: Array = game._recipe_rows()
			for i in rows.size():
				if rows[i]["name"] == "3 Ladder":
					idx = i
			check(idx >= 0 and rows[idx]["ok"], "ladder recipe craftable at the workbench")
			if idx >= 0:
				game._craft(idx)
			check(game.count("ladder") == 7, "crafted 3 ladders (%d)" % game.count("ladder"))],
		[30, func(): shot("16_camp_workbench")],
		# ---- Spring pad
		[1, func():
			var x := 34
			var z := 44
			var y := int(game.world.surface_y(x, z))
			game.world.set_block(x, y, z, game.world.SPRING)
			tp(Vector3(x + 0.5, y + 1.3, z + 0.5), PI / 2.0, -0.1)
			game.set_meta("spring_y", y + 1.0)],
		[4, func():
			var y0: float = game.get_meta("spring_y")
			check(game.player.vel.y > 8.0 or game.player.pos.y > y0 + 2.0, "spring pad launched the hero (vy=%.1f, %.1f above)" % [game.player.vel.y, game.player.pos.y - y0])
			check(game.done.has("spring"), "side goal spring")
			shot("17_spring_launch")],
		# ---- The Hearthroot Shrine
		[60, func():
			var fy: int = game.world.SHRINE_FY
			tp(Vector3(game.world.SHRINE_X0 - 6.5, fy, 86.0), -PI / 2.0 + 0.35, 0.05)],
		[20, func(): shot("18_shrine_outside")],
		[1, func():
			var fy: int = game.world.SHRINE_FY
			tp(Vector3(game.world.SHRINE_X0 + 1.5, fy, 86.0), -PI / 2.0 - 0.5, -0.25)],
		[20, func():
			check(game.region == "shrine", "region shrine: " + game.region)
			check(game.done.has("shrine_find"), "quest step shrine_find")
			shot("19_shrine_room1")
			var c: Vector3i = game._crates[0]
			for i in 3:
				c = game._crates[0]
				tp(Vector3(c.x - 0.5, c.y, c.z + 0.5), -PI / 2.0)
				game._push_crate(c)
			check(game._crates[0] == game.world.shrine["plates"][0] + Vector3i(0, 1, 0), "crate 1 on its plate " + str(game._crates[0]))],
		[10, func():
			check(game._gate1_open, "first gate open")
			# A wrong push, then the tablet puts the crate back.
			var c: Vector3i = game._crates[1]
			tp(Vector3(c.x + 0.5, c.y, c.z - 0.5), 0.0)
			game._push_crate(c)
			check(game._crates[1] != game.world.shrine["crates"][1], "crate moved")
			game._read_tablet("shrine_reset")
			game._advance_dialog()
			game._advance_dialog()
			check(game._crates[1] == game.world.shrine["crates"][1], "reset tablet puts crates back")
			tp(Vector3(game.world.SHRINE_X0 + 9.0, game.world.SHRINE_FY, 86.0), -PI / 2.0 - 0.7, -0.3)],
		[20, func():
			shot("20_crate_hall")
			var pushes := [[1, Vector3i(1, 0, 0)], [1, Vector3i(1, 0, 0)], [1, Vector3i(1, 0, 0)], [1, Vector3i(0, 0, -1)],
				[2, Vector3i(0, 0, 1)], [2, Vector3i(1, 0, 0)], [2, Vector3i(1, 0, 0)], [2, Vector3i(1, 0, 0)], [2, Vector3i(1, 0, 0)]]
			for p in pushes:
				var c: Vector3i = game._crates[p[0]]
				var d: Vector3i = p[1]
				tp(Vector3(c.x + 0.5 - d.x, c.y, c.z + 0.5 - d.z), 0.0)
				game._push_crate(c)
			check(game._crates[1] == game.world.shrine["plates"][1] + Vector3i(0, 1, 0), "crate 2 on its plate " + str(game._crates[1]))
			check(game._crates[2] == game.world.shrine["plates"][2] + Vector3i(0, 1, 0), "crate 3 on its plate " + str(game._crates[2]))
			tp(Vector3(game.world.SHRINE_X0 + 12.5, game.world.SHRINE_FY, 86.0), -PI / 2.0, -0.2)],
		[10, func():
			check(game._gate2_open, "second gate open")
			check(game.done.has("gate2"), "quest step gate2")
			shot("21_crate_hall_solved")
			# Ladders up the smooth ledge.
			var fy: int = game.world.SHRINE_FY
			var lx: int = game.world.SHRINE_X1 - 3
			for y in range(fy, fy + 4):
				game.world.set_block(lx, y, 86, game.world.LADDER)
			tp(Vector3(lx - 0.7, fy, 86.5), -PI / 2.0, 0.1)
			game.player.stamina = game.player.max_stamina
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_W
			ev.pressed = true
			Input.parse_input_event(ev)],
		[40, func(): shot("22_ladder_climb")],
		[140, func():
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_W
			ev.pressed = false
			Input.parse_input_event(ev)
			var fy: int = game.world.SHRINE_FY
			check(game.player.pos.y > fy + 3.5, "climbed the ladder onto the ledge (y=%.2f)" % game.player.pos.y)
			check(game.player.stamina > game.player.max_stamina - 1.0, "ladder costs no stamina (%.1f)" % game.player.stamina)
			var n: Vector3i = game.world.shrine["node"]
			tp(Vector3(n.x - 1.5, n.y, n.z + 0.5), -PI / 2.0, -0.6)
			game.player.first_person = true],
		[10, func():
			check(game._interaction().get("text", "") == "F  Restore the Thread Node", "shrine node prompt: " + str(game._interaction().get("text", "")))
			game._interact()
			check(game.done.has("shrine_node"), "quest step shrine_node")
			var ch: Vector3i = game.world.shrine["chest"]
			var at := Vector3(ch.x - 0.5, ch.y, ch.z - 1.2)
			var to := Vector3(ch) + Vector3(0.5, 0.5, 0.5) - (at + Vector3(0, 1.62, 0))
			tp(at, atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))],
		[20, func():
			check(game._interaction().get("text", "") == "F  Open the chest", "chest prompt: " + str(game._interaction().get("text", "")))
			shot("23_shrine_chest")
			game._interact()
			check(game.done.has("shrine_chest"), "shrine quest complete")
			check(game.player.max_stamina == 125.0, "stamina vessel (%.0f)" % game.player.max_stamina)
			game.player.first_person = false],
		[60, func(): shot("24_shrine_done")],
		# ---- Caches
		[1, func():
			var top: int = game.world.spots["isle_top"]
			tp(Vector3(game.world.ISLE_X - 3.5, top + 1, game.world.ISLE_Z + 3.5), PI * 0.75, -0.3)],
		[20, func(): shot("25_floating_isle")],
		[1, func():
			var c: Vector3i = game.world.spots["cave"]
			game.player.first_person = true
			tp(Vector3(c.x - 2.5, c.y, c.z + 0.5), -PI / 2.0, -0.25)],
		[5, func():
			shot("26_cave")
			game.player.first_person = false
			for k in game.world.chests:
				if game.world.chests[k] != "shrine":
					game._open_chest(k)
			check(game.caches_found == 5, "found all caches (%d)" % game.caches_found)
			check(game.done.has("caches"), "side goal caches")
			check(game.player.max_hp == 12, "heart vessel (%d)" % game.player.max_hp)
			check(game.player.wings, "gale wings")
			check(game.count("bricks") == 8, "bricks from a cache")
			tp(Vector3(108.5, game.world.surface_y(108.5, 36.5), 36.5), 0.0, 0.1)],
		[60, func(): shot("27_caches_hud")],
		[1, func():
			print("RESULT fails=%d" % fails)
			quit(1 if fails > 0 else 0)],
	]


var _armed := false


func _process(_delta: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		return false
	if step >= steps.size():
		return false
	var s = steps[step]
	if not _armed:
		_armed = true
		wait = s[0]
		return false
	_armed = false
	step += 1
	var f: Callable = s[1]
	f.call()
	return false
