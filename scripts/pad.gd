extends Node
## Game controller (gamepad) support: Xbox, PlayStation, Switch and most
## Bluetooth or USB pads, on a computer or an Android phone.
##
## In the world:
##   Left stick   move (click it to toggle sprint)   Right stick  look (click: camera)
##   A            jump / glider / leap up a wall     B            hold to sprint, let go
##   X            talk, read, use, push              Y            climb / let go
##   RT           hold to break, press to attack     LT           place the block, or raise the shield
##   LB / RB      hotbar left / right                D-pad        quest, camera, craft, inventory
##   View/Back    map                                Menu/Start   pause
##
## Menus are moved through with the D-pad or left stick, A picks, B goes back.
## The game switches to controller prompts as soon as a pad is used, and back
## to keyboard or touch prompts when those are used.

const DEAD := 0.2
const TRIGGER := 0.45
const LOOK_SPEED := 3.0  # radians a second with the stick all the way over
const PITCH_SPEED := 2.0
const MAP_PAN := 260.0  # screen pixels a second
const NAV_FIRST := 0.32
const NAV_REPEAT := 0.11

## The game (game.gd). Set before add_child.
var game: Node
## True while the controller is the input in use.
var enabled := false
## "xbox", "ps" or "nintendo": which names the buttons get on screen.
var style := "xbox"
## Left stick: x is right, y is forward, length up to 1.
var move := Vector2.ZERO
var sprint := false
var jump_held := false
## The inventory slot picked with the controller (0..35, -1 is the bin).
var inv_slot := 0

var _sprint_latch := false
var _sprint_b := false
## Pads that sent input (also pretend ones in the tests).
var _seen: Array[int] = []
var _rt := false
var _lt := false
var _nav_dir := Vector2i.ZERO
var _nav_t := 0.0
## Time (msec) the last controller button went down, so Android's back
## gesture that some pads send with B doesn't pause the game.
var last_button_ms := -100000


static func style_of(joy_name: String) -> String:
	var n := joy_name.to_lower()
	if n.contains("xbox") or n.contains("xinput"):
		return "xbox"
	for k in ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony", "wireless controller"]:
		if n.contains(k):
			return "ps"
	for k in ["nintendo", "switch", "joy-con", "joycon", "pro controller"]:
		if n.contains(k):
			return "nintendo"
	return "xbox"


## What a button is called on the controller in use, for on-screen prompts.
## b: a JoyButton, or "lt" / "rt" / "dpad".
func label(b) -> String:
	if b is String:
		match b:
			"lt":
				return {"ps": "L2", "nintendo": "ZL"}.get(style, "LT")
			"rt":
				return {"ps": "R2", "nintendo": "ZR"}.get(style, "RT")
			"dpad":
				return "D-pad"
			"lstick":
				return "Left stick"
			"rstick":
				return "Right stick"
		return str(b)
	var names := {
		"xbox": ["A", "B", "X", "Y", "View", "Guide", "Menu", "LS", "RS", "LB", "RB"],
		# Godot names buttons by where they sit: the bottom one is Cross on a
		# PlayStation pad and B on a Nintendo one.
		"ps": ["Cross", "Circle", "Square", "Triangle", "Create", "PS", "Options", "L3", "R3", "L1", "R1"],
		"nintendo": ["B", "A", "Y", "X", "-", "Home", "+", "LS", "RS", "L", "R"],
	}
	var dpad := ["D-pad up", "D-pad down", "D-pad left", "D-pad right"]
	var i: int = b
	if i >= JOY_BUTTON_DPAD_UP and i <= JOY_BUTTON_DPAD_RIGHT:
		return dpad[i - JOY_BUTTON_DPAD_UP]
	var list: Array = names[style]
	return list[i] if i >= 0 and i < list.size() else "Button %d" % i


func set_enabled(on: bool, device := -1) -> void:
	if device >= 0:
		var s := style_of(Input.get_joy_name(device))
		if s != style:
			style = s
			if enabled and game != null and game.hud != null:
				game.hud.set_pad_mode(true)
	if on == enabled:
		return
	enabled = on
	_release_all()
	if on and game != null and game.touch != null:
		game.touch.set_enabled(false)
	if game != null and game.hud != null:
		game.hud.set_pad_mode(on)
		game.refresh_prompts()


func _release_all() -> void:
	move = Vector2.ZERO
	sprint = false
	jump_held = false
	_sprint_latch = false
	_sprint_b = false
	_rt = false
	_lt = false
	if game != null:
		game.mouse_down = false
		game.block_held = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Godot's menus only take Enter and Space to press a button by default:
	# let A (the bottom face button) press it too, and B mean back.
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var e := InputEventJoypadButton.new()
		e.device = -1
		e.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], e):
			InputMap.action_add_event(pair[0], e)
	Input.joy_connection_changed.connect(_on_joy_connection)


func _on_joy_connection(device: int, connected: bool) -> void:
	if not connected and enabled and Input.get_connected_joypads().is_empty():
		set_enabled(false)
	elif connected and enabled:
		set_enabled(true, device)


func _world_active() -> bool:
	return game != null and game.running and not game.player.dead


static func _stick(x: float, y: float) -> Vector2:
	var v := Vector2(x, y)
	var l := v.length()
	if l < DEAD:
		return Vector2.ZERO
	return v / l * minf(1.0, (l - DEAD) / (1.0 - DEAD))


func _axis(a: JoyAxis) -> float:
	var best := 0.0
	var devs := Input.get_connected_joypads()
	for d in _seen:
		if not devs.has(d):
			devs.append(d)
	for d in devs:
		var v := Input.get_joy_axis(d, a)
		if absf(v) > absf(best):
			best = v
	return best


func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and not _seen.has(event.device):
		_seen.append(event.device)
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed:
			last_button_ms = Time.get_ticks_msec()
			if not enabled:
				set_enabled(true, jb.device)
		if game == null:
			return
		if _handle_button(jb.button_index, jb.pressed):
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if absf(jm.axis_value) > 0.5 and not enabled:
			set_enabled(true, jm.device)
		if game == null or not enabled:
			return
		if jm.axis == JOY_AXIS_TRIGGER_RIGHT or jm.axis == JOY_AXIS_TRIGGER_LEFT:
			var right := jm.axis == JOY_AXIS_TRIGGER_RIGHT
			var was := _rt if right else _lt
			var now := jm.axis_value > (TRIGGER - 0.1 if was else TRIGGER)
			if now != was:
				if right:
					_rt = now
				else:
					_lt = now
				_handle_trigger(right, now)
		# While the inventory or map is open the sticks are read here, not by
		# the menus' own focus moving.
		if _screen_open("inv") or _screen_open("map"):
			get_viewport().set_input_as_handled()
	elif enabled:
		if event is InputEventKey and event.pressed:
			set_enabled(false)
		elif event is InputEventScreenTouch:
			set_enabled(false)
		elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
			if (event as InputEventMouseMotion).relative.length() > 4.0:
				set_enabled(false)
		elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed:
			set_enabled(false)


func _screen_open(key: String) -> bool:
	return game != null and game.hud != null and game.hud.screens[key].visible


## Returns true when the button was used up here (and should not move the
## focus in a menu).
func _handle_button(b: int, down: bool) -> bool:
	if _screen_open("inv"):
		if down:
			_inv_button(b)
		return true
	if _screen_open("map"):
		if down:
			_map_button(b)
		return true
	if not game.running:
		if not down:
			return false
		if b == JOY_BUTTON_B and _screen_open("craft"):
			game.close_menu()
			return true
		if b == JOY_BUTTON_START and _screen_open("start"):
			game.hud.play_pressed.emit()
			return true
		if b == JOY_BUTTON_B and _screen_open("start") and game.started:
			game.hud.play_pressed.emit()
			return true
		return false
	if game.player.dead:
		return false
	if game.talking():
		if down and (b == JOY_BUTTON_A or b == JOY_BUTTON_X):
			game.advance_dialog()
		elif down and b == JOY_BUTTON_B:
			game.skip_dialog()
		return true
	match b:
		JOY_BUTTON_A:
			if down:
				game.jump_pressed = true
			jump_held = down
		JOY_BUTTON_B:
			_sprint_b = down
			if down:
				_sprint_latch = false
		JOY_BUTTON_LEFT_STICK:
			if down:
				_sprint_latch = not _sprint_latch
		_:
			if not down:
				return true
			match b:
				JOY_BUTTON_X:
					game.interact()
				JOY_BUTTON_Y:
					game.player.toggle_climb()
				JOY_BUTTON_LEFT_SHOULDER:
					game.select_slot(game.sel - 1)
				JOY_BUTTON_RIGHT_SHOULDER:
					game.select_slot(game.sel + 1)
				JOY_BUTTON_START:
					game.pause()
				JOY_BUTTON_BACK:
					game.toggle_map()
				JOY_BUTTON_DPAD_UP:
					game.cycle_quest()
				JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_RIGHT_STICK:
					game.toggle_view()
				JOY_BUTTON_DPAD_LEFT:
					game.toggle_craft()
				JOY_BUTTON_DPAD_RIGHT:
					game.toggle_inventory()
	return true


func _handle_trigger(right: bool, down: bool) -> void:
	if _screen_open("map"):
		if down:
			game.hud.map_view.zoom_by(1.5 if right else 1.0 / 1.5)
		return
	if not _world_active() or game.talking():
		if not down:
			game.mouse_down = false
			game.block_held = false
		return
	if right:
		game.mouse_down = down
		if down:
			game.set("_deny_warned", false)
	elif not down:
		game.block_held = false
	elif game.sel_item().has("block"):
		game.place_block()
	else:
		game.block_held = true


# ---------------------------------------------------------------- inventory

## Inventory layout on screen: three rows of nine (the pack, slots 9..35),
## then the hotbar (0..8), then the bin (-1) below.
func _inv_cell(i: int) -> Vector2i:
	if i < 0:
		return Vector2i(0, 4)
	if i < 9:
		return Vector2i(i, 3)
	return Vector2i((i - 9) % 9, (i - 9) / 9)


func _inv_index(c: Vector2i) -> int:
	if c.y >= 4:
		return -1
	if c.y == 3:
		return c.x
	return 9 + c.y * 9 + c.x


func inv_move(d: Vector2i) -> void:
	var c := _inv_cell(inv_slot)
	if inv_slot < 0:
		if d.y < 0:
			inv_slot = 0
		_inv_changed()
		return
	c.x = posmod(c.x + d.x, 9)
	c.y = clampi(c.y + d.y, 0, 4)
	inv_slot = _inv_index(c)
	_inv_changed()


func _inv_changed() -> void:
	game.hud.pad_slot = inv_slot
	game.hud.refresh_pad_slot()
	game.audio.play("ui_click", -14.0, 0.05)


func _inv_button(b: int) -> void:
	match b:
		JOY_BUTTON_A:
			game.inv_click(inv_slot, MOUSE_BUTTON_LEFT, false)
		JOY_BUTTON_X:
			game.inv_click(inv_slot, MOUSE_BUTTON_RIGHT, false)
		JOY_BUTTON_Y:
			game.inv_click(inv_slot, MOUSE_BUTTON_LEFT, true)
		JOY_BUTTON_B, JOY_BUTTON_START:
			game.close_menu()
		JOY_BUTTON_DPAD_UP:
			inv_move(Vector2i(0, -1))
		JOY_BUTTON_DPAD_DOWN:
			inv_move(Vector2i(0, 1))
		JOY_BUTTON_DPAD_LEFT:
			inv_move(Vector2i(-1, 0))
		JOY_BUTTON_DPAD_RIGHT:
			inv_move(Vector2i(1, 0))
		JOY_BUTTON_LEFT_SHOULDER:
			inv_move(Vector2i(-1, 0))
		JOY_BUTTON_RIGHT_SHOULDER:
			inv_move(Vector2i(1, 0))


func _map_button(b: int) -> void:
	match b:
		JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_START:
			game.close_menu()
		JOY_BUTTON_Y, JOY_BUTTON_A:
			game.hud.map_view.recenter()
		JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP:
			game.hud.map_view.zoom_by(1.5)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_DOWN:
			game.hud.map_view.zoom_by(1.0 / 1.5)


# ---------------------------------------------------------------- every frame

func _process(dt: float) -> void:
	if game == null or not enabled:
		return
	var l := _stick(_axis(JOY_AXIS_LEFT_X), _axis(JOY_AXIS_LEFT_Y))
	var r := _stick(_axis(JOY_AXIS_RIGHT_X), _axis(JOY_AXIS_RIGHT_Y))
	if _screen_open("inv"):
		_stick_nav(l, dt)
		move = Vector2.ZERO
		return
	if _screen_open("map"):
		var pan := l + r
		if pan.length_squared() > 0.0:
			var mv = game.hud.map_view
			mv.center += pan * MAP_PAN * dt / mv.zoom
			mv.follow = false
			mv.queue_redraw()
		move = Vector2.ZERO
		return
	if not _world_active() or game.talking():
		move = Vector2.ZERO
		return
	move = Vector2(l.x, -l.y)
	if l == Vector2.ZERO:
		_sprint_latch = false
	sprint = _sprint_b or _sprint_latch
	if r != Vector2.ZERO:
		var pl = game.player
		# A gentle curve: small tilts aim finely, a full tilt turns fast.
		var cx := r.x * absf(r.x)
		var cy := r.y * absf(r.y)
		pl.cam_yaw -= cx * LOOK_SPEED * dt
		var top := 1.5 if pl.first_person else 1.1
		pl.cam_pitch = clampf(pl.cam_pitch - cy * PITCH_SPEED * dt, -1.45, top)


## The left stick moves the inventory selection, repeating while held.
func _stick_nav(l: Vector2, dt: float) -> void:
	var d := Vector2i.ZERO
	if l.length() > 0.5:
		if absf(l.x) > absf(l.y):
			d.x = 1 if l.x > 0 else -1
		else:
			d.y = 1 if l.y > 0 else -1
	if d == Vector2i.ZERO:
		_nav_dir = d
		return
	if d != _nav_dir:
		_nav_dir = d
		_nav_t = NAV_FIRST
		inv_move(d)
		return
	_nav_t -= dt
	if _nav_t <= 0.0:
		_nav_t = NAV_REPEAT
		inv_move(d)
