extends SceneTree
## Checks the phone controls by sending pretend finger touches: the move
## stick, looking around, the buttons, the hotbar, the inventory tap modes and
## the phone graphics setting. Saves screenshots to user://shots/ of the HUD
## at a phone's shape.
##
##   godot --path . -s res://tests/touch.gd

const SAVE := "user://test_touch.save"

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


func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func drag(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func tap(name: String) -> void:
	var b: Array = game.touch._buttons[name]
	touch(7, b[0], true)
	await frames(2)
	touch(7, b[0], false)
	await frames(2)


func btn(name: String) -> Vector2:
	return game.touch._buttons[name][0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in [SAVE, "user://test_touch.settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	game = scene
	await frames(3)
	game._resume()
	await settle()
	var t = game.touch
	var p = game.player

	check(not t.enabled and not t.visible, "touch controls stay hidden on a computer")
	check(game.graphics == "high" and game.world.view == 10, "a computer starts on high graphics")
	var high_meshes: int = game.world.stream_stats()["meshes"]

	# The first touch brings the controls up.
	var sz: Vector2 = t._draw.size
	var stick := Vector2(200, sz.y - 160)
	touch(0, stick, true)
	await frames(2)
	check(t.enabled and t.visible, "touching the screen shows the controls")
	check(game.hud.touch_grid.visible and not game.hud.keys_grid.visible, "help switches to the touch controls")
	drag(0, stick + Vector2(0, -60), Vector2(0, -60))
	await frames(1)
	check(t.move.y > 0.5 and absf(t.move.x) < 0.1, "pushing the stick up walks forward (%.2f)" % t.move.y)
	var start: Vector3 = p.pos
	var fwd: Vector3 = p.forward_flat()
	await frames(40)
	var moved: Vector3 = p.pos - start
	check(moved.dot(fwd) > 1.0, "the hero walks where the camera faces (%.2f)" % moved.dot(fwd))
	drag(0, stick + Vector2(30, -20), Vector2(30, 40))
	await frames(1)
	check(t.move.x > 0.2, "the stick steers right")
	drag(0, stick + Vector2(400, 0), Vector2(370, 20))
	await frames(1)
	check(t.move.length() <= 1.01 and t.move.x > 0.9, "the stick follows a finger past its edge")
	touch(0, stick, false)
	await frames(2)
	check(t.move == Vector2.ZERO, "letting go stops")

	# Look around with a second finger while walking.
	touch(0, stick, true)
	drag(0, stick + Vector2(0, -60), Vector2(0, -60))
	var yaw0: float = p.cam_yaw
	var look := Vector2(sz.x * 0.6, sz.y * 0.35)
	touch(1, look, true)
	drag(1, look + Vector2(120, 0), Vector2(120, 0))
	await frames(2)
	check(p.cam_yaw < yaw0 - 0.3, "dragging the right side turns the camera")
	check(t.move.y > 0.5, "walking keeps going while looking")
	touch(1, look, false)
	touch(0, stick, false)
	await frames(2)

	# Jump.
	await frames(20)
	check(p.grounded, "standing on the ground")
	touch(2, btn("jump"), true)
	await frames(6)
	check(not p.grounded and p.vel.y > 0.0, "Jump jumps")
	touch(2, btn("jump"), false)
	await frames(60)

	# Sprint is held.
	touch(3, btn("sprint"), true)
	await frames(1)
	check(t.sprint, "holding Sprint sprints")
	touch(3, btn("sprint"), false)
	await frames(1)
	check(not t.sprint, "letting go of Sprint stops")

	# Hotbar slots can be tapped.
	await frames(2)
	var live: Array = []
	for c in game.hud.hotbar.get_children():
		if not c.is_queued_for_deletion():
			live.append(c)
	var slot_at: Vector2 = (live[3] as Control).get_global_rect().get_center()
	touch(4, slot_at, true)
	await frames(1)
	touch(4, slot_at, false)
	check(game.sel == 3, "tapping a hotbar slot selects it")

	# Hit breaks the block you aim at; Place puts one back.
	p.first_person = true
	p.cam_pitch = -1.2
	await frames(3)
	var tg: Dictionary = game._current_target()
	check(tg.has("block"), "aiming at the ground")
	if tg.has("block"):
		var bp: Vector3i = tg["block"]["pos"]
		var before: int = game.world.get_b(bp.x, bp.y, bp.z)
		touch(5, btn("hit"), true)
		await frames(2)
		check(game.mouse_down, "holding Hit is like holding the mouse button")
		var t0 := Time.get_ticks_msec()
		while game.world.get_b(bp.x, bp.y, bp.z) != World_AIR() and Time.get_ticks_msec() - t0 < 6000:
			await frames(5)
		touch(5, btn("hit"), false)
		await frames(2)
		check(not game.mouse_down, "letting go of Hit stops")
		check(game.world.get_b(bp.x, bp.y, bp.z) == 0, "Hit broke the block (was %d)" % before)
		game.add_item("dirt", 3)
		for s in 9:
			if game.slots[s] != null and game.slots[s]["id"] == "dirt":
				game.select_slot(s)
		var n0: int = game.count("dirt")
		await tap("place")
		check(game.count("dirt") == n0 - 1, "Place placed a block")
	p.first_person = false

	# A tap on the screen also arrives as a pretend mouse click: it must not
	# break blocks.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.device = InputEvent.DEVICE_ID_EMULATION
	Input.parse_input_event(mb)
	Input.flush_buffered_events()
	await frames(1)
	check(not game.mouse_down, "pretend mouse clicks from taps are ignored in the world")
	mb = mb.duplicate()
	mb.pressed = false
	Input.parse_input_event(mb)

	# Glide and Climb.
	await tap("glide")
	check(p.mode != "glide", "Glide on the ground does not open the glider")
	game.add_item("glider", 1)
	p.pos.y += 14.0
	p.vel = Vector3.ZERO
	p.grounded = false
	await frames(10)
	await tap("glide")
	check(p.mode == "glide", "Glide in the air opens the glider")
	await tap("glide")
	check(p.mode != "glide", "Glide again closes it")
	await frames(120)

	# Screens.
	await tap("inv")
	check(game.hud.screens["inv"].visible and not t.visible, "Bag opens the inventory and hides the controls")
	check(game.hud.tap_button.visible, "the inventory has a tap mode button on a phone")
	shot("touch_inventory")
	game.hud._cycle_tap_mode()
	check(game.hud.tap_mode == 1, "tap mode switches to take half")
	game.hud._cycle_tap_mode()
	game.hud._cycle_tap_mode()
	game._resume()
	await frames(3)
	await tap("craft")
	check(game.hud.screens["craft"].visible, "Craft opens crafting")
	game._resume()
	await frames(3)
	var q0: int = game.tracked
	await tap("quest")
	check(game.tracked != q0 or game.quests.size() < 2, "Quest switches the tracked quest")
	await tap("view")
	check(p.first_person, "View switches to first person")
	await tap("view")
	await tap("pause")
	check(game.hud.screens["start"].visible and not game.running, "II pauses")
	check(game.hud.dialog_hint.text == "Tap to continue", "dialog says tap to continue")
	game._resume()
	await frames(3)

	# Phone graphics.
	game.set_graphics("phone")
	await frames(2)
	check(game.world.view == 5 and not game.world.plants, "phone graphics load less and skip plants")
	check(root.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "phone graphics turn off anti-aliasing")
	check(FileAccess.file_exists("user://test_touch.settings.cfg"), "the graphics choice is saved")
	await settle()
	var st: Dictionary = game.world.stream_stats()
	await frames(70)
	st = game.world.stream_stats()
	print("  chunks drawn: high %d, phone %d" % [high_meshes, st["meshes"]])
	check(st["meshes"] < high_meshes * 0.75, "fewer chunks are drawn")

	# Phone-shaped screen: the HUD and buttons at a Pixel's 20:9.
	var win := root
	DisplayServer.window_set_size(Vector2i(1428, 640))
	win.size = Vector2i(1428, 640)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(1280, 720)
	await frames(10)
	p.pos = game.world.spawn
	p.cam_pitch = -0.25
	await settle()
	await frames(10)
	shot("touch_hud_phone")
	var jb: Vector2 = btn("jump")
	check(jb.x > 1280 and jb.x < t._draw.size.x, "buttons sit at the right edge of a wide phone (%.0f of %.0f)" % [jb.x, t._draw.size.x])
	# Phone-shaped look at a tap through the content scale.
	touch(6, Vector2(1428 * 0.1, 640 * 0.85), true)
	await frames(1)
	check(t._fingers.get(6, "") == "stick", "a touch at the bottom left of the phone grabs the stick")
	touch(6, Vector2(1428 * 0.1, 640 * 0.85), false)
	game._pause()
	await frames(5)
	shot("touch_start_phone")
	game._resume()
	await frames(3)

	# Pressing a key goes back to keyboard and mouse.
	var k := InputEventKey.new()
	k.physical_keycode = KEY_W
	k.keycode = KEY_W
	k.pressed = true
	Input.parse_input_event(k)
	Input.flush_buffered_events()
	await frames(2)
	check(not t.enabled and not t.visible, "a key press hides the touch controls")
	check(not game.hud.touch_grid.visible, "help switches back to the keys")
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)

	game.set_graphics("high")
	check(game.world.view == 10 and game.world.plants, "high graphics come back")
	game.save_path = ""
	print("touch: %d failed" % fails)
	quit(1 if fails > 0 else 0)


func World_AIR() -> int:
	return 0
