extends CanvasLayer
## Everything drawn on top of the 3D view: hearts, stamina ring, hotbar,
## goals, toasts and the start, crafting and knocked-out screens.

signal play_pressed
signal craft_closed
signal respawn_pressed
signal craft_requested(index: int)

const ACCENT := Color("f2b84b")
const INK := Color("f4efe3")
const INK_DIM := Color("c9c2b0")
const PANEL := Color(0.086, 0.11, 0.094, 0.85)
const EDGE := Color(0.957, 0.937, 0.89, 0.18)
const DANGER := Color("e8564a")


class Hearts extends Control:
	var hp := 10

	func _draw() -> void:
		for i in 5:
			var v := hp - i * 2
			var col := Color("ff5a5a")
			if v == 1:
				col = Color("ffaaa0")
			elif v <= 0:
				col = Color(1, 1, 1, 0.25)
			var c := Vector2(16 + i * 30, 16)
			draw_circle(c + Vector2(-5, -3), 6.5, col)
			draw_circle(c + Vector2(5, -3), 6.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11.2, -1), c + Vector2(11.2, -1), c + Vector2(0, 12)]), col)


class Ring extends Control:
	var value := 1.0
	var tired := false

	func _draw() -> void:
		var c := size / 2.0
		draw_arc(c, 17.0, 0.0, TAU, 40, Color(0, 0, 0, 0.35), 6.0, true)
		if value > 0.001:
			var col := Color("e8564a") if tired else Color("7bd66a")
			draw_arc(c, 17.0, -PI / 2.0, -PI / 2.0 + TAU * value, 40, col, 6.0, true)


var root: Control
var hearts: Hearts
var ring: Ring
var state_label: Label
var item_label: Label
var hotbar: HBoxContainer
var toasts: VBoxContainer
var goals_box: VBoxContainer
var hurt_rect: ColorRect
var recipes_box: VBoxContainer
var start_title: Label
var play_button: Button
var screens := {}
var _name_timer := 0.0


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hurt_rect = ColorRect.new()
	hurt_rect.color = Color(0.91, 0.34, 0.29, 0.35)
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_rect.modulate.a = 0.0
	root.add_child(hurt_rect)

	# Crosshair.
	for s in [Vector2(2, 18), Vector2(18, 2)]:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.85)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(r, 0.5, 0.5, 0.5, 0.5, -s.x / 2.0, -s.y / 2.0, s.x / 2.0, s.y / 2.0)
		root.add_child(r)

	ring = Ring.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(ring, 0.5, 0.5, 0.5, 0.5, 46, -52, 90, -8)
	root.add_child(ring)

	hearts = Hearts.new()
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hearts, 0, 0, 0, 0, 16, 14, 176, 46)
	root.add_child(hearts)

	state_label = Label.new()
	state_label.add_theme_color_override("font_color", ACCENT)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(state_label, 1, 0, 1, 0, -220, 16, -16, 44)
	root.add_child(state_label)

	var goals_panel := PanelContainer.new()
	goals_panel.add_theme_stylebox_override("panel", _style(PANEL, 8, 10, 14, EDGE, 1))
	goals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(goals_panel, 0, 0, 0, 0, 16, 56, 290, 56)
	root.add_child(goals_panel)
	goals_box = VBoxContainer.new()
	goals_panel.add_child(goals_box)

	hotbar = HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(hotbar, 0.5, 1, 0.5, 1, -270, -70, 270, -16)
	root.add_child(hotbar)

	item_label = Label.new()
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(item_label, 0.5, 1, 0.5, 1, -200, -104, 200, -78)
	root.add_child(item_label)

	toasts = VBoxContainer.new()
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 6)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(toasts, 0.5, 0.22, 0.5, 0.22, -320, 0, 320, 200)
	root.add_child(toasts)

	_build_start_screen()
	_build_craft_screen()
	_build_dead_screen()


# ---------------------------------------------------------------- helpers

func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


func _style(bg: Color, radius: int, pad_v: int, pad_h: int, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb


func _label(text: String, font_size := 16, color := INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _style(ACCENT, 8, 10, 18))
	b.add_theme_stylebox_override("hover", _style(ACCENT.lightened(0.15), 8, 10, 18))
	b.add_theme_stylebox_override("pressed", _style(ACCENT.darkened(0.1), 8, 10, 18))
	b.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 8, 10, 18, Color.WHITE, 2))
	b.add_theme_stylebox_override("disabled", _style(Color("3a423c"), 8, 10, 18))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Color("1d1608"))
	b.add_theme_color_override("font_disabled_color", Color("8b9289"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


func _make_screen(key: String, title: String, body: String) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.055, 0.047, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.add_theme_stylebox_override("panel", _style(Color("18201b"), 12, 22, 26, EDGE, 1))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var t := _label(title, 30)
	box.add_child(t)
	if key == "start":
		start_title = t
	if body != "":
		box.add_child(_label(body, 16, INK_DIM, true))
	screens[key] = dim
	dim.visible = false
	return box


func _build_start_screen() -> void:
	var box := _make_screen("start", "Adventure Plus", "Prototype island. Gather blocks, craft a glider, climb the cliff to the glowing Sky Shard, and watch out for Thornlings.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	var keys := [
		["Mouse", "Look around"],
		["W A S D", "Move. Walk into a tall wall to climb it"],
		["Space", "Jump. In the air: open or close the glider. On a wall: leap up"],
		["Shift", "Sprint. On a wall or glider: let go"],
		["Left click", "Hold to break a block, click to attack"],
		["Right click", "Place the selected block"],
		["1 to 9, wheel", "Choose a hotbar slot"],
		["C", "Open crafting"],
		["V", "Switch between third and first person"],
		["Esc", "Pause"],
	]
	for k in keys:
		grid.add_child(_label(k[0], 15, ACCENT))
		var desc := _label(k[1], 15, INK, true)
		desc.custom_minimum_size = Vector2(360, 0)
		grid.add_child(desc)
	box.add_child(grid)
	play_button = _button("Play")
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	box.add_child(play_button)


func _build_craft_screen() -> void:
	var box := _make_screen("craft", "Crafting", "Recipes use what is in your hotbar.")
	recipes_box = VBoxContainer.new()
	recipes_box.add_theme_constant_override("separation", 8)
	box.add_child(recipes_box)
	var close := _button("Back to the island")
	close.pressed.connect(func() -> void: craft_closed.emit())
	box.add_child(close)


func _build_dead_screen() -> void:
	var box := _make_screen("dead", "Knocked out", "You wake up back at the beach. Your items are safe.")
	var b := _button("Get up")
	b.pressed.connect(func() -> void: respawn_pressed.emit())
	box.add_child(b)


# ---------------------------------------------------------------- API

func show_screen(key: String) -> void:
	for k in screens:
		screens[k].visible = (k == key)
	if key == "start":
		play_button.grab_focus()


func set_paused_title(paused: bool) -> void:
	start_title.text = "Paused" if paused else "Adventure Plus"
	play_button.text = "Resume" if paused else "Play"


func set_hearts(hp: int) -> void:
	hearts.hp = hp
	hearts.queue_redraw()


func set_stamina(value: float, tired: bool) -> void:
	ring.value = value
	ring.tired = tired
	ring.visible = value < 0.999
	ring.queue_redraw()


func set_state(text: String) -> void:
	state_label.text = text.to_upper()


func flash_hurt() -> void:
	hurt_rect.modulate.a = 1.0
	var tw := hurt_rect.create_tween()
	tw.tween_property(hurt_rect, "modulate:a", 0.0, 0.3)


func toast(msg: String) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(PANEL, 999, 6, 14, EDGE, 1))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.add_child(_label(msg, 15))
	toasts.add_child(pc)
	if toasts.get_child_count() > 4:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)


func show_item_name(text: String) -> void:
	item_label.text = text
	item_label.modulate.a = 1.0
	_name_timer = 1.6


func set_goals(goals: Array, done: Dictionary) -> void:
	for c in goals_box.get_children():
		c.queue_free()
	goals_box.add_child(_label("ISLAND GOALS", 12, ACCENT))
	for g in goals:
		var is_done: bool = done.has(g["id"])
		var l := _label(("✓ " if is_done else "○ ") + str(g["text"]), 14, INK_DIM if is_done else INK, true)
		goals_box.add_child(l)


func render_hotbar(slots: Array, sel: int, items: Dictionary) -> void:
	for c in hotbar.get_children():
		c.queue_free()
	for i in slots.size():
		var p := Panel.new()
		p.custom_minimum_size = Vector2(52, 52)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border := ACCENT if i == sel else EDGE
		p.add_theme_stylebox_override("panel", _style(PANEL, 8, 0, 0, border, 2))
		var key := _label(str(i + 1), 10, INK_DIM)
		key.position = Vector2(5, 1)
		p.add_child(key)
		var s = slots[i]
		if s != null:
			var icon := ColorRect.new()
			icon.color = items[s["id"]]["color"]
			icon.position = Vector2(12, 12)
			icon.size = Vector2(28, 28)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(icon)
			var n: int = s["n"]
			if n > 1:
				var cl := _label(str(n), 13)
				cl.position = Vector2(30, 30)
				cl.size = Vector2(18, 18)
				cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				p.add_child(cl)
		hotbar.add_child(p)


## rows: [{"name", "need" (BBCode), "ok", "color"}]
func render_recipes(rows: Array) -> void:
	for c in recipes_box.get_children():
		c.queue_free()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var sw := ColorRect.new()
		sw.color = row["color"]
		sw.custom_minimum_size = Vector2(26, 26)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(sw)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(row["name"], 16))
		var need := RichTextLabel.new()
		need.bbcode_enabled = true
		need.fit_content = true
		need.scroll_active = false
		need.custom_minimum_size = Vector2(300, 0)
		need.text = row["need"]
		need.add_theme_color_override("default_color", INK_DIM)
		need.add_theme_font_size_override("normal_font_size", 13)
		info.add_child(need)
		hb.add_child(info)
		var b := _button("Craft")
		b.disabled = not row["ok"]
		var idx := i
		b.pressed.connect(func() -> void: craft_requested.emit(idx))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(b)
		recipes_box.add_child(hb)


func _process(delta: float) -> void:
	if _name_timer > 0.0:
		_name_timer -= delta
		if _name_timer <= 0.0:
			var tw := item_label.create_tween()
			tw.tween_property(item_label, "modulate:a", 0.0, 0.5)
