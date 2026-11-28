extends SceneTree
## Checks game controller support by sending pretend controller input:
## moving, looking, every button in the world, the inventory, crafting, the
## map and pause menus, dialogue, and the on-screen button names. Saves
## screenshots to user://shots/.
##
##   godot --path . -s res://tests/pad.gd

const SAVE := "user://test_pad.save"

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


func button(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func press(b: JoyButton) -> void:
	button(b, true)
	await frames(2)
	button(b, false)
	await frames(2)


func axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func focus() -> Control:
	return root.get_viewport().gui_get_focus_owner()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in [SAVE, "user://test_pad.settings.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var scene = load("res://main.tscn").instantiate()
	scene.save_path = SAVE
	root.add_child(scene)
	game = scene
	await frames(3)
	var pad = game.pad
	var hud = game.hud
	var p = game.player

	check(pad != null and not pad.enabled, "the controller waits until it is used")
	check(hud.keys_grid.visible and not hud.pad_grid.visible, "the start screen shows the keyboard help")
	check(InputMap.action_has_event("ui_accept", _joy(JOY_BUTTON_A)), "A presses the focused menu button (Godot's ui_accept)")

	# Any controller button switches to the controller.
	button(JOY_BUTTON_LEFT_SHOULDER, true)
	await frames(2)
	button(JOY_BUTTON_LEFT_SHOULDER, false)
	await frames(2)
	check(pad.enabled, "pressing a controller button switches to the controller")
	check(hud.pad_grid.visible and not hud.keys_grid.visible and not hud.touch_grid.visible, "the start screen shows the controller help")
	check(focus() == hud.play_button, "Play has the focus on the start screen")
	shot("pad_01_start")
	await press(JOY_BUTTON_START)
	check(game.running, "Start begins the game")
	await settle()

	check(hud.prompt_key("use") == "X" and hud.prompt_key("jump") == "A", "prompts name Xbox buttons")
	check(hud.goals_box != null, "the quest panel exists")
	hud.set_prompt("F  Talk to Bryn")
	check(hud.prompt_label.text == "X  Talk to Bryn", "the use prompt names the X button (%s)" % hud.prompt_label.text)
	check(game.pad.style_of("PS5 Controller") == "ps" and game.pad.style_of("DualSense Wireless Controller") == "ps", "PlayStation pads are recognised")
	check(game.pad.style_of("Nintendo Switch Pro Controller") == "nintendo", "Switch pads are recognised")
	check(game.pad.style_of("Xbox Wireless Controller") == "xbox", "Xbox pads are recognised")
	pad.style = "ps"
	hud.set_pad_mode(true)
	check(hud.prompt_key("use") == "Square" and hud.prompt_label.text == "Square  Talk to Bryn", "a PlayStation pad says Square")
	pad.style = "nintendo"
	hud.set_pad_mode(true)
	check(hud.prompt_key("jump") == "B" and pad.label("rt") == "ZR", "a Switch pad says B and ZR")
	pad.style = "xbox"
	hud.set_pad_mode(true)
	hud.set_prompt("")

	# Move with the left stick.
	p.cam_yaw = p.yaw
	var start: Vector3 = p.pos
	var fwd: Vector3 = p.forward_flat()
	axis(JOY_AXIS_LEFT_Y, -1.0)
	await frames(40)
	check(pad.move.y > 0.9, "pushing the left stick up walks forward (%.2f)" % pad.move.y)
	check((p.pos - start).dot(fwd) > 1.0, "the hero walks where the camera faces (%.2f)" % (p.pos - start).dot(fwd))
	axis(JOY_AXIS_LEFT_Y, 0.1)
	await frames(2)
	check(pad.move == Vector2.ZERO, "a stick resting near the middle doesn't drift")
	axis(JOY_AXIS_LEFT_Y, 0.0)

	# Sprint with B or by clicking the stick.
	button(JOY_BUTTON_B, true)
	await frames(2)
	check(pad.sprint, "holding B sprints")
	button(JOY_BUTTON_B, false)
	await frames(2)
	check(not pad.sprint, "letting go of B stops sprinting")
	axis(JOY_AXIS_LEFT_Y, -1.0)
	await press(JOY_BUTTON_LEFT_STICK)
	check(pad.sprint, "clicking the left stick sprints")
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(2)
	check(not pad.sprint, "stopping ends the stick-click sprint")

	# Look around with the right stick.
	var yaw0: float = p.cam_yaw
	var pitch0: float = p.cam_pitch
	axis(JOY_AXIS_RIGHT_X, 1.0)
	axis(JOY_AXIS_RIGHT_Y, -1.0)
	await frames(20)
	axis(JOY_AXIS_RIGHT_X, 0.0)
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	check(p.cam_yaw < yaw0 - 0.3, "right stick right turns the camera right")
	check(p.cam_pitch > pitch0, "right stick up looks up")

	# Jump with A.
	await frames(30)
	check(p.grounded, "standing on the ground")
	button(JOY_BUTTON_A, true)
	await frames(6)
	check(not p.grounded and p.vel.y > 0.0, "A jumps")
	button(JOY_BUTTON_A, false)
	await frames(60)

	# Triggers: break / attack, and place or shield.
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	check(game.mouse_down, "holding RT breaks / attacks")
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await frames(2)
	check(not game.mouse_down, "letting go of RT stops")
	game.add_item("wshield", 1)
	game.select_slot(8)
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await frames(4)
	check(game.block_held and game.blocking, "holding LT raises the shield")
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await frames(2)
	check(not game.block_held, "letting go of LT lowers it")
	game.slots[0] = {"id": "planks", "n": 5}
	game.select_slot(0)
	# Aim at the ground a step ahead, in first person so the hero isn't in the way.
	var was_fp: bool = p.first_person
	p.first_person = true
	p.cam_pitch = -0.9
	for i in 60:
		if p.grounded:
			break
		await frames(1)
	await frames(3)
	var before: int = game.count("planks")
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await frames(3)
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await frames(2)
	check(game.count("planks") == before - 1, "LT with a block in hand places it instead of raising the shield (planks %d -> %d)" % [before, game.count("planks")])
	check(not game.block_held, "LT with a block doesn't raise the shield")
	p.first_person = was_fp

	# Hotbar with the bumpers.
	game.select_slot(3)
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.sel == 4, "RB picks the next hotbar slot")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(game.sel == 2, "LB picks the slot before")

	# D-pad: quest, view.
	var tracked: int = game.tracked
	await press(JOY_BUTTON_DPAD_UP)
	check(game.tracked != tracked or game.quests.size() < 2, "D-pad up switches quest")
	var fp: bool = p.first_person
	await press(JOY_BUTTON_DPAD_DOWN)
	check(p.first_person != fp, "D-pad down switches the camera")
	await press(JOY_BUTTON_RIGHT_STICK)
	check(p.first_person == fp, "clicking the right stick switches it back")

	# Climb with Y.
	await press(JOY_BUTTON_Y)
	check(p.mode == "walk", "Y with no wall in front stays walking")

	# Inventory: D-pad right opens it, the D-pad moves, A picks up and puts down.
	game.slots[9] = {"id": "stone", "n": 10}
	game.slots[10] = null
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(hud.screens["inv"].visible and not game.running, "D-pad right opens the inventory")
	pad.inv_slot = 0
	hud.pad_slot = 0
	await press(JOY_BUTTON_DPAD_UP)
	check(pad.inv_slot == 27, "D-pad up from the hotbar goes to the bottom pack row (%d)" % pad.inv_slot)
	await press(JOY_BUTTON_DPAD_UP)
	await press(JOY_BUTTON_DPAD_UP)
	check(pad.inv_slot == 9, "and on up to the top-left pack slot (%d)" % pad.inv_slot)
	check(hud.prompt_key("use") == "X", "still in controller mode")
	await press(JOY_BUTTON_A)
	check(game.cursor != null and game.cursor["id"] == "stone" and game.slots[9] == null, "A picks up the stack")
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(pad.inv_slot == 10, "D-pad right moves along the row")
	await press(JOY_BUTTON_X)
	check(game.slots[10] != null and int(game.slots[10]["n"]) == 1 and int(game.cursor["n"]) == 9, "X puts down one")
	await press(JOY_BUTTON_A)
	check(game.cursor == null and int(game.slots[10]["n"]) == 10, "A puts the rest down on the same kind")
	shot("pad_02_inventory")
	await press(JOY_BUTTON_Y)
	check(game.slots[10] == null and game.count("stone") == 10, "Y quick-moves the stack to the hotbar")
	axis(JOY_AXIS_LEFT_Y, 1.0)
	await frames(3)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await frames(2)
	check(pad.inv_slot == 19, "the left stick moves too (%d)" % pad.inv_slot)
	game.slots[9] = {"id": "dirt", "n": 3}
	pad.inv_slot = 9
	await press(JOY_BUTTON_A)
	pad.inv_slot = 8
	for i in 3:
		await press(JOY_BUTTON_DPAD_DOWN)
	check(pad.inv_slot == -1, "below the hotbar is the bin")
	await press(JOY_BUTTON_A)
	check(game.cursor == null and game.count("dirt") == 0, "A on the bin throws the stack away")
	await press(JOY_BUTTON_B)
	check(game.running and not hud.screens["inv"].visible, "B goes back to the world")

	# Crafting: D-pad left opens it with a recipe focused; B closes.
	await press(JOY_BUTTON_DPAD_LEFT)
	check(hud.screens["craft"].visible, "D-pad left opens crafting")
	var f := focus()
	check(f is Button and hud.screens["craft"].is_ancestor_of(f), "a crafting button has the focus")
	game.add_item("planks", 4)
	game.add_item("leaves", 8)
	hud.render_recipes(game._recipe_rows())
	await frames(2)
	check(focus() is Button, "the focus stays on a recipe after the list redraws")
	shot("pad_03_craft")
	await press(JOY_BUTTON_B)
	check(game.running and not hud.screens["craft"].visible, "B closes crafting")

	# Map: View opens it, the triggers zoom, the sticks pan, B closes.
	await press(JOY_BUTTON_BACK)
	check(hud.screens["map"].visible, "View opens the map")
	var mv = hud.map_view
	var z0: float = mv.zoom
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await frames(2)
	check(mv.zoom > z0, "RT zooms the map in")
	var c0: Vector2 = mv.center
	axis(JOY_AXIS_LEFT_X, 1.0)
	await frames(10)
	axis(JOY_AXIS_LEFT_X, 0.0)
	check(mv.center.x > c0.x + 1.0, "the left stick pans the map")
	await press(JOY_BUTTON_Y)
	check(mv.follow, "Y finds you again")
	await press(JOY_BUTTON_B)
	check(game.running and not hud.screens["map"].visible, "B closes the map")

	# Dialogue: A moves on, B skips.
	game._say("Bryn", ["One.", "Two.", "Three."])
	await frames(2)
	check(hud.dialog_hint.text == "A to continue", "the dialogue says A to continue")
	await press(JOY_BUTTON_A)
	check(game._dialog_i == 1, "A moves the dialogue on")
	await press(JOY_BUTTON_B)
	check(not game.talking(), "B skips the rest")

	# Pause with Start; the menu is driven by the D-pad and A.
	await press(JOY_BUTTON_START)
	check(hud.screens["start"].visible and not game.running, "Start pauses")
	check(focus() == hud.play_button, "Resume has the focus")
	await press(JOY_BUTTON_B)
	check(game.running, "B resumes from the pause menu")
	await press(JOY_BUTTON_START)
	button(JOY_BUTTON_A, true)
	await frames(2)
	button(JOY_BUTTON_A, false)
	await frames(3)
	check(game.running, "A on Resume resumes")
	await frames(10)
	check(p.grounded or p.vel.y <= 0.5, "pressing A on the menu doesn't also jump")

	# Knocked out: Get up has the focus.
	p.invuln = 0.0
	game.hurt_player(99, null)
	await frames(2)
	check(hud.screens["dead"].visible and focus() == hud.respawn_button, "Get up has the focus when knocked out")
	button(JOY_BUTTON_A, true)
	await frames(2)
	button(JOY_BUTTON_A, false)
	await frames(3)
	check(game.running and not p.dead, "A gets up")

	# The keyboard takes back over.
	key(KEY_W)
	await frames(2)
	check(not pad.enabled and hud.prompt_key("use") == "F", "pressing a key switches back to keyboard prompts")
	game.running = false
	hud.show_screen("start")
	await frames(2)
	check(hud.keys_grid.visible and not hud.pad_grid.visible, "and the keyboard help")

	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _joy(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	return e
