extends SceneTree
## Scripted playtest: walks through the first quest by teleporting the hero,
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
