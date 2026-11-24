extends CanvasLayer
## On-screen controls for phones and tablets: a move stick on the left, drag
## anywhere else to look around, and buttons for everything the keyboard and
## mouse do. Every finger is tracked on its own, so you can walk, look and
## jump at the same time.
##
## On a computer they stay hidden until the screen is touched, and hide again
## as soon as a key is pressed.

const STICK_R := 74.0
const DEAD := 0.18
const LOOK_SPEED := 0.0055

## The game (game.gd). Set before add_child.
var game: Node
## True while the controls are shown and read.
var enabled := false
## Stick: x is right, y is forward, length up to 1.
var move := Vector2.ZERO
var sprint := false
var jump_held := false

## finger index -> "stick", "look" or a button name
var _fingers := {}
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_last := {}
var _draw: Control
var _font: Font
## name -> [center, radius, label, kind]   (kind: "tap", "hold" or "small")
var _buttons := {}
var _order: Array = []


func _ready() -> void:
	layer = 5
	_font = ThemeDB.fallback_font
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_paint)
	add_child(_draw)
	visible = false
	if OS.has_feature("mobile"):
		set_enabled(true)


func set_enabled(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	_release_all()
	if game != null and game.hud != null:
		game.hud.set_touch_mode(on)


func _release_all() -> void:
	_fingers.clear()
	_look_last.clear()
	move = Vector2.ZERO
	sprint = false
	jump_held = false
	if game != null:
		game.mouse_down = false


## Lays the buttons out for the current screen size (in UI units).
func _layout() -> void:
	var sz: Vector2 = _draw.size
	_buttons.clear()
	var r := 46.0
	var br := sz - Vector2(78, 92)
	_buttons["jump"] = [br, r + 8.0, "Jump", "tap"]
	_buttons["hit"] = [br + Vector2(-118, 22), r, "Hit", "hold"]
	_buttons["place"] = [br + Vector2(-208, -46), r - 6.0, "Place", "tap"]
	_buttons["glide"] = [br + Vector2(0, -122), r - 4.0, "Glide", "tap"]
	_buttons["climb"] = [br + Vector2(-104, -100), r - 4.0, "Climb", "tap"]
	_buttons["sprint"] = [br + Vector2(-80, -206), r - 10.0, "Sprint", "hold"]
	var prompt: String = game.hud.prompt_label.text if game != null else ""
	if prompt != "":
		_buttons["use"] = [br + Vector2(-214, -170), r - 2.0, "Use", "tap"]
	var top := Vector2(sz.x - 34, 92)
	var smalls := [["pause", "II"], ["inv", "Bag"], ["craft", "Craft"], ["quest", "Quest"], ["view", "View"]]
	for i in smalls.size():
		_buttons[smalls[i][0]] = [top - Vector2(i * 64, 0), 27.0, smalls[i][1], "small"]
	_order = _buttons.keys()


func _active() -> bool:
	return enabled and game != null and game.running and not game.player.dead


func _process(_dt: float) -> void:
	var show := _active()
	if visible != show:
		visible = show
		if not show:
			_release_all()
	if visible:
		_layout()
		_draw.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not enabled:
			set_enabled(true)
	elif event is InputEventKey and event.pressed and not OS.has_feature("mobile"):
		set_enabled(false)
		return
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and not OS.has_feature("mobile"):
		# A real mouse moved: go back to mouse and keyboard.
		if (event as InputEventMouseMotion).relative.length() > 4.0 and _fingers.is_empty():
			set_enabled(false)
		return
	if not _active():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_lift(t.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position)
		get_viewport().set_input_as_handled()


func _button_at(p: Vector2) -> String:
	for n in _order:
		var b: Array = _buttons[n]
		if p.distance_to(b[0]) <= b[1] + 10.0:
			return n
	return ""


func _hotbar_slot_at(p: Vector2) -> int:
	var hb: Control = game.hud.hotbar
	var i := 0
	for c in hb.get_children():
		var cc := c as Control
		if cc != null and not cc.is_queued_for_deletion():
			if cc.get_global_rect().grow(4.0).has_point(p):
				return i
			i += 1
	return -1


func _press(i: int, p: Vector2) -> void:
	if game.talking():
		# Any tap moves the conversation on.
		game.advance_dialog()
		return
	var b := _button_at(p)
	if b != "":
		_fingers[i] = b
		_button_down(b)
		return
	var slot := _hotbar_slot_at(p)
	if slot >= 0:
		game.select_slot(slot)
		_fingers[i] = "slot"
		return
	var sz: Vector2 = _draw.size
	if p.x < sz.x * 0.42 and p.y > sz.y * 0.3 and not _fingers.values().has("stick"):
		_fingers[i] = "stick"
		_stick_origin = p
		_stick_pos = p
		move = Vector2.ZERO
	else:
		_fingers[i] = "look"
		_look_last[i] = p


func _drag(i: int, p: Vector2) -> void:
	var role: String = _fingers.get(i, "")
	if role == "stick":
		var off := p - _stick_origin
		if off.length() > STICK_R:
			# The stick follows a finger that slides past its edge.
			_stick_origin = p - off.normalized() * STICK_R
			off = p - _stick_origin
		_stick_pos = p
		var v := off / STICK_R
		var l := v.length()
		if l < DEAD:
			move = Vector2.ZERO
		else:
			v = v / l * ((l - DEAD) / (1.0 - DEAD))
			move = Vector2(v.x, -v.y)
	elif role == "look":
		var last: Vector2 = _look_last.get(i, p)
		var rel := p - last
		_look_last[i] = p
		var pl = game.player
		pl.cam_yaw -= rel.x * LOOK_SPEED
		var top := 1.5 if pl.first_person else 1.1
		pl.cam_pitch = clampf(pl.cam_pitch - rel.y * LOOK_SPEED, -1.45, top)


func _lift(i: int) -> void:
	var role: String = _fingers.get(i, "")
	_fingers.erase(i)
	_look_last.erase(i)
	if role == "stick":
		move = Vector2.ZERO
	elif role == "hit":
		game.mouse_down = false
	elif role == "sprint":
		sprint = false
	elif role == "jump":
		jump_held = false


func _button_down(b: String) -> void:
	match b:
		"jump":
			game.jump_pressed = true
			jump_held = true
		"hit":
			game.mouse_down = true
			game.set("_deny_warned", false)
		"place":
			game.place_block()
		"glide":
			game.player.toggle_glide()
		"climb":
			game.player.toggle_climb()
		"sprint":
			sprint = true
		"use":
			game.interact()
		"pause":
			game.pause()
		"inv":
			game.toggle_inventory()
		"craft":
			game.toggle_craft()
		"quest":
			game.cycle_quest()
		"view":
			game.toggle_view()
	game.audio.play("ui_click", -14.0)


# ---------------------------------------------------------------- drawing

func _paint() -> void:
	var ink := Color(1, 1, 1, 0.9)
	var fill := Color(0.06, 0.08, 0.07, 0.38)
	var edge := Color(1, 1, 1, 0.45)
	var held := {}
	for v in _fingers.values():
		held[v] = true
	# Move stick: where your thumb is, or a hint where it will appear.
	var sz: Vector2 = _draw.size
	var base := _stick_origin if held.has("stick") else Vector2(150, sz.y - 150)
	var knob := _stick_pos if held.has("stick") else base
	_draw.draw_circle(base, STICK_R, Color(0.06, 0.08, 0.07, 0.28))
	_draw.draw_arc(base, STICK_R, 0, TAU, 48, edge, 2.0, true)
	_draw.draw_circle(knob, 30.0, Color(1, 1, 1, 0.55 if held.has("stick") else 0.3))
	for n in _order:
		var b: Array = _buttons[n]
		var c: Vector2 = b[0]
		var r: float = b[1]
		var on: bool = held.has(n)
		var lit: bool = (n == "sprint" and sprint) or (n == "glide" and game.player.mode == "glide") or (n == "climb" and game.player.mode == "climb")
		var col := Color(0.95, 0.78, 0.36, 0.6) if (on or lit) else fill
		_draw.draw_circle(c, r, col)
		_draw.draw_arc(c, r, 0, TAU, 40, edge, 2.0, true)
		var fs := 15 if b[3] == "small" else (19 if n == "jump" else 17)
		var text: String = b[2]
		if n == "climb" and game.player.mode == "climb":
			text = "Let go"
		elif n == "glide" and game.player.mode == "glide":
			text = "Close"
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		_draw.draw_string_outline(_font, c + Vector2(-w / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		_draw.draw_string(_font, c + Vector2(-w / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
